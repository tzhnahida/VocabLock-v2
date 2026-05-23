package api

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"net"
	"net/http"
	"sync"
	"time"

	"github.com/vocablock/v2/internal/ai"
	"github.com/vocablock/v2/internal/config"
	"github.com/vocablock/v2/internal/db"
	"github.com/vocablock/v2/internal/dict"
	"github.com/vocablock/v2/internal/engine"
	"github.com/vocablock/v2/internal/tts"
)

type cachedQuestion struct {
	q         *engine.Question
	createdAt time.Time
}

var slowTypes = map[string]bool{
	"listening":    true,
	"reading_comp": true,
	"grammar":      true,
}

type Server struct {
	http   *http.Server
	Port   int
	Token  string
	Mock      bool
	Config    *config.Config
	ConfigDir string // path to configs/ directory
	DB     *db.Database

	// Optional — nil means not configured, handlers fall back gracefully
	AI         *ai.Client
	TTSProvider *tts.Provider
	DictProvider *dict.Provider

	// Question cache for AI-generated questions (maps question_id → cachedQuestion)
	questionCache   map[string]*cachedQuestion
	questionCacheMu sync.Mutex

	// Prevent double-serving: words served in the last 5 seconds are skipped
	servedWordIDs   map[int64]time.Time
	servedWordIDsMu sync.Mutex

	// Blocks quiz until initial bootstrap is complete
	bootstrapDone   bool
	bootstrapDoneMu sync.RWMutex

	// Session budget tracks time/type usage for the current day
	sessionBudget sessionBudget
}

func NewServer(mock bool, cfg *config.Config, database *db.Database) *Server {
	token := make([]byte, 16)
	rand.Read(token)

	s := &Server{
		Token:         hex.EncodeToString(token),
		Mock:          mock,
		Config:        cfg,
		DB:            database,
		questionCache: make(map[string]*cachedQuestion),
		servedWordIDs: make(map[int64]time.Time),
	}
	s.startCacheCleanup()
	return s
}

func (s *Server) Start() error {
	mux := http.NewServeMux()
	s.registerRoutes(mux)

	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return fmt.Errorf("bind: %w", err)
	}

	s.Port = listener.Addr().(*net.TCPAddr).Port
	s.http = &http.Server{
		Handler:      withMiddleware(mux, s.Token),
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 1200 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	go func() {
		if err := s.http.Serve(listener); err != nil && err != http.ErrServerClosed {
			fmt.Printf("http server error: %v\n", err)
		}
	}()

	return nil
}

func (s *Server) Shutdown() error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	return s.http.Shutdown(ctx)
}

// sessionBudget tracks time and type usage during a single day session.
type sessionBudget struct {
	mu           sync.Mutex
	date         string
	timeUsed     int
	slowCount    int
	totalCount   int
	typeWeights  map[string]int // cached from training plan's question_type_ratio
	grammarFocus []string       // cached from training plan's grammar_focus
	sessionDone  bool           // true once quiz/complete was called today
}

func (b *sessionBudget) markSessionDone() {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.sessionDone = true
	b.date = time.Now().Format("2006-01-02")
}

func (b *sessionBudget) isSessionDone() bool {
	b.mu.Lock()
	defer b.mu.Unlock()
	today := time.Now().Format("2006-01-02")
	if b.date != today {
		b.sessionDone = false
	}
	return b.sessionDone
}

func (b *sessionBudget) setTypeWeights(weights map[string]int) {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.typeWeights = weights
}

func (b *sessionBudget) getTypeWeights() map[string]int {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.typeWeights
}

func (b *sessionBudget) setGrammarFocus(focus []string) {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.grammarFocus = focus
}

func (b *sessionBudget) getGrammarFocus() []string {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.grammarFocus
}

func (b *sessionBudget) allowType(typeName string, timeBudgetMinutes int, maxSlowRatio float64) bool {
	b.mu.Lock()
	defer b.mu.Unlock()

	today := time.Now().Format("2006-01-02")
	if b.date != today {
		b.date = today
		b.timeUsed = 0
		b.slowCount = 0
		b.totalCount = 0
	}

	weight := engine.TimeWeights[typeName]
	if weight == 0 {
		weight = 1
	}

	// 0 = unlimited time budget
	if timeBudgetMinutes > 0 {
		maxUnits := timeBudgetMinutes * 6
		if b.timeUsed+weight > maxUnits {
			return false
		}
	}

	// 0 = no slow-type ratio limit
	if maxSlowRatio > 0 && engine.IsSlowType(typeName) {
		maxSlow := int(float64(b.totalCount+1) * maxSlowRatio)
		if b.slowCount >= maxSlow {
			return false
		}
	}

	return true
}

func (b *sessionBudget) recordType(typeName string) {
	b.mu.Lock()
	defer b.mu.Unlock()

	today := time.Now().Format("2006-01-02")
	if b.date != today {
		b.date = today
		b.timeUsed = 0
		b.slowCount = 0
		b.totalCount = 0
	}

	weight := engine.TimeWeights[typeName]
	if weight == 0 {
		weight = 1
	}
	b.timeUsed += weight
	b.totalCount++
	if engine.IsSlowType(typeName) {
		b.slowCount++
	}
}

// mergeTypeWeights caps slow-type weights to maxSlowRatio, redistributing excess to fast types.
func mergeTypeWeights(aiWeights map[string]int, maxSlowRatio float64) map[string]int {
	if len(aiWeights) == 0 || maxSlowRatio <= 0 {
		return aiWeights
	}
	total := 0
	slowTotal := 0
	fastTotal := 0
	for t, w := range aiWeights {
		total += w
		if slowTypes[t] {
			slowTotal += w
		} else {
			fastTotal += w
		}
	}
	if total == 0 {
		return aiWeights
	}
	slowPct := float64(slowTotal) / float64(total)
	if slowPct <= maxSlowRatio {
		return aiWeights // already within cap
	}
	// Cap slow types and redistribute excess to fast types
	maxSlow := int(float64(total) * maxSlowRatio)
	result := make(map[string]int, len(aiWeights))
	for t, w := range aiWeights {
		if slowTypes[t] {
			scaled := int(float64(w) * float64(maxSlow) / float64(slowTotal))
			if scaled < 1 && w > 0 {
				scaled = 1 // keep at least 1 for any slow type that has weight
			}
			result[t] = scaled
		} else {
			result[t] = w
		}
	}
	// Redistribute excess proportionally to fast types
	if fastTotal > 0 {
		excess := slowTotal - maxSlow
		fastWeightTotal := 0
		for t, w := range aiWeights {
			if !slowTypes[t] {
				fastWeightTotal += w
			}
		}
		if fastWeightTotal > 0 {
			for t, w := range result {
				if !slowTypes[t] {
					result[t] = w + excess*w/fastWeightTotal
				}
			}
		}
	}
	return result
}

func (s *Server) cacheQuestion(q *engine.Question) {
	s.questionCacheMu.Lock()
	defer s.questionCacheMu.Unlock()
	if len(s.questionCache) >= 2000 {
		// Evict one random entry when over limit, instead of discarding all.
		// Discarding all would lose expected answers for pending AI questions.
		for k := range s.questionCache {
			delete(s.questionCache, k)
			break
		}
	}
	s.questionCache[q.ID] = &cachedQuestion{q: q, createdAt: time.Now()}
}

func (s *Server) getAndDelCachedQuestion(id string) *engine.Question {
	s.questionCacheMu.Lock()
	defer s.questionCacheMu.Unlock()
	cq, ok := s.questionCache[id]
	if !ok {
		return nil
	}
	// Expire after 15 days
	if time.Since(cq.createdAt) > 15*24*time.Hour {
		delete(s.questionCache, id)
		return nil
	}
	delete(s.questionCache, id)
	return cq.q
}

func (s *Server) startCacheCleanup() {
	go func() {
		ticker := time.NewTicker(1 * time.Hour)
		defer ticker.Stop()
		for range ticker.C {
			s.questionCacheMu.Lock()
			now := time.Now()
			for id, cq := range s.questionCache {
				if now.Sub(cq.createdAt) > 15*24*time.Hour {
					delete(s.questionCache, id)
				}
			}
			s.questionCacheMu.Unlock()
		}
	}()
}

// markWordServed records a word as recently served to prevent double-serving.
func (s *Server) markWordServed(wordID int64) {
	s.servedWordIDsMu.Lock()
	s.servedWordIDs[wordID] = time.Now()
	// Clean expired entries (older than 10 seconds)
	for id, t := range s.servedWordIDs {
		if time.Since(t) > 10*time.Second {
			delete(s.servedWordIDs, id)
		}
	}
	s.servedWordIDsMu.Unlock()
}

// wasRecentlyServed returns true if the word was served within the last 5 seconds.
func (s *Server) wasRecentlyServed(wordID int64) bool {
	s.servedWordIDsMu.Lock()
	defer s.servedWordIDsMu.Unlock()
	t, ok := s.servedWordIDs[wordID]
	if !ok {
		return false
	}
	if time.Since(t) > 5*time.Second {
		delete(s.servedWordIDs, wordID)
		return false
	}
	return true
}

func (s *Server) markBootstrapDone() {
	s.bootstrapDoneMu.Lock()
	s.bootstrapDone = true
	s.bootstrapDoneMu.Unlock()
}

func (s *Server) isBootstrapDone() bool {
	s.bootstrapDoneMu.RLock()
	defer s.bootstrapDoneMu.RUnlock()
	return s.bootstrapDone
}


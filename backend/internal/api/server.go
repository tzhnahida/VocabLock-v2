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

type Server struct {
	http   *http.Server
	Port   int
	Token  string
	Mock   bool
	Config *config.Config
	DB     *db.Database

	// Optional — nil means not configured, handlers fall back gracefully
	AI         *ai.Client
	TTSProvider *tts.Provider
	DictProvider *dict.Provider

	// Question cache for AI-generated questions (maps question_id → Answer)
	questionCache   map[string]*engine.Question
	questionCacheMu sync.RWMutex

	// Session budget tracks time/type usage for the current day
	sessionBudget sessionBudget
}

func NewServer(mock bool, cfg *config.Config, database *db.Database) *Server {
	token := make([]byte, 16)
	rand.Read(token)

	return &Server{
		Token:         hex.EncodeToString(token),
		Mock:          mock,
		Config:        cfg,
		DB:            database,
		questionCache: make(map[string]*engine.Question),
	}
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
		WriteTimeout: 30 * time.Second,
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
	mu         sync.Mutex
	date       string
	timeUsed   int
	slowCount  int
	totalCount int
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

	maxUnits := timeBudgetMinutes * 6

	if b.timeUsed+weight > maxUnits {
		return false
	}

	if engine.IsSlowType(typeName) {
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

func (s *Server) cacheQuestion(q *engine.Question) {
	s.questionCacheMu.Lock()
	defer s.questionCacheMu.Unlock()
	if len(s.questionCache) > 1000 {
		s.questionCache = make(map[string]*engine.Question)
	}
	s.questionCache[q.ID] = q
}

func (s *Server) getAndDelCachedQuestion(id string) *engine.Question {
	s.questionCacheMu.Lock()
	defer s.questionCacheMu.Unlock()
	q, ok := s.questionCache[id]
	if ok {
		delete(s.questionCache, id)
	}
	return q
}

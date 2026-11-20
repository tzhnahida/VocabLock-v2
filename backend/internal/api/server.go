package api

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"net"
	"net/http"
	"sort"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/tzhnahida/VocabLock/internal/log"

	"github.com/tzhnahida/VocabLock/internal/ai"
	"github.com/tzhnahida/VocabLock/internal/asr"
	"github.com/tzhnahida/VocabLock/internal/clock"
	"github.com/tzhnahida/VocabLock/internal/config"
	"github.com/tzhnahida/VocabLock/internal/content"
	"github.com/tzhnahida/VocabLock/internal/db"
	"github.com/tzhnahida/VocabLock/internal/dict"
	"github.com/tzhnahida/VocabLock/internal/engine"
	"github.com/tzhnahida/VocabLock/internal/pronounce"
	"github.com/tzhnahida/VocabLock/internal/system"
	"github.com/tzhnahida/VocabLock/internal/tts"
)

// PronounceAssessor is the part of pronounce.Provider used by the handlers.
// Declaring it here lets tests substitute a fake without spawning binaries.
type PronounceAssessor interface {
	Assess(ctx context.Context, audioPath, targetText string) (*pronounce.Result, error)
}

type cachedQuestion struct {
	q         *engine.Question
	createdAt time.Time
}

type Server struct {
	http      *http.Server
	Port      int
	Token     string
	Mock      bool
	Config    *config.Config
	configMu  sync.RWMutex // guards Config field writes during concurrent bootstrap reads
	ConfigDir string       // path to configs/ directory
	DB        *db.Database

	// Optional — nil means not configured, handlers fall back gracefully
	aiValue      atomic.Value // *ai.Client, safe for concurrent access
	TTSProvider  *tts.Provider
	DictProvider *dict.Provider
	Content      *content.Library

	// Placement-test sessions live in memory with a short TTL.
	placementMu       sync.Mutex
	placementSessions map[string]*placementSession
	PronounceProvider PronounceAssessor
	ASRProvider       asr.Provider

	// Question cache for AI-generated questions (maps question_id → cachedQuestion)
	questionCache   map[string]*cachedQuestion
	questionCacheMu sync.Mutex

	// Prevent double-serving: words served in the last 5 seconds are skipped
	servedWordIDs   map[int64]time.Time
	servedWordIDsMu sync.Mutex

	// Blocks quiz until initial bootstrap is complete
	bootstrapDone   bool
	bootstrapDoneMu sync.RWMutex

	// Prevents concurrent AI word expansion
	expanding   bool
	expandingMu sync.Mutex

	// Deduplicates concurrent TTS generation requests.
	// Key: cacheKey (MD5 of provider:voice:text), Value: chan struct{} closed when done.
	ttsInFlight   map[string]chan struct{}
	ttsInFlightMu sync.Mutex
	// Bounds how many TTS pre-warm subprocesses run at once.
	ttsWarm chan struct{}

	// Silent once-a-day AI plan tuning (summary + tomorrow plan).
	tuneMu      sync.Mutex
	tuneRunning bool
	tuneDate    string

	// Session budget tracks time/type usage for the current day
	sessionBudget sessionBudget

	// System-level features (lock screen, tray, passive quiz)
	System system.SystemProvider
	// NativeShell is true when the spawned UI owns an OS-level lock window
	// (the Flutter shell). The Electron shell draws its own overlay, so the
	// server must not manipulate (or try to find) a Flutter window.
	NativeShell bool

	lockMu sync.Mutex
	locked bool

	// Escape tracking (daily limits)
	escapeMu           sync.Mutex
	escapeDate         string
	escapePasswordUsed int
	escapeClickUsed    int

	// Restart support — set by main after Flutter is spawned
	FlutterPID int
	// RestartFunc re-wires providers in place (config reload + TTS/Dict/
	// Pronounce re-init). It does NOT kill/restart the Flutter process —
	// the comment on the old code claimed otherwise.
	RestartFunc func()

	// Session time accounting (stats only — NOT an unlock condition; the
	// daily target is count-based, see DailyTargetMet). Elapsed time
	// between question interactions accumulates into daily_stats.
	timeMu         sync.Mutex
	lastActivityAt time.Time
}

// sessionGapCapSec bounds a single inter-question gap when accumulating
// study time — anything longer is treated as idle, not study.
const sessionGapCapSec = 15 * 60

// markActivity records the moment a question-interaction happens. Called
// when a session goes READY so the study/learning phase counts as time.
// Stats only; never gates unlock.
func (s *Server) markActivity() {
	s.timeMu.Lock()
	defer s.timeMu.Unlock()
	s.lastActivityAt = time.Now()
}

// consumeActivityElapsed returns the seconds since the last activity,
// clamped to sessionGapCapSec, and resets the clock. Returns 0 if the
// clock was never started (e.g. submit without session/start).
func (s *Server) consumeActivityElapsed() int {
	s.timeMu.Lock()
	defer s.timeMu.Unlock()
	if s.lastActivityAt.IsZero() {
		s.lastActivityAt = time.Now()
		return 0
	}
	elapsed := int(time.Since(s.lastActivityAt).Seconds())
	s.lastActivityAt = time.Now()
	if elapsed > sessionGapCapSec {
		elapsed = sessionGapCapSec
	}
	if elapsed < 0 {
		elapsed = 0
	}
	return elapsed
}

// aiExplLang returns the language the AI should use when speaking to the
// student (explanations, chat, judging feedback, assignments, summaries).
//
// Priority: explicit ai_explanation_lang setting > per-language
// explanation-language config > "en".
// FIX: the UI language was never propagated into the AI prompt layer —
// users with an English UI studying Japanese got AI replies in the
// language config's explanation language (e.g. Chinese) or the hardcoded
// zh-CN default in chat.
func (s *Server) aiExplLang(lang string) string {
	// Explanations are decoupled from the interface language on purpose: the
	// UI translation must not decide which language the model explains in.
	if expl := strings.TrimSpace(s.Config.App.AIExplanationLang); expl != "" {
		return expl
	}
	if lc, ok := s.Config.Languages[lang]; ok && lc.PromptContext.ExplanationLang != "" {
		return lc.PromptContext.ExplanationLang
	}
	return "en"
}

// DailyTargetMet reports whether today's learning target is satisfied.
//
// Semantics (design intent, 2026-09-02): the daily target is COUNT-based.
// "Time" is only a UX conversion (e.g. 30 min ≈ 15 questions) — there is
// NO wall-clock unlock. An earlier wiring made accumulated study time a
// second unlock path (idle 20 min → unlock); that was removed — it was
// not in the original design and let "studying" be faked by idling.
//
// Accuracy gate: once the student has answered anything, the target
// additionally requires accuracy >= MinAccuracy (default 0.8) — this is
// what the onboarding copy promises ("Accuracy >= 80% required to unlock")
// and what the old code never enforced.
//
// Exported for use by cmd/server (main.go startup lock check).
func (s *Server) DailyTargetMet(lang string) bool {
	if s.DB == nil {
		return false
	}
	// Time quota: reaching the configured minutes is enough to release the
	// focus lock, even if the question count is still short.
	if s.Config.App.DailyTimeTarget > 0 {
		if spent, err := s.DB.GetTodayTimeSpent(lang); err == nil && spent >= s.Config.App.DailyTimeTarget {
			return true
		}
	}
	reviewed, err := s.DB.GetUniqueSubjectsReviewed(lang)
	if err != nil {
		return false
	}
	if reviewed < s.Config.App.DailyTarget {
		return false
	}
	// Accuracy is attempts-based: a word answered twice counts as two attempts.
	// Using unique subjects as the denominator let one correct retry push the
	// ratio above 1.0 and bypass the accuracy gate.
	attempts, correct, err := s.DB.GetTodayStats(lang)
	if err != nil {
		return false
	}
	if attempts == 0 {
		return true
	}
	accuracy := float64(correct) / float64(attempts)
	return accuracy >= s.Config.App.MinAccuracy
}

// langHasGrammarType reports whether the language's question types include
// grammar (AI grammar questions & auto grammar expansion are only meaningful
// when the student opted into them — sim §九 ⑦).
func langHasGrammarType(lang string, cfg *config.Config) bool {
	lc, ok := cfg.Languages[lang]
	if !ok {
		return false
	}
	for _, qt := range lc.QuestionTypes {
		if qt == "grammar" {
			return true
		}
	}
	return false
}

func (s *Server) tryStartExpanding() bool {
	s.expandingMu.Lock()
	defer s.expandingMu.Unlock()
	if s.expanding {
		return false
	}
	s.expanding = true
	return true
}

// AI returns the current AI client (nil if not configured).
// Safe for concurrent access from any goroutine.
func (s *Server) AI() *ai.Client {
	v := s.aiValue.Load()
	if v == nil {
		return nil
	}
	return v.(*ai.Client)
}

// WireAI initializes (or re-initializes) the AI client from current config.
// Safe to call at startup and at runtime after config changes.
func (s *Server) WireAI() {
	if s.Config.App.AI.APIKey != "" && !s.Mock {
		client := ai.NewClient(ai.Config{
			BaseURL: s.Config.App.AI.BaseURL,
			APIKey:  s.Config.App.AI.APIKey,
			Model:   s.Config.App.AI.Model,
			Timeout: 120 * time.Second,
		})
		s.aiValue.Store(client)
		log.Info("server", "ai: configured")
	} else {
		s.aiValue.Store((*ai.Client)(nil))
		log.Debug("server", "ai: disabled")
	}
}

// WireTTS initializes (or re-initializes) the TTS provider from the active language config.
// Safe to call at startup and after active_lang changes.
func (s *Server) WireTTS() {
	s.TTSProvider = nil
	lang := s.Config.App.ActiveLang
	lc, ok := s.Config.Languages[lang]
	if !ok || lc.TTS.Provider == "" || s.Mock {
		return
	}
	provCfg, ok := s.Config.TTS.TTS.Providers[lc.TTS.Provider]
	if !ok {
		return
	}
	provider, err := tts.NewProvider(lc.TTS.Provider, provCfg, "data/audio")
	if err != nil {
		log.Warn("tts", "wire: %v", err)
		return
	}
	s.TTSProvider = provider
	log.Info("server", "tts: %s (%s)", lc.TTS.Provider, lc.TTS.Voice)
}

// WireDict initializes (or re-initializes) the dictionary provider from the active language config.
// Safe to call at startup and after active_lang changes.
func (s *Server) WireDict() {
	s.DictProvider = nil
	lang := s.Config.App.ActiveLang
	lc, ok := s.Config.Languages[lang]
	if !ok || lc.Dict.Provider == "" || s.Mock {
		return
	}
	provCfg, ok := s.Config.Dict.Dict.Providers[lc.Dict.Provider]
	if !ok {
		return
	}
	s.DictProvider = dict.NewProvider(lc.Dict.Provider, provCfg)
	log.Info("server", "dict: %s", lc.Dict.Provider)
}

// WirePronounce initializes (or re-initializes) the pronounce provider from the active language config.
// Safe to call at startup and after active_lang changes.
func (s *Server) WirePronounce() {
	s.PronounceProvider = nil
	lang := s.Config.App.ActiveLang
	lc, ok := s.Config.Languages[lang]
	if !ok || lc.Pronounce.Provider == "" || s.Mock {
		return
	}
	provCfg, ok := s.Config.Pronounce.Pronounce.Providers[lc.Pronounce.Provider]
	if !ok {
		return
	}
	// Providers are language-specific (the julius kit scores Japanese with a
	// JNAS acoustic model). Wiring a ja provider into an English course would
	// grade English audio against Japanese phonemes and return meaningless
	// zeros, so a declared mismatch disables read-aloud instead.
	if provCfg.Lang != "" && baseLanguage(provCfg.Lang) != baseLanguage(lang) {
		log.Warn("server", "pronounce: provider %q scores %s, not %s — disabled",
			lc.Pronounce.Provider, provCfg.Lang, lang)
		return
	}
	s.PronounceProvider = pronounce.NewProvider(lc.Pronounce.Provider, provCfg)
	log.Info("server", "pronounce: %s (%s)", lc.Pronounce.Provider, provCfg.Lang)
}

// WireASR initializes (or re-initializes) the local speech-to-text provider.
// Speech answers stay disabled when asr.yaml is absent or the provider is
// not configured — the rest of the app must keep working without it.
func (s *Server) WireASR() {
	s.ASRProvider = nil
	if s.Mock {
		return
	}
	name := strings.TrimSpace(s.Config.ASR.ASR.Provider)
	if name == "" {
		return
	}
	provCfg, ok := s.Config.ASR.ASR.Providers[name]
	if !ok {
		log.Warn("asr", "provider %q not found", name)
		return
	}
	// "auto" is unsafe for a multilingual learner: whisper detects a clear
	// zh/ja clip as English surprisingly often and then translates it instead
	// of transcribing. Prefer the language the app is actually teaching;
	// an explicit non-auto value in asr.yaml remains an override.
	provCfg.Language = resolveASRLanguage(provCfg.Language, s.Config.App.ActiveLang)
	provider, err := asr.NewWhisper(name, provCfg)
	if err != nil {
		log.Warn("asr", "wire: %v", err)
		return
	}
	s.ASRProvider = provider
	log.Info("server", "asr: %s", name)
}

// baseLanguage trims a region suffix so ja-JP and ja compare equal.
func baseLanguage(code string) string {
	code = strings.TrimSpace(strings.ToLower(code))
	if i := strings.IndexAny(code, "-_"); i > 0 {
		return code[:i]
	}
	return code
}

// resolveASRLanguage picks the whisper language code for the active course.
// A configured en/ja/zh value wins; empty or "auto" follows active_lang.
func resolveASRLanguage(configured, active string) string {
	configured = strings.TrimSpace(configured)
	if configured != "" && !strings.EqualFold(configured, "auto") {
		return configured
	}
	active = strings.TrimSpace(active)
	if active == "" {
		return "auto"
	}
	// Active course keys are ISO-639-1 (en/ja/zh); trim a region suffix if a
	// future config uses zh-CN/ja-JP.
	if i := strings.IndexAny(active, "-_"); i > 0 {
		active = active[:i]
	}
	return active
}

func (s *Server) stopExpanding() {
	s.expandingMu.Lock()
	s.expanding = false
	s.expandingMu.Unlock()
}

func (s *Server) isExpanding() bool {
	s.expandingMu.Lock()
	defer s.expandingMu.Unlock()
	return s.expanding
}

// hasNativeLock reports whether server-side lock calls can do anything.
func (s *Server) hasNativeLock() bool { return s.NativeShell && s.System != nil }

// MarkLocked records the lock state. The Electron shell polls /system/status
// and opens or closes its kiosk window accordingly, so the decision (daily
// target, emergency escape) stays on the server while the window is the shell.
func (s *Server) MarkLocked(locked bool) {
	s.lockMu.Lock()
	defer s.lockMu.Unlock()
	s.locked = locked
}

// IsLocked reports the current lock state.
func (s *Server) IsLocked() bool {
	s.lockMu.Lock()
	defer s.lockMu.Unlock()
	return s.locked
}

// enterNativeLock starts a lock. The Flutter shell gets a topmost native
// window; the Electron shell gets the keyboard shield only, because it draws
// the lock UI itself.
func (s *Server) enterNativeLock() error {
	s.MarkLocked(true)
	if s.System == nil {
		return nil
	}
	if !s.hasNativeLock() {
		return s.System.EnterLockShield()
	}
	_ = s.System.FullscreenFlutterWindow()
	hwnd, _ := s.System.FindFlutterWindow()
	return s.System.EnterLockMode(hwnd)
}

// exitNativeLock releases whichever lock the shell owns.
func (s *Server) exitNativeLock() {
	s.MarkLocked(false)
	if s.System == nil {
		return
	}
	if !s.hasNativeLock() {
		_ = s.System.ExitLockShield()
		return
	}
	_ = s.System.ExitLockMode()
	_ = s.System.RestoreFlutterWindow()
}

// EnterLock starts the lock (window for Flutter, keyboard shield for Electron).
func (s *Server) EnterLock() error { return s.enterNativeLock() }

// ReleaseLock is the emergency-escape callback: the Win32 hook fires it when
// the user presses Ctrl+Shift+Q while the shield is up.
func (s *Server) ReleaseLock() { s.exitNativeLock() }

func NewServer(mock bool, cfg *config.Config, database *db.Database) *Server {
	token := make([]byte, 16)
	if _, err := rand.Read(token); err != nil {
		panic(fmt.Sprintf("crypto/rand.Read failed: %v", err))
	}

	s := &Server{
		Token:         hex.EncodeToString(token),
		Mock:          mock,
		Config:        cfg,
		DB:            database,
		questionCache: make(map[string]*cachedQuestion),
		servedWordIDs: make(map[int64]time.Time),
		ttsInFlight:   make(map[string]chan struct{}),
		ttsWarm:       make(chan struct{}, 2),
	}
	s.startCacheCleanup()
	return s
}

func (s *Server) Start() error {
	mux := http.NewServeMux()
	s.registerRoutes(mux)

	addr := "127.0.0.1:0"
	if s.Port != 0 { // tests pin the port; normal runs stay random
		addr = fmt.Sprintf("127.0.0.1:%d", s.Port)
	}
	listener, err := net.Listen("tcp", addr)
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
			log.Error("server", "http serve: %v", err)
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
	mu            sync.Mutex
	date          string
	timeUsed      int
	slowCount     int
	totalCount    int
	typeWeights   map[string]int // cached from training plan's question_type_ratio
	grammarFocus  []string       // cached from training plan's grammar_focus
	sessionDone   bool           // true once quiz/complete was called today
	forceContinue bool           // student opted in past the soft cap (see hitSoftCap)

	// Time-budget plan (design B): daily target questions, cut down when the
	// session_time_budget cannot fit them. Empty when no budget is set.
	planKey    string
	planTotal  int
	planQuotas map[string]int
	planServed map[string]int
}

func (b *sessionBudget) reset() {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.date = ""
	b.timeUsed = 0
	b.slowCount = 0
	b.totalCount = 0
	b.sessionDone = false
	b.forceContinue = false
	b.planKey = ""
	b.planTotal = 0
	b.planQuotas = nil
	b.planServed = nil
}

// rolloverLocked resets the day-accumulated counters when the calendar day
// changed. Callers must hold b.mu. (hitSoftCap previously lacked this check —
// yesterday's totalCount kept the soft cap permanently triggered, see sim §九.)
func (b *sessionBudget) rolloverLocked() {
	today := clock.Today()
	if b.date != today {
		b.date = today
		b.timeUsed = 0
		b.slowCount = 0
		b.totalCount = 0
		b.forceContinue = false
		b.planKey = ""
		b.planTotal = 0
		b.planQuotas = nil
		b.planServed = nil
	}
}

// hitSoftCap reports whether today's session exceeded the soft cap (1.5×
// daily target, min +10) without meeting the target. The day does not end
// silently — the student chooses: continue training (POST /quiz/session/
// continue) or stop (the completion screen shows the remaining gap).
// Without this, a sub-80%-accuracy student was served an unbounded number
// of questions every day (simulation S2: 100+/day).
func (b *sessionBudget) hitSoftCap(dailyTarget int) bool {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.rolloverLocked()
	cap := dailyTarget + dailyTarget/2
	if cap < dailyTarget+10 {
		cap = dailyTarget + 10
	}
	return b.totalCount >= cap
}

// ensurePlan recomputes the per-type quotas when the target, budget or
// training-plan weights changed (including once per new day).
func (b *sessionBudget) ensurePlan(target, budget int, weights map[string]int, available []engine.QuestionType) engine.SessionPlan {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.rolloverLocked()

	keyParts := make([]string, 0, len(weights)+len(available))
	for k, v := range weights {
		keyParts = append(keyParts, fmt.Sprintf("w:%s=%d", k, v))
	}
	sort.Strings(keyParts)
	for _, t := range available {
		keyParts = append(keyParts, "t:"+string(t))
	}
	key := fmt.Sprintf("%d|%d|%s", target, budget, strings.Join(keyParts, ","))

	if b.planKey != key {
		plan := engine.PlanSession(target, budget, weights, available)
		b.planKey = key
		b.planTotal = plan.Total
		b.planQuotas = make(map[string]int, len(plan.Quotas))
		for t, quota := range plan.Quotas {
			b.planQuotas[string(t)] = quota
		}
		b.planServed = map[string]int{}
	}
	return engine.SessionPlan{Total: b.planTotal}
}

// planExhausted reports whether the day's question count or time budget is
// used up. The student can still choose to continue deliberately.
func (b *sessionBudget) planExhausted(budgetMinutes int) bool {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.rolloverLocked()
	if b.planTotal > 0 && b.totalCount >= b.planTotal {
		return true
	}
	if budgetMinutes > 0 && b.timeUsed >= budgetMinutes*6 {
		return true
	}
	return false
}

// typeAvailable reports whether a type still has quota left in today's plan.
func (b *sessionBudget) typeAvailable(typeName string) bool {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.rolloverLocked()
	if b.forceContinue || b.planQuotas == nil {
		return true
	}
	quota, ok := b.planQuotas[typeName]
	if !ok {
		return false
	}
	return b.planServed[typeName] < quota
}

// dropPlan clears the budget plan when the student turns the budget off.
func (b *sessionBudget) dropPlan() {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.planKey = ""
	b.planTotal = 0
	b.planQuotas = nil
	b.planServed = nil
}

func (b *sessionBudget) plannedQuestions() int {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.planTotal
}

func (b *sessionBudget) setForceContinue(v bool) {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.forceContinue = v
}

func (b *sessionBudget) isForceContinue() bool {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.forceContinue
}

func (b *sessionBudget) markSessionDone() {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.sessionDone = true
	b.date = clock.Today()
}

func (b *sessionBudget) isSessionDone() bool {
	b.mu.Lock()
	defer b.mu.Unlock()
	today := clock.Today()
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

	b.rolloverLocked()

	// "Continue deliberately" lifts every budget/quota limit for today.
	if b.forceContinue {
		return true
	}

	if b.planQuotas != nil {
		quota, ok := b.planQuotas[typeName]
		if !ok || b.planServed[typeName] >= quota {
			return false
		}
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

// recordStudyTime adds preview/read-along time to the daily budget. Study cards
// are not questions, but the time spent on them still consumes the session.
func (b *sessionBudget) recordStudyTime(seconds int) int {
	if seconds <= 0 {
		return 0
	}
	if seconds > 300 {
		seconds = 300
	}
	b.mu.Lock()
	defer b.mu.Unlock()
	b.rolloverLocked()
	b.timeUsed += (seconds + 9) / 10
	return b.timeUsed
}

func (b *sessionBudget) recordType(typeName string) {
	b.mu.Lock()
	defer b.mu.Unlock()

	b.rolloverLocked()

	weight := engine.TimeWeights[typeName]
	if weight == 0 {
		weight = 1
	}
	b.timeUsed += weight
	b.totalCount++
	if b.planServed != nil {
		b.planServed[typeName]++
	}
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
		if engine.IsSlowType(t) {
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
		if engine.IsSlowType(t) {
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
			if !engine.IsSlowType(t) {
				fastWeightTotal += w
			}
		}
		if fastWeightTotal > 0 {
			for t, w := range result {
				if !engine.IsSlowType(t) {
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
// Uses the injectable clock so the "recent" window is defined in application
// time (simulation/time-travel friendly), not raw wall-clock.
func (s *Server) markWordServed(wordID int64) {
	s.servedWordIDsMu.Lock()
	s.servedWordIDs[wordID] = clock.Now()
	// Clean expired entries (older than 10 seconds)
	for id, t := range s.servedWordIDs {
		if clock.Now().Sub(t) > 10*time.Second {
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
	if clock.Now().Sub(t) > 5*time.Second {
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

func (s *Server) markBootstrapNotDone() {
	s.bootstrapDoneMu.Lock()
	s.bootstrapDone = false
	s.bootstrapDoneMu.Unlock()
}

func (s *Server) isBootstrapDone() bool {
	s.bootstrapDoneMu.RLock()
	defer s.bootstrapDoneMu.RUnlock()
	return s.bootstrapDone
}

// HasPronounce returns true if a pronunciation assessment provider is configured.
func (s *Server) HasPronounce() bool {
	return s.PronounceProvider != nil
}

// HasASR returns true if a speech-to-text provider is configured.
func (s *Server) HasASR() bool {
	return s.ASRProvider != nil
}

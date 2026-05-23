package api

import (
	"context"
	"encoding/json"
	"net/http"
	"strings"
	"time"

	"github.com/vocablock/v2/internal/ai"
	"github.com/vocablock/v2/internal/api/mock"
	"github.com/vocablock/v2/internal/config"
	"github.com/vocablock/v2/internal/db"
	"github.com/vocablock/v2/internal/engine"
	"github.com/vocablock/v2/internal/engine/judge"
)

// nonAITypes are question types that work without AI.
var nonAITypes = []engine.QuestionType{
	engine.TypeChoice,
	engine.TypeFill,
	engine.TypeSpelling,
	engine.TypePronounce,
}

// langQuestionTypes extracts the QuestionType list from the active language config.
func langQuestionTypes(lang string, cfg *config.Config) []engine.QuestionType {
	lc, ok := cfg.Languages[lang]
	if !ok || len(lc.QuestionTypes) == 0 {
		return nonAITypes
	}
	types := make([]engine.QuestionType, len(lc.QuestionTypes))
	for i, s := range lc.QuestionTypes {
		types[i] = engine.QuestionType(s)
	}
	return types
}

func (s *Server) handleQuizProgress(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleQuizProgress(w, r); return
	}
	if s.DB == nil {
		writeError(w, 500, "database not available")
		return
	}

	lang := s.Config.App.ActiveLang
	reviewed, remaining, err := s.DB.GetQuizProgress(lang, s.Config.App.DailyTarget)
	if err != nil {
		writeError(w, 500, "query progress: "+err.Error())
		return
	}

	writeJSON(w, map[string]interface{}{
		"reviewed_today": reviewed,
		"remaining":      remaining,
		"daily_target":   s.Config.App.DailyTarget,
	})
}

func (s *Server) handleQuizSessionStart(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleQuizSessionStart(w, r); return
	}
	if s.DB == nil {
		writeError(w, 500, "database not available")
		return
	}

	lang := s.Config.App.ActiveLang
	nw, ng, rw, rg, err := s.DB.SessionCounts(lang)
	if err != nil {
		writeError(w, 500, "session counts: "+err.Error())
		return
	}

	// If no words exist yet but AI is configured, words are being generated
	if nw == 0 && rw == 0 && s.AI != nil {
		_, total, _ := s.DB.ListWords(lang, 1, 0)
		if total == 0 {
			writeJSON(w, map[string]interface{}{
				"new_words":       0,
				"new_grammar":     0,
				"review_words":    0,
				"review_grammar":  0,
				"preparing":       true,
			})
			return
		}
	}

	// If a session was already completed today, learning is done
	if s.sessionBudget.isSessionDone() {
		writeJSON(w, map[string]interface{}{
			"new_words":       0,
			"new_grammar":     0,
			"review_words":    0,
			"review_grammar":  0,
			"daily_completed": true,
		})
		return
	}

	// Check if daily target already met — today's learning is done
	reviewed, _, _ := s.DB.GetTodayStats(lang)
	if reviewed >= s.Config.App.DailyTarget {
		writeJSON(w, map[string]interface{}{
			"new_words":       0,
			"new_grammar":     0,
			"review_words":    0,
			"review_grammar":  0,
			"daily_completed": true,
		})
		return
	}

	// Cache plan's question type weights for this session
	s.cachePlanWeights(lang)

	writeJSON(w, map[string]interface{}{
		"new_words":    nw,
		"new_grammar":  ng,
		"review_words": rw,
		"review_grammar": rg,
	})
}

func (s *Server) handleQuizNext(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleQuizNext(w, r, s.Config.App.ActiveLang); return
	}
	if s.DB == nil {
		writeError(w, 500, "database not available")
		return
	}

	lang := s.Config.App.ActiveLang

	// Resolve explanation language (e.g. "zh-CN", "ko", "en") for prompt i18n
	explLang := "en"
	if lc, ok := s.Config.Languages[lang]; ok && lc.PromptContext.ExplanationLang != "" {
		explLang = lc.PromptContext.ExplanationLang
	}

	// Get words and grammar points due for review
	words, err := s.DB.GetReviewWords(lang, 10)
	if err != nil {
		writeError(w, 500, "get review words: "+err.Error())
		return
	}

	grammarPoints, err := s.DB.GetReviewGrammarPoints(lang, 5)
	if err != nil {
		writeError(w, 500, "get review grammar: "+err.Error())
		return
	}
	// Prioritize grammar points matching the plan's grammar_focus
	prioritizeGrammarByPlan(grammarPoints, s.sessionBudget.getGrammarFocus())

	if len(words) == 0 && len(grammarPoints) == 0 {
		// No items to review — return completed, don't expand here.
		// Word expansion happens after summarize (end of session).
	}

	if len(words) == 0 && len(grammarPoints) == 0 {
		writeJSON(w, map[string]interface{}{
			"completed": true,
			"message":   "No items to review",
		})
		return
	}

	// Determine which item comes next: first by NULL next_review_at (new items),
	// then by next_review_at ASC. Grammar and words are interleaved equally.
	wi, gi := 0, 0
	var q *engine.Question
	var currentWord *db.Word // captured for response enrichment

	for q == nil {
		// Pick the higher-priority item
		pickWord := false
		if gi >= len(grammarPoints) {
			pickWord = true
		} else if wi < len(words) {
			pickWord = compareWordGrammarPriority(words[wi], grammarPoints[gi])
		}

		if pickWord {
			word := words[wi]
			wi++
			currentWord = word
			// Skip words served within the last few seconds (prevents double-serving)
			if s.wasRecentlyServed(word.ID) {
				continue
			}
			s.markWordServed(word.ID)
			info := wordToInfo(word)
			distractors := s.buildDistractors(word, words[wi:], lang)

			qType := engine.SelectQuestionTypeWithWeights(
				word.NextReviewAt, word.EasinessFactor, word.Interval, word.Repetitions,
				langQuestionTypes(lang, s.Config), s.AI != nil,
				s.sessionBudget.getTypeWeights(),
			)

			if !s.sessionBudget.allowType(string(qType), s.Config.App.SessionTimeBudget, s.Config.App.MaxSlowTypeRatio) {
				fastTypes := []engine.QuestionType{engine.TypeChoice, engine.TypeFill, engine.TypePronounce}
				for _, ft := range fastTypes {
					if engine.TimeWeights[string(ft)] < engine.TimeWeights[string(qType)] {
						qType = ft
						break
					}
				}
			}
			s.sessionBudget.recordType(string(qType))

			switch qType {
			case engine.TypeChoice:
				q = engine.GenerateChoice(info, distractors, explLang)
			case engine.TypeFill:
				q = engine.GenerateFill(info, explLang)
			case engine.TypeSpelling:
				q = engine.GenerateSpelling(info, explLang)
			case engine.TypePronounce:
				q = engine.GeneratePronounce(info, explLang)
			case engine.TypeListening, engine.TypeReadingComp, engine.TypeGrammar:
				q, err = s.aiGenerateQuestion(r.Context(), info, qType)
				if err != nil {
					q = engine.GenerateChoice(info, distractors, explLang)
				} else {
					s.cacheQuestion(q)
				}
			default:
				q = engine.GenerateChoice(info, distractors, explLang)
			}
		} else {
			gp := grammarPoints[gi]
			gi++

			// Tiered grammar questions: choice first (reps<3), AI later
			if gp.Repetitions < 3 {
				ginfo := &engine.GrammarInfo{
					ID: gp.ID, Title: gp.Title,
					Explanation: gp.Explanation, Example: gp.Example,
				}
				// Build distractors from other grammar points' explanations
				var gdist []string
				for j, g2 := range grammarPoints {
					if j != gi-1 && g2.Explanation != "" {
						gdist = append(gdist, g2.Explanation)
					}
				}
				q = engine.GenerateGrammarChoice(ginfo, gdist, explLang)
				s.sessionBudget.recordType(string(engine.TypeChoice))
			} else {
				if s.AI == nil {
					continue
				}
				q, err = s.aiGenerateGrammarQuestion(r.Context(), gp)
				if err != nil {
					continue
				}
				s.cacheQuestion(q)
				s.sessionBudget.recordType(string(engine.TypeGrammar))
			}
		}
	}

	resp := map[string]interface{}{
		"id":           q.ID,
		"type":         q.Type,
		"subject_type": q.SubjectType,
		"subject_id":   q.SubjectID,
		"prompt":       q.Prompt,
	}
	if len(q.Options) > 0 {
		resp["options"] = q.Options
	}
	// Attach word data for preview card (choice/pronounce questions)
	if q.SubjectType == "word" && currentWord != nil {
		resp["subject_word"] = currentWord.Word
		resp["subject_reading"] = currentWord.Reading
		resp["subject_meaning"] = currentWord.Meaning
	}
	writeJSON(w, resp)
}

// compareWordGrammarPriority returns true if the word should come before the grammar point.
// Priority: NULL next_review_at (new items) first, then earlier next_review_at.
func compareWordGrammarPriority(w *db.Word, g *db.GrammarPoint) bool {
	if w.NextReviewAt == nil && g.NextReviewAt != nil {
		return true
	}
	if w.NextReviewAt != nil && g.NextReviewAt == nil {
		return false
	}
	if w.NextReviewAt == nil && g.NextReviewAt == nil {
		return true // both new, word first
	}
	return w.NextReviewAt.Before(*g.NextReviewAt)
}

func (s *Server) handleQuizSubmit(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleQuizSubmit(w, r); return
	}
	if s.DB == nil {
		writeError(w, 500, "database not available")
		return
	}

	var req struct {
		QuestionID   string `json:"question_id"`
		SubjectType  string `json:"subject_type"`
		SubjectID    int64  `json:"subject_id"`
		QuestionType string `json:"question_type"`
		Answer       string `json:"answer"`
	}
	if err := readJSON(r, &req); err != nil {
		writeError(w, 400, "invalid request body")
		return
	}

	// Default subject_type for backward compat with old clients
	if req.SubjectType == "" {
		req.SubjectType = "word"
	}

	// Retrieve expected answer from cache (AI-generated questions)
	primaryExpected := ""
	if cachedQ := s.getAndDelCachedQuestion(req.QuestionID); cachedQ != nil {
		primaryExpected = cachedQ.Answer
	}

	var (
		expected   []string
		word       *db.Word
		grammar    *db.GrammarPoint
		aiCallback func(user, expected string) (*judge.Result, error)
	)

	switch req.SubjectType {
	case "grammar":
		var err error
		grammar, err = s.DB.GetGrammarPoint(req.SubjectID)
		if err != nil {
			writeError(w, 500, "get grammar point: "+err.Error())
			return
		}
		if grammar == nil {
			writeError(w, 404, "grammar point not found")
			return
		}
		if primaryExpected == "" {
			// Cache miss -- return friendly error instead of HTTP 400
			writeJSON(w, map[string]interface{}{
				"correct":  false,
				"feedback": "Question expired, please get a new one",
				"source":   "cache_miss",
			})
			return
		}
		expected = []string{primaryExpected}
	default: // "word"
		var err error
		word, err = s.DB.GetWord(req.SubjectID)
		if err != nil {
			writeError(w, 500, "get word: "+err.Error())
			return
		}
		if word == nil {
			writeError(w, 404, "word not found")
			return
		}
		if primaryExpected == "" {
			expected = expectedAnswers(req.QuestionType, word)
			primaryExpected = expected[0]
		} else {
			expected = []string{primaryExpected}
		}
		if s.AI != nil {
			aiCallback = s.makeAIJudge(req.QuestionType, word)
		}
	}

	strictness := strictnessForType(req.QuestionType)
	result := judge.Judge(req.Answer, expected, strictness, aiCallback)

	// Update SM-2 on the right table
	quality := engine.QualityFromScore(result.Score)
	now := time.Now()

	switch req.SubjectType {
	case "grammar":
		sm2 := engine.SM2(grammar.EasinessFactor, grammar.Interval, grammar.Repetitions, quality, now, 0)
		if sm2 != nil {
			grammar.EasinessFactor = sm2.EasinessFactor
			grammar.Interval = sm2.Interval
			grammar.Repetitions = sm2.Repetitions
			grammar.NextReviewAt = &sm2.NextReviewAt
		}
		grammar.LastReviewAt = &now
		grammar.TotalAttempts++
		if result.Correct {
			grammar.TotalCorrect++
		}
		if err := s.DB.UpdateGrammarPoint(grammar); err != nil {
			writeError(w, 500, "update grammar point: "+err.Error())
			return
		}
	default:
		sm2 := engine.SM2(word.EasinessFactor, word.Interval, word.Repetitions, quality, now, s.Config.App.Sm2MaxIntervalDays)
		if sm2 != nil {
			word.EasinessFactor = sm2.EasinessFactor
			word.Interval = sm2.Interval
			word.Repetitions = sm2.Repetitions
			word.NextReviewAt = &sm2.NextReviewAt
		}
		word.LastReviewAt = &now
		word.TotalAttempts++
		if result.Correct {
			word.TotalCorrect++
		}
		if err := s.DB.UpdateWord(word); err != nil {
			writeError(w, 500, "update word: "+err.Error())
			return
		}
	}

	// Log review
	qType := req.QuestionType
	if qType == "" {
		qType = "choice"
	}
	logEntry := &db.ReviewLog{
		SubjectType:    req.SubjectType,
		SubjectID:      req.SubjectID,
		QuestionType:   qType,
		UserAnswer:     req.Answer,
		ExpectedAnswer: primaryExpected,
		Correct:        result.Correct,
		Score:          result.Score,
		Source:         string(result.Source),
	}
	if req.SubjectType == "word" {
		logEntry.WordID = req.SubjectID
	}
	s.DB.InsertReviewLog(logEntry)

	// Update daily stats for heatmap / streak
	correctCount := 0
	if result.Correct {
		correctCount = 1
	}
	s.DB.UpsertDailyStats(now.Format("2006-01-02"), 1, correctCount, 0)

	var nextReviewAt *time.Time
	if word != nil {
		nextReviewAt = word.NextReviewAt
	} else if grammar != nil {
		nextReviewAt = grammar.NextReviewAt
	}

	writeJSON(w, map[string]interface{}{
		"correct":        result.Correct,
		"score":          result.Score,
		"feedback":       result.Feedback,
		"source":         result.Source,
		"next_review_at": nextReviewAt,
	})
}

func (s *Server) handleQuizTodayStats(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleQuizTodayStats(w, r); return
	}
	if s.DB == nil {
		writeError(w, 500, "database not available")
		return
	}

	lang := s.Config.App.ActiveLang
	reviewed, correct, err := s.DB.GetTodayStats(lang)
	if err != nil {
		writeError(w, 500, "get today stats: "+err.Error())
		return
	}

	accuracy := 0.0
	if reviewed > 0 {
		accuracy = float64(correct) / float64(reviewed)
	}

	writeJSON(w, map[string]interface{}{
		"reviewed": reviewed,
		"correct":  correct,
		"accuracy": accuracy,
	})
}

func (s *Server) handleQuizComplete(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleQuizComplete(w, r); return
	}

	s.sessionBudget.markSessionDone()

	lang := s.Config.App.ActiveLang
	reviewed, _, _ := s.DB.GetTodayStats(lang)

	writeJSON(w, map[string]interface{}{
		"completed":        true,
		"daily_target_met": reviewed >= s.Config.App.DailyTarget,
	})
}

// ——— helpers ———

func wordToInfo(w *db.Word) *engine.WordInfo {
	return &engine.WordInfo{
		ID:      w.ID,
		Word:    w.Word,
		Reading: w.Reading,
		Meaning: w.Meaning,
		POS:     w.POS,
	}
}

func wordsToInfos(words []*db.Word) []*engine.WordInfo {
	infos := make([]*engine.WordInfo, len(words))
	for i, w := range words {
		infos[i] = wordToInfo(w)
	}
	return infos
}

// expectedAnswers returns acceptable answers for a question type.
// For fill/spelling, both Word and Reading are accepted (if non-empty and distinct),
// so typing kana instead of kanji (or vice versa) is also correct.
func expectedAnswers(qType string, w *db.Word) []string {
	switch engine.QuestionType(qType) {
	case engine.TypeFill, engine.TypeSpelling:
		return dedupNonEmpty(w.Word, w.Reading)
	case engine.TypePronounce:
		return nonEmpty(w.Reading)
	case engine.TypeListening:
		return nonEmpty(w.Meaning)
	default:
		return nonEmpty(w.Meaning)
	}
}

func nonEmpty(s string) []string {
	if s == "" {
		return nil
	}
	return []string{s}
}

func dedupNonEmpty(a, b string) []string {
	if a == "" && b == "" {
		return nil
	}
	if a == "" {
		return []string{b}
	}
	if b == "" || a == b {
		return []string{a}
	}
	return []string{a, b}
}

func strictnessForType(qType string) judge.Strictness {
	switch engine.QuestionType(qType) {
	case engine.TypeSpelling:
		return judge.Strict
	default:
		return judge.Normal
	}
}

func (s *Server) makeAIJudge(qType string, word *db.Word) func(user, expected string) (*judge.Result, error) {
	return func(userAnswer, expectedAnswer string) (*judge.Result, error) {
		if s.AI == nil {
			return nil, nil
		}

		pt, err := ai.LoadPrompt("judge")
		if err != nil {
			return nil, err
		}

		// Determine explanation language from active language config
		explLang := "en"
		if lc, ok := s.Config.Languages[s.Config.App.ActiveLang]; ok {
			explLang = lc.PromptContext.ExplanationLang
		}

		messages, err := pt.BuildMessages(&ai.PromptVars{
			Word:            word.Word,
			Reading:         word.Reading,
			Meaning:         word.Meaning,
			UserAnswer:      userAnswer,
			ExpectedAnswer:  expectedAnswer,
			ExplanationLang: explLang,
		})
		if err != nil {
			return nil, err
		}

		ctx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
		defer cancel()

		response, err := s.AI.Chat(ctx, messages, pt.Temperature)
		if err != nil {
			return nil, err
		}

		// Parse AI JSON response
		var aiResult struct {
			Correct  bool    `json:"correct"`
			Score    float64 `json:"score"`
			Feedback string  `json:"feedback"`
		}
		if err := json.Unmarshal([]byte(response), &aiResult); err != nil {
			return nil, err
		}

		return &judge.Result{
			Correct:  aiResult.Correct,
			Score:    aiResult.Score,
			Feedback: aiResult.Feedback,
		}, nil
	}
}

// buildDistractors returns 3 unique-meaning WordInfo distractors for a choice question.
// Uses remaining words first, then queries DB to fill shortages.
func (s *Server) buildDistractors(word *db.Word, remaining []*db.Word, lang string) []*engine.WordInfo {
	result := make([]*engine.WordInfo, 0, 3)
	seen := map[string]bool{word.Meaning: true}

	addIfNew := func(w *db.Word) bool {
		if w == nil || w.Meaning == "" || w.ID == word.ID || seen[w.Meaning] {
			return false
		}
		seen[w.Meaning] = true
		result = append(result, wordToInfo(w))
		return false // keep collecting until we have 3
	}

	for _, w := range remaining {
		addIfNew(w)
		if len(result) >= 3 {
			return result
		}
	}

	// Fallback: query more words from DB (with offset to vary)
	if s.DB != nil && len(result) < 3 {
		// Try multiple offsets to get different words
		for offset := 0; offset < 50 && len(result) < 3; offset += 10 {
			extra, total, _ := s.DB.ListWords(lang, 20, offset)
			for _, w := range extra {
				addIfNew(w)
				if len(result) >= 3 {
					return result
				}
			}
			if offset >= total {
				break
			}
		}
	}

	return result
}

// planExpandParams returns the expand count and context string based on the active plan.
// Falls back to app config when no plan exists or plan data is incomplete.
func (s *Server) planExpandParams(lang string) (count int, extraCtx string) {
	count = s.Config.App.ExpandBatchSize
	extraCtx = "general"

	plan, err := s.DB.GetActivePlan(lang)
	if err != nil || plan == nil {
		return
	}
	if plan.Direction == "complete" || plan.Direction == "review-only" {
		return
	}

	extraCtx = plan.Direction

	tw := parsePlanTomorrow(plan.PlanJSON)
	if tw == nil {
		return
	}
	if tw.WordCount > 0 {
		count = tw.WordCount
	}
	if len(tw.DomainWords) > 0 {
		extraCtx = plan.Direction + ": " + strings.Join(tw.DomainWords, ", ")
	}

	// Also cache type weights for this session (capped by max slow-type ratio)
	if len(tw.QuestionTypeRatio) > 0 {
		merged := mergeTypeWeights(tw.QuestionTypeRatio, s.Config.App.MaxSlowTypeRatio)
		s.sessionBudget.setTypeWeights(merged)
	}
	return
}

// cachePlanWeights loads the active plan and caches its question_type_ratio
// and grammar_focus for use during question selection. Called at session start.
func (s *Server) cachePlanWeights(lang string) {
	plan, err := s.DB.GetActivePlan(lang)
	if err != nil || plan == nil {
		return
	}
	tw := parsePlanTomorrow(plan.PlanJSON)
	if tw == nil {
		return
	}
	if len(tw.QuestionTypeRatio) > 0 {
		merged := mergeTypeWeights(tw.QuestionTypeRatio, s.Config.App.MaxSlowTypeRatio)
		s.sessionBudget.setTypeWeights(merged)
	}
	if len(tw.GrammarFocus) > 0 {
		s.sessionBudget.setGrammarFocus(tw.GrammarFocus)
	}
}

// prioritizeGrammarByPlan reorders grammar points so that those matching the
// plan's grammar_focus come first. Non-matching points retain original order.
func prioritizeGrammarByPlan(points []*db.GrammarPoint, focus []string) {
	if len(focus) == 0 || len(points) <= 1 {
		return
	}
	focusSet := make(map[string]bool, len(focus))
	for _, f := range focus {
		focusSet[f] = true
	}

	matched := make([]*db.GrammarPoint, 0, len(points))
	rest := make([]*db.GrammarPoint, 0, len(points))
	for _, g := range points {
		if focusSet[g.Title] {
			matched = append(matched, g)
		} else {
			rest = append(rest, g)
		}
	}

	// In-place reorder: matched first, then rest
	i := 0
	for _, g := range matched {
		points[i] = g
		i++
	}
	for _, g := range rest {
		points[i] = g
		i++
	}
}

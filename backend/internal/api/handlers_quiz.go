package api

import (
	"context"
	"encoding/json"
	"net/http"
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

	// Auto-expand new words when plan says more content is needed
	if nw == 0 && s.AI != nil {
		plan, planErr := s.DB.GetActivePlan(lang)
		if planErr == nil && plan != nil && plan.Direction != "" &&
			plan.Direction != "complete" && plan.Direction != "review-only" {
			verified, pending, expandErr := s.expandWords(r.Context(), lang, 5, plan.Direction)
			if expandErr == nil && (verified > 0 || pending > 0) {
				nw += verified + pending // pending also counts as "new" for the student
			}
		}
	}

	writeJSON(w, map[string]interface{}{
		"new_words":    nw,
		"new_grammar":  ng,
		"review_words": rw,
		"review_grammar": rg,
	})
}

func (s *Server) handleQuizNext(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleQuizNext(w, r); return
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

	if len(words) == 0 && len(grammarPoints) == 0 {
		// Try expanding new words before giving up
		if s.AI != nil {
			plan, planErr := s.DB.GetActivePlan(lang)
			if planErr == nil && plan != nil && plan.Direction != "" &&
				plan.Direction != "complete" && plan.Direction != "review-only" {
				s.expandWords(r.Context(), lang, 5, plan.Direction)
				// Re-fetch after expansion
				words, _ = s.DB.GetReviewWords(lang, 10)
				grammarPoints, _ = s.DB.GetReviewGrammarPoints(lang, 5)
			}
		}
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
			info := wordToInfo(word)
			distractors := wordsToInfos(words[wi:]) // remaining words as distractors

			qType := engine.SelectQuestionType(
				word.NextReviewAt, word.EasinessFactor, word.Interval, word.Repetitions,
				langQuestionTypes(lang, s.Config), s.AI != nil,
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

			if s.AI == nil {
				// No AI — skip grammar points, try next item
				continue
			}

			q, err = s.aiGenerateGrammarQuestion(r.Context(), gp)
			if err != nil {
				// AI failed for grammar — skip and try next item
				continue
			}
			s.cacheQuestion(q)

			s.sessionBudget.recordType(string(engine.TypeGrammar))
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
			writeError(w, 400, "cached answer required for grammar questions")
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
		sm2 := engine.SM2(grammar.EasinessFactor, grammar.Interval, grammar.Repetitions, quality, now)
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
		sm2 := engine.SM2(word.EasinessFactor, word.Interval, word.Repetitions, quality, now)
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
		return []string{""}
	}
	return []string{s}
}

func dedupNonEmpty(a, b string) []string {
	if a == "" && b == "" {
		return []string{""}
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

		response, err := s.AI.Chat(ctx, messages)
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

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
	engine.TypeReading,
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

func (s *Server) handleQuizNext(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleQuizNext(w, r); return
	}
	if s.DB == nil {
		writeError(w, 500, "database not available")
		return
	}

	lang := s.Config.App.ActiveLang

	// Get words due for review
	words, err := s.DB.GetReviewWords(lang, 10)
	if err != nil {
		writeError(w, 500, "get review words: "+err.Error())
		return
	}

	if len(words) == 0 {
		writeJSON(w, map[string]interface{}{
			"completed": true,
			"message":   "No words to review",
		})
		return
	}

	// Pick the first due word
	word := words[0]
	info := wordToInfo(word)

	// Fetch distractors for choice questions (from other words)
	distractors := wordsToInfos(words[1:])

	// Pick question type based on word's SM-2 state (memory curve)
	qType := engine.SelectQuestionType(
		word.NextReviewAt, word.EasinessFactor, word.Interval, word.Repetitions,
		langQuestionTypes(lang, s.Config), s.AI != nil,
	)

	var q *engine.Question
	switch qType {
	case engine.TypeChoice:
		q = engine.GenerateChoice(info, distractors)
	case engine.TypeFill:
		q = engine.GenerateFill(info)
	case engine.TypeSpelling:
		q = engine.GenerateSpelling(info)
	case engine.TypeReading:
		q = engine.GenerateReading(info)
	case engine.TypeListening, engine.TypeReadingComp, engine.TypeGrammar:
		q, err = s.aiGenerateQuestion(r.Context(), info, qType)
		if err != nil {
			// AI failed — fall back to choice (lowest cognitive load)
			q = engine.GenerateChoice(info, distractors)
		} else {
			s.cacheQuestion(q)
		}
	default:
		q = engine.GenerateChoice(info, distractors)
	}

	resp := map[string]interface{}{
		"id":      q.ID,
		"type":    q.Type,
		"word_id": q.WordID,
		"word":    q.Word,
		"reading": q.Reading,
		"prompt":  q.Prompt,
	}
	if len(q.Options) > 0 {
		resp["options"] = q.Options
	}
	writeJSON(w, resp)
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
		WordID       int64  `json:"word_id"`
		QuestionType string `json:"question_type"`
		Answer       string `json:"answer"`
	}
	if err := readJSON(r, &req); err != nil {
		writeError(w, 400, "invalid request body")
		return
	}

	// Load word from DB
	word, err := s.DB.GetWord(req.WordID)
	if err != nil {
		writeError(w, 500, "get word: "+err.Error())
		return
	}
	if word == nil {
		writeError(w, 404, "word not found")
		return
	}

	// Determine expected answer based on question type
	expected := expectedAnswer(req.QuestionType, word)
	// For AI-generated questions, retrieve the expected answer from cache
	if cachedQ := s.getAndDelCachedQuestion(req.QuestionID); cachedQ != nil {
		expected = cachedQ.Answer
	}
	strictness := strictnessForType(req.QuestionType)

	// Run 3-tier judge: exact → regex → (AI if available)
	var aiCallback func(user, expected string) (*judge.Result, error)
	if s.AI != nil {
		aiCallback = s.makeAIJudge(req.QuestionType, word)
	}
	result := judge.Judge(req.Answer, expected, strictness, aiCallback)

	// Update SM-2
	quality := engine.QualityFromScore(result.Score)
	sm2 := engine.SM2(word.EasinessFactor, word.Interval, word.Repetitions, quality, time.Now())
	if sm2 != nil {
		word.EasinessFactor = sm2.EasinessFactor
		word.Interval = sm2.Interval
		word.Repetitions = sm2.Repetitions
		word.NextReviewAt = &sm2.NextReviewAt
	}
	now := time.Now()
	word.LastReviewAt = &now
	word.TotalAttempts++
	if result.Correct {
		word.TotalCorrect++
	}

	if err := s.DB.UpdateWord(word); err != nil {
		writeError(w, 500, "update word: "+err.Error())
		return
	}

	// Log review
	qType := req.QuestionType
	if qType == "" {
		qType = "choice"
	}
	s.DB.InsertReviewLog(&db.ReviewLog{
		WordID:         word.ID,
		QuestionType:   qType,
		UserAnswer:     req.Answer,
		ExpectedAnswer: expected,
		Correct:        result.Correct,
		Score:          result.Score,
		Source:         string(result.Source),
	})

	writeJSON(w, map[string]interface{}{
		"correct":        result.Correct,
		"score":          result.Score,
		"feedback":       result.Feedback,
		"source":         result.Source,
		"next_review_at": word.NextReviewAt,
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

func expectedAnswer(qType string, w *db.Word) string {
	switch engine.QuestionType(qType) {
	case engine.TypeFill, engine.TypeSpelling:
		return w.Word
	case engine.TypeReading:
		return w.Reading
	case engine.TypeListening:
		return w.Meaning
	default:
		return w.Meaning
	}
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

package api

import (
	"math/rand"
	"net/http"
	"time"

	"github.com/vocablock/v2/internal/api/mock"
	"github.com/vocablock/v2/internal/db"
	"github.com/vocablock/v2/internal/engine"
	"github.com/vocablock/v2/internal/engine/judge"
)

// vocabTypes are question types that operate on a single word (no AI needed).
var vocabTypes = []engine.QuestionType{
	engine.TypeChoice,
	engine.TypeFill,
	engine.TypeSpelling,
	engine.TypeReading,
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

	// Pick a random vocabulary question type
	qType := vocabTypes[rand.Intn(len(vocabTypes))]

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
	strictness := strictnessForType(req.QuestionType)

	// Run 3-tier judge: exact → regex → (AI if available)
	result := judge.Judge(req.Answer, expected, strictness, nil)

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

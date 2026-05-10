package api

import (
	"net/http"
	"time"

	"github.com/vocablock/v2/internal/api/mock"
	"github.com/vocablock/v2/internal/db"
	"github.com/vocablock/v2/internal/engine"
)

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

	// Get words due for review (NULLS FIRST = new words first)
	words, err := s.DB.GetReviewWords(lang, 1)
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

	word := words[0]
	info := &engine.WordInfo{
		ID:      word.ID,
		Word:    word.Word,
		Reading: word.Reading,
		Meaning: word.Meaning,
		POS:     word.POS,
	}

	// Generate a choice question using the word itself (distractors come from other words)
	q := engine.GenerateChoice(info, nil)

	writeJSON(w, map[string]interface{}{
		"id":      q.ID,
		"type":    q.Type,
		"word_id": q.WordID,
		"word":    q.Word,
		"reading": q.Reading,
		"prompt":  q.Prompt,
		"options": q.Options,
	})
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
		QuestionID string `json:"question_id"`
		WordID     int64  `json:"word_id"`
		Answer     string `json:"answer"`
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

	// Judge: exact match on meaning
	correct := req.Answer == word.Meaning
	score := 0.0
	if correct {
		score = 1.0
	}

	// Update SM-2
	quality := engine.QualityFromScore(score)

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
	if correct {
		word.TotalCorrect++
	}

	if err := s.DB.UpdateWord(word); err != nil {
		writeError(w, 500, "update word: "+err.Error())
		return
	}

	// Log review
	logEntry := &db.ReviewLog{
		WordID:         word.ID,
		QuestionType:   "choice",
		UserAnswer:     req.Answer,
		ExpectedAnswer: word.Meaning,
		Correct:        correct,
		Score:          score,
		Source:         "exact",
	}
	s.DB.InsertReviewLog(logEntry)

	feedback := "Correct!"
	if !correct {
		feedback = "Incorrect. The answer is: " + word.Meaning
	}

	writeJSON(w, map[string]interface{}{
		"correct":        correct,
		"score":          score,
		"feedback":       feedback,
		"source":         "exact",
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
		"completed":         true,
		"daily_target_met":  reviewed >= s.Config.App.DailyTarget,
	})
}

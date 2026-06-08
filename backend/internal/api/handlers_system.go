package api

import (
	"net/http"
	"os"
	"time"

	"github.com/vocablock/v2/internal/api/mock"
	"github.com/vocablock/v2/internal/db"
	"github.com/vocablock/v2/internal/engine"
	"github.com/vocablock/v2/internal/log"
)

func (s *Server) handleSystemStatus(w http.ResponseWriter, r *http.Request) {
	log.Debug("system", "status")
	writeJSON(w, map[string]interface{}{
		"status":      "running",
		"locked":      false,
		"active_lang": s.Config.App.ActiveLang,
	})
}

func (s *Server) handleSystemLock(w http.ResponseWriter, r *http.Request) {
	log.Debug("system", "lock")
	if s.Mock {
		mock.HandleSystemLock(w, r); return
	}
	writeJSON(w, map[string]interface{}{
		"locked": true,
		"status": "lock screen not implemented",
	})
}

func (s *Server) handleSystemUnlock(w http.ResponseWriter, r *http.Request) {
	log.Debug("system", "unlock")
	if s.Mock {
		mock.HandleSystemUnlock(w, r); return
	}
	writeJSON(w, map[string]interface{}{
		"locked": false,
	})
}

func (s *Server) handleSystemPassiveQ(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleSystemPassiveQ(w, r); return
	}
	// Return a random word card for passive display widget
	if s.DB != nil {
		words, err := s.DB.GetReviewWords(s.Config.App.ActiveLang, 1)
		if err == nil && len(words) > 0 {
			wd := words[0]
			writeJSON(w, map[string]interface{}{
				"word_id": wd.ID,
				"word":    wd.Word,
				"reading": wd.Reading,
				"meaning": wd.Meaning,
			})
			return
		}
	}
	writeJSON(w, map[string]interface{}{
		"word_id": 0, "word": "", "reading": "", "meaning": "",
	})
}

func (s *Server) handleSystemPassiveSubmit(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleSystemPassiveSubmit(w, r); return
	}

	var req struct {
		WordID int64  `json:"word_id"`
		Recall string `json:"recall"` // "easy", "hard", "forgot"
	}
	if err := readJSON(r, &req); err != nil {
		// Backward compat: accept empty body as basic acknowledgement
		writeJSON(w, map[string]bool{"accepted": true})
		return
	}

	if s.DB != nil && req.WordID > 0 {
		word, err := s.DB.GetWord(req.WordID)
		if err == nil && word != nil {
			// Light SM-2 boost for passive recall
			quality := engine.QualityFromPassiveRecall(req.Recall)
			now := time.Now()
			sm2 := engine.SM2(word.EasinessFactor, word.Interval, word.Repetitions, quality, now, s.Config.App.Sm2MaxIntervalDays)
			if sm2 != nil {
				word.EasinessFactor = sm2.EasinessFactor
				word.Interval = sm2.Interval
				word.Repetitions = sm2.Repetitions
				word.NextReviewAt = &sm2.NextReviewAt
			}
			word.LastReviewAt = &now
			s.DB.UpdateWord(word)

			// Log passive review
			s.DB.InsertReviewLog(&db.ReviewLog{
				SubjectType:    "word",
				SubjectID:      req.WordID,
				WordID:         req.WordID,
				QuestionType:   "passive",
				ExpectedAnswer: word.Meaning,
				Correct:        quality >= 3,
				Score:          float64(quality) / 5.0,
				Source:         "passive",
			})
			log.Debug("system", "passive submit: word=%s recall=%s quality=%d", word.Word, req.Recall, quality)
		}
	}

	writeJSON(w, map[string]bool{"accepted": true})
}

func (s *Server) handleSystemQuit(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleSystemQuit(w, r); return
	}
	writeJSON(w, map[string]bool{"quitting": true})

	// Graceful shutdown: signal via exit
	go func() {
		s.Shutdown()
		os.Exit(0)
	}()
}

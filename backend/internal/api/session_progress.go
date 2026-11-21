package api

import (
	"net/http"

	"github.com/tzhnahida/VocabLock/internal/clock"
)

func (s *Server) handleQuizSessionProgress(w http.ResponseWriter, r *http.Request) {
	if s.DB == nil {
		writeError(w, 500, "database not available")
		return
	}
	lang := s.Config.App.ActiveLang
	date := clock.Today()
	if r.Method == http.MethodGet {
		idx, done, _ := s.DB.GetSessionProgress(date, lang)
		writeJSON(w, map[string]interface{}{"study_index": idx, "study_done": done})
		return
	}
	var req struct {
		StudyIndex int  `json:"study_index"`
		StudyDone  bool `json:"study_done"`
	}
	if err := readJSON(r, &req); err != nil {
		writeError(w, 400, "invalid request body")
		return
	}
	if req.StudyIndex < 0 {
		req.StudyIndex = 0
	}
	if err := s.DB.SaveSessionProgress(date, lang, req.StudyIndex, req.StudyDone); err != nil {
		writeError(w, 500, err.Error())
		return
	}
	writeJSON(w, map[string]interface{}{"ok": true})
}

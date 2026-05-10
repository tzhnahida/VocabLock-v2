package api

import (
	"net/http"
	"strconv"

	"github.com/vocablock/v2/internal/api/mock"
)

func (s *Server) handleStatsHeatmap(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleStatsHeatmap(w, r); return
	}
	if s.DB == nil {
		writeError(w, 500, "database not available")
		return
	}

	days := 90
	if d := r.URL.Query().Get("days"); d != "" {
		if parsed, err := strconv.Atoi(d); err == nil && parsed > 0 && parsed <= 365 {
			days = parsed
		}
	}

	heatmap, err := s.DB.GetHeatmap(days)
	if err != nil {
		writeError(w, 500, "get heatmap: "+err.Error())
		return
	}

	writeJSON(w, heatmap)
}

func (s *Server) handleStatsStreak(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleStatsStreak(w, r); return
	}
	if s.DB == nil {
		writeError(w, 500, "database not available")
		return
	}

	streak, err := s.DB.GetStreak()
	if err != nil {
		writeError(w, 500, "get streak: "+err.Error())
		return
	}

	writeJSON(w, map[string]interface{}{
		"streak": streak,
	})
}

func (s *Server) handleStatsDailyReport(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleStatsDailyReport(w, r); return
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
		"date":           "today",
		"words_reviewed": reviewed,
		"words_correct":  correct,
		"accuracy":       accuracy,
	})
}

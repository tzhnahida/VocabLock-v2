package api

import (
	"net/http"

	"github.com/vocablock/v2/internal/api/mock"
)

func (s *Server) handleStatsHeatmap(w http.ResponseWriter, r *http.Request) {
	if s.Mock { mock.HandleStatsHeatmap(w, r); return }
	writeNotImplemented(w)
}

func (s *Server) handleStatsStreak(w http.ResponseWriter, r *http.Request) {
	if s.Mock { mock.HandleStatsStreak(w, r); return }
	writeNotImplemented(w)
}

func (s *Server) handleStatsDailyReport(w http.ResponseWriter, r *http.Request) {
	if s.Mock { mock.HandleStatsDailyReport(w, r); return }
	writeNotImplemented(w)
}

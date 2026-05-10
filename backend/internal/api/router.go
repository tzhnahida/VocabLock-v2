package api

import (
	"net/http"
)

func (s *Server) registerRoutes(mux *http.ServeMux) {
	mux.HandleFunc("/health", s.handleHealth)

	prefix := "/api/v1"

	// Quiz
	mux.HandleFunc("GET "+prefix+"/quiz/progress", s.handleQuizProgress)
	mux.HandleFunc("GET "+prefix+"/quiz/next", s.handleQuizNext)
	mux.HandleFunc("POST "+prefix+"/quiz/submit", s.handleQuizSubmit)
	mux.HandleFunc("GET "+prefix+"/quiz/today-stats", s.handleQuizTodayStats)
	mux.HandleFunc("POST "+prefix+"/quiz/complete", s.handleQuizComplete)

	// Words
	mux.HandleFunc("GET "+prefix+"/words", s.handleWordsList)
	mux.HandleFunc("GET "+prefix+"/words/{id}", s.handleWordsGet)
	mux.HandleFunc("POST "+prefix+"/words", s.handleWordsCreate)
	mux.HandleFunc("PUT "+prefix+"/words/{id}", s.handleWordsUpdate)
	mux.HandleFunc("DELETE "+prefix+"/words/{id}", s.handleWordsDelete)
	mux.HandleFunc("POST "+prefix+"/words/{id}/reset", s.handleWordsReset)
	mux.HandleFunc("GET "+prefix+"/words/export", s.handleWordsExport)
	mux.HandleFunc("POST "+prefix+"/words/import", s.handleWordsImport)
	mux.HandleFunc("POST "+prefix+"/words/expand", s.handleWordsExpand)

	// AI
	mux.HandleFunc("POST "+prefix+"/ai/chat", s.handleAIChat)
	mux.HandleFunc("GET "+prefix+"/ai/profile", s.handleAIProfile)
	mux.HandleFunc("PUT "+prefix+"/ai/profile", s.handleAIProfileUpdate)

	// TTS
	mux.HandleFunc("GET "+prefix+"/tts/word/{id}", s.handleTTSWord)
	mux.HandleFunc("POST "+prefix+"/tts/text", s.handleTTSText)

	// Stats
	mux.HandleFunc("GET "+prefix+"/stats/heatmap", s.handleStatsHeatmap)
	mux.HandleFunc("GET "+prefix+"/stats/streak", s.handleStatsStreak)
	mux.HandleFunc("GET "+prefix+"/stats/daily-report", s.handleStatsDailyReport)

	// System
	mux.HandleFunc("GET "+prefix+"/system/status", s.handleSystemStatus)
	mux.HandleFunc("POST "+prefix+"/system/lock", s.handleSystemLock)
	mux.HandleFunc("POST "+prefix+"/system/unlock", s.handleSystemUnlock)
	mux.HandleFunc("GET "+prefix+"/system/passive-q", s.handleSystemPassiveQ)
	mux.HandleFunc("POST "+prefix+"/system/passive-submit", s.handleSystemPassiveSubmit)
	mux.HandleFunc("POST "+prefix+"/system/quit", s.handleSystemQuit)

	// Config
	mux.HandleFunc("GET "+prefix+"/config", s.handleConfigGet)
	mux.HandleFunc("GET "+prefix+"/config/{key}", s.handleConfigGetKey)
	mux.HandleFunc("PUT "+prefix+"/config", s.handleConfigUpdate)
	mux.HandleFunc("POST "+prefix+"/config/password", s.handleConfigPassword)
}

func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.Write([]byte(`{"status":"ok"}`))
}

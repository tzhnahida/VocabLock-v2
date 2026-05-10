package api

import (
	"net/http"

	"github.com/vocablock/v2/internal/api/mock"
)

func (s *Server) handleAIChat(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleAIChat(w, r); return
	}

	var req struct {
		Message string `json:"message"`
	}
	if err := readJSON(r, &req); err != nil {
		writeError(w, 400, "invalid request body")
		return
	}

	writeJSON(w, map[string]interface{}{
		"reply": "AI chat requires API key configuration.",
		"model": "none",
	})
}

func (s *Server) handleAIProfile(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleAIProfile(w, r); return
	}

	writeJSON(w, map[string]interface{}{
		"base_url":   "",
		"model":      "",
		"configured": false,
	})
}

func (s *Server) handleAIProfileUpdate(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleAIProfileUpdate(w, r); return
	}
	writeNotImplemented(w)
}

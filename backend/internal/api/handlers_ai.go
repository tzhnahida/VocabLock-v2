package api

import (
	"net/http"

	"github.com/vocablock/v2/internal/api/mock"
)

func (s *Server) handleAIChat(w http.ResponseWriter, r *http.Request) {
	if s.Mock { mock.HandleAIChat(w, r); return }
	writeNotImplemented(w)
}

func (s *Server) handleAIProfile(w http.ResponseWriter, r *http.Request) {
	if s.Mock { mock.HandleAIProfile(w, r); return }
	writeNotImplemented(w)
}

func (s *Server) handleAIProfileUpdate(w http.ResponseWriter, r *http.Request) {
	if s.Mock { mock.HandleAIProfileUpdate(w, r); return }
	writeNotImplemented(w)
}

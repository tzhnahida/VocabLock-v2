package api

import (
	"net/http"

	"github.com/vocablock/v2/internal/api/mock"
)

func (s *Server) handleConfigGet(w http.ResponseWriter, r *http.Request) {
	if s.Mock { mock.HandleConfigGet(w, r); return }
	writeNotImplemented(w)
}

func (s *Server) handleConfigGetKey(w http.ResponseWriter, r *http.Request) {
	if s.Mock { mock.HandleConfigGetKey(w, r); return }
	writeNotImplemented(w)
}

func (s *Server) handleConfigUpdate(w http.ResponseWriter, r *http.Request) {
	if s.Mock { mock.HandleConfigUpdate(w, r); return }
	writeNotImplemented(w)
}

func (s *Server) handleConfigPassword(w http.ResponseWriter, r *http.Request) {
	if s.Mock { mock.HandleConfigPassword(w, r); return }
	writeNotImplemented(w)
}

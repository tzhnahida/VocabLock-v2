package api

import (
	"net/http"

	"github.com/vocablock/v2/internal/api/mock"
)

func (s *Server) handleTTSWord(w http.ResponseWriter, r *http.Request) {
	if s.Mock { mock.HandleTTSWord(w, r); return }
	writeNotImplemented(w)
}

func (s *Server) handleTTSText(w http.ResponseWriter, r *http.Request) {
	if s.Mock { mock.HandleTTSText(w, r); return }
	writeNotImplemented(w)
}

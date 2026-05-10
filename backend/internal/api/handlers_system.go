package api

import (
	"net/http"

	"github.com/vocablock/v2/internal/api/mock"
)

func (s *Server) handleSystemStatus(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleSystemStatus(w, r)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.Write([]byte(`{"status":"running","locked":false}`))
}

func (s *Server) handleSystemLock(w http.ResponseWriter, r *http.Request) {
	if s.Mock { mock.HandleSystemLock(w, r); return }
	writeNotImplemented(w)
}

func (s *Server) handleSystemUnlock(w http.ResponseWriter, r *http.Request) {
	if s.Mock { mock.HandleSystemUnlock(w, r); return }
	writeNotImplemented(w)
}

func (s *Server) handleSystemPassiveQ(w http.ResponseWriter, r *http.Request) {
	if s.Mock { mock.HandleSystemPassiveQ(w, r); return }
	writeNotImplemented(w)
}

func (s *Server) handleSystemPassiveSubmit(w http.ResponseWriter, r *http.Request) {
	if s.Mock { mock.HandleSystemPassiveSubmit(w, r); return }
	writeNotImplemented(w)
}

func (s *Server) handleSystemQuit(w http.ResponseWriter, r *http.Request) {
	if s.Mock { mock.HandleSystemQuit(w, r); return }
	writeNotImplemented(w)
}

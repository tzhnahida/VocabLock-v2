package api

import (
	"net/http"

	"github.com/vocablock/v2/internal/api/mock"
)

func (s *Server) handleQuizProgress(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleQuizProgress(w, r); return
	}
	writeNotImplemented(w)
}

func (s *Server) handleQuizNext(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleQuizNext(w, r); return
	}
	writeNotImplemented(w)
}

func (s *Server) handleQuizSubmit(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleQuizSubmit(w, r); return
	}
	writeNotImplemented(w)
}

func (s *Server) handleQuizTodayStats(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleQuizTodayStats(w, r); return
	}
	writeNotImplemented(w)
}

func (s *Server) handleQuizComplete(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleQuizComplete(w, r); return
	}
	writeNotImplemented(w)
}

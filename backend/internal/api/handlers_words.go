package api

import (
	"net/http"

	"github.com/vocablock/v2/internal/api/mock"
)

func (s *Server) handleWordsList(w http.ResponseWriter, r *http.Request) {
	if s.Mock { mock.HandleWordsList(w, r); return }
	writeNotImplemented(w)
}

func (s *Server) handleWordsGet(w http.ResponseWriter, r *http.Request) {
	if s.Mock { mock.HandleWordsGet(w, r); return }
	writeNotImplemented(w)
}

func (s *Server) handleWordsCreate(w http.ResponseWriter, r *http.Request) {
	if s.Mock { mock.HandleWordsCreate(w, r); return }
	writeNotImplemented(w)
}

func (s *Server) handleWordsUpdate(w http.ResponseWriter, r *http.Request) {
	if s.Mock { mock.HandleWordsUpdate(w, r); return }
	writeNotImplemented(w)
}

func (s *Server) handleWordsDelete(w http.ResponseWriter, r *http.Request) {
	if s.Mock { mock.HandleWordsDelete(w, r); return }
	writeNotImplemented(w)
}

func (s *Server) handleWordsReset(w http.ResponseWriter, r *http.Request) {
	if s.Mock { mock.HandleWordsReset(w, r); return }
	writeNotImplemented(w)
}

func (s *Server) handleWordsExport(w http.ResponseWriter, r *http.Request) {
	if s.Mock { mock.HandleWordsExport(w, r); return }
	writeNotImplemented(w)
}

func (s *Server) handleWordsImport(w http.ResponseWriter, r *http.Request) {
	if s.Mock { mock.HandleWordsImport(w, r); return }
	writeNotImplemented(w)
}

func (s *Server) handleWordsExpand(w http.ResponseWriter, r *http.Request) {
	if s.Mock { mock.HandleWordsExpand(w, r); return }
	writeNotImplemented(w)
}

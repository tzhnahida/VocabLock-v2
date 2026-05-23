package api

import (
	"net/http"
	"strconv"

	"github.com/vocablock/v2/internal/api/mock"
	"github.com/vocablock/v2/internal/db"
)

// handleGrammarPointsList returns grammar points for the active language.
func (s *Server) handleGrammarPointsList(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleGrammarPointsList(w, r, s.Config.App.ActiveLang); return
	}
	if s.DB == nil {
		writeError(w, 500, "database not available"); return
	}
	lang := r.URL.Query().Get("language")
	if lang == "" {
		lang = s.Config.App.ActiveLang
	}
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	if limit <= 0 || limit > 100 {
		limit = 50
	}
	offset, _ := strconv.Atoi(r.URL.Query().Get("offset"))

	points, total, err := s.DB.ListGrammarPoints(lang, limit, offset)
	if err != nil {
		writeError(w, 500, "list grammar points: "+err.Error())
		return
	}
	if points == nil {
		points = []*db.GrammarPoint{}
	}
	writeJSON(w, map[string]interface{}{
		"grammar_points": points,
		"total":          total,
	})
}

// handleGrammarPointCreate creates a new grammar point.
func (s *Server) handleGrammarPointCreate(w http.ResponseWriter, r *http.Request) {
	if s.DB == nil {
		writeError(w, 500, "database not available"); return
	}
	var gp db.GrammarPoint
	if err := readJSON(r, &gp); err != nil {
		writeError(w, 400, "invalid request body"); return
	}
	if gp.Language == "" {
		gp.Language = s.Config.App.ActiveLang
	}
	id, err := s.DB.InsertGrammarPoint(&gp)
	if err != nil {
		writeError(w, 500, "create grammar point: "+err.Error())
		return
	}
	gp.ID = id
	writeJSON(w, gp)
}

// handleGrammarPointUpdate updates an existing grammar point.
func (s *Server) handleGrammarPointUpdate(w http.ResponseWriter, r *http.Request) {
	if s.DB == nil {
		writeError(w, 500, "database not available"); return
	}
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeError(w, 400, "invalid id"); return
	}
	var gp db.GrammarPoint
	if err := readJSON(r, &gp); err != nil {
		writeError(w, 400, "invalid request body"); return
	}
	gp.ID = id
	if err := s.DB.UpdateGrammarPoint(&gp); err != nil {
		writeError(w, 500, "update grammar point: "+err.Error())
		return
	}
	writeJSON(w, map[string]interface{}{"updated": true, "id": id})
}

// handleGrammarPointDelete deletes a grammar point.
func (s *Server) handleGrammarPointDelete(w http.ResponseWriter, r *http.Request) {
	if s.DB == nil {
		writeError(w, 500, "database not available"); return
	}
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeError(w, 400, "invalid id"); return
	}
	if err := s.DB.DeleteGrammarPoint(id); err != nil {
		writeError(w, 500, "delete grammar point: "+err.Error())
		return
	}
	writeJSON(w, map[string]interface{}{"deleted": true, "id": id})
}

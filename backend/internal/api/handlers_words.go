package api

import (
	"net/http"
	"strconv"

	"github.com/vocablock/v2/internal/api/mock"
	"github.com/vocablock/v2/internal/db"
)

func (s *Server) handleWordsList(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleWordsList(w, r); return
	}
	if s.DB == nil {
		writeError(w, 500, "database not available")
		return
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

	words, total, err := s.DB.ListWords(lang, limit, offset)
	if err != nil {
		writeError(w, 500, "list words: "+err.Error())
		return
	}

	if words == nil {
		words = []*db.Word{}
	}

	writeJSON(w, map[string]interface{}{
		"words": words,
		"total": total,
	})
}

func (s *Server) handleWordsGet(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleWordsGet(w, r); return
	}
	if s.DB == nil {
		writeError(w, 500, "database not available")
		return
	}

	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeError(w, 400, "invalid word id")
		return
	}

	word, err := s.DB.GetWord(id)
	if err != nil {
		writeError(w, 500, "get word: "+err.Error())
		return
	}
	if word == nil {
		writeError(w, 404, "word not found")
		return
	}

	writeJSON(w, word)
}

func (s *Server) handleWordsCreate(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleWordsCreate(w, r); return
	}
	if s.DB == nil {
		writeError(w, 500, "database not available")
		return
	}

	var req struct {
		Word     string `json:"word"`
		Reading  string `json:"reading"`
		Meaning  string `json:"meaning"`
		POS      string `json:"pos"`
		Language string `json:"language"`
	}
	if err := readJSON(r, &req); err != nil {
		writeError(w, 400, "invalid request body")
		return
	}

	if req.Word == "" {
		writeError(w, 400, "word is required")
		return
	}
	if req.Language == "" {
		req.Language = s.Config.App.ActiveLang
	}

	wrd := &db.Word{
		Word:     req.Word,
		Reading:  req.Reading,
		Meaning:  req.Meaning,
		POS:      req.POS,
		Language: req.Language,
		Source:   "manual",
	}

	id, err := s.DB.InsertWord(wrd)
	if err != nil {
		writeError(w, 500, "insert word: "+err.Error())
		return
	}

	// Re-query to get DB defaults (easiness_factor, created_at, etc.)
	inserted, _ := s.DB.GetWord(id)
	if inserted != nil {
		writeJSON(w, inserted)
	} else {
		wrd.ID = id
		writeJSON(w, wrd)
	}
}

func (s *Server) handleWordsUpdate(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleWordsUpdate(w, r); return
	}
	if s.DB == nil {
		writeError(w, 500, "database not available")
		return
	}

	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeError(w, 400, "invalid word id")
		return
	}

	word, err := s.DB.GetWord(id)
	if err != nil {
		writeError(w, 500, "get word: "+err.Error())
		return
	}
	if word == nil {
		writeError(w, 404, "word not found")
		return
	}

	var req struct {
		Word    *string `json:"word"`
		Reading *string `json:"reading"`
		Meaning *string `json:"meaning"`
		POS     *string `json:"pos"`
	}
	if err := readJSON(r, &req); err != nil {
		writeError(w, 400, "invalid request body")
		return
	}

	if req.Word != nil {
		word.Word = *req.Word
	}
	if req.Reading != nil {
		word.Reading = *req.Reading
	}
	if req.Meaning != nil {
		word.Meaning = *req.Meaning
	}
	if req.POS != nil {
		word.POS = *req.POS
	}

	if err := s.DB.UpdateWord(word); err != nil {
		writeError(w, 500, "update word: "+err.Error())
		return
	}

	writeJSON(w, word)
}

func (s *Server) handleWordsDelete(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleWordsDelete(w, r); return
	}
	if s.DB == nil {
		writeError(w, 500, "database not available")
		return
	}

	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeError(w, 400, "invalid word id")
		return
	}

	if err := s.DB.DeleteWord(id); err != nil {
		writeError(w, 500, "delete word: "+err.Error())
		return
	}

	writeJSON(w, map[string]bool{"deleted": true})
}

func (s *Server) handleWordsReset(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleWordsReset(w, r); return
	}
	if s.DB == nil {
		writeError(w, 500, "database not available")
		return
	}

	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeError(w, 400, "invalid word id")
		return
	}

	if err := s.DB.ResetWord(id); err != nil {
		writeError(w, 500, "reset word: "+err.Error())
		return
	}

	writeJSON(w, map[string]interface{}{
		"reset":   true,
		"word_id": id,
	})
}

func (s *Server) handleWordsExport(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleWordsExport(w, r); return
	}
	if s.DB == nil {
		writeError(w, 500, "database not available")
		return
	}

	lang := r.URL.Query().Get("language")
	if lang == "" {
		lang = s.Config.App.ActiveLang
	}

	words, _, err := s.DB.ListWords(lang, 10000, 0)
	if err != nil {
		writeError(w, 500, "export words: "+err.Error())
		return
	}

	type exportWord struct {
		Word    string `json:"word"`
		Reading string `json:"reading"`
		Meaning string `json:"meaning"`
		POS     string `json:"pos"`
	}
	result := make([]exportWord, 0, len(words))
	for _, wd := range words {
		result = append(result, exportWord{
			Word: wd.Word, Reading: wd.Reading, Meaning: wd.Meaning, POS: wd.POS,
		})
	}

	w.Header().Set("Content-Disposition", "attachment; filename=vocablock-export.json")
	writeJSON(w, result)
}

func (s *Server) handleWordsImport(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleWordsImport(w, r); return
	}
	if s.DB == nil {
		writeError(w, 500, "database not available")
		return
	}

	var words []struct {
		Word     string `json:"word"`
		Reading  string `json:"reading"`
		Meaning  string `json:"meaning"`
		POS      string `json:"pos"`
		Language string `json:"language"`
	}
	if err := readJSON(r, &words); err != nil {
		writeError(w, 400, "invalid import data: "+err.Error())
		return
	}

	lang := s.Config.App.ActiveLang
	imported, skipped := 0, 0
	for _, iw := range words {
		if iw.Word == "" {
			skipped++
			continue
		}
		if iw.Language == "" {
			iw.Language = lang
		}
		s.DB.InsertWord(&db.Word{
			Word: iw.Word, Reading: iw.Reading, Meaning: iw.Meaning,
			POS: iw.POS, Language: iw.Language, Source: "import",
		})
		imported++
	}

	writeJSON(w, map[string]interface{}{
		"imported": imported,
		"skipped":  skipped,
	})
}

func (s *Server) handleWordsExpand(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleWordsExpand(w, r); return
	}
	writeJSON(w, map[string]interface{}{
		"verified":       []interface{}{},
		"pending_review": []interface{}{},
		"message":        "AI word expansion requires API key configuration",
	})
}

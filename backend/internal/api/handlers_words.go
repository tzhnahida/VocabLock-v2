package api

import (
	"context"
	"encoding/json"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/vocablock/v2/internal/ai"
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
	if s.DB == nil {
		writeError(w, 500, "database not available")
		return
	}
	if s.AI == nil {
		writeJSON(w, map[string]interface{}{
			"verified":       []interface{}{},
			"pending_review": []interface{}{},
			"message":        "AI word expansion requires API key configuration",
		})
		return
	}

	lang := s.Config.App.ActiveLang

	// Parse optional request body
	var req struct {
		Count   int      `json:"count"`
		Context []string `json:"context"`
	}
	req.Count = 5
	if err := readJSON(r, &req); err != nil {
		req.Count = 5
		req.Context = nil
	}
	if req.Count <= 0 || req.Count > 20 {
		req.Count = 5
	}

	// Build context from recently mastered words
	recentContext := ""
	if len(req.Context) > 0 {
		recentContext = strings.Join(req.Context, ", ")
	} else {
		recentWords, _ := s.DB.GetReviewWords(lang, 5)
		parts := make([]string, 0, len(recentWords))
		for _, w := range recentWords {
			parts = append(parts, w.Word)
		}
		recentContext = strings.Join(parts, ", ")
	}
	if recentContext == "" {
		recentContext = "(new learner, no words yet)"
	}

	// Load expand prompt
	pt, err := ai.LoadPrompt("expand")
	if err != nil {
		writeError(w, 500, "load prompt: "+err.Error())
		return
	}

	teacherRole := "Language Teacher"
	level := "beginner"
	if lc, ok := s.Config.Languages[lang]; ok {
		teacherRole = lc.PromptContext.TeacherRole
		for lvl := range lc.PromptContext.LevelDescriptions {
			level = lvl
			break
		}
	}

	messages, err := pt.BuildMessages(&ai.PromptVars{
		TeacherRole: teacherRole,
		Level:       level,
		ExtraContext: recentContext,
	})
	if err != nil {
		writeError(w, 500, "build prompt: "+err.Error())
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 30*time.Second)
	defer cancel()

	response, err := s.AI.Chat(ctx, messages)
	if err != nil {
		writeJSON(w, map[string]interface{}{
			"verified":       []interface{}{},
			"pending_review": []interface{}{},
			"message":        "AI temporarily unavailable: " + err.Error(),
		})
		return
	}

	// Parse AI JSON response
	var aiResult struct {
		Words []struct {
			Word       string `json:"word"`
			Reading    string `json:"reading"`
			Meaning    string `json:"meaning"`
			POS        string `json:"pos"`
			Confidence string `json:"confidence"`
		} `json:"words"`
	}
	if err := json.Unmarshal([]byte(response), &aiResult); err != nil {
		writeError(w, 500, "parse AI response: "+err.Error())
		return
	}

	// Classify and insert
	var verified []map[string]interface{}
	var pendingReview []map[string]interface{}

	for _, aiw := range aiResult.Words {
		if aiw.Word == "" {
			continue
		}
		if aiw.Confidence == "" {
			aiw.Confidence = "medium"
		}

		entry := map[string]interface{}{
			"word":       aiw.Word,
			"reading":    aiw.Reading,
			"meaning":    aiw.Meaning,
			"pos":        aiw.POS,
			"confidence": aiw.Confidence,
			"source":     "ai_expansion",
		}

		// Verify against dictionary if available
		verifiedByDict := false
		if s.DictProvider != nil {
			lookupCtx, lookupCancel := context.WithTimeout(r.Context(), 5*time.Second)
			result, lookupErr := s.DictProvider.Lookup(lookupCtx, aiw.Word)
			lookupCancel()
			if lookupErr == nil && result != nil && result.Found {
				verifiedByDict = true
				// Use dict-provided data when available (more reliable)
				if result.Reading != "" {
					aiw.Reading = result.Reading
				}
				if result.Meaning != "" {
					aiw.Meaning = result.Meaning
				}
				if result.POS != "" {
					aiw.POS = result.POS
				}
				entry["reading"] = aiw.Reading
				entry["meaning"] = aiw.Meaning
				entry["pos"] = aiw.POS
			}
		}

		if verifiedByDict {
			_, insertErr := s.DB.InsertWord(&db.Word{
				Word:       aiw.Word,
				Reading:    aiw.Reading,
				Meaning:    aiw.Meaning,
				POS:        aiw.POS,
				Language:   lang,
				Source:     "ai_expansion",
				Confidence: aiw.Confidence,
			})
			if insertErr != nil {
				entry["insert_error"] = insertErr.Error()
			}
			verified = append(verified, entry)
		} else {
			pendingReview = append(pendingReview, entry)
		}
	}

	if verified == nil {
		verified = []map[string]interface{}{}
	}
	if pendingReview == nil {
		pendingReview = []map[string]interface{}{}
	}

	writeJSON(w, map[string]interface{}{
		"verified":       verified,
		"pending_review": pendingReview,
	})
}

package api

import (
	"net/http"
	"strings"

	"github.com/tzhnahida/VocabLock/internal/content"
	"github.com/tzhnahida/VocabLock/internal/log"
)

// handleContentPacks lists installed packs. The UI uses it to show which
// dictionaries/lists are active and where they come from.
func (s *Server) handleContentPacks(w http.ResponseWriter, r *http.Request) {
	if s.Content == nil {
		writeJSON(w, map[string]interface{}{"root": "", "packs": []content.PackInfo{}})
		return
	}
	writeJSON(w, map[string]interface{}{
		"root":  s.Content.Root(),
		"packs": s.Content.Packs(),
	})
}

// handleDictionaryLookup exposes the merged content-pack lookup, so the UI
// (and diagnostics) can preview what a pack knows about a word.
func (s *Server) handleDictionaryLookup(w http.ResponseWriter, r *http.Request) {
	word := strings.TrimSpace(r.URL.Query().Get("word"))
	if word == "" {
		writeError(w, http.StatusBadRequest, "word required")
		return
	}
	lang := strings.TrimSpace(r.URL.Query().Get("language"))
	if lang == "" {
		lang = s.currentLang()
	}
	if s.Content == nil {
		writeJSON(w, map[string]interface{}{"found": false, "reason": "no content packs"})
		return
	}
	entry := s.Content.Lookup(lang, word)
	if entry == nil {
		writeJSON(w, map[string]interface{}{"found": false})
		return
	}
	writeJSON(w, map[string]interface{}{"found": true, "entry": entry})
}

// handleContentReload re-scans the content directory after the user drops a
// pack in, without restarting the service.
func (s *Server) handleContentReload(w http.ResponseWriter, r *http.Request) {
	lib, err := content.Load(s.Config.App.ContentDir)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "reload content: "+err.Error())
		return
	}
	s.Content = lib
	log.Info("content", "reloaded %d pack(s) from %s", len(lib.Packs()), lib.Root())
	writeJSON(w, map[string]interface{}{
		"root":  lib.Root(),
		"packs": lib.Packs(),
	})
}

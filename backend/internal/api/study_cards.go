package api

import (
	"net/http"
	"strconv"
	"strings"
)

// handleQuizStudyCards returns the new words of the current session so the
// shell can show study cards before the first question. Reviews are skipped:
// only words that have never been reviewed are worth a preview.
func (s *Server) handleQuizStudyCards(w http.ResponseWriter, r *http.Request) {
	if s.DB == nil {
		writeError(w, 500, "database not available")
		return
	}
	lang := s.Config.App.ActiveLang
	count := 8
	if v := r.URL.Query().Get("count"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			count = n
		}
	}
	if count > 20 {
		count = 20
	}

	words, err := s.DB.GetReviewWords(lang, count*4)
	if err != nil {
		writeError(w, 500, "list study words: "+err.Error())
		return
	}
	cards := make([]map[string]interface{}, 0, count)
	for _, word := range words {
		if word.NextReviewAt != nil || strings.TrimSpace(word.Meaning) == "" {
			continue
		}
		cards = append(cards, map[string]interface{}{
			"id":      word.ID,
			"word":    word.Word,
			"reading": word.Reading,
			"meaning": word.Meaning,
			"pos":     word.POS,
		})
		if len(cards) >= count {
			break
		}
	}
	writeJSON(w, map[string]interface{}{"cards": cards})
}

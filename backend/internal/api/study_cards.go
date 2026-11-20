package api

import (
	"encoding/json"
	"net/http"

	"github.com/tzhnahida/VocabLock/internal/clock"
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
		// Lexical extras come from the word detail JSON; packs provide a
		// fallback example sentence when the detail is empty.
		detail := map[string]interface{}{}
		if word.Detail != "" {
			_ = json.Unmarshal([]byte(word.Detail), &detail)
		}
		str := func(key string) string {
			if v, ok := detail[key].(string); ok {
				return v
			}
			return ""
		}
		example := str("example_sentence")
		if example == "" && s.Content != nil {
			if entry := s.Content.Lookup(lang, word.Word); entry != nil {
				for _, sense := range entry.Senses {
					if len(sense.Examples) > 0 {
						example = sense.Examples[0].Text
						break
					}
				}
			}
		}
		cards = append(cards, map[string]interface{}{
			"id":          word.ID,
			"word":        word.Word,
			"reading":     word.Reading,
			"meaning":     word.Meaning,
			"pos":         word.POS,
			"level":       word.Level,
			"example":     example,
			"forms":       str("morphology"),
			"pitch":       str("pitch_accent"),
			"syllables":   str("syllables"),
			"register":    str("register"),
			"morphology":  str("morphology"),
			"collocation": str("collocation"),
			"syntax":      str("syntax"),
		})
		if len(cards) >= count {
			break
		}
	}
	ids := make([]int64, 0, len(cards))
	for _, card := range cards {
		if id, ok := card["id"].(int64); ok {
			ids = append(ids, id)
		}
	}
	s.setStudyQueue(ids)

	// The old Flutter flow showed grammar study cards after the word cards.
	grammarCards := make([]map[string]interface{}, 0, 4)
	if gps, err := s.DB.GetReviewGrammarPoints(lang, 4); err == nil {
		for _, gp := range gps {
			grammarCards = append(grammarCards, map[string]interface{}{
				"id":          gp.ID,
				"title":       gp.Title,
				"explanation": gp.Explanation,
				"example":     gp.Example,
				"detail":      gp.Detail,
			})
		}
	}

	writeJSON(w, map[string]interface{}{"cards": cards, "grammar": grammarCards})
}

// handleQuizStudyTime credits read-along time from a study card to the session
// budget. The audio itself is not graded here.
func (s *Server) handleQuizStudyTime(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Seconds int   `json:"seconds"`
		WordID  int64 `json:"word_id"`
	}
	if err := readJSON(r, &req); err != nil {
		writeError(w, 400, "invalid request body")
		return
	}
	if req.Seconds <= 0 || req.Seconds > 300 {
		writeError(w, 400, "seconds must be between 1 and 300")
		return
	}
	// A study card is a fixed-cost activity too (30s), not the recording length.
	const studyCardSeconds = 30
	used := s.sessionBudget.recordStudyTime(studyCardSeconds)
	if s.DB != nil {
		_ = s.DB.UpsertDailyStats(clock.Today(), s.Config.App.ActiveLang, 0, 0, studyCardSeconds)
	}
	writeJSON(w, map[string]interface{}{"ok": true, "time_used": used})
}

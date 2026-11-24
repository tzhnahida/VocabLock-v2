package api

import (
	"encoding/json"
	"strings"
	"unicode"

	"github.com/tzhnahida/VocabLock/internal/db"
)

func detailString(detail, key string) string {
	if detail == "" || detail == "{}" {
		return ""
	}
	var m map[string]interface{}
	if json.Unmarshal([]byte(detail), &m) != nil {
		return ""
	}
	if v, ok := m[key].(string); ok {
		return strings.TrimSpace(v)
	}
	return ""
}

func hasHan(s string) bool {
	for _, r := range s {
		if unicode.Is(unicode.Han, r) {
			return true
		}
	}
	return false
}

// displayMeaning prefers the localized detail meaning when the raw dictionary
// sense is English-only. This keeps every option/answer in the explanation
// language instead of mixing "to read" with Chinese options.
func displayMeaning(w *db.Word) string {
	if w == nil {
		return ""
	}
	raw := strings.TrimSpace(w.Meaning)
	detail := detailString(w.Detail, "meaning")
	if detail == "" {
		return raw
	}
	if raw == "" || (!hasHan(raw) && hasHan(detail)) {
		return detail
	}
	return raw
}

// displayPOS hides raw JMdict tags such as "v5u,vt" behind the localized
// grammatical description when one exists.
func displayPOS(w *db.Word) string {
	if w == nil {
		return ""
	}
	raw := strings.TrimSpace(w.POS)
	detail := detailString(w.Detail, "pos")
	if detail == "" {
		return raw
	}
	if raw == "" || (!hasHan(raw) && hasHan(detail)) {
		return detail
	}
	return raw
}

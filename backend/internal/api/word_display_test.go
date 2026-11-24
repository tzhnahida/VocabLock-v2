package api

import (
	"testing"

	"github.com/tzhnahida/VocabLock/internal/db"
)

func TestDisplayMeaningPrefersLocalizedDetail(t *testing.T) {
	w := &db.Word{
		Meaning: "to read",
		POS:     "v5m,vt",
		Detail:  `{"meaning":"读；阅读；念；解读","pos":"动词（五段动词，他动词）"}`,
	}
	if got := displayMeaning(w); got != "读；阅读；念；解读" {
		t.Fatalf("meaning = %q", got)
	}
	if got := displayPOS(w); got != "动词（五段动词，他动词）" {
		t.Fatalf("pos = %q", got)
	}
	// Already-localized values win over detail.
	w.Meaning = "读"
	w.POS = "v5m"
	if displayMeaning(w) != "读" {
		t.Fatalf("localized meaning overwritten: %q", displayMeaning(w))
	}
	if displayPOS(w) != "动词（五段动词，他动词）" {
		t.Fatalf("raw POS should still be replaced by detail: %q", displayPOS(w))
	}
}

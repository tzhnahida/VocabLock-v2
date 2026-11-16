package api

import (
	"testing"

	"github.com/tzhnahida/VocabLock/internal/db"
)

// /stats/diagnostics feeds the Flutter diagnostics panel. The panel renders
// whatever shape this endpoint returns, so the shape itself needs a test:
// a rename here would silently empty every section of the UI.

func TestStatsDiagnosticsShape(t *testing.T) {
	s := newTestServer(t)

	active, err := s.DB.InsertWord(&db.Word{Word: "水", Meaning: "water", Language: "en", Status: "active"})
	if err != nil {
		t.Fatalf("insert word: %v", err)
	}
	if _, err := s.DB.InsertWord(&db.Word{Word: "火", Meaning: "fire", Language: "en", Status: "pending"}); err != nil {
		t.Fatalf("insert pending word: %v", err)
	}

	rows := []*db.ReviewLog{
		// correct, deterministic
		{SubjectType: "word", SubjectID: active, WordID: active, Language: "en", QuestionType: "choice",
			UserAnswer: "water", ExpectedAnswer: "water", Correct: true, Score: 1, Source: "exact"},
		// wrong, categorised
		{SubjectType: "word", SubjectID: active, WordID: active, Language: "en", QuestionType: "choice",
			UserAnswer: "wader", ExpectedAnswer: "water", Correct: false, Score: 0.2, Source: "ai", ErrorCategory: "similarity"},
		// AI said wrong although the answer matched exactly → false negative
		{SubjectType: "word", SubjectID: active, WordID: active, Language: "en", QuestionType: "spelling",
			UserAnswer: "fire", ExpectedAnswer: "fire", Correct: false, Score: 0, Source: "ai"},
		// read-aloud with structured phonemes (one weak, one fine)
		{SubjectType: "word", SubjectID: active, WordID: active, Language: "en", QuestionType: "read_word",
			UserAnswer: "みず", ExpectedAnswer: "みず", Correct: true, Score: 0.7, Source: "pronounce",
			PhonemesJSON: `[{"phoneme":"ɕ","score":0.3},{"phoneme":"k","score":0.9}]`},
	}
	for i, r := range rows {
		if _, err := s.DB.InsertReviewLog(r); err != nil {
			t.Fatalf("insert review log %d: %v", i, err)
		}
	}

	rec, _ := newTestRequest(s, "GET", "/api/v1/stats/diagnostics?days=30", "")
	if rec.Code != 200 {
		t.Fatalf("status = %d: %s", rec.Code, rec.Body.String())
	}
	m := mustUnmarshal(t, rec.Body.String())

	if got := int(m["days"].(float64)); got != 30 {
		t.Errorf("days = %d", got)
	}

	cats, ok := m["by_category"].(map[string]interface{})
	if !ok {
		t.Fatalf("by_category missing or wrong type: %T", m["by_category"])
	}
	if got := int(cats["similarity"].(float64)); got != 1 {
		t.Errorf("by_category[similarity] = %d, want 1", got)
	}

	weak, ok := m["weak_phonemes"].(map[string]interface{})
	if !ok {
		t.Fatalf("weak_phonemes missing: %T", m["weak_phonemes"])
	}
	if got := int(weak["ɕ"].(float64)); got != 1 {
		t.Errorf("weak_phonemes[ɕ] = %d, want 1", got)
	}
	if _, present := weak["k"]; present {
		t.Error("strong phoneme k must not be reported as weak")
	}
	if got := int(m["phoneme_samples"].(float64)); got != 1 {
		t.Errorf("phoneme_samples = %d, want 1", got)
	}

	ai, ok := m["ai_disagreement"].(map[string]interface{})
	if !ok {
		t.Fatalf("ai_disagreement missing: %T", m["ai_disagreement"])
	}
	if got := int(ai["ai_verdicts"].(float64)); got != 2 {
		t.Errorf("ai_verdicts = %d, want 2", got)
	}
	if got := int(ai["wrong_but_exact_hit"].(float64)); got != 1 {
		t.Errorf("wrong_but_exact_hit = %d, want 1", got)
	}

	types, ok := m["type_rates"].(map[string]interface{})
	if !ok {
		t.Fatalf("type_rates missing: %T", m["type_rates"])
	}
	choice := types["choice"].(map[string]interface{})
	if int(choice["total"].(float64)) != 2 || int(choice["correct"].(float64)) != 1 {
		t.Errorf("choice rate = %v, want 2/1", choice)
	}

	cov, ok := m["coverage"].(map[string]interface{})
	if !ok {
		t.Fatalf("coverage missing: %T", m["coverage"])
	}
	if got := int(cov["total_words"].(float64)); got != 1 {
		t.Errorf("total_words = %d, want 1 (pending words excluded)", got)
	}
	if got := int(cov["pending_review"].(float64)); got != 1 {
		t.Errorf("pending_review = %d, want 1", got)
	}
}

// No rows at all must still be a valid, renderable payload — the panel's empty
// state is driven by these zero values.
func TestStatsDiagnosticsEmpty(t *testing.T) {
	s := newTestServer(t)

	rec, _ := newTestRequest(s, "GET", "/api/v1/stats/diagnostics", "")
	if rec.Code != 200 {
		t.Fatalf("status = %d: %s", rec.Code, rec.Body.String())
	}
	m := mustUnmarshal(t, rec.Body.String())
	if got := int(m["days"].(float64)); got != 30 {
		t.Errorf("default days = %d, want 30", got)
	}
	if m["ai_disagreement"] != nil {
		t.Errorf("ai_disagreement = %v, want null when there are no AI verdicts", m["ai_disagreement"])
	}
	if cov := m["coverage"].(map[string]interface{}); int(cov["total_words"].(float64)) != 0 {
		t.Errorf("total_words = %v, want 0", cov["total_words"])
	}
}

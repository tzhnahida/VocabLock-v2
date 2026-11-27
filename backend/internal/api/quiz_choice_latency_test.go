package api

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"sync/atomic"
	"testing"

	"github.com/tzhnahida/VocabLock/internal/config"
	"github.com/tzhnahida/VocabLock/internal/db"
)

// A wrong multiple-choice pick is a closed-set answer: the learner can only
// echo one of the served options, so the verdict is decidable locally.
// Routing it through the AI tier made every wrong answer wait for a network
// round trip (~1s, unbounded on a bad link) before the UI could show anything,
// which read as "the click did not register".
func TestChoiceSubmitSkipsAITier(t *testing.T) {
	s := newTestServer(t)
	withJapaneseCourse(s)
	s.Config.Languages["ja"] = &config.LanguageConfig{QuestionTypes: []string{"choice"}}

	var aiCalls int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		atomic.AddInt32(&aiCalls, 1)
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]interface{}{
			"choices": []map[string]interface{}{
				{"message": map[string]string{"role": "assistant", "content": `{"correct":true,"score":1,"feedback":"ok"}`}},
			},
			"usage": map[string]int{"prompt_tokens": 1, "completion_tokens": 1},
		})
	}))
	t.Cleanup(srv.Close)
	s.Config.App.AI.BaseURL = srv.URL
	s.Config.App.AI.APIKey = "test-key"
	s.Config.App.AI.Model = "fake-model"
	s.WireAI()
	if s.AI() == nil {
		t.Fatal("fake AI client not wired")
	}

	if _, err := s.DB.InsertWord(&db.Word{Word: "水", Reading: "みず", Meaning: "水，凉水", POS: "n", Language: "ja", Status: "active"}); err != nil {
		t.Fatalf("seed: %v", err)
	}

	if rec, _ := newTestRequest(s, "POST", "/api/v1/quiz/session/start", `{}`); rec.Code != 200 {
		t.Fatalf("session start = %d %s", rec.Code, rec.Body.String())
	}
	rec, _ := newTestRequest(s, "GET", "/api/v1/quiz/next?language=ja", "")
	if rec.Code != 200 {
		t.Fatalf("next = %d %s", rec.Code, rec.Body.String())
	}
	payload := decodeJSON(t, rec)
	if payload["completed"] == true {
		t.Fatalf("no question served: %v", payload)
	}
	if payload["type"] != "choice" {
		t.Skipf("served question type %v, not choice", payload["type"])
	}

	rec, _ = newTestRequest(s, "POST", "/api/v1/quiz/submit", submitBody(t, map[string]interface{}{
		"question_id":   payload["id"],
		"subject_type":  "word",
		"subject_id":    payload["subject_id"],
		"question_type": "choice",
		"answer":        "definitely-not-one-of-the-options",
	}))
	if rec.Code != 200 {
		t.Fatalf("submit = %d %s", rec.Code, rec.Body.String())
	}
	if got := atomic.LoadInt32(&aiCalls); got != 0 {
		t.Fatalf("a wrong choice answer triggered %d AI call(s); closed-set answers must be graded locally", got)
	}
	if decodeJSON(t, rec)["correct"] != false {
		t.Errorf("wrong choice graded as correct: %s", rec.Body.String())
	}
}

// Open-ended answers still get the AI tier: a paraphrase cannot be decided by
// string comparison, so this guard protects the behaviour we are keeping.
func TestOptionQuestionOnlyClosesOptionTypes(t *testing.T) {
	for _, qtype := range []string{"choice", "listening", "reading_comp", "grammar"} {
		if !optionQuestion(qtype) {
			t.Errorf("optionQuestion(%q) = false, want true", qtype)
		}
	}
	for _, qtype := range []string{"fill", "spelling", "meaning", "pronounce", "dialogue_write", "dialogue_speak", "read_sentence"} {
		if optionQuestion(qtype) {
			t.Errorf("optionQuestion(%q) = true, want false", qtype)
		}
	}
}

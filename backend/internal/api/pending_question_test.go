package api

import (
	"testing"
	"time"

	"github.com/tzhnahida/VocabLock/internal/clock"
	"github.com/tzhnahida/VocabLock/internal/db"
)

// A restart must serve the exact question that was open, not a freshly
// generated one. Submitting clears it so the next question can advance.
func TestPendingQuestionResumesExactOpenQuestion(t *testing.T) {
	s := newTestServer(t)
	withJapaneseCourse(s)
	s.Config.Languages["ja"].QuestionTypes = []string{"choice"}
	s.Config.App.DailyTarget = 5
	s.Config.App.SessionTimeBudget = 10

	past := clock.Now().Add(-time.Hour)
	if _, err := s.DB.InsertWord(&db.Word{
		Word: "一", Reading: "いち", Meaning: "one", POS: "noun", Language: "ja", Status: "active",
		NextReviewAt: &past,
	}); err != nil {
		t.Fatalf("seed: %v", err)
	}

	rec, _ := newTestRequest(s, "POST", "/api/v1/quiz/session/start", `{}`)
	if rec.Code != 200 {
		t.Fatalf("start = %d %s", rec.Code, rec.Body.String())
	}
	rec, _ = newTestRequest(s, "GET", "/api/v1/quiz/next?language=ja", "")
	if rec.Code != 200 {
		t.Fatalf("next = %d %s", rec.Code, rec.Body.String())
	}
	first := decodeJSON(t, rec)
	if first["completed"] == true {
		t.Fatal("expected a question")
	}
	id, _ := first["id"].(string)
	if id == "" {
		t.Fatal("missing question id")
	}

	// Same day, next request: must return the same question while it is open.
	rec, _ = newTestRequest(s, "GET", "/api/v1/quiz/next?language=ja", "")
	second := decodeJSON(t, rec)
	if second["id"] != id {
		t.Fatalf("resumed id = %v, want %s", second["id"], id)
	}

	// Submitting clears the pending question.
	rec, _ = newTestRequest(s, "POST", "/api/v1/quiz/submit", submitBody(t, map[string]interface{}{
		"question_id": id, "subject_type": "word", "subject_id": 1,
		"question_type": "choice", "answer": "one",
	}))
	if rec.Code != 200 {
		t.Fatalf("submit = %d %s", rec.Code, rec.Body.String())
	}
	rec, _ = newTestRequest(s, "GET", "/api/v1/quiz/next?language=ja", "")
	third := decodeJSON(t, rec)
	if third["id"] == id {
		t.Fatal("pending question was not cleared after submit")
	}
}

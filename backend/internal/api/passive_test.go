package api

import (
	"testing"

	"github.com/tzhnahida/VocabLock/internal/db"
)

// The Flutter passive card submits {word_id, recall}. Before it did, the
// client sent no body at all: the handler acknowledged and moved on, so the
// card looked connected while nothing was ever scheduled. These tests pin the
// contract the UI depends on.

func TestPassiveSubmitAppliesRecall(t *testing.T) {
	s := newTestServer(t)

	id, err := s.DB.InsertWord(&db.Word{
		Word: "猫", Reading: "ねこ", Meaning: "cat", Language: "en", Status: "active",
	})
	if err != nil {
		t.Fatalf("insert word: %v", err)
	}
	before, err := s.DB.GetWord(id)
	if err != nil {
		t.Fatalf("get word: %v", err)
	}

	rec, _ := newTestRequest(s, "POST", "/api/v1/system/passive-submit",
		`{"word_id":`+itoa64(id)+`,"recall":"easy"}`)
	if rec.Code != 200 {
		t.Fatalf("status = %d: %s", rec.Code, rec.Body.String())
	}
	if m := mustUnmarshal(t, rec.Body.String()); m["accepted"] != true {
		t.Errorf("accepted = %v, want true", m["accepted"])
	}

	after, err := s.DB.GetWord(id)
	if err != nil {
		t.Fatalf("get word after: %v", err)
	}
	if after.Repetitions != before.Repetitions+1 {
		t.Errorf("repetitions = %d, want %d", after.Repetitions, before.Repetitions+1)
	}
	if after.Interval <= before.Interval {
		t.Errorf("interval = %d, want > %d", after.Interval, before.Interval)
	}
	if after.LastReviewAt == nil {
		t.Error("last_review_at not set")
	}
	if after.NextReviewAt == nil {
		t.Error("next_review_at not set")
	}

	// The row must be findable by word AND by language — that is what the
	// diagnostics panel and the per-word history query read.
	logs, err := s.DB.GetReviewLogs("word", id, 10)
	if err != nil {
		t.Fatalf("get review logs: %v", err)
	}
	if len(logs) != 1 {
		t.Fatalf("review logs = %d, want 1", len(logs))
	}
	l := logs[0]
	if l.QuestionType != "passive" || l.Source != "passive" {
		t.Errorf("log type/source = %q/%q", l.QuestionType, l.Source)
	}
	if l.Language != "en" {
		t.Errorf("log language = %q, want en", l.Language)
	}
	if !l.Correct {
		t.Error("easy recall should be logged as correct (quality 4 >= 3)")
	}
}

func TestPassiveSubmitForgotIsIncorrect(t *testing.T) {
	s := newTestServer(t)

	id, _ := s.DB.InsertWord(&db.Word{Word: "犬", Meaning: "dog", Language: "en", Status: "active"})
	rec, _ := newTestRequest(s, "POST", "/api/v1/system/passive-submit",
		`{"word_id":`+itoa64(id)+`,"recall":"forgot"}`)
	if rec.Code != 200 {
		t.Fatalf("status = %d: %s", rec.Code, rec.Body.String())
	}

	logs, _ := s.DB.GetReviewLogs("word", id, 10)
	if len(logs) != 1 {
		t.Fatalf("review logs = %d, want 1", len(logs))
	}
	if logs[0].Correct {
		t.Error("forgot recall should be logged as incorrect (quality 1)")
	}
}

// An empty body is still accepted (older clients / the native popup ack), but
// it must not invent a word: nothing to update means nothing changes.
func TestPassiveSubmitWithoutWordIsNoop(t *testing.T) {
	s := newTestServer(t)

	rec, _ := newTestRequest(s, "POST", "/api/v1/system/passive-submit", "")
	if rec.Code != 200 {
		t.Fatalf("status = %d: %s", rec.Code, rec.Body.String())
	}
	if m := mustUnmarshal(t, rec.Body.String()); m["accepted"] != true {
		t.Errorf("accepted = %v, want true", m["accepted"])
	}
}

func TestPassiveQuestionReturnsDueWord(t *testing.T) {
	s := newTestServer(t)

	id, _ := s.DB.InsertWord(&db.Word{
		Word: "空", Reading: "そら", Meaning: "sky", Language: "en", Status: "active",
	})

	rec, _ := newTestRequest(s, "GET", "/api/v1/system/passive-q", "")
	if rec.Code != 200 {
		t.Fatalf("status = %d: %s", rec.Code, rec.Body.String())
	}
	m := mustUnmarshal(t, rec.Body.String())
	if got := int64(m["word_id"].(float64)); got != id {
		t.Errorf("word_id = %d, want %d", got, id)
	}
	if m["word"] != "空" {
		t.Errorf("word = %v", m["word"])
	}
	if m["meaning"] != "sky" {
		t.Errorf("meaning = %v", m["meaning"])
	}
}

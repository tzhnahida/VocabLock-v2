package api

import (
	"encoding/json"
	"fmt"
	"net/http/httptest"
	"testing"

	"github.com/tzhnahida/VocabLock/internal/db"
	"github.com/tzhnahida/VocabLock/internal/engine"
)

func TestReadAloudTargetTextUsesCachedSentence(t *testing.T) {
	s := newTestServer(t)
	id, err := s.DB.InsertWord(&db.Word{
		Word: "hello", Reading: "həˈloʊ", Meaning: "你好",
		POS: "interjection", Language: "en", Source: "seed", Status: "active",
	})
	if err != nil {
		t.Fatalf("insert word: %v", err)
	}
	s.cacheQuestion(&engine.Question{
		ID:     "rs-target",
		Type:   engine.TypeReadSentence,
		Answer: "  This is a full sentence.  ",
	})

	got := s.readAloudTargetText("read_sentence", "word", id, "rs-target")
	if got != "This is a full sentence." {
		t.Fatalf("read_sentence target = %q, want cached sentence", got)
	}
	// Without the cached sentence it must NOT fall back to the word reading.
	if got := s.readAloudTargetText("read_sentence", "word", id, "rs-target"); got != "" {
		t.Fatalf("read_sentence without cache = %q, want empty (no word fallback)", got)
	}
	// read_word still uses the word's reading.
	if got := s.readAloudTargetText("read_word", "word", id, "missing"); got != "həˈloʊ" {
		t.Fatalf("read_word target = %q, want word reading", got)
	}
}

func TestQuestionRequiresCachedAnswerDialogue(t *testing.T) {
	for _, qtype := range []string{"dialogue_write", "dialogue_speak"} {
		if !questionRequiresCachedAnswer(qtype) {
			t.Errorf("%s should require a cached reference answer", qtype)
		}
	}
	if questionRequiresCachedAnswer("choice") {
		t.Error("choice must not require a cached answer")
	}
}

func TestStudyReadAloudDoesNotAdvanceSM2(t *testing.T) {
	s := newTestServer(t)
	id, err := s.DB.InsertWord(&db.Word{
		Word: "hello", Reading: "həˈloʊ", Meaning: "你好",
		POS: "interjection", Language: "en", Source: "seed", Status: "active",
	})
	if err != nil {
		t.Fatalf("insert word: %v", err)
	}
	before, err := s.DB.GetWord(id)
	if err != nil || before == nil {
		t.Fatalf("get word before: %v", err)
	}

	rec := httptest.NewRecorder()
	s.writeReadAloudResult(rec, "word", id, "read_word", true, 0.9, nil, "hello", "pronounce", true)

	var out map[string]interface{}
	if err := json.Unmarshal(rec.Body.Bytes(), &out); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if out["log_id"].(float64) != 0 {
		t.Fatalf("study log_id = %v, want 0", out["log_id"])
	}

	after, err := s.DB.GetWord(id)
	if err != nil || after == nil {
		t.Fatalf("get word after: %v", err)
	}
	if after.TotalAttempts != before.TotalAttempts ||
		after.TotalCorrect != before.TotalCorrect ||
		after.Interval != before.Interval ||
		after.EasinessFactor != before.EasinessFactor ||
		after.Repetitions != before.Repetitions {
		t.Fatalf("study read-aloud mutated SM-2: before=%+v after=%+v", before, after)
	}

	reviewed, _, err := s.DB.GetTodayStats("en")
	if err != nil {
		t.Fatalf("today stats: %v", err)
	}
	if reviewed != 0 {
		t.Fatalf("study read-aloud wrote %d review rows, want 0", reviewed)
	}
	logs, err := s.DB.GetReviewLogs("word", id, 10)
	if err != nil {
		t.Fatalf("review logs: %v", err)
	}
	if len(logs) != 0 {
		t.Fatalf("study read-aloud wrote %d review logs, want 0", len(logs))
	}
}

func TestAICacheMissDoesNotWriteReviewLog(t *testing.T) {
	s := newTestServer(t)
	id, err := s.DB.InsertWord(&db.Word{
		Word: "hello", Reading: "həˈloʊ", Meaning: "你好",
		POS: "interjection", Language: "en", Source: "seed", Status: "active",
	})
	if err != nil {
		t.Fatalf("insert word: %v", err)
	}
	before, _ := s.DB.GetWord(id)

	body := fmt.Sprintf(`{"question_id":"missing-cache","subject_type":"word","subject_id":%d,"question_type":"listening","answer":"x"}`, id)
	rec, _ := newTestRequest(s, "POST", "/api/v1/quiz/submit", body)
	if rec.Code != 200 {
		t.Fatalf("status = %d, body=%s", rec.Code, rec.Body.String())
	}
	var out map[string]interface{}
	if err := json.Unmarshal(rec.Body.Bytes(), &out); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if out["source"] != "cache_miss" {
		t.Fatalf("source = %v, want cache_miss", out["source"])
	}

	after, _ := s.DB.GetWord(id)
	if after.TotalAttempts != before.TotalAttempts || after.Repetitions != before.Repetitions {
		t.Fatalf("cache miss mutated word: before=%+v after=%+v", before, after)
	}
	reviewed, _, err := s.DB.GetTodayStats("en")
	if err != nil {
		t.Fatalf("today stats: %v", err)
	}
	if reviewed != 0 {
		t.Fatalf("cache miss wrote %d review rows, want 0", reviewed)
	}
}

func TestDailyTargetMetUsesAttemptAccuracy(t *testing.T) {
	s := newTestServer(t)
	s.Config.App.DailyTarget = 1
	s.Config.App.MinAccuracy = 0.8

	id, err := s.DB.InsertWord(&db.Word{
		Word: "hello", Reading: "həˈloʊ", Meaning: "你好",
		POS: "interjection", Language: "en", Source: "seed", Status: "active",
	})
	if err != nil {
		t.Fatalf("insert word: %v", err)
	}
	insert := func(correct bool) {
		t.Helper()
		_, err := s.DB.InsertReviewLog(&db.ReviewLog{
			WordID: id, Language: "en", SubjectType: "word", SubjectID: id,
			QuestionType: "choice", UserAnswer: "x", ExpectedAnswer: "你好",
			Correct: correct, Source: "exact",
		})
		if err != nil {
			t.Fatalf("insert review log: %v", err)
		}
	}

	insert(true)
	insert(false)
	if s.DailyTargetMet("en") {
		t.Fatal("1 correct out of 2 attempts must not satisfy accuracy 0.8")
	}

	for i := 0; i < 4; i++ {
		insert(true)
	}
	if !s.DailyTargetMet("en") {
		t.Fatal("5 correct out of 6 attempts must satisfy accuracy 0.8")
	}
}

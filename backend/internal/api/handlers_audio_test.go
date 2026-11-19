package api

import (
	"context"
	"encoding/base64"
	"errors"
	"testing"

	"github.com/tzhnahida/VocabLock/internal/db"
	"github.com/tzhnahida/VocabLock/internal/engine"
	"github.com/tzhnahida/VocabLock/internal/pronounce"
)

type fakePronounce struct {
	score float64
	err   error
	text  string
}

func (f *fakePronounce) Assess(ctx context.Context, audioPath, targetText string) (*pronounce.Result, error) {
	f.text = targetText
	if f.err != nil {
		return nil, f.err
	}
	return &pronounce.Result{Score: f.score}, nil
}

func seedWater(t *testing.T, s *Server) int64 {
	t.Helper()
	id, err := s.DB.InsertWord(&db.Word{Word: "水", Reading: "みず", Meaning: "water", POS: "n", Language: "ja", Status: "active"})
	if err != nil {
		t.Fatalf("seed word: %v", err)
	}
	return id
}

func TestReadAloudBranches(t *testing.T) {
	s := newTestServer(t)
	withJapaneseCourse(s)
	wordID := seedWater(t, s)
	audio := base64.StdEncoding.EncodeToString([]byte("fake audio"))

	sub := func(qtype, qid, audio string) map[string]interface{} {
		t.Helper()
		rec, _ := newTestRequest(s, "POST", "/api/v1/quiz/submit", submitBody(t, map[string]interface{}{
			"question_id": qid, "subject_type": "word", "subject_id": wordID,
			"question_type": qtype, "audio": audio, "answer": "",
		}))
		if rec.Code != 200 {
			t.Fatalf("%s = %d %s", qid, rec.Code, rec.Body.String())
		}
		return decodeJSON(t, rec)
	}

	fp := &fakePronounce{score: 0.9}
	s.PronounceProvider = fp
	got := sub("read_word", "r1", audio)
	if got["correct"] != true || got["source"] != "pronounce" {
		t.Errorf("read_word = %v", got)
	}
	if fp.text != "みず" {
		t.Errorf("target text = %q, want みず", fp.text)
	}

	if got := sub("read_word", "r2", ""); got["source"] != "skipped" {
		t.Errorf("skipped = %v", got)
	}
	if got := sub("read_word", "r3", "%%%"); got["source"] != "bad_audio" {
		t.Errorf("bad audio = %v", got)
	}

	s.PronounceProvider = &fakePronounce{err: errors.New("boom")}
	if got := sub("read_word", "r4", audio); got["source"] != "assess_error" {
		t.Errorf("assess error = %v", got)
	}

	s.PronounceProvider = nil
	if got := sub("read_word", "r5", audio); got["source"] != "no_provider" {
		t.Errorf("no provider = %v", got)
	}

	// read_sentence needs the cached prompt to know what to grade.
	s.PronounceProvider = &fakePronounce{score: 0.5}
	if got := sub("read_sentence", "missing", audio); got["source"] != "no_target" {
		t.Errorf("no target = %v", got)
	}
	s.cacheQuestion(&engine.Question{ID: "s1", Answer: "これは水です。", SubjectType: "word", SubjectID: wordID})
	if got := sub("read_sentence", "s1", audio); got["correct"] != true || got["source"] != "pronounce" {
		t.Errorf("read_sentence = %v", got)
	}
}

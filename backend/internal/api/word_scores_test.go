package api

import (
	"testing"

	"github.com/tzhnahida/VocabLock/internal/db"
	"github.com/tzhnahida/VocabLock/internal/pronounce"
)

func TestSentenceWordScoresAlignsSegments(t *testing.T) {
	s := newTestServer(t)
	withJapaneseCourse(s)
	for _, w := range []string{"学校", "行く"} {
		if _, err := s.DB.InsertWord(&db.Word{Word: w, Reading: w, Meaning: w, POS: "noun", Language: "ja", Status: "active"}); err != nil {
			t.Fatalf("seed %s: %v", w, err)
		}
	}
	segs := s.splitSentenceSegments("学校へ行く")
	if len(segs) < 3 {
		t.Fatalf("segments = %v, want word + particle + word", segs)
	}
	scores := s.sentenceWordScores("学校へ行く", []pronounce.PhonemeScore{
		{Phoneme: "g", Score: 0.9}, {Phoneme: "a", Score: 0.8},
		{Phoneme: "k", Score: 0.7}, {Phoneme: "u", Score: 0.6},
	}, 0.5)
	if len(scores) != len(segs) {
		t.Fatalf("scores = %d, segments = %d", len(scores), len(segs))
	}
	for _, sc := range scores {
		if sc["text"] == "" {
			t.Fatalf("empty segment score: %#v", sc)
		}
	}
	if got := s.sentenceWordScores("", nil, 0); got != nil {
		t.Fatalf("empty target = %#v, want nil", got)
	}
}

package db

import (
	"testing"
	"time"
)

// A failed review resets SM-2 repetitions to 0 while next_review_at and
// last_review_at stay set. Using repetitions as the "new word" test made such a
// word reappear in the study-card preview, which the learner reads as "this word
// I already studied shows up as new again".
func TestGetStudyWordsExcludesFailedReview(t *testing.T) {
	d := openTestDB(t)

	freshID, err := d.InsertWord(&Word{
		Word: "食べる", Reading: "たべる", Meaning: "吃", POS: "v",
		Language: "ja", Status: "active", Source: "manual",
	})
	if err != nil {
		t.Fatalf("insert fresh word: %v", err)
	}

	failedID, err := d.InsertWord(&Word{
		Word: "見る", Reading: "みる", Meaning: "看，观看", POS: "v",
		Language: "ja", Status: "active", Source: "manual",
	})
	if err != nil {
		t.Fatalf("insert failed word: %v", err)
	}

	// Failed review: SM-2 dropped repetitions back to 0 but scheduled the word.
	next := time.Now().Add(24 * time.Hour)
	last := time.Now().Add(-24 * time.Hour)
	word, err := d.GetWord(failedID)
	if err != nil {
		t.Fatalf("get failed word: %v", err)
	}
	word.Repetitions = 0
	word.Interval = 1
	word.NextReviewAt = &next
	word.LastReviewAt = &last
	if err := d.UpdateWord(word); err != nil {
		t.Fatalf("update failed word: %v", err)
	}

	words, err := d.GetStudyWords("ja", 10)
	if err != nil {
		t.Fatalf("GetStudyWords: %v", err)
	}

	seen := map[int64]bool{}
	for _, w := range words {
		seen[w.ID] = true
	}
	if !seen[freshID] {
		t.Errorf("never-reviewed word %d missing from study words", freshID)
	}
	if seen[failedID] {
		t.Errorf("failed word %d (next_review_at set, repetitions 0) must not be a study word", failedID)
	}
}

package api

import (
	"testing"
	"time"

	"github.com/tzhnahida/VocabLock/internal/db"
)

// A word that failed its last review keeps next_review_at but gets repetitions
// reset to 0 by SM-2. It must not be offered again as a brand-new study card:
// the learner already studied it and sees that as "learned words reappearing".
func TestStudyCardsExcludeFailedReview(t *testing.T) {
	s := newTestServer(t)
	withJapaneseCourse(s)

	freshID, err := s.DB.InsertWord(&db.Word{
		Word: "食べる", Reading: "たべる", Meaning: "吃", POS: "v",
		Language: "ja", Status: "active", Source: "manual",
	})
	if err != nil {
		t.Fatalf("insert fresh word: %v", err)
	}

	failedID, err := s.DB.InsertWord(&db.Word{
		Word: "見る", Reading: "みる", Meaning: "看，观看", POS: "v",
		Language: "ja", Status: "active", Source: "manual",
	})
	if err != nil {
		t.Fatalf("insert failed word: %v", err)
	}
	word, err := s.DB.GetWord(failedID)
	if err != nil {
		t.Fatalf("get failed word: %v", err)
	}
	next := time.Now().Add(24 * time.Hour)
	last := time.Now().Add(-24 * time.Hour)
	word.Repetitions = 0
	word.Interval = 1
	word.NextReviewAt = &next
	word.LastReviewAt = &last
	if err := s.DB.UpdateWord(word); err != nil {
		t.Fatalf("update failed word: %v", err)
	}

	rec, _ := newTestRequest(s, "GET", "/api/v1/quiz/study-cards?count=10", "")
	if rec.Code != 200 {
		t.Fatalf("study cards = %d %s", rec.Code, rec.Body.String())
	}
	payload := decodeJSON(t, rec)
	cards, _ := payload["cards"].([]interface{})
	if len(cards) != 1 {
		t.Fatalf("cards = %v, want only the never-reviewed word", cards)
	}
	card, _ := cards[0].(map[string]interface{})
	if card["word"] != "食べる" {
		t.Errorf("card word = %v, want 食べる", card["word"])
	}

	queue := s.studyQueueSnapshot()
	if len(queue) != 1 || queue[0] != freshID {
		t.Errorf("study queue = %v, want [%d]", queue, freshID)
	}
}

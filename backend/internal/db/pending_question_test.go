package db

import (
	"testing"
)

func TestPendingQuestionAndLearnedCounts(t *testing.T) {
	d := openTestDB(t)
	if _, err := d.InsertWord(&Word{Word: "一", Reading: "いち", Meaning: "one", Language: "ja", Status: "active"}); err != nil {
		t.Fatalf("seed: %v", err)
	}
	if _, err := d.DB.Exec(`UPDATE words SET repetitions = 5, interval = 30`); err != nil {
		t.Fatalf("mark learned: %v", err)
	}
	learned, mature, err := d.LearnedCounts("ja")
	if err != nil {
		t.Fatalf("learned counts: %v", err)
	}
	if learned != 1 || mature != 1 {
		t.Fatalf("learned=%d mature=%d, want 1/1", learned, mature)
	}

	if err := d.SavePendingQuestion("2026-11-23", "ja", `{"id":"q1"}`, 1); err != nil {
		t.Fatalf("save pending: %v", err)
	}
	q, wordID, err := d.LoadPendingQuestion("2026-11-23", "ja")
	if err != nil || q == "" || wordID != 1 {
		t.Fatalf("load pending q=%q id=%d err=%v", q, wordID, err)
	}
	d.ClearPendingQuestion("2026-11-23", "ja")
	q, _, _ = d.LoadPendingQuestion("2026-11-23", "ja")
	if q != "" {
		t.Fatalf("pending not cleared: %q", q)
	}
}

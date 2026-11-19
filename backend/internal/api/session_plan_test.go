package api

import (
	"testing"

	"github.com/tzhnahida/VocabLock/internal/config"
	"github.com/tzhnahida/VocabLock/internal/db"
)

// Design B: daily_target questions are cut down when the session time budget
// cannot fit them; when the plan is spent the session completes, and the
// student can deliberately continue.
func TestSessionPlanCutsQuestionsToBudget(t *testing.T) {
	s := newTestServer(t)
	withJapaneseCourse(s)
	s.Config.Languages["ja"] = &config.LanguageConfig{QuestionTypes: []string{"choice"}}
	s.Config.App.DailyTarget = 20
	s.Config.App.SessionTimeBudget = 1 // 6 units, choice costs 1 → 6 questions

	for _, w := range []string{"一", "二", "三", "四", "五", "六", "七", "八"} {
		if _, err := s.DB.InsertWord(&db.Word{Word: w, Reading: w, Meaning: "m" + w, POS: "n", Language: "ja", Status: "active"}); err != nil {
			t.Fatalf("seed: %v", err)
		}
	}

	rec, _ := newTestRequest(s, "POST", "/api/v1/quiz/session/start", `{}`)
	if rec.Code != 200 {
		t.Fatalf("session start = %d", rec.Code)
	}

	answered := 0
	var done map[string]interface{}
	for {
		rec, _ = newTestRequest(s, "GET", "/api/v1/quiz/next?language=ja", "")
		if rec.Code != 200 {
			t.Fatalf("next = %d %s", rec.Code, rec.Body.String())
		}
		payload := decodeJSON(t, rec)
		if payload["completed"] == true {
			done = payload
			break
		}
		sid := int64(payload["subject_id"].(float64))
		word, err := s.DB.GetWord(sid)
		if err != nil || word == nil {
			t.Fatalf("subject %d: %v", sid, err)
		}
		rec, _ = newTestRequest(s, "POST", "/api/v1/quiz/submit", submitBody(t, map[string]interface{}{
			"question_id": payload["id"], "subject_type": "word", "subject_id": sid,
			"question_type": payload["type"], "answer": word.Meaning,
		}))
		if rec.Code != 200 {
			t.Fatalf("submit = %d %s", rec.Code, rec.Body.String())
		}
		answered++
		if answered > 50 {
			t.Fatal("session never completed")
		}
	}

	if answered != 6 {
		t.Errorf("answered = %d, want 6 (1-minute budget / 1-unit questions)", answered)
	}
	if got := done["planned_questions"].(float64); got != 6 {
		t.Errorf("planned_questions = %v, want 6", got)
	}
	if done["session_exhausted"] != true {
		t.Errorf("session_exhausted = %v", done["session_exhausted"])
	}

	// Deliberate continue: the next request must serve a question again.
	rec, _ = newTestRequest(s, "POST", "/api/v1/quiz/session/continue", `{}`)
	if rec.Code != 200 {
		t.Fatalf("continue = %d %s", rec.Code, rec.Body.String())
	}
	rec, _ = newTestRequest(s, "GET", "/api/v1/quiz/next?language=ja", "")
	if rec.Code != 200 {
		t.Fatalf("next after continue = %d", rec.Code)
	}
	if decodeJSON(t, rec)["completed"] == true {
		t.Error("continue did not lift the plan cap")
	}
}

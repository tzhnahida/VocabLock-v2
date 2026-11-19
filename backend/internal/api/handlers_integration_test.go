package api

import (
	"encoding/json"
	"errors"
	"net/http/httptest"
	"net/url"
	"strconv"
	"testing"

	"github.com/tzhnahida/VocabLock/internal/config"
	"github.com/tzhnahida/VocabLock/internal/content"
	"github.com/tzhnahida/VocabLock/internal/db"
)

func decodeJSON(t *testing.T, rec *httptest.ResponseRecorder) map[string]interface{} {
	t.Helper()
	var out map[string]interface{}
	if err := json.Unmarshal(rec.Body.Bytes(), &out); err != nil {
		t.Fatalf("decode %q: %v", rec.Body.String(), err)
	}
	return out
}

func withJapaneseCourse(s *Server) {
	s.Config.App.ActiveLang = "ja"
	s.Config.Languages["ja"] = &config.LanguageConfig{QuestionTypes: []string{"choice", "fill"}}
}

func withContentLibrary(t *testing.T, s *Server) {
	t.Helper()
	lib, err := content.Load("../../../content")
	if err != nil {
		t.Fatalf("load content packs: %v", err)
	}
	s.Content = lib
	s.Config.App.ContentDir = "../../../content"
}

func TestHTTPConfig(t *testing.T) {
	s := newTestServer(t)
	withJapaneseCourse(s)

	rec, _ := newTestRequest(s, "GET", "/api/v1/config", "")
	if rec.Code != 200 {
		t.Fatalf("GET config = %d", rec.Code)
	}
	if got := decodeJSON(t, rec)["active_lang"]; got != "ja" {
		t.Errorf("active_lang = %v", got)
	}

	rec, _ = newTestRequest(s, "PUT", "/api/v1/config", `{"daily_target":33,"student_level":"N2"}`)
	if rec.Code != 200 {
		t.Fatalf("PUT config = %d %s", rec.Code, rec.Body.String())
	}
	rec, _ = newTestRequest(s, "GET", "/api/v1/config", "")
	got := decodeJSON(t, rec)
	if got["daily_target"].(float64) != 33 {
		t.Errorf("daily_target = %v", got["daily_target"])
	}
	if got["student_level"] != "n2" {
		t.Errorf("student_level = %v", got["student_level"])
	}

	rec, _ = newTestRequest(s, "PUT", "/api/v1/config", `{"student_level":"N6"}`)
	if rec.Code != 400 {
		t.Errorf("invalid level = %d, want 400", rec.Code)
	}

	// Once the course is locked, a different active language is rejected.
	s.Config.App.LanguageLocked = true
	rec, _ = newTestRequest(s, "PUT", "/api/v1/config", `{"active_lang":"en"}`)
	if rec.Code != 409 {
		t.Errorf("locked language switch = %d, want 409 (%s)", rec.Code, rec.Body.String())
	}
}

func TestHTTPWordsCRUD(t *testing.T) {
	s := newTestServer(t)
	withJapaneseCourse(s)

	rec, _ := newTestRequest(s, "POST", "/api/v1/words", `{"word":"水","reading":"みず","meaning":"water","pos":"n"}`)
	if rec.Code != 200 {
		t.Fatalf("create = %d %s", rec.Code, rec.Body.String())
	}
	var id int64
	if v, ok := decodeJSON(t, rec)["id"].(float64); ok {
		id = int64(v)
	}
	if id == 0 {
		t.Fatalf("create did not return an id: %s", rec.Body.String())
	}

	rec, _ = newTestRequest(s, "GET", "/api/v1/words?limit=10", "")
	if rec.Code != 200 {
		t.Fatalf("list = %d", rec.Code)
	}
	wrapped := decodeJSON(t, rec)
	if _, ok := wrapped["words"]; !ok {
		t.Errorf("list payload has no words: %s", rec.Body.String())
	}

	rec, _ = newTestRequest(s, "GET", "/api/v1/words/"+itoa(id), "")
	if rec.Code != 200 {
		t.Fatalf("get = %d", rec.Code)
	}
	if got := decodeJSON(t, rec)["word"]; got != "水" {
		t.Errorf("get word = %v", got)
	}

	rec, _ = newTestRequest(s, "PUT", "/api/v1/words/"+itoa(id), `{"meaning":"water (cold)"}`)
	if rec.Code != 200 {
		t.Fatalf("update = %d %s", rec.Code, rec.Body.String())
	}

	rec, _ = newTestRequest(s, "PUT", "/api/v1/words/"+itoa(id)+"/tags", `{"tags":["nature"]}`)
	if rec.Code != 200 {
		t.Fatalf("tags = %d %s", rec.Code, rec.Body.String())
	}

	rec, _ = newTestRequest(s, "POST", "/api/v1/words/"+itoa(id)+"/reset", "")
	if rec.Code != 200 {
		t.Fatalf("reset = %d", rec.Code)
	}

	rec, _ = newTestRequest(s, "GET", "/api/v1/words/export", "")
	if rec.Code != 200 || rec.Body.Len() == 0 {
		t.Fatalf("export = %d body=%d", rec.Code, rec.Body.Len())
	}

	rec, _ = newTestRequest(s, "POST", "/api/v1/words/import", `[{"word":"火","reading":"ひ","meaning":"fire"}]`)
	if rec.Code != 200 {
		t.Fatalf("import = %d", rec.Code)
	}
	if got := decodeJSON(t, rec)["imported"].(float64); got != 1 {
		t.Errorf("imported = %v, want 1", got)
	}

	// Pending review: seed one, accept it, then reject another.
	if _, err := s.DB.InsertWord(&db.Word{Word: "空", Reading: "そら", Meaning: "sky", Language: "ja", Source: "test", Status: "pending_review"}); err != nil {
		t.Fatalf("seed pending: %v", err)
	}
	if _, err := s.DB.InsertWord(&db.Word{Word: "海", Reading: "うみ", Meaning: "sea", Language: "ja", Source: "test", Status: "pending_review"}); err != nil {
		t.Fatalf("seed pending 2: %v", err)
	}
	rec, _ = newTestRequest(s, "GET", "/api/v1/words/pending-review", "")
	if rec.Code != 200 {
		t.Fatalf("pending-review = %d", rec.Code)
	}
	pending, _ := s.DB.ListPendingReview("ja")
	if len(pending) != 2 {
		t.Fatalf("pending in db = %d", len(pending))
	}
	rec, _ = newTestRequest(s, "POST", "/api/v1/words/pending-review/"+itoa(pending[0].ID)+"/accept", `{"reading":"そら","meaning":"sky","pos":"n"}`)
	if rec.Code != 200 {
		t.Errorf("accept = %d %s", rec.Code, rec.Body.String())
	}
	rec, _ = newTestRequest(s, "POST", "/api/v1/words/pending-review/"+itoa(pending[1].ID)+"/reject", "")
	if rec.Code != 200 {
		t.Errorf("reject = %d %s", rec.Code, rec.Body.String())
	}

	rec, _ = newTestRequest(s, "DELETE", "/api/v1/words/"+itoa(id), "")
	if rec.Code != 200 {
		t.Errorf("delete = %d", rec.Code)
	}
}

func TestHTTPContentAndPlacement(t *testing.T) {
	s := newTestServer(t)
	withJapaneseCourse(s)
	withContentLibrary(t, s)

	rec, _ := newTestRequest(s, "GET", "/api/v1/content/packs", "")
	if rec.Code != 200 {
		t.Fatalf("packs = %d", rec.Code)
	}
	packs, _ := decodeJSON(t, rec)["packs"].([]interface{})
	if len(packs) < 2 {
		t.Errorf("packs = %d, want at least 2", len(packs))
	}

	rec, _ = newTestRequest(s, "GET", "/api/v1/dictionary/lookup?word="+urlEncode("会う"), "")
	if rec.Code != 200 {
		t.Fatalf("lookup = %d %s", rec.Code, rec.Body.String())
	}
	lookup := decodeJSON(t, rec)
	if lookup["found"] != true {
		t.Fatalf("lookup 会う not found: %s", rec.Body.String())
	}
	entry := lookup["entry"].(map[string]interface{})
	if entry["level"] != "N5" {
		t.Errorf("lookup level = %v, want N5", entry["level"])
	}

	rec, _ = newTestRequest(s, "GET", "/api/v1/dictionary/lookup?word=not-a-real-word-xl", "")
	if got := decodeJSON(t, rec)["found"]; got != false {
		t.Errorf("unknown lookup found = %v", got)
	}

	rec, _ = newTestRequest(s, "POST", "/api/v1/content/reload", `{}`)
	if rec.Code != 200 {
		t.Errorf("reload = %d", rec.Code)
	}

	rec, _ = newTestRequest(s, "POST", "/api/v1/quiz/placement/start", `{}`)
	if rec.Code != 200 {
		t.Fatalf("placement start = %d %s", rec.Code, rec.Body.String())
	}
	start := decodeJSON(t, rec)
	questions, _ := start["questions"].([]interface{})
	if len(questions) < 10 {
		t.Fatalf("placement questions = %d", len(questions))
	}
	answers := make([]map[string]string, 0, len(questions))
	for _, raw := range questions {
		q := raw.(map[string]interface{})
		answers = append(answers, map[string]string{"id": q["id"].(string), "answer": "definitely-wrong"})
	}
	body, _ := json.Marshal(map[string]interface{}{"id": start["id"], "answers": answers})
	rec, _ = newTestRequest(s, "POST", "/api/v1/quiz/placement/submit", string(body))
	if rec.Code != 200 {
		t.Fatalf("placement submit = %d %s", rec.Code, rec.Body.String())
	}
	result := decodeJSON(t, rec)
	if result["estimated_level"] != "beginner" {
		t.Errorf("estimated_level = %v, want beginner", result["estimated_level"])
	}
	if len(result["bands"].(map[string]interface{})) == 0 {
		t.Error("bands are empty")
	}

	rec, _ = newTestRequest(s, "POST", "/api/v1/quiz/placement/submit", `{"id":"nope","answers":[]}`)
	if rec.Code != 404 {
		t.Errorf("unknown placement id = %d, want 404", rec.Code)
	}
}

func TestHTTPStatsAndAuth(t *testing.T) {
	s := newTestServer(t)
	withJapaneseCourse(s)

	for _, path := range []string{
		"/api/v1/quiz/progress?language=ja",
		"/api/v1/quiz/today-stats?language=ja",
		"/api/v1/stats/heatmap?days=7&language=ja",
		"/api/v1/stats/streak?language=ja",
		"/api/v1/stats/daily-report?language=ja",
		"/api/v1/stats/diagnostics?days=7",
		"/api/v1/config/languages",
		"/api/v1/ai/profile",
	} {
		rec, _ := newTestRequest(s, "GET", path, "")
		if rec.Code != 200 && rec.Code != 204 {
			t.Errorf("GET %s = %d", path, rec.Code)
		}
	}

	unauth := unauthedRequest(s, "GET", "/api/v1/config")
	if unauth.Code != 401 {
		t.Errorf("unauthenticated request = %d, want 401", unauth.Code)
	}
}

func itoa(n int64) string { return strconv.FormatInt(n, 10) }

func urlEncode(s string) string { return url.QueryEscape(s) }

func TestHTTPQuizFlow(t *testing.T) {
	s := newTestServer(t)
	withJapaneseCourse(s)
	s.Config.Languages["ja"] = &config.LanguageConfig{QuestionTypes: []string{"choice"}}

	words := []struct{ w, r, m string }{
		{"水", "みず", "water"},
		{"火", "ひ", "fire"},
		{"山", "やま", "mountain"},
		{"川", "かわ", "river"},
		{"空", "そら", "sky"},
		{"海", "うみ", "sea"},
	}
	for _, w := range words {
		if _, err := s.DB.InsertWord(&db.Word{
			Word: w.w, Reading: w.r, Meaning: w.m, POS: "n", Language: "ja", Source: "test", Status: "active",
		}); err != nil {
			t.Fatalf("seed word: %v", err)
		}
	}

	rec, _ := newTestRequest(s, "POST", "/api/v1/quiz/session/start", `{}`)
	if rec.Code != 200 {
		t.Fatalf("session start = %d %s", rec.Code, rec.Body.String())
	}

	answered := 0
	for i := 0; i < 3; i++ {
		rec, _ = newTestRequest(s, "GET", "/api/v1/quiz/next?language=ja", "")
		if rec.Code != 200 {
			t.Fatalf("next = %d %s", rec.Code, rec.Body.String())
		}
		q := decodeJSON(t, rec)
		if q["id"] == nil || q["subject_id"] == nil {
			t.Fatalf("next payload: %s", rec.Body.String())
		}
		subjectID := int64(q["subject_id"].(float64))
		word, err := s.DB.GetWord(subjectID)
		if err != nil {
			t.Fatalf("get subject %d: %v", subjectID, err)
		}
		answer := word.Meaning
		switch q["type"] {
		case "fill", "spelling":
			answer = word.Word
		case "pronounce":
			answer = word.Reading
		}
		body := map[string]interface{}{
			"question_id":   q["id"],
			"subject_type":  q["subject_type"],
			"subject_id":    subjectID,
			"question_type": q["type"],
			"answer":        answer,
		}
		raw, _ := json.Marshal(body)
		rec, _ = newTestRequest(s, "POST", "/api/v1/quiz/submit", string(raw))
		if rec.Code != 200 {
			t.Fatalf("submit = %d %s", rec.Code, rec.Body.String())
		}
		result := decodeJSON(t, rec)
		if result["correct"] != true {
			t.Errorf("submit %s (%s) marked wrong: %s", word.Word, answer, rec.Body.String())
		}
		answered++
	}
	if answered != 3 {
		t.Errorf("answered = %d", answered)
	}

	rec, _ = newTestRequest(s, "POST", "/api/v1/quiz/complete", `{}`)
	if rec.Code != 200 {
		t.Errorf("complete = %d %s", rec.Code, rec.Body.String())
	}

	for _, path := range []string{"/api/v1/quiz/progress?language=ja", "/api/v1/quiz/plan?language=ja"} {
		rec, _ = newTestRequest(s, "GET", path, "")
		if rec.Code != 200 {
			t.Errorf("GET %s = %d", path, rec.Code)
		}
	}
	rec, _ = newTestRequest(s, "PUT", "/api/v1/quiz/direction", `{"direction":"exam"}`)
	if rec.Code != 200 && rec.Code != 400 {
		t.Errorf("direction = %d", rec.Code)
	}

	for _, path := range []string{"/api/v1/system/status", "/api/v1/system/passive-q"} {
		rec, _ = newTestRequest(s, "GET", path, "")
		if rec.Code != 200 && rec.Code != 204 {
			t.Errorf("GET %s = %d", path, rec.Code)
		}
	}
}

func TestHTTPContentPackErrors(t *testing.T) {
	s := newTestServer(t)
	s.Content = &content.Library{Errors: []error{errors.New("pack broken: no entries")}}
	rec, _ := newTestRequest(s, "GET", "/api/v1/content/packs", "")
	if rec.Code != 200 {
		t.Fatalf("packs = %d", rec.Code)
	}
	errs, _ := decodeJSON(t, rec)["errors"].([]interface{})
	if len(errs) != 1 {
		t.Errorf("errors = %v, want one", errs)
	}
}

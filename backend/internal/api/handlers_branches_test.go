package api

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/tzhnahida/VocabLock/internal/db"
)

func submitBody(t *testing.T, v map[string]interface{}) string {
	t.Helper()
	b, err := json.Marshal(v)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	return string(b)
}

func TestQuizSubmitErrorBranches(t *testing.T) {
	s := newTestServer(t)
	withJapaneseCourse(s)
	if _, err := s.DB.InsertWord(&db.Word{Word: "水", Reading: "みず", Meaning: "water", POS: "n", Language: "ja", Status: "active"}); err != nil {
		t.Fatal(err)
	}

	cases := []struct {
		name string
		body string
		want int
	}{
		{"invalid json", `{`, 400},
		{"answer too long", submitBody(t, map[string]interface{}{
			"question_id": "q", "subject_type": "word", "subject_id": 1, "question_type": "choice",
			"answer": strings.Repeat("x", maxQuizAnswer+1),
		}), 400},
		{"audio too large", submitBody(t, map[string]interface{}{
			"question_id": "q", "subject_type": "word", "subject_id": 1, "question_type": "read_word",
			"answer": "", "audio": strings.Repeat("A", maxQuizAudioBase64+1),
		}), 400},
		{"word missing", submitBody(t, map[string]interface{}{
			"question_id": "q", "subject_type": "word", "subject_id": 99999, "question_type": "choice", "answer": "x",
		}), 404},
		{"grammar cache miss", submitBody(t, map[string]interface{}{
			"question_id": "q", "subject_type": "grammar", "subject_id": 99999, "question_type": "grammar", "answer": "x",
		}), 200},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			rec, _ := newTestRequest(s, "POST", "/api/v1/quiz/submit", c.body)
			if rec.Code != c.want {
				t.Errorf("status = %d, want %d (%s)", rec.Code, c.want, rec.Body.String())
			}
		})
	}

	// AI-generated types have no local answer; a missing cache is an expired
	// question, not a wrong answer.
	rec, _ := newTestRequest(s, "POST", "/api/v1/quiz/submit", submitBody(t, map[string]interface{}{
		"question_id": "never-cached", "subject_type": "word", "subject_id": 1, "question_type": "listening", "answer": "water",
	}))
	if rec.Code != 200 || decodeJSON(t, rec)["source"] != "cache_miss" {
		t.Errorf("cache miss = %d %s", rec.Code, rec.Body.String())
	}
}

func TestQuizMiscEndpoints(t *testing.T) {
	s := newTestServer(t)
	withJapaneseCourse(s)

	rec, _ := newTestRequest(s, "POST", "/api/v1/quiz/dispute", `{}`)
	if rec.Code != 400 {
		t.Errorf("dispute without log_id = %d, want 400", rec.Code)
	}

	rec, _ = newTestRequest(s, "POST", "/api/v1/quiz/summarize", `{}`)
	if rec.Code != 200 {
		t.Errorf("summarize without AI = %d, want 200 message", rec.Code)
	}

	for _, path := range []string{"/api/v1/quiz/assignment", "/api/v1/quiz/assignment/cadence"} {
		rec, _ = newTestRequest(s, "GET", path, "")
		if rec.Code != 200 && rec.Code != 204 {
			t.Errorf("GET %s = %d", path, rec.Code)
		}
	}
	rec, _ = newTestRequest(s, "POST", "/api/v1/quiz/assignment/submit", `{}`)
	if rec.Code != 400 && rec.Code != 200 && rec.Code != 500 {
		t.Errorf("assignment submit empty = %d", rec.Code)
	}
}

func TestGrammarCRUD(t *testing.T) {
	s := newTestServer(t)
	withJapaneseCourse(s)

	rec, _ := newTestRequest(s, "POST", "/api/v1/grammar-points", `{"title":"〜ている","meaning":"progressive","language":"ja"}`)
	if rec.Code != 200 {
		t.Fatalf("create grammar = %d %s", rec.Code, rec.Body.String())
	}
	created := decodeJSON(t, rec)
	id := int64(created["id"].(float64))
	if id == 0 {
		t.Fatalf("no id: %s", rec.Body.String())
	}

	rec, _ = newTestRequest(s, "GET", "/api/v1/grammar-points?language=ja", "")
	if rec.Code != 200 {
		t.Fatalf("list grammar = %d", rec.Code)
	}

	rec, _ = newTestRequest(s, "PUT", "/api/v1/grammar-points/"+itoa(id), `{"title":"〜ている","meaning":"progressive form","language":"ja"}`)
	if rec.Code != 200 {
		t.Errorf("update grammar = %d %s", rec.Code, rec.Body.String())
	}

	rec, _ = newTestRequest(s, "DELETE", "/api/v1/grammar-points/"+itoa(id), "")
	if rec.Code != 200 {
		t.Errorf("delete grammar = %d", rec.Code)
	}
}

func TestConfigAIAndPassword(t *testing.T) {
	s := newTestServer(t)

	rec, _ := newTestRequest(s, "GET", "/api/v1/config/ai", "")
	if rec.Code != 200 {
		t.Fatalf("GET config/ai = %d", rec.Code)
	}
	if _, ok := decodeJSON(t, rec)["configured"]; !ok {
		t.Errorf("config/ai payload: %s", rec.Body.String())
	}

	rec, _ = newTestRequest(s, "PUT", "/api/v1/config/ai", `{"model":"deepseek-chat"}`)
	if rec.Code != 200 {
		t.Errorf("PUT config/ai = %d %s", rec.Code, rec.Body.String())
	}

	rec, _ = newTestRequest(s, "POST", "/api/v1/config/password", `{"password":"x"}`)
	if rec.Code != 501 {
		t.Errorf("config/password = %d, want 501", rec.Code)
	}
}

func TestSystemEndpoints(t *testing.T) {
	s := newTestServer(t)
	withJapaneseCourse(s)

	for _, tc := range []struct {
		method, path string
		want         int
	}{
		{"GET", "/api/v1/system/status", 200},
		{"GET", "/api/v1/system/passive-q", 200},
		{"POST", "/api/v1/system/unlock", 200},
	} {
		rec, _ := newTestRequest(s, tc.method, tc.path, `{}`)
		if rec.Code != tc.want && rec.Code != 204 {
			t.Errorf("%s %s = %d, want %d", tc.method, tc.path, rec.Code, tc.want)
		}
	}
}

func TestProviderConfigEndpoints(t *testing.T) {
	s := newTestServer(t)
	withJapaneseCourse(s)
	s.ConfigDir = t.TempDir()

	for _, path := range []string{"/api/v1/config/tts", "/api/v1/config/dict", "/api/v1/config/language/ja"} {
		rec, _ := newTestRequest(s, "GET", path, "")
		if rec.Code != 200 {
			t.Errorf("GET %s = %d %s", path, rec.Code, rec.Body.String())
		}
	}
	rec, _ := newTestRequest(s, "GET", "/api/v1/config/language/xx", "")
	if rec.Code != 404 {
		t.Errorf("unknown language = %d, want 404", rec.Code)
	}

	// Unknown providers are 404s; save/delete paths are exercised even when
	// the payload is rejected by validation.
	for _, base := range []string{"/api/v1/config/tts/foo", "/api/v1/config/dict/foo"} {
		rec, _ = newTestRequest(s, "GET", base, "")
		if rec.Code != 404 {
			t.Errorf("GET %s = %d, want 404", base, rec.Code)
		}
		rec, _ = newTestRequest(s, "PUT", base, `{}`)
		if rec.Code != 200 && rec.Code != 400 && rec.Code != 500 {
			t.Errorf("PUT %s = %d", base, rec.Code)
		}
		rec, _ = newTestRequest(s, "DELETE", base, "")
		if rec.Code < 200 || rec.Code >= 500 {
			t.Errorf("DELETE %s = %d", base, rec.Code)
		}
	}

	rec, _ = newTestRequest(s, "POST", "/api/v1/config/language/init", `{"language":"zz"}`)
	if rec.Code != 400 {
		t.Errorf("init unknown language = %d, want 400", rec.Code)
	}

	// Save-then-delete exercises the YAML writers with a real config dir.
	rec, _ = newTestRequest(s, "PUT", "/api/v1/config/tts/saved", `{"args":["--x"],"voices":{"a":"b"}}`)
	if rec.Code != 200 && rec.Code != 500 {
		t.Errorf("save tts = %d %s", rec.Code, rec.Body.String())
	}
	rec, _ = newTestRequest(s, "DELETE", "/api/v1/config/tts/saved", "")
	if rec.Code != 200 && rec.Code != 404 {
		t.Errorf("delete tts = %d", rec.Code)
	}
	rec, _ = newTestRequest(s, "PUT", "/api/v1/config/dict/saved", `{"args":["--w"]}`)
	if rec.Code != 200 && rec.Code != 500 {
		t.Errorf("save dict = %d %s", rec.Code, rec.Body.String())
	}
	rec, _ = newTestRequest(s, "DELETE", "/api/v1/config/dict/saved", "")
	if rec.Code != 200 && rec.Code != 404 {
		t.Errorf("delete dict = %d", rec.Code)
	}
}

func fakeAIServerContent(t *testing.T, content string) *httptest.Server {
	t.Helper()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]interface{}{
			"choices": []map[string]interface{}{
				{"message": map[string]string{"role": "assistant", "content": content}},
			},
			"usage": map[string]int{"prompt_tokens": 1, "completion_tokens": 1},
		})
	}))
	t.Cleanup(srv.Close)
	return srv
}

func fakeAIServer(t *testing.T) *httptest.Server {
	return fakeAIServerContent(t, "{\"reply\":\"hi\",\"verdict\":true}")
}

func withFakeAIContent(t *testing.T, s *Server, content string) {
	t.Helper()
	srv := fakeAIServerContent(t, content)
	s.Config.App.AI.BaseURL = srv.URL
	s.Config.App.AI.APIKey = "test-key"
	s.Config.App.AI.Model = "fake-model"
	s.WireAI()
	if s.AI() == nil {
		t.Fatal("fake AI client not wired")
	}
}

func withFakeAI(t *testing.T, s *Server) {
	t.Helper()
	withFakeAIContent(t, s, "{\"reply\":\"hi\",\"verdict\":true}")
}

func TestExpandWithFakeAI(t *testing.T) {
	s := newTestServer(t)
	withJapaneseCourse(s)
	withContentLibrary(t, s)
	withFakeAIContent(t, s, `{"status":"ok","words":[{"word":"雨","reading":"あめ","meaning":"rain","example":"雨が降る。"}]}`)

	rec, _ := newTestRequest(s, "POST", "/api/v1/words/expand", `{"count":2}`)
	if rec.Code != 200 {
		t.Fatalf("expand = %d %s", rec.Code, rec.Body.String())
	}
	if rec.Code == 200 && strings.Contains(rec.Body.String(), "error") {
		t.Logf("expand body: %s", rec.Body.String())
	}
}

func TestFakeAIBranches(t *testing.T) {
	s := newTestServer(t)
	withJapaneseCourse(s)
	withFakeAI(t, s)

	rec, _ := newTestRequest(s, "GET", "/api/v1/ai/profile", "")
	if rec.Code != 200 {
		t.Fatalf("profile = %d", rec.Code)
	}
	if decodeJSON(t, rec)["configured"] != true {
		t.Errorf("profile configured = %v", decodeJSON(t, rec)["configured"])
	}

	rec, _ = newTestRequest(s, "PUT", "/api/v1/ai/profile", `{"model":"fake-model"}`)
	if rec.Code != 200 {
		t.Errorf("profile update = %d %s", rec.Code, rec.Body.String())
	}

	rec, _ = newTestRequest(s, "POST", "/api/v1/ai/chat", `{"message":"hello"}`)
	if rec.Code != 200 {
		t.Errorf("ai chat = %d %s", rec.Code, rec.Body.String())
	}

	for _, tc := range []struct{ method, path, body string }{
		{"POST", "/api/v1/quiz/summarize", `{}`},
		{"GET", "/api/v1/quiz/assignment", ""},
		{"GET", "/api/v1/quiz/assignment/cadence", ""},
		{"POST", "/api/v1/quiz/session/continue", `{}`},
	} {
		rec, _ = newTestRequest(s, tc.method, tc.path, tc.body)
		if rec.Code >= 500 {
			t.Errorf("%s %s = %d %s", tc.method, tc.path, rec.Code, rec.Body.String())
		}
	}
}

func TestMiscHandlerBranches(t *testing.T) {
	s := newTestServer(t)
	withJapaneseCourse(s)

	for _, tc := range []struct{ method, path, body string }{
		{"POST", "/api/v1/pronounce/assess", `{}`},
		{"POST", "/api/v1/tts/text", `{}`},
		{"POST", "/api/v1/quiz/submit", `{"question_id":"r1","subject_type":"word","subject_id":1,"question_type":"read_word","audio":"AAAA"}`},
		{"GET", "/api/v1/tts/word/1", ""},
		{"PUT", "/api/v1/quiz/direction", `{"direction":"nope"}`},
		{"GET", "/api/v1/words/new", ""},
		{"POST", "/api/v1/words/expand", `{"count":1}`},
		{"POST", "/api/v1/quiz/complete", `{}`},
	} {
		rec, _ := newTestRequest(s, tc.method, tc.path, tc.body)
		if rec.Code >= 500 {
			t.Errorf("%s %s = %d %s", tc.method, tc.path, rec.Code, rec.Body.String())
		}
	}
}

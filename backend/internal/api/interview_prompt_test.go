package api

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

// The onboarding interview must use a dedicated prompt: the normal chat prompt
// turns the model into a teacher, which starts teaching vocabulary instead of
// collecting requirements.
func TestAIChatInterviewUsesRequirementsPrompt(t *testing.T) {
	s := newTestServer(t)
	withJapaneseCourse(s)

	var systemPrompt string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Messages []struct {
				Role    string `json:"role"`
				Content string `json:"content"`
			} `json:"messages"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		if len(body.Messages) > 0 {
			systemPrompt = body.Messages[0].Content
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]interface{}{
			"choices": []map[string]interface{}{
				{"message": map[string]string{"role": "assistant", "content": "what is your level?"}},
			},
			"usage": map[string]int{"prompt_tokens": 1, "completion_tokens": 1},
		})
	}))
	defer srv.Close()

	s.Config.App.AI.BaseURL = srv.URL
	s.Config.App.AI.APIKey = "test-key"
	s.Config.App.AI.Model = "fake"
	s.WireAI()

	rec, _ := newTestRequest(s, "POST", "/api/v1/ai/chat", `{"message":"I want to prepare for N2","purpose":"interview"}`)
	if rec.Code != 200 {
		t.Fatalf("chat = %d %s", rec.Code, rec.Body.String())
	}
	if !strings.Contains(systemPrompt, "requirements interviewer") {
		t.Errorf("system prompt was not the interview prompt: %.200s", systemPrompt)
	}
	if strings.Contains(systemPrompt, "You are a language teacher") {
		t.Errorf("teacher prompt leaked into interview: %.200s", systemPrompt)
	}
}

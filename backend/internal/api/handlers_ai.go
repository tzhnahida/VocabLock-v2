package api

import (
	"context"
	"net/http"
	"time"

	"github.com/tzhnahida/VocabLock/internal/ai"
	"github.com/tzhnahida/VocabLock/internal/api/mock"
	"github.com/tzhnahida/VocabLock/internal/log"
)

func (s *Server) handleAIChat(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleAIChat(w, r)
		return
	}

	var req struct {
		Message string       `json:"message"`
		History []ai.Message `json:"history"`
	}
	if err := readJSON(r, &req); err != nil {
		writeError(w, 400, "invalid request body")
		return
	}

	if len(req.Message) > maxAIChatMessage {
		writeError(w, 400, "message is too long")
		return
	}
	if len(req.History) > maxAIChatHistory {
		writeError(w, 400, "history is too long")
		return
	}
	for _, m := range req.History {
		if len(m.Content) > maxAIChatHistoryItem {
			writeError(w, 400, "history message is too long")
			return
		}
	}

	log.Debug("ai/chat", "request: len=%d history=%d", len(req.Message), len(req.History))

	if s.AI() == nil {
		writeJSON(w, map[string]interface{}{
			"reply": "AI chat requires API key configuration. Set ai.api_key in app.yaml.",
			"model": "none",
		})
		return
	}

	// Load chat prompt
	pt, err := ai.LoadPrompt("chat")
	if err != nil {
		writeError(w, 500, "load prompt: "+err.Error())
		return
	}

	// The chat is course-scoped: the student is already enrolled, so the prompt
	// must not ask which language they want to learn.
	teacherRole, explLang, level := s.langContext(s.Config.App.ActiveLang)
	courseLang := s.Config.App.ActiveLang
	if lc, ok := s.Config.Languages[s.Config.App.ActiveLang]; ok {
		if lc.Lang.NativeName != "" {
			courseLang = lc.Lang.NativeName
		} else if lc.Lang.DisplayName != "" {
			courseLang = lc.Lang.DisplayName
		}
	}

	messages, err := pt.BuildMessages(&ai.PromptVars{
		TeacherRole:     teacherRole,
		ExplanationLang: explLang,
		Language:        courseLang,
		Level:           level,
		ExtraContext:    req.Message,
	})
	if err != nil {
		writeError(w, 500, "build prompt: "+err.Error())
		return
	}

	// Insert conversation history between system prompt and current message
	sysMsg := messages[0]
	var allMsgs []ai.Message
	allMsgs = append(allMsgs, sysMsg)
	allMsgs = append(allMsgs, req.History...)
	allMsgs = append(allMsgs, messages[1:]...)

	ctx, cancel := context.WithTimeout(r.Context(), 60*time.Second)
	defer cancel()

	log.Debug("ai/chat", "user: %.80s...", req.Message)
	reply, err := s.AI().Chat(ctx, allMsgs, pt.Temperature)
	if err != nil {
		log.Error("ai/chat", "%v", err)
		writeJSON(w, map[string]interface{}{
			"reply": "AI暂时无法响应，请稍后重试。",
			"model": "error",
			"error": err.Error(),
		})
		return
	}
	log.Debug("ai/chat", "reply: %.120s...", reply)

	writeJSON(w, map[string]interface{}{
		"reply": reply,
		"model": s.Config.App.AI.Model,
	})
}

func (s *Server) handleAIProfile(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleAIProfile(w, r)
		return
	}

	writeJSON(w, map[string]interface{}{
		"base_url":   s.Config.App.AI.BaseURL,
		"model":      s.Config.App.AI.Model,
		"configured": s.AI() != nil,
	})
}

func (s *Server) handleAIProfileUpdate(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleAIProfileUpdate(w, r)
		return
	}

	var req struct {
		Language  string `json:"language"`
		Level     string `json:"level"`
		Direction string `json:"direction"`
		Profile   string `json:"profile"` // full AI-generated profile text
	}
	if err := readJSON(r, &req); err != nil {
		writeError(w, 400, "invalid request body")
		return
	}
	if len(req.Profile) > maxAITrainingProfile {
		writeError(w, 400, "profile is too long")
		return
	}

	lang := req.Language
	if lang == "" {
		lang = s.Config.App.ActiveLang
	}

	log.Debug("ai/profile", "set: lang=%s", lang)

	direction := req.Direction
	if direction == "" {
		direction = "general"
	}

	if s.DB != nil {
		if _, err := s.DB.InsertTrainingPlan(lang, direction, 1.0, req.Profile); err != nil {
			log.Error("ai/profile", "save plan: %v", err)
		}
	}

	writeJSON(w, map[string]interface{}{
		"saved":     true,
		"language":  lang,
		"direction": direction,
	})
}

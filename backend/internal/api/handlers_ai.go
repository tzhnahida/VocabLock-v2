package api

import (
	"context"
	"net/http"
	"time"

	"github.com/vocablock/v2/internal/ai"
	"github.com/vocablock/v2/internal/api/mock"
)

func (s *Server) handleAIChat(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleAIChat(w, r); return
	}

	var req struct {
		Message string `json:"message"`
	}
	if err := readJSON(r, &req); err != nil {
		writeError(w, 400, "invalid request body")
		return
	}

	if s.AI == nil {
		writeJSON(w, map[string]interface{}{
			"reply":  "AI chat requires API key configuration. Set ai.api_key in app.yaml.",
			"model":  "none",
		})
		return
	}

	// Load chat prompt
	pt, err := ai.LoadPrompt("chat")
	if err != nil {
		writeError(w, 500, "load prompt: "+err.Error())
		return
	}

	explLang := "en"
	teacherRole := "Language Teacher"
	if lc, ok := s.Config.Languages[s.Config.App.ActiveLang]; ok {
		explLang = lc.PromptContext.ExplanationLang
		teacherRole = lc.PromptContext.TeacherRole
	}

	messages, err := pt.BuildMessages(&ai.PromptVars{
		TeacherRole:     teacherRole,
		ExplanationLang: explLang,
		ExtraContext:    req.Message,
	})
	if err != nil {
		writeError(w, 500, "build prompt: "+err.Error())
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 30*time.Second)
	defer cancel()

	reply, err := s.AI.Chat(ctx, messages)
	if err != nil {
		writeJSON(w, map[string]interface{}{
			"reply": "AI暂时无法响应，请稍后重试。",
			"model": "error",
			"error": err.Error(),
		})
		return
	}

	writeJSON(w, map[string]interface{}{
		"reply": reply,
		"model": s.Config.App.AI.Model,
	})
}

func (s *Server) handleAIProfile(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleAIProfile(w, r); return
	}

	writeJSON(w, map[string]interface{}{
		"base_url":   s.Config.App.AI.BaseURL,
		"model":      s.Config.App.AI.Model,
		"configured": s.AI != nil,
	})
}

func (s *Server) handleAIProfileUpdate(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleAIProfileUpdate(w, r); return
	}
	writeNotImplemented(w)
}

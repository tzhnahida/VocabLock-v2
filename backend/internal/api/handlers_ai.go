package api

import (
	"context"
	"fmt"
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
		Message  string         `json:"message"`
		History  []ai.Message   `json:"history"`
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

	explLang := "zh-CN"
	teacherRole := "语言教师"
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

	// Insert conversation history between system prompt and current message
	sysMsg := messages[0]
	var allMsgs []ai.Message
	allMsgs = append(allMsgs, sysMsg)
	allMsgs = append(allMsgs, req.History...)
	allMsgs = append(allMsgs, messages[1:]...)

	ctx, cancel := context.WithTimeout(r.Context(), 30*time.Second)
	defer cancel()

	fmt.Printf("  AI user: %.80s...\n", req.Message)
	reply, err := s.AI.Chat(ctx, allMsgs)
	if err != nil {
		fmt.Printf("  AI error: %v\n", err)
		writeJSON(w, map[string]interface{}{
			"reply": "AI暂时无法响应，请稍后重试。",
			"model": "error",
			"error": err.Error(),
		})
		return
	}
	fmt.Printf("  AI reply: %.120s...\n", reply)

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

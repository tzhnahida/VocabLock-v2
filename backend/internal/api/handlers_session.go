package api

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/vocablock/v2/internal/ai"
	"github.com/vocablock/v2/internal/db"
)

// handleQuizSummarize triggers AI analysis of today's session.
func (s *Server) handleQuizSummarize(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		writeJSON(w, map[string]interface{}{
			"message": "mock mode: no summary available",
		})
		return
	}
	if s.AI == nil {
		writeJSON(w, map[string]interface{}{
			"message": "AI required for session summary",
		})
		return
	}

	lang := s.Config.App.ActiveLang

	// Collect today's session data
	logs, err := s.DB.GetSessionLogs(lang, 200)
	if err != nil || len(logs) == 0 {
		writeJSON(w, map[string]interface{}{
			"message": "no session data to summarize",
		})
		return
	}

	stats := buildSessionStats(logs)
	yesterdayPlan := s.getYesterdayPlan(lang)

	result, err := s.runSummarize(r.Context(), lang, stats, yesterdayPlan)
	if err != nil {
		writeError(w, 500, "summarize: "+err.Error())
		return
	}

	// Auto-generate updated plan after summary
	plan, planErr := s.runPlan(r.Context(), lang, stats, result)
	if planErr != nil {
		writeJSON(w, map[string]interface{}{
			"summary": result,
			"plan":    nil,
			"warning": "plan generation failed: " + planErr.Error(),
		})
		return
	}

	writeJSON(w, map[string]interface{}{
		"summary": result,
		"plan":    plan,
	})
}

// handleQuizPlan returns the current active training plan.
func (s *Server) handleQuizPlan(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		writeJSON(w, map[string]interface{}{
			"direction": "general",
			"plan_json": `{}`,
			"message":   "mock mode",
		})
		return
	}

	lang := s.Config.App.ActiveLang
	plan, err := s.DB.GetActivePlan(lang)
	if err != nil {
		writeJSON(w, map[string]interface{}{
			"direction": "general",
			"message":   "no plan yet — complete a session first",
		})
		return
	}

	writeJSON(w, map[string]interface{}{
		"id":                   plan.ID,
		"direction":            plan.Direction,
		"direction_confidence": plan.DirectionConfidence,
		"plan_json":            plan.PlanJSON,
		"created_at":           plan.CreatedAt,
	})
}

// handleQuizDirection sets the learning direction.
func (s *Server) handleQuizDirection(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		writeJSON(w, map[string]interface{}{"direction": "general", "set": true}); return
	}
	if s.DB == nil {
		writeError(w, 500, "database not available"); return
	}
	var req struct {
		Direction string `json:"direction"`
	}
	if err := readJSON(r, &req); err != nil || req.Direction == "" {
		writeError(w, 400, "direction is required")
		return
	}

	lang := s.Config.App.ActiveLang
	if _, err := s.DB.InsertTrainingPlan(lang, req.Direction, 1.0, "{}"); err != nil {
		writeError(w, 500, "save direction: "+err.Error())
		return
	}
	writeJSON(w, map[string]interface{}{
		"direction": req.Direction,
		"set":       true,
	})
}

// ——— helpers ———

func buildSessionStats(logs []*db.ReviewLog) string {
	typeCount := map[string]int{}
	correct, total := 0, 0
	for _, l := range logs {
		typeCount[l.QuestionType]++
		total++
		if l.Correct {
			correct++
		}
	}
	accuracy := 0.0
	if total > 0 {
		accuracy = float64(correct) / float64(total)
	}
	stats := map[string]interface{}{
		"total":         total,
		"correct":       correct,
		"accuracy":      accuracy,
		"by_type":       typeCount,
	}
	b, _ := json.Marshal(stats)
	return string(b)
}

func (s *Server) getYesterdayPlan(lang string) string {
	plan, err := s.DB.GetActivePlan(lang)
	if err != nil {
		return "(no previous plan)"
	}
	return plan.PlanJSON
}

func (s *Server) runSummarize(ctx context.Context, lang, stats, yesterdayPlan string) (map[string]interface{}, error) {
	pt, err := ai.LoadPrompt("summarize")
	if err != nil {
		return nil, err
	}

	teacherRole, explLang, level := s.langContext(lang)

	messages, err := pt.BuildMessages(&ai.PromptVars{
		TeacherRole:     teacherRole,
		ExplanationLang: explLang,
		Language:        lang,
		Level:           level,
		SessionStats:    stats,
		YesterdayPlan:   yesterdayPlan,
	})
	if err != nil {
		return nil, err
	}

	timeoutCtx, cancel := context.WithTimeout(ctx, 60*time.Second)
	defer cancel()

	response, err := s.AI.Chat(timeoutCtx, messages)
	if err != nil {
		return nil, err
	}

	cleaned := extractJSON(response)
	var result map[string]interface{}
	if err := json.Unmarshal([]byte(cleaned), &result); err != nil {
		return nil, fmt.Errorf("parse AI response: %w", err)
	}
	return result, nil
}

func (s *Server) runPlan(ctx context.Context, lang, stats string, summary map[string]interface{}) (map[string]interface{}, error) {
	pt, err := ai.LoadPrompt("plan")
	if err != nil {
		return nil, err
	}

	teacherRole, explLang, level := s.langContext(lang)

	weakPoints := ""
	if w, ok := summary["today_summary"].(map[string]interface{})["weaknesses"]; ok {
		b, _ := json.Marshal(w)
		weakPoints = string(b)
	}

	messages, err := pt.BuildMessages(&ai.PromptVars{
		TeacherRole:     teacherRole,
		ExplanationLang: explLang,
		Language:        lang,
		Level:           level,
		SessionStats:    stats,
		WeakPoints:      weakPoints,
		YesterdayPlan:   s.getYesterdayPlan(lang),
	})
	if err != nil {
		return nil, err
	}

	timeoutCtx, cancel := context.WithTimeout(ctx, 60*time.Second)
	defer cancel()

	response, err := s.AI.Chat(timeoutCtx, messages)
	if err != nil {
		return nil, err
	}

	cleaned := extractJSON(response)
	var result map[string]interface{}
	if err := json.Unmarshal([]byte(cleaned), &result); err != nil {
		return nil, fmt.Errorf("parse AI response: %w", err)
	}

	// Store the plan
	direction := "general"
	if d, ok := result["direction"].(string); ok {
		direction = d
	}
	confidence := 0.0
	if c, ok := result["direction_confidence"].(float64); ok {
		confidence = c
	}
	planJSON, _ := json.Marshal(result)
	s.DB.InsertTrainingPlan(lang, direction, confidence, string(planJSON))

	return result, nil
}

func (s *Server) langContext(lang string) (teacherRole, explLang, level string) {
	teacherRole = "Language Teacher"
	explLang = "en"
	level = "beginner"
	if lc, ok := s.Config.Languages[lang]; ok {
		teacherRole = lc.PromptContext.TeacherRole
		explLang = lc.PromptContext.ExplanationLang
		for lvl := range lc.PromptContext.LevelDescriptions {
			level = lvl
			break
		}
	}
	return
}

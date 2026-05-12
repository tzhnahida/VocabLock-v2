package api

import (
	"context"
	"encoding/json"
	"net/http"
	"strings"
	"time"

	"github.com/vocablock/v2/internal/ai"
	"github.com/vocablock/v2/internal/engine"
)

// handleAssignmentNext returns the next pending assignment, or generates a new batch if due.
func (s *Server) handleAssignmentNext(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		writeJSON(w, map[string]interface{}{
			"assignments": []interface{}{},
			"message":     "mock mode: no assignments",
		})
		return
	}
	if s.DB == nil {
		writeError(w, 500, "database not available")
		return
	}
	if s.AI == nil {
		writeJSON(w, map[string]interface{}{
			"assignments": []interface{}{},
			"message":     "AI required for assignments",
		})
		return
	}

	lang := s.Config.App.ActiveLang
	cfg := s.Config.App.Assignment

	// Check for existing pending assignments
	pending, err := s.DB.ListPendingAssignments(lang)
	if err == nil && len(pending) > 0 {
		writeJSON(w, map[string]interface{}{
			"assignments": pending,
			"pending":     true,
		})
		return
	}

	// Check cadence: is it time for new assignments?
	if !s.isAssignmentDue(lang) {
		nextDue := s.nextAssignmentDue(lang)
		writeJSON(w, map[string]interface{}{
			"assignments": []interface{}{},
			"message":     "no assignments due",
			"next_due_at": nextDue,
		})
		return
	}

	// Generate new assignments
	count := cfg.CadenceCount
	if count > cfg.MaxPerSession {
		count = cfg.MaxPerSession
	}
	if count < 1 {
		count = 1
	}

	assignments := make([]map[string]interface{}, 0, count)
	for i := 0; i < count; i++ {
		// Rotate through assignment types
		types := []engine.AssignmentType{
			engine.AssignmentSentence,
			engine.AssignmentTranslation,
			engine.AssignmentFillPassage,
			engine.AssignmentEssay,
		}
		aType := types[i%len(types)]

		a, err := s.generateAssignment(r.Context(), lang, aType)
		if err != nil {
			continue
		}
		assignments = append(assignments, map[string]interface{}{
			"id":      a.ID,
			"type":    a.Type,
			"prompt":  a.Prompt,
			"context": a.Context,
		})
		// Store in DB
		s.DB.InsertAssignment(lang, string(a.Type), a.Prompt, a.Context)
	}

	if len(assignments) == 0 {
		writeJSON(w, map[string]interface{}{
			"assignments": []interface{}{},
			"message":     "AI generation failed, try again later",
		})
		return
	}

	// Mark assignment as given today
	s.DB.MarkAssignmentGiven(lang)

	writeJSON(w, map[string]interface{}{
		"assignments": assignments,
		"pending":     false,
	})
}

// handleAssignmentSubmit grades a submitted assignment.
func (s *Server) handleAssignmentSubmit(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		writeJSON(w, map[string]interface{}{
			"original":  "mock submission",
			"corrected": "mock corrected",
			"score":     0.95,
			"feedback":  "Great job!",
			"errors":    []interface{}{},
		})
		return
	}
	if s.AI == nil {
		writeError(w, 500, "AI not available")
		return
	}

	var req struct {
		AssignmentID string `json:"assignment_id"`
		Answer       string `json:"answer"`
	}
	if err := readJSON(r, &req); err != nil {
		writeError(w, 400, "invalid request body")
		return
	}
	if strings.TrimSpace(req.Answer) == "" {
		writeError(w, 400, "answer cannot be empty")
		return
	}

	lang := s.Config.App.ActiveLang
	grade, err := s.gradeAssignment(r.Context(), lang, req.Answer)
	if err != nil {
		writeError(w, 500, "grade assignment: "+err.Error())
		return
	}

	// Mark assignment as completed
	if req.AssignmentID != "" {
		s.DB.CompleteAssignment(req.AssignmentID, req.Answer, grade.Score, grade.Feedback)
	}

	writeJSON(w, grade)
}

// handleAssignmentCadence returns AI-recommended assignment cadence.
func (s *Server) handleAssignmentCadence(w http.ResponseWriter, r *http.Request) {
	if s.Mock || s.AI == nil {
		writeJSON(w, map[string]interface{}{
			"cadence_days":  s.Config.App.Assignment.CadenceDays,
			"cadence_count": s.Config.App.Assignment.CadenceCount,
			"reason":        "using configured defaults",
		})
		return
	}

	lang := s.Config.App.ActiveLang
	recommend, err := s.aiCadenceRecommend(r.Context(), lang)
	if err != nil {
		writeJSON(w, map[string]interface{}{
			"cadence_days":  s.Config.App.Assignment.CadenceDays,
			"cadence_count": s.Config.App.Assignment.CadenceCount,
			"reason":        "AI unavailable, using defaults",
		})
		return
	}
	writeJSON(w, recommend)
}

// ——— AI call helpers ———

func (s *Server) generateAssignment(ctx context.Context, lang string, aType engine.AssignmentType) (*engine.Assignment, error) {
	pt, err := ai.LoadPrompt("assignment_generate")
	if err != nil {
		return nil, err
	}

	teacherRole := "Language Teacher"
	explLang := "en"
	level := "beginner"
	if lc, ok := s.Config.Languages[lang]; ok {
		teacherRole = lc.PromptContext.TeacherRole
		explLang = lc.PromptContext.ExplanationLang
		for lvl := range lc.PromptContext.LevelDescriptions {
			level = lvl
			break
		}
	}

	// Get recent words for context
	wordList := ""
	recentWords, _ := s.DB.GetReviewWords(lang, 10)
	parts := make([]string, 0, len(recentWords))
	for _, w := range recentWords {
		parts = append(parts, w.Word)
	}
	wordList = strings.Join(parts, ", ")
	if wordList == "" {
		wordList = "(new learner, no words yet)"
	}

	messages, err := pt.BuildMessages(&ai.PromptVars{
		TeacherRole:     teacherRole,
		ExplanationLang: explLang,
		Language:        lang,
		Level:           level,
		AssignmentType:  string(aType),
		WordList:        wordList,
		WordCount:       100, // default for essay
	})
	if err != nil {
		return nil, err
	}

	timeoutCtx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()

	response, err := s.AI.Chat(timeoutCtx, messages)
	if err != nil {
		return nil, err
	}

	var result struct {
		Type      string `json:"type"`
		Prompt    string `json:"prompt"`
		Context   string `json:"context"`
		WordCount int    `json:"word_count"`
		Reference string `json:"reference"`
	}
	if err := json.Unmarshal([]byte(response), &result); err != nil {
		return nil, err
	}

	return &engine.Assignment{
		ID:        genAssignmentID(aType),
		Type:      engine.AssignmentType(result.Type),
		Prompt:    result.Prompt,
		Context:   result.Context,
		WordCount: result.WordCount,
	}, nil
}

func (s *Server) gradeAssignment(ctx context.Context, lang, answer string) (*engine.AssignmentGrade, error) {
	pt, err := ai.LoadPrompt("assignment_grade")
	if err != nil {
		return nil, err
	}

	teacherRole := "Language Teacher"
	explLang := "en"
	level := "beginner"
	if lc, ok := s.Config.Languages[lang]; ok {
		teacherRole = lc.PromptContext.TeacherRole
		explLang = lc.PromptContext.ExplanationLang
		for lvl := range lc.PromptContext.LevelDescriptions {
			level = lvl
			break
		}
	}

	messages, err := pt.BuildMessages(&ai.PromptVars{
		TeacherRole:     teacherRole,
		ExplanationLang: explLang,
		Level:           level,
		UserSubmission:  answer,
	})
	if err != nil {
		return nil, err
	}

	timeoutCtx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()

	response, err := s.AI.Chat(timeoutCtx, messages)
	if err != nil {
		return nil, err
	}

	var grade engine.AssignmentGrade
	if err := json.Unmarshal([]byte(response), &grade); err != nil {
		return nil, err
	}
	grade.Original = answer
	return &grade, nil
}

func (s *Server) aiCadenceRecommend(ctx context.Context, lang string) (map[string]interface{}, error) {
	pt, err := ai.LoadPrompt("cadence")
	if err != nil {
		return nil, err
	}

	teacherRole := "Language Teacher"
	explLang := "en"
	level := "beginner"
	if lc, ok := s.Config.Languages[lang]; ok {
		teacherRole = lc.PromptContext.TeacherRole
		explLang = lc.PromptContext.ExplanationLang
		for lvl := range lc.PromptContext.LevelDescriptions {
			level = lvl
			break
		}
	}

	messages, err := pt.BuildMessages(&ai.PromptVars{
		TeacherRole:     teacherRole,
		ExplanationLang: explLang,
		Level:           level,
	})
	if err != nil {
		return nil, err
	}

	timeoutCtx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()

	response, err := s.AI.Chat(timeoutCtx, messages)
	if err != nil {
		return nil, err
	}

	var result map[string]interface{}
	if err := json.Unmarshal([]byte(response), &result); err != nil {
		return nil, err
	}
	return result, nil
}

func genAssignmentID(aType engine.AssignmentType) string {
	return "a-" + string(aType[0:1]) + "-" + time.Now().Format("150405")
}

// ——— DB helper placeholders (framework stubs, real impl in db package) ———

func (s *Server) isAssignmentDue(lang string) bool {
	if s.DB == nil {
		return false
	}
	lastDate := s.DB.LastAssignmentDate(lang)
	if lastDate.IsZero() {
		return true
	}
	days := s.Config.App.Assignment.CadenceDays
	if days < 1 {
		days = 1
	}
	return time.Since(lastDate) >= time.Duration(days)*24*time.Hour
}

func (s *Server) nextAssignmentDue(lang string) string {
	if s.DB == nil {
		return ""
	}
	lastDate := s.DB.LastAssignmentDate(lang)
	if lastDate.IsZero() {
		return "now"
	}
	days := s.Config.App.Assignment.CadenceDays
	if days < 1 {
		days = 1
	}
	return lastDate.Add(time.Duration(days) * 24 * time.Hour).Format(time.RFC3339)
}

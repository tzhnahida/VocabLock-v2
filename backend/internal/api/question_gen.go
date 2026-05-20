package api

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/vocablock/v2/internal/ai"
	"github.com/vocablock/v2/internal/db"
	"github.com/vocablock/v2/internal/engine"
)

// aiGenerateQuestion calls the AI to generate a question of the given type for the word.
// Returns nil, error on failure (caller should fall back to a vocabulary question).
// aiGenerateGrammarQuestion calls the AI to generate a question for a grammar point.
func (s *Server) aiGenerateGrammarQuestion(ctx context.Context, gp *db.GrammarPoint) (*engine.Question, error) {
	if s.AI == nil {
		return nil, fmt.Errorf("AI not configured")
	}

	pt, err := ai.LoadPrompt("generate_grammar")
	if err != nil {
		return nil, fmt.Errorf("load prompt: %w", err)
	}

	explLang := "en"
	teacherRole := "Language Teacher"
	level := "beginner"
	if lc, ok := s.Config.Languages[s.Config.App.ActiveLang]; ok {
		explLang = lc.PromptContext.ExplanationLang
		teacherRole = lc.PromptContext.TeacherRole
		for lvl := range lc.PromptContext.LevelDescriptions {
			level = lvl
			break
		}
	}

	messages, err := pt.BuildMessages(&ai.PromptVars{
		TeacherRole:       teacherRole,
		ExplanationLang:   explLang,
		Level:             level,
		GrammarTitle:      gp.Title,
		GrammarExplanation: gp.Explanation,
		GrammarExample:    gp.Example,
	})
	if err != nil {
		return nil, fmt.Errorf("build prompt: %w", err)
	}

	timeoutCtx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()

	response, err := s.AI.Chat(timeoutCtx, messages)
	if err != nil {
		return nil, fmt.Errorf("AI chat: %w", err)
	}

	cleaned := extractJSON(response)
	var result struct {
		Question struct {
			Type    string   `json:"type"`
			Prompt  string   `json:"prompt"`
			Options []string `json:"options"`
			Answer  string   `json:"answer"`
		} `json:"question"`
	}
	if err := json.Unmarshal([]byte(cleaned), &result); err != nil {
		return nil, fmt.Errorf("parse AI response: %w", err)
	}
	if result.Question.Answer == "" {
		return nil, fmt.Errorf("AI returned empty answer")
	}

	q := &engine.Question{
		ID:          fmt.Sprintf("gg-%d", gp.ID),
		Type:        engine.TypeGrammar,
		SubjectType: "grammar",
		SubjectID:   gp.ID,
		Prompt:      result.Question.Prompt,
		Options:     result.Question.Options,
		Answer:      result.Question.Answer,
	}

	return q, nil
}

func (s *Server) aiGenerateQuestion(ctx context.Context, word *engine.WordInfo, qType engine.QuestionType) (*engine.Question, error) {
	if s.AI == nil {
		return nil, fmt.Errorf("AI not configured")
	}

	pt, err := ai.LoadPrompt("generate")
	if err != nil {
		return nil, fmt.Errorf("load prompt: %w", err)
	}

	explLang := "en"
	teacherRole := "Language Teacher"
	level := "beginner"
	if lc, ok := s.Config.Languages[s.Config.App.ActiveLang]; ok {
		explLang = lc.PromptContext.ExplanationLang
		teacherRole = lc.PromptContext.TeacherRole
		for lvl := range lc.PromptContext.LevelDescriptions {
			level = lvl
			break
		}
	}

	messages, err := pt.BuildMessages(&ai.PromptVars{
		Word:            word.Word,
		Reading:         word.Reading,
		Meaning:         word.Meaning,
		POS:             word.POS,
		TeacherRole:     teacherRole,
		ExplanationLang: explLang,
		Level:           level,
		QuestionType:    string(qType),
	})
	if err != nil {
		return nil, fmt.Errorf("build prompt: %w", err)
	}

	timeoutCtx, cancel := context.WithTimeout(ctx, 60*time.Second)
	defer cancel()

	response, err := s.AI.Chat(timeoutCtx, messages)
	if err != nil {
		return nil, fmt.Errorf("AI chat: %w", err)
	}

	var result struct {
		Question struct {
			Type    string   `json:"type"`
			Word    string   `json:"word"`
			Reading string   `json:"reading"`
			Prompt  string   `json:"prompt"`
			Options []string `json:"options"`
			Answer  string   `json:"answer"`
		} `json:"question"`
	}
	if err := json.Unmarshal([]byte(response), &result); err != nil {
		return nil, fmt.Errorf("parse AI response: %w", err)
	}
	if result.Question.Answer == "" {
		return nil, fmt.Errorf("AI returned empty answer")
	}

	q := &engine.Question{
		ID:          fmt.Sprintf("ai-%c-%d", qType[0], word.ID),
		Type:        engine.QuestionType(result.Question.Type),
		SubjectType: "word",
		SubjectID:   word.ID,
		Prompt:      result.Question.Prompt,
		Options:     result.Question.Options,
		Answer:      result.Question.Answer,
	}

	return q, nil
}

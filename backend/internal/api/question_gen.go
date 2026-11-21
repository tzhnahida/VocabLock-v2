package api

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/tzhnahida/VocabLock/internal/ai"
	"github.com/tzhnahida/VocabLock/internal/db"
	"github.com/tzhnahida/VocabLock/internal/engine"
	"github.com/tzhnahida/VocabLock/internal/log"
)

// aiGenerateQuestion calls the AI to generate a question of the given type for the word.
// Returns nil, error on failure (caller should fall back to a vocabulary question).
// answerUsesKnown rejects a target-language sentence that contains words the
// learner has never reviewed. The target word itself is always allowed.
func (s *Server) answerUsesKnown(answer, target string) bool {
	if s.DB == nil || strings.TrimSpace(answer) == "" {
		return true
	}
	unknown, err := s.DB.UnknownWords(s.Config.App.ActiveLang, 500)
	if err != nil {
		return true
	}
	for _, u := range unknown {
		if u == target || len([]rune(u)) < 2 {
			continue
		}
		if strings.Contains(answer, u) {
			// Closed loop: count words the model keeps needing but the learner
			// has not studied; three hits promote the word to the new-word front.
			_ = s.DB.RecordUnknownHit(s.Config.App.ActiveLang, u)
			return false
		}
	}
	return true
}

// aiGenerateGrammarQuestion calls the AI to generate a question for a grammar point.
func (s *Server) aiGenerateGrammarQuestion(ctx context.Context, gp *db.GrammarPoint) (*engine.Question, error) {
	if s.AI() == nil {
		return nil, fmt.Errorf("AI not configured")
	}

	pt, err := ai.LoadPrompt("generate_grammar")
	if err != nil {
		return nil, fmt.Errorf("load prompt: %w", err)
	}

	explLang := s.aiExplLang(s.Config.App.ActiveLang)
	teacherRole := "Language Teacher"
	level := s.getStudentLevel(s.Config.App.ActiveLang)
	if lc, ok := s.Config.Languages[s.Config.App.ActiveLang]; ok {
		teacherRole = lc.PromptContext.TeacherRole
	}

	// Build vocabulary summary so AI only uses familiar vocabulary
	vocabSummary := s.buildVocabSummary(s.Config.App.ActiveLang)

	messages, err := pt.BuildMessages(&ai.PromptVars{
		TeacherRole:        teacherRole,
		ExplanationLang:    explLang,
		Level:              level,
		GrammarTitle:       gp.Title,
		GrammarExplanation: gp.Explanation,
		GrammarExample:     gp.Example,
		VocabSummary:       vocabSummary,
	})
	if err != nil {
		return nil, fmt.Errorf("build prompt: %w", err)
	}

	timeoutCtx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()

	response, err := s.AI().Chat(timeoutCtx, messages, pt.Temperature)
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
	if s.AI() == nil {
		return nil, fmt.Errorf("AI not configured")
	}

	pt, err := ai.LoadPrompt("generate")
	if err != nil {
		return nil, fmt.Errorf("load prompt: %w", err)
	}

	explLang := s.aiExplLang(s.Config.App.ActiveLang)
	teacherRole := "Language Teacher"
	level := s.getStudentLevel(s.Config.App.ActiveLang)
	if lc, ok := s.Config.Languages[s.Config.App.ActiveLang]; ok {
		teacherRole = lc.PromptContext.TeacherRole
	}

	known, _ := s.DB.LearnedWords(s.Config.App.ActiveLang, 300)
	messages, err := pt.BuildMessages(&ai.PromptVars{
		Word:            word.Word,
		Reading:         word.Reading,
		Meaning:         word.Meaning,
		POS:             word.POS,
		TeacherRole:     teacherRole,
		ExplanationLang: explLang,
		Level:           level,
		QuestionType:    string(qType),
		ExistingWords:   strings.Join(known, ", "),
	})
	if err != nil {
		return nil, fmt.Errorf("build prompt: %w", err)
	}

	timeoutCtx, cancel := context.WithTimeout(ctx, 60*time.Second)
	defer cancel()

	response, err := s.AI().Chat(timeoutCtx, messages, pt.Temperature)
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
	if err := json.Unmarshal([]byte(extractJSON(response)), &result); err != nil {
		return nil, fmt.Errorf("parse AI response: %w", err)
	}
	if result.Question.Answer == "" {
		return nil, fmt.Errorf("AI returned empty answer")
	}

	// Sentence-like answers must not smuggle in unlearned vocabulary. One
	// corrective retry, then fall back to a template question.
	sentenceLike := qType == engine.TypeReadSentence ||
		qType == engine.TypeDialogueWrite ||
		qType == engine.TypeDialogueSpeak
	if sentenceLike && !s.answerUsesKnown(result.Question.Answer, word.Word) {
		feedback := "The learner has not studied all words in your answer. Rewrite the answer using ONLY the target word and words the learner already knows; simplify the sentence instead of introducing new vocabulary."
		retryMessages := append(append([]ai.Message{}, messages...), ai.Message{Role: "system", Content: feedback})
		retry, err := s.AI().Chat(timeoutCtx, retryMessages, pt.Temperature)
		if err != nil {
			return nil, fmt.Errorf("AI retry: %w", err)
		}
		var retryResult struct {
			Question struct {
				Type    string   `json:"type"`
				Word    string   `json:"word"`
				Reading string   `json:"reading"`
				Prompt  string   `json:"prompt"`
				Options []string `json:"options"`
				Answer  string   `json:"answer"`
			} `json:"question"`
		}
		if err := json.Unmarshal([]byte(extractJSON(retry)), &retryResult); err != nil {
			return nil, fmt.Errorf("parse AI retry: %w", err)
		}
		if !s.answerUsesKnown(retryResult.Question.Answer, word.Word) {
			return nil, fmt.Errorf("AI answer still uses unlearned words")
		}
		result = retryResult
	}

	q := &engine.Question{
		ID:          fmt.Sprintf("ai-%s-%d", qType, word.ID),
		Type:        qType,
		SubjectType: "word",
		SubjectID:   word.ID,
		Prompt:      result.Question.Prompt,
		Options:     result.Question.Options,
		Answer:      result.Question.Answer,
	}

	return q, nil
}

// ——— Example sentence generation with 3-round vocabulary validation ———
// Mirrors the expandGrammar check_words → QueryResult pattern.

// generateExample produces a validated example sentence for a word.
// Runs up to 3 rounds: AI generates → extract content words → DB check → feedback.
// Returns "" if all 3 rounds fail, so the caller can fall back to a different question type.
func (s *Server) generateExample(ctx context.Context, word *db.Word, lang string) string {
	if s.AI() == nil || s.DB == nil {
		return ""
	}

	pt, err := ai.LoadPrompt("generate_example")
	if err != nil {
		return ""
	}

	teacherRole, level, explLang, _ := s.expandLangContext(lang)
	vocabSummary := s.buildVocabSummary(lang)

	exampleFeedback := ""
	for round := 0; round < 3; round++ {
		messages, err := pt.BuildMessages(&ai.PromptVars{
			Word:            word.Word,
			Reading:         word.Reading,
			Meaning:         word.Meaning,
			TeacherRole:     teacherRole,
			ExplanationLang: explLang,
			Level:           level,
			VocabSummary:    vocabSummary,
			ExampleFeedback: exampleFeedback,
		})
		if err != nil {
			return ""
		}

		timeoutCtx, cancel := context.WithTimeout(ctx, 15*time.Second)
		response, aiErr := s.AI().Chat(timeoutCtx, messages, pt.Temperature)
		cancel()
		if aiErr != nil {
			return ""
		}

		cleaned := extractJSON(response)
		var result struct {
			Example string `json:"example"`
		}
		if json.Unmarshal([]byte(cleaned), &result) != nil {
			return ""
		}

		// AI gave up — no example possible with known vocabulary
		if result.Example == "" {
			return ""
		}

		// Validate: check content words against known vocabulary
		unknownWords := s.findUnknownWords(result.Example, word.Word, lang)
		if len(unknownWords) == 0 {
			return result.Example
		}

		// Build feedback for next round
		exampleFeedback = "Unknown words: " + strings.Join(unknownWords, ", ")
	}

	// 3 rounds exhausted — give up
	return ""
}

// findUnknownWords extracts content words from a sentence and checks which ones
// are NOT in the student's vocabulary. Returns the list of unknown words.
func (s *Server) findUnknownWords(sentence, targetWord, lang string) []string {
	candidates := extractContentWords(sentence, targetWord, lang)
	var unknown []string
	for _, w := range candidates {
		if w == "" || w == targetWord {
			continue
		}
		exists, err := s.DB.WordExists(lang, w)
		if err != nil {
			// Treat a failed lookup as "unknown" but never silently: a swallowed
			// error here used to make the vocabulary check lie.
			log.Warn("quiz", "word existence check %q: %v", w, err)
		}
		if !exists {
			// Try stripping common conjugations (Japanese)
			if base := tryBaseForm(w); base != "" {
				baseExists, baseErr := s.DB.WordExists(lang, base)
				if baseErr != nil {
					log.Warn("quiz", "word existence check %q: %v", base, baseErr)
				}
				exists = baseExists
			}
		}
		if !exists {
			unknown = append(unknown, w)
		}
	}
	return unknown
}

// extractContentWords splits a sentence into candidate content words,
// removing the target word, particles, punctuation, and function words.
func extractContentWords(sentence, targetWord, lang string) []string {
	// Japanese particles + common function words
	jpParticles := map[string]bool{
		"は": true, "が": true, "を": true, "に": true, "で": true,
		"へ": true, "と": true, "から": true, "まで": true, "の": true,
		"か": true, "も": true, "や": true, "ね": true, "よ": true,
		"な": true, "わ": true, "さ": true, "し": true, "て": true,
		"た": true, "だ": true, "です": true, "ます": true, "いる": true,
		"ある": true, "する": true, "これ": true, "それ": true, "あれ": true,
		"この": true, "その": true, "あの": true, "どの": true, "こんな": true,
		"そんな": true, "あんな": true, "どう": true, "こう": true, "そう": true,
	}
	// Chinese particles + function words
	zhParticles := map[string]bool{
		"的": true, "了": true, "吗": true, "呢": true, "吧": true,
		"啊": true, "着": true, "过": true, "在": true, "和": true,
		"与": true, "或": true, "很": true, "都": true, "也": true,
		"不": true, "没": true, "是": true, "有": true, "会": true,
		"能": true, "要": true, "就": true, "才": true, "只": true,
		"这": true, "那": true, "哪": true, "我": true, "你": true,
		"他": true, "她": true, "它": true, "们": true, "个": true,
	}
	// English function words
	enParticles := map[string]bool{
		"the": true, "a": true, "an": true, "is": true, "are": true,
		"was": true, "were": true, "be": true, "been": true, "am": true,
		"to": true, "of": true, "in": true, "on": true, "at": true,
		"by": true, "for": true, "with": true, "from": true, "as": true,
		"it": true, "its": true, "and": true, "or": true, "but": true,
		"not": true, "no": true, "so": true, "if": true, "than": true,
		"that": true, "this": true, "these": true, "those": true,
		"he": true, "she": true, "they": true, "we": true, "you": true,
		"me": true, "him": true, "her": true, "us": true, "them": true,
		"my": true, "your": true, "his": true, "our": true, "their": true,
		"do": true, "does": true, "did": true, "have": true, "has": true, "had": true,
		"can": true, "will": true, "would": true, "could": true, "should": true,
	}

	// Detect language and pick particle set
	particles := jpParticles // default Japanese
	if lang == "zh" {
		particles = zhParticles
	} else if lang == "en" {
		particles = enParticles
	}

	// Tokenize: for space-separated, split by spaces; for CJK, split by particles
	var tokens []string
	if lang == "en" || lang == "ko" {
		s := strings.TrimFunc(sentence, func(r rune) bool {
			return r == '。' || r == '.' || r == '！' || r == '?' || r == '「' || r == '」' || r == '、' || r == ','
		})
		for _, tok := range strings.Fields(s) {
			tok = strings.TrimFunc(tok, func(r rune) bool {
				return r == '.' || r == ',' || r == '!' || r == '?' || r == '"' || r == '\''
			})
			tok = strings.ToLower(tok)
			if tok != "" && tok != strings.ToLower(targetWord) && !particles[tok] {
				tokens = append(tokens, tok)
			}
		}
	} else {
		// CJK: walk character by character, collect runs between particles
		var current []rune
		for _, r := range sentence {
			ch := string(r)
			if particles[ch] || r == '。' || r == '、' || r == '「' || r == '」' ||
				r == '（' || r == '）' || r == '！' || r == '？' || r == '.' || r == ',' {
				if len(current) > 0 {
					tok := string(current)
					if tok != targetWord {
						tokens = append(tokens, tok)
					}
					current = nil
				}
				continue
			}
			current = append(current, r)
		}
		if len(current) > 0 {
			tok := string(current)
			if tok != targetWord {
				tokens = append(tokens, tok)
			}
		}
	}

	// Dedup, skip single-char tokens (likely particles we missed)
	seen := make(map[string]bool)
	var result []string
	for _, t := range tokens {
		if !seen[t] && len([]rune(t)) >= 2 {
			seen[t] = true
			result = append(result, t)
		}
	}
	return result
}

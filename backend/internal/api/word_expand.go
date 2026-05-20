package api

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/vocablock/v2/internal/ai"
	"github.com/vocablock/v2/internal/db"
)

const maxExpandRounds = 3

type expandWordEntry struct {
	Word       string `json:"word"`
	Reading    string `json:"reading"`
	Meaning    string `json:"meaning"`
	POS        string `json:"pos"`
	Confidence string `json:"confidence"`
}

type expandResponse struct {
	Status string            `json:"status"`
	Reason string            `json:"reason"`
	Words  []expandWordEntry `json:"words"`
}

// expandWords generates new words via AI, with dedup feedback loop and dict verification.
// Returns (verified, pending, error).
func (s *Server) expandWords(ctx context.Context, lang string, count int, extraContext string) (verified, pending int, err error) {
	if s.AI == nil {
		return 0, 0, fmt.Errorf("AI not configured")
	}
	if count <= 0 || count > 20 {
		count = 5
	}

	// Collect existing words for dedup context
	existingWords, totalCount := s.collectExistingWords(lang)

	// Build language context once
	teacherRole, level, explLang := s.expandLangContext(lang)

	// Build extraContext from recent words if not provided
	if extraContext == "" {
		extraContext = s.buildRecentContext(lang)
	}

	duplicates := ""
	for round := 1; round <= maxExpandRounds; round++ {
		pt, err := ai.LoadPrompt("expand")
		if err != nil {
			return 0, 0, fmt.Errorf("load prompt: %w", err)
		}

		messages, err := pt.BuildMessages(&ai.PromptVars{
			TeacherRole:     teacherRole,
			Level:           level,
			ExplanationLang: explLang,
			ExistingWords:   existingWords,
			WordCount:       totalCount,
			ExtraContext:    extraContext,
			DuplicateWords:  duplicates,
		})
		if err != nil {
			return 0, 0, fmt.Errorf("build prompt: %w", err)
		}

		timeoutCtx, cancel := context.WithTimeout(ctx, 60*time.Second)
		response, aiErr := s.AI.Chat(timeoutCtx, messages)
		cancel()
		if aiErr != nil {
			return 0, 0, fmt.Errorf("AI chat: %w", aiErr)
		}

		cleaned := extractJSON(response)
		var result expandResponse
		if err := json.Unmarshal([]byte(cleaned), &result); err != nil {
			return 0, 0, fmt.Errorf("parse AI response: %w", err)
		}

		// AI says vocabulary is complete
		if result.Status == "complete" {
			if s.DB != nil {
				s.DB.CompletePlan(lang)
			}
			return 0, 0, nil
		}

		// Check each word for duplicates
		var dupList []string
		for i := range result.Words {
			if result.Words[i].Word == "" {
				continue
			}
			w := &result.Words[i]
			if w.Confidence == "" {
				w.Confidence = "medium"
			}
			exists, _ := s.DB.WordExists(lang, w.Word)
			if exists {
				dupList = append(dupList, w.Word)
			}
		}

		// All words are duplicates — feedback to AI and retry
		if len(dupList) > 0 && len(dupList) == len(result.Words) {
			duplicates = strings.Join(dupList, ", ")
			continue
		}

		// Process non-duplicate words
		dupSet := make(map[string]bool, len(dupList))
		for _, d := range dupList {
			dupSet[d] = true
		}

		for i := range result.Words {
			w := &result.Words[i]
			if w.Word == "" || dupSet[w.Word] {
				continue
			}

			// Dictionary verification
			dictOK := s.verifyWord(ctx, w)

			// Auto-accept conditions
			dictAvailable := s.DictProvider != nil
			dictFailed := dictAvailable && !dictOK
			shouldAutoAccept := dictOK || (!dictAvailable && w.Confidence == "high")

			if shouldAutoAccept && !dictFailed {
				_, insertErr := s.DB.InsertWord(&db.Word{
					Word:       w.Word,
					Reading:    w.Reading,
					Meaning:    w.Meaning,
					POS:        w.POS,
					Language:   lang,
					Source:     "ai_expansion",
					Confidence: w.Confidence,
				})
				if insertErr == nil {
					verified++
				}
			} else {
				s.DB.InsertWord(&db.Word{
					Word: w.Word, Reading: w.Reading, Meaning: w.Meaning,
					POS: w.POS, Language: lang, Source: "ai_expansion", Status: "pending_review",
				})
				pending++
			}
		}
		return verified, pending, nil
	}

	// All 3 rounds produced only duplicates — mark plan complete
	if s.DB != nil {
		s.DB.CompletePlan(lang)
	}
	return 0, 0, nil
}

// ——— helpers ———

func (s *Server) collectExistingWords(lang string) (existingWords string, total int) {
	words, total, err := s.DB.ListWords(lang, 100, 0)
	if err != nil {
		words, total, _ = s.DB.ListWords(lang, 5, 0)
	}
	parts := make([]string, 0, len(words))
	for _, w := range words {
		if w.Word != "" {
			parts = append(parts, w.Word)
		}
	}
	if len(parts) == 0 {
		return "(no words yet)", 0
	}
	return strings.Join(parts, ", "), total
}

func (s *Server) buildRecentContext(lang string) string {
	recentWords, _ := s.DB.GetReviewWords(lang, 5)
	parts := make([]string, 0, len(recentWords))
	for _, w := range recentWords {
		parts = append(parts, w.Word)
	}
	if len(parts) == 0 {
		return "(new learner, no words yet)"
	}
	return strings.Join(parts, ", ")
}

func (s *Server) expandLangContext(lang string) (teacherRole, level, explLang string) {
	teacherRole = "Language Teacher"
	level = "beginner"
	explLang = "zh-CN"
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

// verifyWord looks up the word in the configured dict provider.
// Returns true if found and meaning/reading/pos are patched with dict data.
func (s *Server) verifyWord(ctx context.Context, w *expandWordEntry) bool {
	if s.DictProvider == nil {
		return false
	}
	lookupCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	result, err := s.DictProvider.Lookup(lookupCtx, w.Word)
	if err != nil || result == nil || !result.Found {
		return false
	}
	if result.Reading != "" {
		w.Reading = result.Reading
	}
	if result.Meaning != "" {
		w.Meaning = result.Meaning
	}
	if result.POS != "" {
		w.POS = result.POS
	}
	return true
}

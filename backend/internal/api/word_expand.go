package api

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/vocablock/v2/internal/ai"
	"github.com/vocablock/v2/internal/db"
	"github.com/vocablock/v2/internal/dict"
)

const maxExpandRounds = 3

type expandResponse struct {
	Status string   `json:"status"`
	Reason string   `json:"reason"`
	Words  []string `json:"words"`
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
	teacherRole, level, explLang, targetLang := s.expandLangContext(lang)

	// Build extraContext from recent words if not provided
	if extraContext == "" {
		extraContext = s.buildRecentContext(lang)
	}

	// Retry pending-review words before expanding new ones
	if s.DB != nil {
		pendingWords, _ := s.DB.ListPendingReview(lang)
		if len(pendingWords) > 10 {
			pendingWords = pendingWords[:10]
		}
		for _, pw := range pendingWords {
			// Try dictionary lookup again
			dictEntry := s.lookupDict(ctx, pw.Word)
			if dictEntry != nil {
				aiDetail := s.generateDetail(ctx, pw.Word, dictEntry.Reading, dictEntry.Meaning, dictEntry.POS, level, lang)
				detail := mergeJSON(dictEntry.Detail, aiDetail)
				wordLevel := dictEntry.Level
				if lv := extractFieldFromDetail(detail, "level"); lv != "" {
					wordLevel = lv
				}
				pw.Reading = dictEntry.Reading
				pw.Meaning = dictEntry.Meaning
				pw.POS = dictEntry.POS
				pw.Level = wordLevel
				pw.Detail = detail
				pw.Status = "active"
				pw.Source = "ai_expansion_dict"
				pw.Confidence = "high"
				s.DB.UpdateWord(pw)
				verified++
				continue
			}
			// Dict still miss -- try AI fill
			aiDetail := s.generateDetail(ctx, pw.Word, "", "", "", level, lang)
			if aiDetail != "" {
				pw.Reading = extractFieldFromDetail(aiDetail, "reading")
				pw.Meaning = extractFieldFromDetail(aiDetail, "meaning")
				pw.POS = extractFieldFromDetail(aiDetail, "pos")
				pw.Level = extractFieldFromDetail(aiDetail, "level")
				pw.Detail = aiDetail
				pw.Status = "active"
				pw.Source = "ai_expansion_ai"
				pw.Confidence = "low"
				s.DB.UpdateWord(pw)
				verified++
			}
		}
	}

	duplicates := ""
	for round := 1; round <= maxExpandRounds; round++ {
		pt, err := ai.LoadPrompt("expand")
		if err != nil {
			return 0, 0, fmt.Errorf("load prompt: %w", err)
		}

		messages, err := pt.BuildMessages(&ai.PromptVars{
			TeacherRole:     teacherRole,
			Language:        targetLang,
			Level:           level,
			ExplanationLang: explLang,
			ExistingWords:   existingWords,
			WordCount:       totalCount,
			ExpandCount:     count,
			ExtraContext:    extraContext,
			DuplicateWords:  duplicates,
		})
		if err != nil {
			return 0, 0, fmt.Errorf("build prompt: %w", err)
		}

		timeoutCtx, cancel := context.WithTimeout(ctx, 60*time.Second)
		response, aiErr := s.AI.Chat(timeoutCtx, messages, pt.Temperature)
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
		for _, word := range result.Words {
			if word == "" {
				continue
			}
			exists, _ := s.DB.WordExists(lang, word)
			if exists {
				dupList = append(dupList, word)
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

		for _, word := range result.Words {
			if word == "" || dupSet[word] {
				continue
			}

			// Dictionary provides reading, meaning, POS — not AI
			dictEntry := s.lookupDict(ctx, word)
			if dictEntry != nil {
				// AI generates extension fields (morphology, collocation, etc.)
				aiDetail := s.generateDetail(ctx, word, dictEntry.Reading, dictEntry.Meaning, dictEntry.POS, level, lang)

				// Merge: dict detail base + AI detail overrides
				detail := mergeJSON(dictEntry.Detail, aiDetail)

				// Extract level from detail JSON (dictEntry.Level is often empty)
				wordLevel := dictEntry.Level
				if lv := extractFieldFromDetail(detail, "level"); lv != "" {
					wordLevel = lv
				}

				_, insertErr := s.DB.InsertWord(&db.Word{
					Word:       word,
					Reading:    dictEntry.Reading,
					Meaning:    dictEntry.Meaning,
					POS:        dictEntry.POS,
					Level:      wordLevel,
					Detail:     detail,
					Language:   lang,
					Source:     "ai_expansion_dict",
					Confidence: "high",
				})
				if insertErr == nil {
					verified++
				}
			} else {
				// Dictionary miss — AI fills all fields (reading, meaning, POS, detail)
				aiDetail := s.generateDetail(ctx, word, "", "", "", level, lang)
				if aiDetail != "" {
					reading := extractFieldFromDetail(aiDetail, "reading")
					meaning := extractFieldFromDetail(aiDetail, "meaning")
					pos := extractFieldFromDetail(aiDetail, "pos")
					wordLevel := extractFieldFromDetail(aiDetail, "level")

					_, insertErr := s.DB.InsertWord(&db.Word{
						Word:       word,
						Reading:    reading,
						Meaning:    meaning,
						POS:        pos,
						Level:      wordLevel,
						Detail:     aiDetail,
						Language:   lang,
						Source:     "ai_expansion_ai",
						Confidence: "low",
					})
					if insertErr == nil {
						verified++
						continue
					}
				}
				s.DB.InsertWord(&db.Word{
					Word: word, Language: lang, Source: "ai_expansion", Status: "pending_review",
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

func (s *Server) expandLangContext(lang string) (teacherRole, level, explLang, targetLang string) {
	teacherRole = "Language Teacher"
	level = s.getStudentLevel(lang)
	explLang = "zh-CN"
	targetLang = lang
	if lc, ok := s.Config.Languages[lang]; ok {
		teacherRole = lc.PromptContext.TeacherRole
		explLang = lc.PromptContext.ExplanationLang
		targetLang = lc.Lang.DisplayName
	}
	return
}

// lookupDict returns the dictionary entry for a word, or nil if not found.
func (s *Server) lookupDict(ctx context.Context, word string) *dict.LookupResult {
	if s.DictProvider == nil {
		return nil
	}
	lookupCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	result, err := s.DictProvider.Lookup(lookupCtx, word)
	if err != nil || result == nil || !result.Found {
		return nil
	}
	return result
}

// generateDetail fills missing extension fields via AI.
// Takes dict-provided data and returns a JSON string with additional linguistic detail.
func (s *Server) generateDetail(ctx context.Context, word, reading, meaning, pos, level, lang string) string {
	if s.AI == nil {
		return ""
	}

	pt, err := ai.LoadPrompt("detail")
	if err != nil {
		return ""
	}

	teacherRole, _, explLang, _ := s.expandLangContext(lang)

	messages, err := pt.BuildMessages(&ai.PromptVars{
		Word:            word,
		Reading:         reading,
		Meaning:         meaning,
		POS:             pos,
		Level:           level,
		Language:        lang,
		TeacherRole:     teacherRole,
		ExplanationLang: explLang,
	})
	if err != nil {
		return ""
	}

	aiCtx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()

	response, err := s.AI.Chat(aiCtx, messages, pt.Temperature)
	if err != nil {
		return ""
	}

	// Extract JSON from response (may be wrapped in markdown)
	cleaned := extractJSON(response)
	if cleaned == "" {
		return ""
	}
	return cleaned
}

// extractFieldFromDetail extracts a single string field from a detail JSON blob.
func extractFieldFromDetail(detail, key string) string {
	if detail == "" || detail == "{}" {
		return ""
	}
	var m map[string]interface{}
	if err := json.Unmarshal([]byte(detail), &m); err != nil {
		return ""
	}
	if v, ok := m[key]; ok {
		if s, ok := v.(string); ok {
			return s
		}
	}
	return ""
}

// mergeJSON merges two JSON objects. Values in b override values in a.
func mergeJSON(a, b string) string {
	if a == "" || a == "{}" {
		if b == "" {
			return "{}"
		}
		return b
	}
	if b == "" || b == "{}" {
		return a
	}

	var ma, mb map[string]interface{}
	if err := json.Unmarshal([]byte(a), &ma); err != nil {
		return b
	}
	if err := json.Unmarshal([]byte(b), &mb); err != nil {
		return a
	}
	for k, v := range mb {
		ma[k] = v
	}
	result, err := json.Marshal(ma)
	if err != nil {
		return a
	}
	return string(result)
}

// expandGrammar generates new grammar points via AI, following the same pattern as expandWords.
func (s *Server) expandGrammar(ctx context.Context, lang string, count int) (inserted int, err error) {
	if s.AI == nil || s.DB == nil {
		return 0, fmt.Errorf("AI or DB not configured")
	}
	if count <= 0 || count > 5 {
		count = 2
	}

	// Get existing grammar titles for dedup
	existing, _, _ := s.DB.ListGrammarPoints(lang, 50, 0)
	existingTitles := make([]string, 0, len(existing))
	for _, g := range existing {
		if g.Title != "" {
			existingTitles = append(existingTitles, g.Title)
		}
	}

	// Build language context
	teacherRole, level, explLang, targetLang := s.expandLangContext(lang)
	_, extraCtx := s.planExpandParams(lang)

	// Get existing words to inform grammar suggestions
	words, wordTotal, _ := s.DB.ListWords(lang, 10, 0)
	wordList := make([]string, 0, len(words))
	for _, w := range words {
		if w.Word != "" {
			wordList = append(wordList, w.Word)
		}
	}

	pt, err := ai.LoadPrompt("expand_grammar")
	if err != nil {
		return 0, fmt.Errorf("load prompt: %w", err)
	}

	messages, err := pt.BuildMessages(&ai.PromptVars{
		TeacherRole:      teacherRole,
		Language:         targetLang,
		Level:            level,
		ExplanationLang:  explLang,
		WordCount:        wordTotal,
		ExistingWords:    strings.Join(wordList, ", "),
		ExtraContext:      extraCtx,
		ExistingGrammar:   strings.Join(existingTitles, ", "),
	})
	if err != nil {
		return 0, fmt.Errorf("build prompt: %w", err)
	}

	timeoutCtx, cancel := context.WithTimeout(ctx, 60*time.Second)
	response, aiErr := s.AI.Chat(timeoutCtx, messages, pt.Temperature)
	cancel()
	if aiErr != nil {
		return 0, fmt.Errorf("AI chat: %w", aiErr)
	}

	cleaned := extractJSON(response)
	var result struct {
		Points []string `json:"grammar_points"`
	}
	if err := json.Unmarshal([]byte(cleaned), &result); err != nil {
		return 0, fmt.Errorf("parse AI response: %w", err)
	}

	for _, title := range result.Points {
		if title == "" {
			continue
		}
		exists, _ := s.DB.GrammarPointExists(lang, title)
		if exists {
			continue
		}

		// Generate full detail for the grammar point
		gp := &db.GrammarPoint{
			Title:    title,
			Language: lang,
			Source:   "ai_expansion",
			Status:   "active",
		}

		// AI fills explanation, example, and all detail fields
		dt, _ := ai.LoadPrompt("grammar_detail")
		if dt != nil {
			dm, _ := dt.BuildMessages(&ai.PromptVars{
				GrammarTitle:    title,
				Language:        targetLang,
				TeacherRole:     teacherRole,
				ExplanationLang: explLang,
				Level:           level,
			})
			aiCtx, c2 := context.WithTimeout(ctx, 30*time.Second)
			resp, err := s.AI.Chat(aiCtx, dm, dt.Temperature)
			c2()
			if err == nil {
				detailJSON := extractJSON(resp)
				if detailJSON != "" && detailJSON != "{}" {
					gp.Detail = detailJSON
					if v := extractFieldFromDetail(detailJSON, "explanation"); v != "" {
						gp.Explanation = v
					}
					if v := extractFieldFromDetail(detailJSON, "example"); v != "" {
						gp.Example = v
					}
				}
			}
		}

		if _, err := s.DB.InsertGrammarPoint(gp); err == nil {
			inserted++
		}
	}

	return inserted, nil
}

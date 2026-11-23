package api

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"sort"

	"github.com/tzhnahida/VocabLock/internal/clock"

	"github.com/tzhnahida/VocabLock/internal/ai"
	"github.com/tzhnahida/VocabLock/internal/api/mock"
	"github.com/tzhnahida/VocabLock/internal/config"
	"github.com/tzhnahida/VocabLock/internal/db"
	"github.com/tzhnahida/VocabLock/internal/engine"
	"github.com/tzhnahida/VocabLock/internal/engine/judge"
	"github.com/tzhnahida/VocabLock/internal/log"
	"github.com/tzhnahida/VocabLock/internal/pronounce"
)

// nonAITypes are question types that work without AI.
var nonAITypes = []engine.QuestionType{
	engine.TypeChoice,
	engine.TypeFill,
	engine.TypeSpelling,
	engine.TypePronounce,
}

// langQuestionTypes extracts the QuestionType list from the active language config.
func langQuestionTypes(lang string, cfg *config.Config) []engine.QuestionType {
	lc, ok := cfg.Languages[lang]
	if !ok || len(lc.QuestionTypes) == 0 {
		return nonAITypes
	}
	types := make([]engine.QuestionType, len(lc.QuestionTypes))
	for i, s := range lc.QuestionTypes {
		types[i] = engine.QuestionType(s)
	}
	return types
}

// planTypes filters out question types the current build cannot actually
// generate (no AI/ASR/pronounce provider), so the time-budget plan does not
// reserve quota for types that will never be served.
func planTypes(types []engine.QuestionType, hasAI, hasPron, hasASR bool) []engine.QuestionType {
	out := make([]engine.QuestionType, 0, len(types))
	for _, t := range types {
		switch t {
		case engine.TypeListening, engine.TypeReadingComp, engine.TypeGrammar, engine.TypeDialogueWrite:
			if !hasAI {
				continue
			}
		case engine.TypeDialogueSpeak:
			if !hasAI || !hasASR {
				continue
			}
		case engine.TypeReadWord, engine.TypeReadSentence, engine.TypePronounce:
			if !hasPron {
				continue
			}
		}
		out = append(out, t)
	}
	if len(out) == 0 {
		return []engine.QuestionType{engine.TypeChoice}
	}
	return out
}

func (s *Server) handleQuizProgress(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleQuizProgress(w, r)
		return
	}
	if s.DB == nil {
		writeError(w, 500, "database not available")
		return
	}

	lang := s.Config.App.ActiveLang
	reviewed, remaining, err := s.DB.GetQuizProgress(lang, s.Config.App.DailyTarget)
	if err != nil {
		writeError(w, 500, "query progress: "+err.Error())
		return
	}
	// Time-based target can also complete the day.
	if s.DailyTargetMet(lang) {
		remaining = 0
		log.Debug("quiz", "progress: target met (reviewed=%d time_min=%d)", reviewed, s.Config.App.DailyTimeTarget)
	}

	// Report the achievable target: a 15-question setting over a 12-word pool
	// is a 12/12 day, not "12/15, keep going".
	effectiveTarget := s.Config.App.DailyTarget
	if nw, ng, rw, rg, err := s.DB.SessionCounts(lang); err == nil {
		available := nw + ng + rw + rg
		if reviewed > 0 && available == 0 {
			effectiveTarget = reviewed
		} else if available > 0 && reviewed+available < effectiveTarget {
			effectiveTarget = reviewed + available
		}
	}
	if effectiveTarget <= 0 {
		effectiveTarget = s.Config.App.DailyTarget
	}
	remaining = effectiveTarget - reviewed
	if remaining < 0 {
		remaining = 0
	}

	writeJSON(w, map[string]interface{}{
		"reviewed_today": reviewed,
		"remaining":      remaining,
		"daily_target":   effectiveTarget,
	})
}

func (s *Server) handleQuizSessionStart(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleQuizSessionStart(w, r)
		return
	}
	if s.DB == nil {
		writeError(w, 500, "database not available")
		return
	}

	lang := s.Config.App.ActiveLang
	// Fix the session size BEFORE any study card or question is served.
	s.ensureSessionPlan(lang)
	s.restoreSessionProgress(lang)
	nw, ng, rw, rg, err := s.DB.SessionCounts(lang)
	if err != nil {
		writeError(w, 500, "session counts: "+err.Error())
		return
	}

	// If bootstrap hasn't finished, block — show preparing
	if !s.isBootstrapDone() && s.AI() != nil {
		writeJSON(w, map[string]interface{}{
			"new_words":      0,
			"new_grammar":    0,
			"review_words":   0,
			"review_grammar": 0,
			"preparing":      true,
		})
		return
	}

	// If a session was already completed today, allow re-entry with whatever
	// review items are still due — just don't trigger new AI expansion.
	if s.sessionBudget.isSessionDone() {
		totalAvailable := nw + ng + rw + rg
		if totalAvailable == 0 {
			writeJSON(w, map[string]interface{}{
				"new_words":       0,
				"new_grammar":     0,
				"review_words":    0,
				"review_grammar":  0,
				"daily_completed": true,
			})
			return
		}
		// Still has reviewable items — allow the session without expansion.
		log.Debug("session", "post-target session: nw=%d ng=%d rw=%d rg=%d", nw, ng, rw, rg)
		writeJSON(w, map[string]interface{}{
			"new_words":       nw,
			"new_grammar":     ng,
			"review_words":    rw,
			"review_grammar":  rg,
			"daily_completed": false,
		})
		return
	}

	// Check if daily target already met — today's learning is done.
	// Use unique subjects (not total attempts) so repeated answers on the
	// same word don't prematurely mark the session as complete. The
	// time-based target (daily_time_target) can also satisfy the day.
	reviewed, err := s.DB.GetUniqueSubjectsReviewed(lang)
	if err != nil {
		log.Warn("quiz", "get unique subjects for session start: %v", err)
		reviewed = 0
	}
	if s.DailyTargetMet(lang) {
		writeJSON(w, map[string]interface{}{
			"new_words":       0,
			"new_grammar":     0,
			"review_words":    0,
			"review_grammar":  0,
			"daily_completed": true,
		})
		return
	}

	totalAvailable := nw + ng + rw + rg

	// Fill the gap between the configured daily target and what is actually
	// available. Without this, a 15-question target over a 12-word pool ends at
	// 12 and looks like a broken quota.
	need := s.Config.App.DailyTarget - reviewed - totalAvailable
	if need > 0 && s.AI() != nil {
		if s.tryStartExpanding() {
			log.Debug("session", "TRIGGER shortage expansion: need=%d target=%d reviewed=%d available=%d", need, s.Config.App.DailyTarget, reviewed, totalAvailable)
			go func() {
				defer s.stopExpanding()
				if _, _, err := s.expandWords(context.Background(), lang, need, "fill today's quota"); err != nil {
					log.Error("session", "shortage expansion: %v", err)
				}
			}()
		}
		writeJSON(w, map[string]interface{}{
			"new_words": nw, "new_grammar": ng, "review_words": rw, "review_grammar": rg,
			"preparing": true, "shortage": need,
		})
		return
	}

	// ── Expansion guard ──────────────────────────────────────────
	// CRITICAL: read isExpanding() ONCE and use the captured value for
	// both the log and the blocking decision. The old code called
	// isExpanding() twice — once for the debug log and once for the
	// condition — creating a TOCTOU window where the expansion goroutine
	// could finish between calls, causing the server to return READY
	// while totalAvailable was still below DailyTarget.
	//
	// User requirement: "AI没出完单词和题目不许进入"
	// → ALWAYS block while expansion is running, regardless of counts.
	expanding := s.isExpanding()
	log.Debug("session", "counts: nw=%d ng=%d rw=%d rg=%d total=%d target=%d expanding=%v",
		nw, ng, rw, rg, totalAvailable, s.Config.App.DailyTarget, expanding)

	if expanding {
		log.Debug("session", "BLOCK: expansion running")
		writeJSON(w, map[string]interface{}{
			"new_words":      0,
			"new_grammar":    0,
			"review_words":   0,
			"review_grammar": 0,
			"preparing":      true,
		})
		return
	}

	// ── 准入语义(仿真 §九 2026-09-03)──
	// Admission is about "is there anything to learn", NOT "is the pool big
	// enough to hit the target". The old gate (totalAvailable < DailyTarget
	// → preparing) dead-locked zero-AI users in a permanent "AI preparing"
	// spinner and refused to serve sessions that had 1-19 due items.
	//
	//   totalAvailable > 0  → always READY (pool < target just means the
	//                          day may end "not met", not that learning is
	//                          forbidden)
	//   totalAvailable == 0 + AI  → trigger expansion, preparing (the ONLY
	//                          legitimate spinner: words are being made)
	//   totalAvailable == 0 + no AI → "empty": true (frontend shows an
	//                          empty-state CTA: import words / configure AI)
	// The pool can be exhausted before the configured target. That is a
	// finished day, not an empty vault: never ask the user to import words.
	if totalAvailable == 0 && reviewed > 0 {
		// No AI to expand the gap: the available pool is genuinely exhausted.
		s.sessionBudget.capPlan(reviewed)
		s.exitNativeLock()
		writeJSON(w, map[string]interface{}{
			"new_words": 0, "new_grammar": 0, "review_words": 0, "review_grammar": 0,
			"daily_completed": true, "reviewed": reviewed,
		})
		return
	}
	if totalAvailable == 0 {
		if s.AI() != nil && reviewed == 0 {
			if s.tryStartExpanding() {
				log.Debug("session", "TRIGGER expansion: empty vault, target=%d", s.Config.App.DailyTarget)
				go func() {
					defer s.stopExpanding()
					expandCount, extraCtx := s.planExpandParams(lang)
					log.Debug("expand", "session/start goroutine: count=%d extraCtx=%s", expandCount, extraCtx)
					v, p, err := s.expandWords(context.Background(), lang, expandCount, extraCtx)
					if err != nil {
						log.Error("expand", "session/start ERROR: %v", err)
					} else {
						log.Debug("expand", "session/start DONE: %d verified + %d pending", v, p)
					}
				}()
			}
			log.Debug("session", "return preparing=true (empty vault, AI filling)")
			writeJSON(w, map[string]interface{}{
				"new_words":      0,
				"new_grammar":    0,
				"review_words":   0,
				"review_grammar": 0,
				"preparing":      true,
			})
			return
		}
		// Nothing to learn and no way to make more: honest empty state.
		log.Debug("session", "EMPTY vault (no items, no AI) — user needs to import words")
		writeJSON(w, map[string]interface{}{
			"new_words":      0,
			"new_grammar":    0,
			"review_words":   0,
			"review_grammar": 0,
			"empty":          true,
		})
		return
	}

	// Cache plan's question type weights for this session
	s.cachePlanWeights(lang)

	// Daily-target framing for the session overview: the UI must show the
	// REAL requirement (remaining to unlock) not the whole due pool — a
	// 76-due review queue would otherwise render as "90 questions today".
	s.sessionBudget.capPlan(reviewed + totalAvailable)
	dailyRem := s.Config.App.DailyTarget - reviewed
	if dailyRem < 0 {
		dailyRem = 0
	}

	log.Debug("session", "READY: nw=%d ng=%d rw=%d rg=%d", nw, ng, rw, rg)

	// Pre-warm TTS for new study words in background so audio is
	// cached before the user reaches the learning screen.
	if nw > 0 && s.TTSProvider != nil {
		go s.preWarmNewWords(lang, nw)
	}

	writeJSON(w, map[string]interface{}{
		"new_words":       nw,
		"new_grammar":     ng,
		"review_words":    rw,
		"review_grammar":  rg,
		"daily_remaining": dailyRem,
		"daily_target":    s.Config.App.DailyTarget,
	})
}

// earlyTypes keeps the first minutes to recognition only. Sentence production
// (grammar, fill, reading_comp, dialogue) waits until the learner is warmed up.
func earlyTypes(reviewed int, available []engine.QuestionType) []engine.QuestionType {
	allowed := map[engine.QuestionType]bool{}
	if reviewed < 3 {
		allowed[engine.TypeChoice] = true
		allowed[engine.TypeMeaning] = true
	} else if reviewed < 6 {
		allowed[engine.TypeChoice] = true
		allowed[engine.TypeMeaning] = true
		allowed[engine.TypePronounce] = true
		allowed[engine.TypeReadWord] = true
	} else {
		for _, t := range available {
			allowed[t] = true
		}
	}
	out := make([]engine.QuestionType, 0, len(available))
	for _, t := range available {
		// Grammar is only served from grammar points, never invented around a
		// random vocabulary word ("蜂 是名词，下面哪个句子…" was this bug).
		if t == engine.TypeGrammar {
			continue
		}
		if allowed[t] {
			out = append(out, t)
		}
	}
	return out
}

func typesForWord(word *db.Word, available []engine.QuestionType) []engine.QuestionType {
	out := make([]engine.QuestionType, 0, len(available))
	for _, t := range available {
		// Grammar is scheduled from grammar_points, never invented around a word.
		if t == engine.TypeGrammar {
			continue
		}
		switch t {
		case engine.TypeReadSentence, engine.TypeListening, engine.TypeReadingComp,
			engine.TypeDialogueWrite, engine.TypeDialogueSpeak:
			if word.Repetitions < 4 || word.Interval <= 14 {
				continue
			}
		}
		out = append(out, t)
	}
	if len(out) == 0 {
		out = append(out, engine.TypeChoice)
	}
	return out
}

func fillExampleUsable(example, word string) bool {
	context := strings.ReplaceAll(example, word, "")
	context = strings.TrimSpace(context)
	return len([]rune(context)) >= 6
}

func (s *Server) handleQuizNext(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleQuizNext(w, r, s.Config.App.ActiveLang)
		return
	}
	if s.DB == nil {
		writeError(w, 500, "database not available")
		return
	}

	lang := s.Config.App.ActiveLang
	budget := s.Config.App.SessionTimeBudget
	s.ensureSessionPlan(lang)
	s.restoreSessionProgress(lang)
	available := planTypes(langQuestionTypes(lang, s.Config), s.AI() != nil, s.HasPronounce(), s.HasASR())

	log.Debug("quiz", "next question: lang=%s", lang)

	// ── Daily target cap ──────────────────────────────────────
	// Stop serving questions once the user has reviewed enough unique
	// subjects today (or met the time target). Without this check the
	// session could serve 80+ questions when SM-2 accumulates many due
	// items on the same day.
	reviewed, err := s.DB.GetUniqueSubjectsReviewed(lang)
	stageTypes := available
	if err != nil {
		log.Warn("quiz", "get unique subjects for next: %v", err)
	} else if s.DailyTargetMet(lang) {
		log.Debug("quiz", "daily target met: reviewed=%d time_min=%d", reviewed, s.Config.App.DailyTimeTarget)
		writeJSON(w, map[string]interface{}{
			"completed":        true,
			"message":          "Daily target met",
			"reviewed":         reviewed,
			"daily_target":     s.Config.App.DailyTarget,
			"daily_target_met": true,
		})
		s.exitNativeLock()
		return
	} else if budget > 0 && s.sessionBudget.planExhausted(budget) && !s.sessionBudget.isForceContinue() {
		// The planned questions (or their time budget) are used up. The
		// completion screen offers "continue deliberately" instead of
		// silently extending the session.
		log.Debug("quiz", "session plan exhausted: answered=%d planned=%d", s.sessionBudget.totalCount, s.sessionBudget.plannedQuestions())
		writeJSON(w, map[string]interface{}{
			"completed":           true,
			"message":             "Session plan reached — review the rest tomorrow, or continue deliberately",
			"reviewed":            reviewed,
			"daily_target":        s.Config.App.DailyTarget,
			"daily_target_met":    false,
			"planned_questions":   s.sessionBudget.plannedQuestions(),
			"session_time_budget": budget,
			"session_exhausted":   true,
		})
		s.exitNativeLock()
		return
	} else if s.sessionBudget.hitSoftCap(s.Config.App.DailyTarget) && !s.sessionBudget.isForceContinue() {
		// Soft cap (simulation §九 ②): stop FORCING questions when the day
		// has clearly exceeded the target without meeting it. The student
		// can deliberately continue via POST /quiz/session/continue; the
		// completion screen offers both actions instead of an endless grind.
		log.Debug("quiz", "soft cap reached: answered=%d target=%d met=false", s.sessionBudget.totalCount, s.Config.App.DailyTarget)
		writeJSON(w, map[string]interface{}{
			"completed":         true,
			"message":           "Session cap reached — review the rest tomorrow, or continue deliberately",
			"reviewed":          reviewed,
			"daily_target":      s.Config.App.DailyTarget,
			"daily_target_met":  false,
			"session_exhausted": true,
		})
		return
	}

	// Resolve explanation language (e.g. "zh-CN", "ko", "en") for prompt i18n
	explLang := s.aiExplLang(lang)

	// Get words and grammar points due for review
	words, err := s.DB.GetReviewWords(lang, 10)
	if err != nil {
		writeError(w, 500, "get review words: "+err.Error())
		return
	}
	// Serve the words that were just previewed as study cards first, in order.
	if queue := s.studyQueueSnapshot(); len(queue) > 0 {
		rank := make(map[int64]int, len(queue))
		for i, id := range queue {
			rank[id] = i
		}
		sort.SliceStable(words, func(i, j int) bool {
			ri, iok := rank[words[i].ID]
			rj, jok := rank[words[j].ID]
			if iok != jok {
				return iok
			}
			if iok && jok {
				return ri < rj
			}
			return false
		})
	}

	grammarPoints, err := s.DB.GetReviewGrammarPoints(lang, 5)
	if err != nil {
		writeError(w, 500, "get review grammar: "+err.Error())
		return
	}
	if reviewed < 6 || len(s.studyQueueSnapshot()) > 0 {
		// No grammar/sentence tasks during the recognition warm-up.
		grammarPoints = nil
	}
	// Prioritize grammar points matching the plan's grammar_focus
	prioritizeGrammarByPlan(grammarPoints, s.sessionBudget.getGrammarFocus())

	// Grammar points require AI — if unavailable, drop them early so the loop
	// doesn't silently skip them one-by-one.
	grammarUnavailable := false
	if s.AI() == nil && len(grammarPoints) > 0 {
		grammarPoints = nil
		grammarUnavailable = true
	}

	if len(words) == 0 && len(grammarPoints) == 0 {
		// Nothing left to generate. Releasing the lock is the only humane
		// outcome: otherwise a generation failure becomes an unclosable app.
		log.Warn("quiz", "no items available — releasing focus lock")
		s.exitNativeLock()
		writeJSON(w, map[string]interface{}{
			"completed":           true,
			"message":             "No items to review — focus lock released",
			"grammar_unavailable": grammarUnavailable,
			"session_exhausted":   true,
		})
		return
	}

	// Determine which item comes next: first by NULL next_review_at (new items),
	// then by next_review_at ASC. Grammar and words are interleaved equally.
	wi, gi := 0, 0
	var q *engine.Question
	var currentWord *db.Word // captured for response enrichment

	for q == nil {
		// Both exhausted - nothing left to serve
		if wi >= len(words) && gi >= len(grammarPoints) {
			log.Warn("quiz", "generation exhausted without a question — releasing focus lock")
			s.exitNativeLock()
			writeJSON(w, map[string]interface{}{
				"completed":         true,
				"message":           "Could not generate a question — focus lock released",
				"session_exhausted": true,
			})
			return
		}
		// Pick the higher-priority item
		pickWord := false
		if gi >= len(grammarPoints) {
			pickWord = true
		} else if wi < len(words) {
			pickWord = compareWordGrammarPriority(words[wi], grammarPoints[gi])
		}

		if pickWord {
			if wi >= len(words) {
				continue
			}
			word := words[wi]
			wi++
			currentWord = word
			// Skip words served within the last few seconds (prevents double-serving)
			if s.wasRecentlyServed(word.ID) {
				continue
			}
			s.markWordServed(word.ID)
			s.takeStudyWord(word.ID)
			info := wordToInfo(word)
			distractors := s.buildDistractors(word, words[wi:], lang)

			qType := engine.SelectQuestionTypeWithWeights(
				word.NextReviewAt, word.EasinessFactor, word.Interval, word.Repetitions,
				typesForWord(word, stageTypes), s.AI() != nil, s.HasPronounce(), s.HasASR(),
				s.sessionBudget.getTypeWeights(),
			)

			if !s.sessionBudget.allowType(string(qType), s.Config.App.SessionTimeBudget, s.Config.App.MaxSlowTypeRatio) {
				// Prefer a cheaper type that still has quota, then any type
				// with quota left. When the whole plan is spent, stop.
				chosen := engine.QuestionType("")
				fastTypes := []engine.QuestionType{engine.TypeChoice, engine.TypeFill, engine.TypePronounce}
				for _, ft := range fastTypes {
					if engine.TimeWeights[string(ft)] < engine.TimeWeights[string(qType)] && s.sessionBudget.typeAvailable(string(ft)) {
						chosen = ft
						break
					}
				}
				if chosen == "" {
					for _, t := range typesForWord(word, stageTypes) {
						if s.sessionBudget.typeAvailable(string(t)) {
							chosen = t
							break
						}
					}
				}
				if chosen == "" {
					writeJSON(w, map[string]interface{}{
						"completed":         true,
						"message":           "Session plan reached — review the rest tomorrow, or continue deliberately",
						"daily_target":      s.Config.App.DailyTarget,
						"daily_target_met":  false,
						"planned_questions": s.sessionBudget.plannedQuestions(),
						"session_exhausted": true,
					})
					s.exitNativeLock()
					return
				}
				qType = chosen
			}
			s.sessionBudget.recordType(string(qType))

			switch qType {
			case engine.TypeChoice:
				q = engine.GenerateChoice(info, distractors, explLang)
			case engine.TypeFill:
				if info.Example != "" && fillExampleUsable(info.Example, info.Word) {
					q = engine.GenerateFill(info, explLang)
				} else if currentWord != nil && s.AI() != nil {
					// No cached example — generate with 3-round vocabulary validation
					example := s.generateExample(r.Context(), currentWord, lang)
					if example != "" {
						currentWord.Detail = injectExample(currentWord.Detail, example)
						s.DB.UpdateWord(currentWord)
						info.Example = example
						q = engine.GenerateFill(info, explLang)
					} else {
						// 3 rounds failed — fall back to choice
						q = engine.GenerateChoice(info, distractors, explLang)
					}
				} else {
					// No AI available — use word-masking fallback
					q = engine.GenerateFill(info, explLang)
				}
			case engine.TypeSpelling:
				q = engine.GenerateSpelling(info, explLang)
			case engine.TypePronounce:
				if info.Word == info.Reading {
					// Word is kana-only (e.g. ありがとう) — pronouncing IS the word.
					// Fall through to meaning instead.
					q = engine.GenerateMeaning(info, explLang)
				} else {
					q = engine.GeneratePronounce(info, explLang)
				}
			case engine.TypeMeaning:
				q = engine.GenerateMeaning(info, explLang)
			case engine.TypeReadWord:
				q = engine.GenerateReadWord(info, explLang)
			case engine.TypeReadSentence:
				q, err = s.aiGenerateQuestion(r.Context(), info, qType)
				if err != nil {
					q = engine.GenerateChoice(info, distractors, explLang)
				} else {
					s.cacheQuestion(q)
				}
			case engine.TypeListening, engine.TypeReadingComp, engine.TypeGrammar, engine.TypeDialogueWrite, engine.TypeDialogueSpeak:
				q, err = s.aiGenerateQuestion(r.Context(), info, qType)
				if err != nil {
					q = engine.GenerateChoice(info, distractors, explLang)
				} else {
					s.cacheQuestion(q)
				}
			default:
				q = engine.GenerateChoice(info, distractors, explLang)
			}
		} else {
			gp := grammarPoints[gi]
			gi++

			q, err = s.aiGenerateGrammarQuestion(r.Context(), gp)
			if err != nil {
				continue
			}
			s.cacheQuestion(q)
			s.sessionBudget.recordType(string(engine.TypeGrammar))
		}
	}

	writeJSON(w, questionPayload(q, currentWord))
}

// questionPayload builds the client view of a question. Word data is attached
// for the preview card, but any field that IS the expected answer is withheld
// per type: listening (word), spelling (word), fill (word), pronounce
// (reading) and meaning (meaning) would otherwise print the answer above the
// input.
func questionPayload(q *engine.Question, word *db.Word) map[string]interface{} {
	resp := map[string]interface{}{
		"id":           q.ID,
		"type":         q.Type,
		"subject_type": q.SubjectType,
		"subject_id":   q.SubjectID,
		"prompt":       q.Prompt,
	}
	if len(q.Options) > 0 {
		resp["options"] = q.Options
	}
	if q.SubjectType == "word" && word != nil {
		hideWord := q.Type == engine.TypeListening || q.Type == engine.TypeSpelling || q.Type == engine.TypeFill
		hideReading := hideWord || q.Type == engine.TypePronounce
		hideMeaning := hideWord || q.Type == engine.TypeMeaning
		if !hideWord {
			resp["subject_word"] = word.Word
		}
		if !hideReading {
			resp["subject_reading"] = word.Reading
		}
		if !hideMeaning {
			resp["subject_meaning"] = word.Meaning
		}
	}
	return resp
}

// compareWordGrammarPriority returns true if the word should come before the grammar point.
// Priority: NULL next_review_at (new items) first, then earlier next_review_at.
func compareWordGrammarPriority(w *db.Word, g *db.GrammarPoint) bool {
	if w.NextReviewAt == nil && g.NextReviewAt != nil {
		return true
	}
	if w.NextReviewAt != nil && g.NextReviewAt == nil {
		return false
	}
	if w.NextReviewAt == nil && g.NextReviewAt == nil {
		return true // both new, word first
	}
	return w.NextReviewAt.Before(*g.NextReviewAt)
}

func (s *Server) handleQuizSubmit(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleQuizSubmit(w, r)
		return
	}
	if s.DB == nil {
		writeError(w, 500, "database not available")
		return
	}

	var req struct {
		QuestionID   string `json:"question_id"`
		SubjectType  string `json:"subject_type"`
		SubjectID    int64  `json:"subject_id"`
		QuestionType string `json:"question_type"`
		Answer       string `json:"answer"`
		Audio        string `json:"audio,omitempty"`
		Study        bool   `json:"study,omitempty"`   // evaluate only: no SM-2 / review log / daily stats
		Dispute      bool   `json:"dispute,omitempty"` // student disputes the AI verdict
	}
	if err := readJSON(r, &req); err != nil {
		writeError(w, 400, "invalid request body")
		return
	}
	if len(req.Answer) > maxQuizAnswer {
		writeError(w, 400, "answer is too long")
		return
	}
	if len(req.Audio) > maxQuizAudioBase64 {
		writeError(w, 400, "audio is too large")
		return
	}

	// Default subject_type for backward compat with old clients
	if req.SubjectType == "" {
		req.SubjectType = "word"
	}

	log.Debug("quiz", "submit: id=%s type=%s audioLen=%d", req.QuestionID, req.QuestionType, len(req.Audio))

	// Route read-aloud submissions to the dedicated handler
	if qt := engine.QuestionType(req.QuestionType); qt == engine.TypeReadWord || qt == engine.TypeReadSentence {
		s.handleReadAloudSubmit(w, r, req.QuestionType, req.SubjectType, req.SubjectID, req.QuestionID, req.Audio, req.Study)
		return
	}
	// Dialogue tasks are AI-generated free-form answers, graded semantically.
	if qt := engine.QuestionType(req.QuestionType); qt == engine.TypeDialogueWrite || qt == engine.TypeDialogueSpeak {
		s.handleDialogueSubmit(w, r, req.QuestionType, req.SubjectType, req.SubjectID, req.QuestionID, req.Answer, req.Audio, req.Study)
		return
	}

	// Retrieve expected answer from cache (AI-generated questions)
	primaryExpected := ""
	if cachedQ := s.getAndDelCachedQuestion(req.QuestionID); cachedQ != nil {
		primaryExpected = cachedQ.Answer
	}
	if primaryExpected == "" && questionRequiresCachedAnswer(req.QuestionType) {
		// AI-generated questions have no local expected answer. After a server
		// restart (or cache eviction) grading against a guessed local answer
		// would both mis-grade and corrupt SM-2. Treat it as expired instead.
		writeJSON(w, map[string]interface{}{
			"correct":  false,
			"feedback": "Question expired, please get a new one",
			"source":   "cache_miss",
		})
		return
	}

	var (
		expected   []string
		word       *db.Word
		grammar    *db.GrammarPoint
		aiCallback func(user, expected string) (*judge.Result, error)
	)

	switch req.SubjectType {
	case "grammar":
		var err error
		grammar, err = s.DB.GetGrammarPoint(req.SubjectID)
		if err != nil {
			writeError(w, 500, "get grammar point: "+err.Error())
			return
		}
		if grammar == nil {
			writeError(w, 404, "grammar point not found")
			return
		}
		if primaryExpected == "" {
			// Cache miss is not an answer. Do not advance SM-2 or write a
			// review log — a server restart must not be recorded as a failure.
			writeJSON(w, map[string]interface{}{
				"correct":  false,
				"feedback": "Question expired, please get a new one",
				"source":   "cache_miss",
			})
			return
		}
		expected = []string{primaryExpected}
	default: // "word"
		var err error
		word, err = s.DB.GetWord(req.SubjectID)
		if err != nil {
			writeError(w, 500, "get word: "+err.Error())
			return
		}
		if word == nil {
			writeError(w, 404, "word not found")
			return
		}
		if primaryExpected == "" {
			expected = expectedAnswers(req.QuestionType, word)
			if len(expected) == 0 {
				// Missing local data is not a wrong answer. Do not touch SM-2.
				writeJSON(w, map[string]interface{}{
					"correct":  false,
					"feedback": "Word data incomplete, please try another word",
					"source":   "data_missing",
				})
				return
			}
			primaryExpected = expected[0]
		} else {
			expected = []string{primaryExpected}
		}
		if s.AI() != nil {
			aiCallback = s.makeAIJudge(req.QuestionType, word)
		}
	}

	strictness := strictnessForType(req.QuestionType)
	result := judge.Judge(req.Answer, expected, strictness, aiCallback)

	// Update SM-2 on the right table
	quality := engine.QualityFromScore(result.Score)
	now := clock.Now()

	switch req.SubjectType {
	case "grammar":
		// Grammar spacing: skip the 1-day interval, start at 6 days
		gReps := grammar.Repetitions
		if quality >= 3 && gReps == 0 {
			gReps = 1
		}
		sm2 := engine.SM2(grammar.EasinessFactor, grammar.Interval, gReps, quality, now, 0)
		if sm2 != nil {
			grammar.EasinessFactor = sm2.EasinessFactor
			grammar.Interval = sm2.Interval
			grammar.Repetitions = sm2.Repetitions
			grammar.NextReviewAt = &sm2.NextReviewAt
		}
		grammar.LastReviewAt = &now
		grammar.TotalAttempts++
		if result.Correct {
			grammar.TotalCorrect++
		}
		if err := s.DB.UpdateGrammarPoint(grammar); err != nil {
			writeError(w, 500, "update grammar point: "+err.Error())
			return
		}
	default:
		sm2 := engine.SM2(word.EasinessFactor, word.Interval, word.Repetitions, quality, now, s.Config.App.Sm2MaxIntervalDays)
		if sm2 != nil {
			word.EasinessFactor = sm2.EasinessFactor
			word.Interval = sm2.Interval
			word.Repetitions = sm2.Repetitions
			word.NextReviewAt = &sm2.NextReviewAt
		}
		word.LastReviewAt = &now
		word.TotalAttempts++
		if result.Correct {
			word.TotalCorrect++
		}
		if err := s.DB.UpdateWord(word); err != nil {
			writeError(w, 500, "update word: "+err.Error())
			return
		}

		// —— Sense expansion ——
		if result.Correct && engine.IsLongTerm(word.Repetitions, word.Interval) {
			s.unlockNextSense(word)
		}
	}

	// Log review
	qType := req.QuestionType
	if qType == "" {
		qType = "choice"
	}
	logEntry := &db.ReviewLog{
		Language:       s.Config.App.ActiveLang,
		SubjectType:    req.SubjectType,
		SubjectID:      req.SubjectID,
		QuestionType:   qType,
		UserAnswer:     req.Answer,
		ExpectedAnswer: primaryExpected,
		Correct:        result.Correct,
		Score:          result.Score,
		Source:         string(result.Source),
		ErrorCategory:  result.ErrorCategory,
	}
	if req.Dispute {
		logEntry.Dispute = 1
	}
	if req.SubjectType == "word" {
		logEntry.WordID = req.SubjectID
	}
	logID, _ := s.DB.InsertReviewLog(logEntry)

	// Update daily stats for heatmap / streak. Time credit is fixed by type,
	// not measured: a 2-second answer still consumes the type's budget.
	correctCount := 0
	if result.Correct {
		correctCount = 1
	}
	s.DB.UpsertDailyStats(now.Format("2006-01-02"), s.Config.App.ActiveLang, 1, correctCount, s.questionTimeCredit(qType))

	var nextReviewAt *time.Time
	if word != nil {
		nextReviewAt = word.NextReviewAt
	} else if grammar != nil {
		nextReviewAt = grammar.NextReviewAt
	}

	// Auto-unlock if daily target met (count- or time-based)
	if s.System != nil && result.Correct {
		if s.DailyTargetMet(s.Config.App.ActiveLang) {
			log.Info("quiz", "daily target met — auto-unlocking")
			s.exitNativeLock()
		}
	}

	writeJSON(w, map[string]interface{}{
		"correct":        result.Correct,
		"score":          result.Score,
		"feedback":       result.Feedback,
		"source":         result.Source,
		"next_review_at": nextReviewAt,
		"log_id":         logID,
	})
}

// handleDialogueSubmit grades a free-form written or spoken answer against
// the reference sentence generated with the question. For spoken answers the
// audio is transcribed locally first; ASR failures never touch SM-2.
func (s *Server) handleDialogueSubmit(w http.ResponseWriter, r *http.Request, qtype, stype string, sid int64, qid, answer, audio string, study bool) {
	if s.AI() == nil {
		writeJSON(w, map[string]interface{}{
			"correct":  false,
			"feedback": "AI grading not configured",
			"source":   "no_ai",
		})
		return
	}
	if s.DB == nil {
		writeError(w, 500, "database not available")
		return
	}
	if stype != "word" {
		writeError(w, 400, "dialogue tasks require a word subject")
		return
	}

	// The reference sentence and scenario exist only in the question cache.
	cachedQ := s.getAndDelCachedQuestion(qid)
	if cachedQ == nil || strings.TrimSpace(cachedQ.Answer) == "" {
		writeJSON(w, map[string]interface{}{
			"correct":  false,
			"feedback": "Question expired, please get a new one",
			"source":   "cache_miss",
		})
		return
	}
	reference := strings.TrimSpace(cachedQ.Answer)
	scenario := cachedQ.Prompt

	word, err := s.DB.GetWord(sid)
	if err != nil {
		writeError(w, 500, "get word: "+err.Error())
		return
	}
	if word == nil {
		writeError(w, 404, "word not found")
		return
	}

	userAnswer := strings.TrimSpace(answer)
	transcript := ""
	answerSource := "text"

	if qtype == string(engine.TypeDialogueSpeak) {
		if strings.TrimSpace(audio) == "" {
			answerSource = "skipped"
			userAnswer = ""
		} else {
			if s.ASRProvider == nil {
				writeJSON(w, map[string]interface{}{
					"correct":  false,
					"feedback": "Speech recognition not configured",
					"source":   "no_asr",
				})
				return
			}
			audioBytes, err := base64.StdEncoding.DecodeString(audio)
			if err != nil || !looksLikeWAV(audioBytes) {
				writeJSON(w, map[string]interface{}{
					"correct":  false,
					"feedback": "Invalid audio data",
					"source":   "bad_audio",
				})
				return
			}
			tmpDir := filepath.Join("data", "asr")
			if err := os.MkdirAll(tmpDir, 0755); err != nil {
				writeError(w, 500, "create ASR temp dir: "+err.Error())
				return
			}
			tmpFile, err := os.CreateTemp(tmpDir, "dialogue_*.wav")
			if err != nil {
				writeError(w, 500, "create ASR temp file: "+err.Error())
				return
			}
			tmpPath := tmpFile.Name()
			defer os.Remove(tmpPath)
			if _, err := tmpFile.Write(audioBytes); err != nil {
				tmpFile.Close()
				writeError(w, 500, "write ASR audio: "+err.Error())
				return
			}
			tmpFile.Close()

			ctx, cancel := context.WithTimeout(r.Context(), 90*time.Second)
			defer cancel()
			asrResult, asrErr := s.ASRProvider.Transcribe(ctx, tmpPath)
			if asrErr != nil {
				writeJSON(w, map[string]interface{}{
					"correct":  false,
					"feedback": fmt.Sprintf("Speech recognition error: %v", asrErr),
					"source":   "asr_error",
				})
				return
			}
			transcript = strings.TrimSpace(asrResult.Text)
			userAnswer = transcript
			answerSource = "asr"
		}
	} else if userAnswer == "" {
		answerSource = "skipped"
	}

	if userAnswer == "" {
		feedback := "未作答。参考答案: " + reference
		if answerSource == "asr" {
			feedback = "未识别到语音。参考答案: " + reference
			answerSource = "asr_empty"
		}
		result := &judge.Result{
			Correct:       false,
			Score:         0,
			Feedback:      feedback,
			Source:        judge.SourceRegex,
			ErrorCategory: "empty",
		}
		s.writeDialogueResult(w, word, qtype, stype, sid, reference, userAnswer, transcript, answerSource, result, study)
		return
	}

	result := judge.Judge(userAnswer, []string{reference}, judge.Normal, s.makeJudgeWithScenario(qtype, word, scenario))
	if result.Source == judge.SourceRegexFallback {
		writeJSON(w, map[string]interface{}{
			"correct":  false,
			"feedback": "AI grading failed, please try again",
			"source":   "ai_error",
		})
		return
	}
	s.writeDialogueResult(w, word, qtype, stype, sid, reference, userAnswer, transcript, answerSource, result, study)
}

// looksLikeWAV rejects arbitrary bytes before whisper sees them. The client
// always sends a RIFF/WAVE container (record package, 16 kHz mono PCM); a
// malformed payload should be bad_audio, not an empty transcript that counts
// as a wrong answer.
func looksLikeWAV(data []byte) bool {
	return len(data) >= 12 && string(data[0:4]) == "RIFF" && string(data[8:12]) == "WAVE"
}

// writeDialogueResult persists SM-2/review log/daily stats and writes the
// response for a dialogue answer. study=true is evaluation only.
func (s *Server) writeDialogueResult(w http.ResponseWriter, word *db.Word, qtype, stype string, sid int64, reference, userAnswer, transcript, answerSource string, result *judge.Result, study bool) {
	quality := engine.QualityFromScore(result.Score)
	now := clock.Now()

	logSource := string(result.Source)
	switch answerSource {
	case "skipped", "asr_empty":
		logSource = answerSource
	case "asr":
		logSource = "asr+" + logSource
	}
	errorCategory := result.ErrorCategory
	if userAnswer == "" {
		errorCategory = "empty"
	}

	if study {
		writeJSON(w, map[string]interface{}{
			"correct":         result.Correct,
			"score":           result.Score,
			"feedback":        result.Feedback,
			"source":          logSource,
			"next_review_at":  nil,
			"log_id":          0,
			"transcript":      transcript,
			"expected_answer": reference,
		})
		return
	}

	sm2 := engine.SM2(word.EasinessFactor, word.Interval, word.Repetitions, quality, now, s.Config.App.Sm2MaxIntervalDays)
	if sm2 != nil {
		word.EasinessFactor = sm2.EasinessFactor
		word.Interval = sm2.Interval
		word.Repetitions = sm2.Repetitions
		word.NextReviewAt = &sm2.NextReviewAt
	}
	word.LastReviewAt = &now
	word.TotalAttempts++
	if result.Correct {
		word.TotalCorrect++
	}
	if err := s.DB.UpdateWord(word); err != nil {
		log.Warn("quiz", "update word after dialogue (id=%d): %v", word.ID, err)
	}

	logEntry := &db.ReviewLog{
		Language:       s.Config.App.ActiveLang,
		SubjectType:    stype,
		SubjectID:      sid,
		WordID:         sid,
		QuestionType:   qtype,
		UserAnswer:     userAnswer,
		ExpectedAnswer: reference,
		Correct:        result.Correct,
		Score:          result.Score,
		Source:         logSource,
		ErrorCategory:  errorCategory,
	}
	logID, _ := s.DB.InsertReviewLog(logEntry)

	correctCount := 0
	if result.Correct {
		correctCount = 1
	}
	s.DB.UpsertDailyStats(now.Format("2006-01-02"), s.Config.App.ActiveLang, 1, correctCount, s.questionTimeCredit(qtype))

	if s.System != nil && result.Correct {
		if s.DailyTargetMet(s.Config.App.ActiveLang) {
			log.Info("quiz", "daily target met (dialogue) — auto-unlocking")
			s.exitNativeLock()
		}
	}

	writeJSON(w, map[string]interface{}{
		"correct":         result.Correct,
		"score":           result.Score,
		"feedback":        result.Feedback,
		"source":          logSource,
		"next_review_at":  word.NextReviewAt,
		"log_id":          logID,
		"transcript":      transcript,
		"expected_answer": reference,
		"error_category":  errorCategory,
	})
}

// handleQuizDispute marks a review_log entry as disputed by the student
// ("I think this was graded wrong"). No SM-2 side effects — the stamp is
// pure diagnostics/feedback for AI calibration.
func (s *Server) handleQuizDispute(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		writeJSON(w, map[string]interface{}{"ok": true})
		return
	}
	if s.DB == nil {
		writeError(w, 500, "database not available")
		return
	}
	var req struct {
		LogID int64 `json:"log_id"`
	}
	if err := readJSON(r, &req); err != nil || req.LogID <= 0 {
		writeError(w, 400, "log_id is required")
		return
	}
	if err := s.DB.MarkDispute(req.LogID); err != nil {
		writeError(w, 500, "mark dispute: "+err.Error())
		return
	}
	writeJSON(w, map[string]interface{}{"ok": true})
}

func (s *Server) handleQuizTodayStats(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleQuizTodayStats(w, r)
		return
	}
	if s.DB == nil {
		writeError(w, 500, "database not available")
		return
	}

	lang := s.Config.App.ActiveLang
	reviewed, correct, err := s.DB.GetTodayStats(lang)
	if err != nil {
		writeError(w, 500, "get today stats: "+err.Error())
		return
	}

	accuracy := 0.0
	if reviewed > 0 {
		accuracy = float64(correct) / float64(reviewed)
	}

	writeJSON(w, map[string]interface{}{
		"reviewed": reviewed,
		"correct":  correct,
		"accuracy": accuracy,
	})
}

// handleQuizSessionContinue lets the student deliberately opt back IN after
// the soft cap (see sessionBudget.hitSoftCap): "I know I haven't met the
// target — keep serving questions anyway."
func (s *Server) handleQuizSessionContinue(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		writeJSON(w, map[string]interface{}{"ok": true})
		return
	}
	s.sessionBudget.setForceContinue(true)
	writeJSON(w, map[string]interface{}{"ok": true, "continue": true})
}

func (s *Server) handleQuizComplete(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleQuizComplete(w, r)
		return
	}

	lang := s.Config.App.ActiveLang
	reviewed, err := s.DB.GetUniqueSubjectsReviewed(lang)
	if err != nil {
		log.Warn("quiz", "get unique subjects for complete: %v", err)
		reviewed = 0
	}

	targetMet := s.DailyTargetMet(lang)
	adjusted := false
	if !targetMet && reviewed > 0 {
		adjusted = s.maybeAdjustDailyTarget(lang)
	}
	if targetMet {
		s.sessionBudget.markSessionDone()
		if s.System != nil {
			log.Info("quiz", "complete: target met — unlocking")
			s.exitNativeLock()
		}
	}

	// Adjust tomorrow's plan from today's performance, in the background.
	if reviewed > 0 {
		s.autoTune(lang)
	}

	writeJSON(w, map[string]interface{}{
		"completed":        targetMet,
		"daily_target_met": targetMet,
		"reviewed":         reviewed,
		"daily_target":     s.Config.App.DailyTarget,
		"target_adjusted":  adjusted,
	})
}

// maybeAdjustDailyTarget softens the daily target when the student has
// genuinely tried (answered yesterday and today) but failed to meet it on
// 3 consecutive days. Local fallback for zero-AI setups (the AI plan path
// already adapts via tomorrow.word_count). The ACCURACY GATE IS NEVER
// LOWERED — quality bar stays fixed; only the workload scale moves.
func (s *Server) maybeAdjustDailyTarget(lang string) bool {
	if s.DB == nil {
		return false
	}
	guarded, err := s.DB.GetRecentUniqueDaily(lang, 3)
	if err != nil || len(guarded) < 3 {
		return false // insufficient history (missed a day = streak broken)
	}
	byDate := map[string]*db.DailyUnique{}
	for i := range guarded {
		byDate[guarded[i].Date] = &guarded[i]
	}
	for i := 0; i < 3; i++ {
		dayStr := clock.Now().AddDate(0, 0, -i).Format("2006-01-02")
		d := byDate[dayStr]
		if d == nil || d.Unique == 0 {
			return false // a day with no session breaks the streak
		}
		// Met semantics mirror DailyTargetMet: unique >= target AND accuracy >= min.
		acc := 0.0
		if d.Attempts > 0 {
			acc = float64(d.Correct) / float64(d.Attempts)
		}
		if d.Unique >= s.Config.App.DailyTarget && acc >= s.Config.App.MinAccuracy {
			return false // met at least one day → no adjustment
		}
	}
	newTarget := int(float64(s.Config.App.DailyTarget) * 0.8)
	if newTarget < 10 {
		newTarget = 10
	}
	if newTarget >= s.Config.App.DailyTarget {
		return false
	}
	old := s.Config.App.DailyTarget
	s.Config.App.DailyTarget = newTarget
	if s.ConfigDir != "" {
		if err := s.Config.SaveAppConfig(s.ConfigDir); err != nil {
			log.Warn("quiz", "save adjusted daily target: %v", err)
		}
	}
	log.Info("quiz", "daily target adjusted (3 consecutive unmet days): %d → %d", old, newTarget)
	return true
}

func questionRequiresCachedAnswer(qtype string) bool {
	switch engine.QuestionType(qtype) {
	case engine.TypeListening, engine.TypeReadingComp, engine.TypeGrammar, engine.TypeDialogueWrite, engine.TypeDialogueSpeak:
		return true
	}
	return false
}

// readAloudTargetText resolves what the learner is asked to read. read_sentence
// is AI-generated and its target sentence lives only in the question cache;
// DO NOT fall back to the word's reading, which would grade a whole sentence
// against a single word. Other read-aloud types can fall back to the cache.
func (s *Server) readAloudTargetText(qtype, stype string, sid int64, qid string) string {
	if qtype == string(engine.TypeReadSentence) {
		if cachedQ := s.getAndDelCachedQuestion(qid); cachedQ != nil {
			return strings.TrimSpace(cachedQ.Answer)
		}
		return ""
	}
	targetText := ""
	if stype == "word" && s.DB != nil {
		word, err := s.DB.GetWord(sid)
		if err == nil && word != nil {
			targetText = word.Reading
			if targetText == "" {
				targetText = word.Word
			}
		}
	}
	if targetText == "" {
		if cachedQ := s.getAndDelCachedQuestion(qid); cachedQ != nil {
			targetText = strings.TrimSpace(cachedQ.Answer)
		}
	}
	return targetText
}

// ——— read-aloud submit ———

func (s *Server) handleReadAloudSubmit(w http.ResponseWriter, r *http.Request, qtype, stype string, sid int64, qid, audio string, study bool) {
	log.Debug("quiz", "read-aloud submit: subjectType=%s subjectId=%d study=%v", stype, sid, study)
	if s.PronounceProvider == nil {
		writeJSON(w, map[string]interface{}{
			"correct":  false,
			"feedback": "Pronunciation assessment not configured",
			"source":   "no_provider",
		})
		return
	}

	// Determine target text (need even if skipping). read_sentence must use the
	// sentence stored with the cached AI question; falling back to word.Reading
	// would grade a sentence against a single word.
	targetText := s.readAloudTargetText(qtype, stype, sid, qid)
	if targetText == "" {
		writeJSON(w, map[string]interface{}{
			"correct":  false,
			"feedback": "Could not determine target text",
			"source":   "no_target",
		})
		return
	}

	// Empty audio = user skipped (doesn't know how to read)
	if audio == "" {
		s.writeReadAloudResult(w, stype, sid, qtype, false, 0, nil, targetText, "skipped", study)
		return
	}

	// Decode audio
	audioBytes, err := base64.StdEncoding.DecodeString(audio)
	if err != nil {
		writeJSON(w, map[string]interface{}{
			"correct":  false,
			"feedback": "Invalid audio data",
			"source":   "bad_audio",
		})
		return
	}

	tmpDir := filepath.Join("data", "pronounce")
	os.MkdirAll(tmpDir, 0755)
	tmpFile, err := os.CreateTemp(tmpDir, "read_*.wav")
	if err != nil {
		writeJSON(w, map[string]interface{}{
			"correct":  false,
			"feedback": "Failed to create temp file",
			"source":   "tmp_error",
		})
		return
	}
	tmpPath := tmpFile.Name()
	defer os.Remove(tmpPath)
	if _, err := tmpFile.Write(audioBytes); err != nil {
		tmpFile.Close()
		writeError(w, 500, "write temp audio: "+err.Error())
		return
	}
	tmpFile.Close()

	ctx, cancel := context.WithTimeout(r.Context(), 15*time.Second)
	defer cancel()

	result, err := s.PronounceProvider.Assess(ctx, tmpPath, targetText)
	if err != nil {
		writeJSON(w, map[string]interface{}{
			"correct":  false,
			"feedback": fmt.Sprintf("Assessment error: %v", err),
			"source":   "assess_error",
		})
		return
	}

	// Score thresholds: 0.4 for word, 0.35 for sentence (same pass line as UI)
	threshold := 0.4
	if qtype == "read_sentence" {
		threshold = 0.35
	}
	correct := result.Score >= threshold
	s.writeReadAloudResult(w, stype, sid, qtype, correct, result.Score, result.Phonemes, targetText, "pronounce", study)
}

// writeReadAloudResult records SM-2, review log, and returns the result JSON.
// categoryForReadAloud tags read-aloud verdicts for diagnostics.
func categoryForReadAloud(source string, correct bool) string {
	if source == "skipped" {
		return "empty"
	}
	if !correct {
		return "pronunciation"
	}
	return ""
}

func (s *Server) writeReadAloudResult(w http.ResponseWriter, stype string, sid int64, qtype string, correct bool, score float64, phonemes []pronounce.PhonemeScore, targetText, source string, study bool) {
	quality := engine.QualityFromScore(score)
	now := clock.Now()

	feedback := fmt.Sprintf("正确答案: %s", targetText)
	if score > 0 {
		feedback = fmt.Sprintf("Score: %.0f%%", score*100)
		if len(phonemes) > 0 {
			parts := make([]string, len(phonemes))
			for i, p := range phonemes {
				mark := "+"
				if p.Score < 0.4 {
					mark = "-"
				}
				parts[i] = fmt.Sprintf("%s:%.0f%s", p.Phoneme, p.Score*100, mark)
			}
			feedback = strings.Join(parts, " ") + " | " + feedback
		}
	}

	// Study-card read-aloud is evaluation only. It must never advance SM-2 or
	// count toward the daily target: the card is practice, not a graded review.
	if study {
		writeJSON(w, map[string]interface{}{
			"correct":        correct,
			"score":          score,
			"phonemes":       phonemes,
			"log_id":         0,
			"feedback":       feedback,
			"source":         source,
			"next_review_at": nil,
		})
		return
	}

	var nextReviewAt *time.Time
	if stype == "word" && s.DB != nil {
		word, err := s.DB.GetWord(sid)
		if err == nil && word != nil {
			sm2 := engine.SM2(word.EasinessFactor, word.Interval, word.Repetitions, quality, now, s.Config.App.Sm2MaxIntervalDays)
			if sm2 != nil {
				word.EasinessFactor = sm2.EasinessFactor
				word.Interval = sm2.Interval
				word.Repetitions = sm2.Repetitions
				word.NextReviewAt = &sm2.NextReviewAt
			}
			word.LastReviewAt = &now
			word.TotalAttempts++
			if correct {
				word.TotalCorrect++
			}
			if err := s.DB.UpdateWord(word); err != nil {
				log.Warn("quiz", "update word after read-aloud (id=%d): %v", word.ID, err)
			}
			nextReviewAt = word.NextReviewAt
		}
	}

	userAnswer := fmt.Sprintf("score=%.2f", score)
	if source == "skipped" {
		userAnswer = "skipped"
	}

	logEntry := &db.ReviewLog{
		Language:       s.Config.App.ActiveLang,
		SubjectType:    stype,
		SubjectID:      sid,
		QuestionType:   qtype,
		UserAnswer:     userAnswer,
		ExpectedAnswer: targetText,
		Correct:        correct,
		Score:          score,
		Source:         source,
		ErrorCategory:  categoryForReadAloud(source, correct),
	}
	if len(phonemes) > 0 {
		if b, err := json.Marshal(phonemes); err == nil {
			logEntry.PhonemesJSON = string(b)
		}
	}
	if stype == "word" {
		logEntry.WordID = sid
	}
	raLogID, _ := s.DB.InsertReviewLog(logEntry)

	correctCount := 0
	if correct {
		correctCount = 1
	}
	s.DB.UpsertDailyStats(now.Format("2006-01-02"), s.Config.App.ActiveLang, 1, correctCount, s.questionTimeCredit(qtype))

	// Auto-unlock if daily target met (count- OR time-based)
	if s.System != nil && correct {
		if s.DailyTargetMet(s.Config.App.ActiveLang) {
			log.Info("quiz", "daily target met (read-aloud) — auto-unlocking")
			s.exitNativeLock()
		}
	}

	writeJSON(w, map[string]interface{}{
		"correct":        correct,
		"score":          score,
		"phonemes":       phonemes,
		"log_id":         raLogID,
		"feedback":       feedback,
		"source":         source,
		"next_review_at": nextReviewAt,
	})
}

// ——— helpers ———

func wordToInfo(w *db.Word) *engine.WordInfo {
	return &engine.WordInfo{
		ID:      w.ID,
		Word:    w.Word,
		Reading: w.Reading,
		Meaning: w.Meaning,
		POS:     w.POS,
		Example: extractFieldFromDetail(w.Detail, "example"),
	}
}

// expectedAnswers returns acceptable answers for a question type.
// For fill/spelling, both Word and Reading are accepted (if non-empty and distinct),
// so typing kana instead of kanji (or vice versa) is also correct.
func expectedAnswers(qType string, w *db.Word) []string {
	switch engine.QuestionType(qType) {
	case engine.TypeFill, engine.TypeSpelling:
		return dedupNonEmpty(w.Word, w.Reading)
	case engine.TypePronounce, engine.TypeReadWord, engine.TypeReadSentence:
		return nonEmpty(w.Reading)
	case engine.TypeMeaning:
		return nonEmpty(w.Meaning)
	case engine.TypeListening:
		return nonEmpty(w.Meaning)
	default:
		return nonEmpty(w.Meaning)
	}
}

func nonEmpty(s string) []string {
	if s == "" {
		return nil
	}
	return []string{s}
}

func dedupNonEmpty(a, b string) []string {
	if a == "" && b == "" {
		return nil
	}
	if a == "" {
		return []string{b}
	}
	if b == "" || a == b {
		return []string{a}
	}
	return []string{a, b}
}

func strictnessForType(qType string) judge.Strictness {
	switch engine.QuestionType(qType) {
	case engine.TypeSpelling:
		return judge.Strict
	default:
		return judge.Normal
	}
}

func (s *Server) makeAIJudge(qType string, word *db.Word) func(user, expected string) (*judge.Result, error) {
	return s.makeJudgeWithScenario(qType, word, "")
}

// makeJudgeWithScenario builds an AI judge that also sees the dialogue
// scenario. The scenario is empty for non-dialogue question types.
func (s *Server) makeJudgeWithScenario(qType string, word *db.Word, scenario string) func(user, expected string) (*judge.Result, error) {
	return func(userAnswer, expectedAnswer string) (*judge.Result, error) {
		if s.AI() == nil {
			return nil, nil
		}

		pt, err := ai.LoadPrompt("judge")
		if err != nil {
			return nil, err
		}

		// Determine explanation language: UI language takes precedence
		explLang := s.aiExplLang(s.Config.App.ActiveLang)

		messages, err := pt.BuildMessages(&ai.PromptVars{
			Word:            word.Word,
			Reading:         word.Reading,
			Meaning:         word.Meaning,
			UserAnswer:      userAnswer,
			ExpectedAnswer:  expectedAnswer,
			ExplanationLang: explLang,
			QuestionType:    qType,
			Scenario:        scenario,
		})
		if err != nil {
			return nil, err
		}

		ctx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
		defer cancel()

		response, err := s.AI().Chat(ctx, messages, pt.Temperature)
		if err != nil {
			return nil, err
		}

		// Parse AI JSON response
		var aiResult struct {
			Correct  bool    `json:"correct"`
			Score    float64 `json:"score"`
			Feedback string  `json:"feedback"`
		}
		if err := json.Unmarshal([]byte(extractJSON(response)), &aiResult); err != nil {
			return nil, err
		}

		return &judge.Result{
			Correct:  aiResult.Correct,
			Score:    aiResult.Score,
			Feedback: aiResult.Feedback,
		}, nil
	}
}

// buildDistractors returns 3 unique-meaning WordInfo distractors for a choice question.
// Uses remaining words first, then queries DB to fill shortages.
func (s *Server) buildDistractors(word *db.Word, remaining []*db.Word, lang string) []*engine.WordInfo {
	result := make([]*engine.WordInfo, 0, 3)
	seen := map[string]bool{word.Meaning: true}

	addIfNew := func(w *db.Word) bool {
		if w == nil || w.Meaning == "" || w.ID == word.ID || seen[w.Meaning] {
			return false
		}
		seen[w.Meaning] = true
		result = append(result, wordToInfo(w))
		return false // keep collecting until we have 3
	}

	for _, w := range remaining {
		addIfNew(w)
		if len(result) >= 3 {
			return result
		}
	}

	// Fallback: query more words from DB (with offset to vary)
	if s.DB != nil && len(result) < 3 {
		// Try multiple offsets to get different words
		for offset := 0; offset < 50 && len(result) < 3; offset += 10 {
			extra, total, _ := s.DB.ListWords(lang, 20, offset)
			for _, w := range extra {
				addIfNew(w)
				if len(result) >= 3 {
					return result
				}
			}
			if offset >= total {
				break
			}
		}
	}

	return result
}

// planExpandParams returns the expand count and context string based on the active plan.
// Falls back to app config when no plan exists or plan data is incomplete.
func (s *Server) planExpandParams(lang string) (count int, extraCtx string) {
	gap := 0

	// Default: fill the gap between daily target and total available (new + review)
	if s.DB != nil {
		newWords, newGrammar, reviewWords, reviewGrammar, err := s.DB.SessionCounts(lang)
		if err == nil {
			total := newWords + newGrammar + reviewWords + reviewGrammar
			reviewed, _ := s.DB.GetUniqueSubjectsReviewed(lang)
			gap = s.Config.App.DailyTarget - reviewed - total
			if gap > 0 {
				count = gap
			}
			log.Debug("expand", "SessionCounts: nw=%d ng=%d rw=%d rg=%d total=%d gap=%d target=%d",
				newWords, newGrammar, reviewWords, reviewGrammar, total, gap, s.Config.App.DailyTarget)
		}
	}
	if count <= 0 {
		count = s.Config.App.ExpandBatchSize
		log.Debug("expand", "gap<=0, fallback=%d", count)
	}
	extraCtx = "general"

	plan, err := s.DB.GetActivePlan(lang)
	if err != nil || plan == nil {
		log.Debug("expand", "no plan: count=%d extraCtx=%s", count, extraCtx)
		return
	}
	if plan.Direction == "complete" || plan.Direction == "review-only" {
		log.Debug("expand", "plan dir=%s, skip: count=%d", plan.Direction, count)
		return
	}

	extraCtx = plan.Direction

	tw := parsePlanTomorrow(plan.PlanJSON)
	if tw == nil {
		log.Debug("expand", "plan parse nil: count=%d extraCtx=%s", count, extraCtx)
		return
	}
	log.Debug("expand", "plan.word_count=%d gap=%d before=%d", tw.WordCount, gap, count)
	if tw.WordCount > 0 {
		count = tw.WordCount
		// Cap to actual gap: don't generate more than needed
		if gap > 0 && count > gap {
			log.Debug("expand", "CAP %d->%d (gap=%d)", tw.WordCount, gap, gap)
			count = gap
		}
	}
	if len(tw.DomainWords) > 0 {
		extraCtx = plan.Direction + ": " + strings.Join(tw.DomainWords, ", ")
	}

	// Also cache type weights for this session (capped by max slow-type ratio)
	if len(tw.QuestionTypeRatio) > 0 {
		merged := mergeTypeWeights(tw.QuestionTypeRatio, s.Config.App.MaxSlowTypeRatio)
		s.sessionBudget.setTypeWeights(merged)
	}
	log.Debug("expand", "final: count=%d extraCtx=%s", count, extraCtx)
	return
}

// cachePlanWeights loads the active plan and caches its question_type_ratio
// and grammar_focus for use during question selection. Called at session start.
func (s *Server) cachePlanWeights(lang string) {
	plan, err := s.DB.GetActivePlan(lang)
	if err != nil || plan == nil {
		return
	}
	tw := parsePlanTomorrow(plan.PlanJSON)
	if tw == nil {
		return
	}
	if len(tw.QuestionTypeRatio) > 0 {
		merged := mergeTypeWeights(tw.QuestionTypeRatio, s.Config.App.MaxSlowTypeRatio)
		s.sessionBudget.setTypeWeights(merged)
	}
	if len(tw.GrammarFocus) > 0 {
		s.sessionBudget.setGrammarFocus(tw.GrammarFocus)
	}
}

// prioritizeGrammarByPlan reorders grammar points so that those matching the
// plan's grammar_focus come first. Non-matching points retain original order.
func prioritizeGrammarByPlan(points []*db.GrammarPoint, focus []string) {
	if len(focus) == 0 || len(points) <= 1 {
		return
	}
	focusSet := make(map[string]bool, len(focus))
	for _, f := range focus {
		focusSet[f] = true
	}

	matched := make([]*db.GrammarPoint, 0, len(points))
	rest := make([]*db.GrammarPoint, 0, len(points))
	for _, g := range points {
		if focusSet[g.Title] {
			matched = append(matched, g)
		} else {
			rest = append(rest, g)
		}
	}

	// In-place reorder: matched first, then rest
	i := 0
	for _, g := range matched {
		points[i] = g
		i++
	}
	for _, g := range rest {
		points[i] = g
		i++
	}
}

package engine

import (
	"math/rand"
	"time"
)

// tierTypes maps SM-2 learning stages to appropriate question types.
// Higher tier = more demanding question types.
var tierTypes = map[int][]QuestionType{
	0: {TypeChoice},                                                              // new: recognition only
	1: {TypeChoice, TypeFill},                                                    // early: cued recall
	2: {TypeFill, TypePronounce},                                                 // mid: unaided recall
	3: {TypePronounce, TypeSpelling, TypeListening, TypeReadingComp, TypeGrammar}, // mature: production
}

// SelectQuestionType picks the best question type for a word based on its SM-2 state.
//
// Tier calculation:
//
//	nextReviewAt == nil → tier 0 (new, never reviewed)
//	reps 0-1, interval ≤ 3 → tier 1 (early)
//	reps 2-3 → tier 2 (mid)
//	reps ≥ 4, interval > 14 → tier 3 (mature)
//	otherwise → tier 2 (default)
//
// EF < 1.5 drops one tier (struggling word needs easier questions).
//
// available is the list of question types enabled for this language (from config).
// aiAvailable indicates whether AI-dependent types (listening/reading_comp/grammar) can be used.
func SelectQuestionType(nextReviewAt *time.Time, ef float64, interval, reps int, available []QuestionType, aiAvailable bool) QuestionType {
	tier := computeTier(nextReviewAt, interval, reps)
	if ef < 1.5 && tier > 0 {
		tier--
	}

	// Build the set of allowed types for this tier
	allowed := tierTypes[tier]

	// Intersect with language config's available types
	availableSet := make(map[QuestionType]bool, len(available))
	for _, qt := range available {
		availableSet[qt] = true
	}

	candidates := make([]QuestionType, 0, len(allowed))
	for _, qt := range allowed {
		if !availableSet[qt] {
			continue
		}
		if isAIType(qt) && !aiAvailable {
			continue
		}
		candidates = append(candidates, qt)
	}

	// Fall back: if no candidates in current tier, try lower tiers
	for t := tier - 1; t >= 0 && len(candidates) == 0; t-- {
		for _, qt := range tierTypes[t] {
			if availableSet[qt] && !(isAIType(qt) && !aiAvailable) {
				candidates = append(candidates, qt)
			}
		}
	}

	// Ultimate fallback
	if len(candidates) == 0 {
		return TypeChoice
	}

	return candidates[rand.Intn(len(candidates))]
}

func computeTier(nextReviewAt *time.Time, interval, reps int) int {
	if nextReviewAt == nil {
		return 0
	}
	if reps <= 1 && interval <= 3 {
		return 1
	}
	if reps >= 4 && interval > 14 {
		return 3
	}
	return 2
}

func isAIType(qt QuestionType) bool {
	switch qt {
	case TypeListening, TypeReadingComp, TypeGrammar:
		return true
	}
	return false
}

package judge

import (
	"regexp"
	"strings"
)

type Source string

const (
	SourceExact         Source = "exact"
	SourceRegex        Source = "regex"
	SourceAI           Source = "ai"
	SourceRegexFallback Source = "regex_fallback"
)

type Strictness string

const (
	Strict  Strictness = "strict"
	Normal  Strictness = "normal"
	Lenient Strictness = "lenient"
)

type Result struct {
	Correct  bool    `json:"correct"`
	Score    float64 `json:"score"`
	Feedback string  `json:"feedback"`
	Source   Source  `json:"source"`
}

// Exact compares the user answer exactly against the expected answer.
func Exact(userAnswer, expected string) *Result {
	ua := normalize(userAnswer)
	ea := normalize(expected)
	if ua == ea {
		return &Result{Correct: true, Score: 1.0, Feedback: "Correct", Source: SourceExact}
	}
	return nil // not an exact match, try next tier
}

// Regex scores the user answer against the expected using pattern matching.
// Returns a score 0.0–1.0 indicating confidence.
func Regex(userAnswer, expected string, strictness Strictness) *Result {
	ua := normalize(userAnswer)
	ea := normalize(expected)

	// Exact substring match gets high confidence
	if strings.Contains(ua, ea) || strings.Contains(ea, ua) {
		score := 0.9
		if strictness == Strict {
			score = 0.7
		}
		return &Result{
			Correct:  true,
			Score:    score,
			Feedback: "Close match",
			Source:   SourceRegex,
		}
	}

	// For lenient mode, try fuzzy matching
	if strictness == Lenient {
		if fuzzyMatch(ua, ea) {
			return &Result{
				Correct:  true,
				Score:    0.7,
				Feedback: "Approximate match",
				Source:   SourceRegex,
			}
		}
	}

	// No match — return low-confidence result
	if strictness == Lenient {
		return &Result{
			Correct:  false,
			Score:    0.3,
			Feedback: "No match found",
			Source:   SourceRegex,
		}
	}
	return &Result{
		Correct:  false,
		Score:    0.0,
		Feedback: "Incorrect",
		Source:   SourceRegex,
	}
}

// Judge runs the 3-tier chain: exact → regex → (ai callback if provided).
// If ai callback is nil or returns an error, falls back to regex result.
func Judge(userAnswer, expected string, strictness Strictness, aiJudge func(user, expected string) (*Result, error)) *Result {
	// Tier 1: exact
	if r := Exact(userAnswer, expected); r != nil {
		return r
	}

	// Tier 2: regex
	regexR := Regex(userAnswer, expected, strictness)

	// If regex is high-confidence, return immediately
	if regexR.Score > 0.9 {
		return regexR
	}

	// Tier 3: AI (if available)
	if aiJudge != nil {
		aiR, err := aiJudge(userAnswer, expected)
		if err == nil && aiR != nil {
			aiR.Source = SourceAI
			return aiR
		}
		// AI failed — fall back to regex
		regexR.Source = SourceRegexFallback
	}

	return regexR
}

func normalize(s string) string {
	s = strings.TrimSpace(s)
	s = strings.ToLower(s)
	s = collapseSpaces(s)
	return s
}

func collapseSpaces(s string) string {
	re := regexp.MustCompile(`\s+`)
	return re.ReplaceAllString(s, " ")
}

func fuzzyMatch(a, b string) bool {
	// Simple Levenshtein-based check
	dist := levenshtein([]rune(a), []rune(b))
	maxLen := len([]rune(a))
	if len([]rune(b)) > maxLen {
		maxLen = len([]rune(b))
	}
	if maxLen == 0 {
		return true
	}
	// Accept if >70% similar
	return 1.0-float64(dist)/float64(maxLen) > 0.7
}

func levenshtein(a, b []rune) int {
	m, n := len(a), len(b)
	if m == 0 {
		return n
	}
	if n == 0 {
		return m
	}
	prev := make([]int, n+1)
	cur := make([]int, n+1)
	for j := 0; j <= n; j++ {
		prev[j] = j
	}
	for i := 1; i <= m; i++ {
		cur[0] = i
		for j := 1; j <= n; j++ {
			cost := 1
			if a[i-1] == b[j-1] {
				cost = 0
			}
			cur[j] = min3(prev[j]+1, cur[j-1]+1, prev[j-1]+cost)
		}
		prev, cur = cur, prev
	}
	return prev[n]
}

func min3(a, b, c int) int {
	if a < b {
		if a < c {
			return a
		}
		return c
	}
	if b < c {
		return b
	}
	return c
}

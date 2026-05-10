package judge

import "testing"

func TestExactMatch(t *testing.T) {
	r := Exact("hello", "hello")
	if r == nil || !r.Correct || r.Source != SourceExact {
		t.Errorf("exact match failed: %+v", r)
	}
}

func TestExactMatchNormalized(t *testing.T) {
	r := Exact("  Hello World  ", "hello world")
	if r == nil || !r.Correct {
		t.Errorf("normalized exact match failed: %+v", r)
	}
}

func TestExactMismatch(t *testing.T) {
	r := Exact("hello", "world")
	if r != nil {
		t.Error("exact should return nil on mismatch")
	}
}

func TestRegexSubstring(t *testing.T) {
	r := Regex("hello world", "hello", Normal)
	if !r.Correct || r.Score < 0.8 {
		t.Errorf("regex substring failed: %+v", r)
	}
}

func TestRegexNoMatch(t *testing.T) {
	r := Regex("abc", "xyz", Normal)
	if r.Correct {
		t.Errorf("regex no-match should be false: %+v", r)
	}
}

func TestJudgeExactChain(t *testing.T) {
	r := Judge("hello", "hello", Normal, nil)
	if r.Source != SourceExact {
		t.Errorf("judge should use exact: got %s", r.Source)
	}
}

func TestJudgeRegexChain(t *testing.T) {
	r := Judge("hello world", "hello", Normal, nil)
	if r.Source != SourceRegex {
		t.Errorf("judge should use regex: got %s", r.Source)
	}
}

func TestJudgeAIFallback(t *testing.T) {
	aiCalled := false
	ai := func(u, e string) (*Result, error) {
		aiCalled = true
		return &Result{Correct: true, Score: 0.95, Feedback: "AI says correct"}, nil
	}
	r := Judge("bonjour", "hello", Normal, ai)
	if !aiCalled || r.Source != SourceAI {
		t.Errorf("judge should call AI for low-confidence regex: source=%s aiCalled=%v", r.Source, aiCalled)
	}
}

func TestJudgeAIFallbackOnError(t *testing.T) {
	ai := func(u, e string) (*Result, error) {
		return nil, nil
	}
	r := Judge("abc", "xyz", Normal, ai)
	if r.Source != SourceRegexFallback {
		t.Errorf("judge should use regex_fallback when AI errors: got %s", r.Source)
	}
}

func TestNormalize(t *testing.T) {
	if n := normalize("  Héllo   Wörld  "); n != "héllo wörld" {
		t.Errorf("normalize failed: %q", n)
	}
}

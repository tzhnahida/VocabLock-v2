package api

import "testing"

func TestLevelRank(t *testing.T) {
	cases := map[string]int{
		"": 0, "auto": 0, "beginner": 0,
		"N5": 1, "N4": 2, "N3": 3, "N2": 4, "N1": 5,
		"HSK1": 1, "HSK6": 6,
		"intermediate": 3, "advanced": 6,
		"weird": 0,
	}
	for in, want := range cases {
		if got := levelRank(in); got != want {
			t.Errorf("levelRank(%q) = %d, want %d", in, got, want)
		}
	}
}

func TestBelowLevel(t *testing.T) {
	cases := []struct {
		entry, learner string
		want           bool
	}{
		{"N5", "N2", true},
		{"N2", "N2", false},
		{"N1", "N2", false},
		{"", "N2", false},
		{"N5", "", false},
		{"HSK2", "HSK4", true},
		{"N5", "beginner", false},
	}
	for _, c := range cases {
		if got := belowLevel(c.entry, c.learner); got != c.want {
			t.Errorf("belowLevel(%q,%q) = %v, want %v", c.entry, c.learner, got, c.want)
		}
	}
}

func TestValidStudentLevel(t *testing.T) {
	for _, ok := range []string{"", "auto", "beginner", "N2", "hsk3", "advanced"} {
		if !validStudentLevel(ok) {
			t.Errorf("validStudentLevel(%q) = false", ok)
		}
	}
	for _, bad := range []string{"N6", "HSK7", "fluent", "N"} {
		if validStudentLevel(bad) {
			t.Errorf("validStudentLevel(%q) = true", bad)
		}
	}
}

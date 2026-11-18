package api

import "strings"

// levelRank maps proficiency labels onto one scale so the expansion pipeline
// can compare them: beginner < intermediate < advanced and N5 < N4 < N3 < N2
// < N1, HSK1 < ... < HSK6. Unknown labels return 0 and are treated as "no
// opinion" rather than guessed.
func levelRank(level string) int {
	l := strings.ToUpper(strings.TrimSpace(level))
	switch l {
	case "", "AUTO", "BEGINNER", "入门":
		return 0
	case "INTERMEDIATE", "中级":
		return 3
	case "ADVANCED", "高级":
		return 6
	}
	if strings.HasPrefix(l, "N") && len(l) == 2 && l[1] >= '1' && l[1] <= '5' {
		return int('5'-l[1]) + 1 // N5→1 … N1→5
	}
	if strings.HasPrefix(l, "HSK") {
		n := l[3:]
		if len(n) == 1 && n[0] >= '1' && n[0] <= '6' {
			return int(n[0] - '0')
		}
	}
	return 0
}

// validStudentLevel accepts the values the settings screen may send.
func validStudentLevel(s string) bool {
	switch strings.ToLower(strings.TrimSpace(s)) {
	case "", "auto", "beginner", "intermediate", "advanced":
		return true
	}
	u := strings.ToUpper(strings.TrimSpace(s))
	if len(u) == 2 && u[0] == 'N' && u[1] >= '1' && u[1] <= '5' {
		return true
	}
	if strings.HasPrefix(u, "HSK") {
		n := u[3:]
		return len(n) == 1 && n[0] >= '1' && n[0] <= '6'
	}
	return false
}

// belowLevel reports whether an entry should be skipped because the learner
// already declares that level or above. Unknown labels never skip.
func belowLevel(entryLevel, learnerLevel string) bool {
	e, l := levelRank(entryLevel), levelRank(learnerLevel)
	if e == 0 || l == 0 {
		return false
	}
	return e < l
}

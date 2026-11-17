package ai

import (
	"os"
	"path/filepath"
	"regexp"
	"testing"
)

// Prompts must stay language-agnostic: they may only refer to the language
// through the variables (Language/TeacherRole/Level/ExplanationLang). A literal
// "日本語" or "Japanese" in a template would bake one course into every course.
var cjkLiteral = regexp.MustCompile(`[\p{Han}\p{Hiragana}\p{Katakana}]`)

func TestPromptsCarryNoLanguageLiterals(t *testing.T) {
	files, err := filepath.Glob(filepath.Join("prompts", "*.yaml"))
	if err != nil || len(files) == 0 {
		t.Fatalf("glob prompts: %v (files=%d)", err, len(files))
	}
	for _, path := range files {
		data, err := os.ReadFile(path)
		if err != nil {
			t.Fatalf("read %s: %v", path, err)
		}
		for i, line := range regexp.MustCompile("\r?\n").Split(string(data), -1) {
			if cjkLiteral.MatchString(line) {
				t.Errorf("%s:%d hardcodes a language literal: %q", path, i+1, line)
			}
		}
	}
}

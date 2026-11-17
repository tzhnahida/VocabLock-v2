package config

import (
	"os"
	"path/filepath"
	"testing"

	"gopkg.in/yaml.v3"
)

// Templates in configs/_languages are what a new course is built from. They
// must parse with the current schema and carry the fields the runtime needs
// (question types, a display name, a teacher role), otherwise switching to
// that language silently produces a half-configured course.
//
// This parses the files directly: config.InstallTemplate also copies the
// template into configs/languages, which a test must not do.
func TestShippedLanguageTemplatesParse(t *testing.T) {
	dir := filepath.Join("..", "..", "configs", "_languages")
	files, err := filepath.Glob(filepath.Join(dir, "*.yaml"))
	if err != nil || len(files) == 0 {
		t.Fatalf("glob templates: %v (%d files)", err, len(files))
	}
	for _, path := range files {
		code := filepath.Base(path)
		code = code[:len(code)-len(".yaml")]

		data, err := os.ReadFile(path)
		if err != nil {
			t.Errorf("%s: %v", code, err)
			continue
		}
		var lc LanguageConfig
		if err := yaml.Unmarshal(data, &lc); err != nil {
			t.Errorf("%s: parse: %v", code, err)
			continue
		}
		if len(lc.QuestionTypes) == 0 {
			t.Errorf("%s: no question_types", code)
		}
		if lc.Lang.DisplayName == "" && lc.Lang.NativeName == "" {
			t.Errorf("%s: no display name", code)
		}
		if lc.PromptContext.TeacherRole == "" {
			t.Errorf("%s: no prompt_context.teacher_role", code)
		}
		t.Logf("%s: %d types, tts=%q dict=%q pronounce=%q fields_base=%d",
			code, len(lc.QuestionTypes), lc.TTS.Provider, lc.Dict.Provider, lc.Pronounce.Provider, len(lc.WordFieldsBase))
	}
}

package ai

import (
	"path/filepath"
	"testing"
)

// Every prompt must render with the variables the handlers actually pass.
// A template that references {{.Something}} which PromptVars lacks fails at
// request time (the AI feature silently breaks), so catch it here instead.
func TestPromptsRenderWithFullVars(t *testing.T) {
	files, err := filepath.Glob(filepath.Join("prompts", "*.yaml"))
	if err != nil || len(files) == 0 {
		t.Fatalf("glob prompts: %v (files=%d)", err, len(files))
	}
	vars := &PromptVars{
		Word: "word", Reading: "reading", Meaning: "meaning", POS: "noun",
		UserAnswer: "a", ExpectedAnswer: "b", Language: "Japanese",
		Level: "beginner", TeacherRole: "teacher", ExplanationLang: "en",
		ExtraContext: "ctx", QuestionType: "choice", Scenario: "scenario",
		AssignmentType: "sentence", Topic: "topic", WordList: "a, b",
		GrammarPoint: "point", GrammarTitle: "title", GrammarExplanation: "expl",
		GrammarExample: "example", ExistingWords: "a, b", ExistingGrammar: "g1",
		VocabSummary: "nouns: a", QueryResult: "a=yes", ExampleFeedback: "fb",
		WordCount: 5, ExpandCount: 3, DuplicateWords: "", UserSubmission: "u",
		SessionStats: "{}", YesterdayPlan: "p", WeakPoints: "w", TrendData: "[]",
	}
	for _, path := range files {
		name := path[len("prompts"+string(filepath.Separator)):]
		name = name[:len(name)-len(".yaml")]
		pt, err := LoadPrompt(name)
		if err != nil {
			t.Fatalf("load %s: %v", name, err)
		}
		if _, err := pt.BuildMessages(vars); err != nil {
			t.Errorf("prompt %q does not render with PromptVars: %v", name, err)
		}
	}
}

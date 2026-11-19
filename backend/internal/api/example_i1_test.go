package api

import (
	"strings"
	"testing"

	"github.com/tzhnahida/VocabLock/internal/content"
)

func TestExampleCompatible(t *testing.T) {
	unknown := []string{"教育", "経済", "学校"}
	cases := []struct {
		name    string
		example string
		target  string
		want    bool
	}{
		{"only the target is unknown", "毎日泳ぐ。", "泳ぐ", true},
		{"contains another unknown word", "学校で泳ぐ。", "泳ぐ", false},
		{"target missing", "毎日本を読む。", "泳ぐ", false},
		{"unknown list shorter than two runes is ignored", "あの家に住む。", "住む", true},
		{"empty example", "", "泳ぐ", false},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := exampleCompatible(c.example, c.target, unknown); got != c.want {
				t.Errorf("exampleCompatible(%q) = %v, want %v", c.example, got, c.want)
			}
		})
	}
}

// pickPackExample must return a real sentence from the installed packs that
// contains the target and no other word from the unknown set.
func TestPickPackExample(t *testing.T) {
	lib, err := content.Load("../../../content")
	if err != nil {
		t.Fatalf("load content: %v", err)
	}
	s := &Server{Content: lib}
	ex := s.pickPackExample("ja", "会う", nil)
	if ex == "" || !strings.Contains(ex, "会") {
		t.Fatalf("pickPackExample(会う) = %q, want a sentence mentioning 会", ex)
	}
	entry := lib.Lookup("ja", "会う")
	var secondUnknown string
	for _, sense := range entry.Senses {
		for _, e := range sense.Examples {
			if strings.Contains(e.Text, "会う") && strings.Contains(e.Text, "パーティー") {
				secondUnknown = "パーティー"
			}
		}
	}
	if secondUnknown == "" {
		t.Skip("no example with a second content word to filter on")
	}
	if got := s.pickPackExample("ja", "会う", []string{secondUnknown}); got != "" && strings.Contains(got, secondUnknown) {
		t.Errorf("filtered example still contains %q: %q", secondUnknown, got)
	}
}

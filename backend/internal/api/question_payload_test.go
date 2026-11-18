package api

import (
	"encoding/json"
	"testing"

	"github.com/tzhnahida/VocabLock/internal/db"
	"github.com/tzhnahida/VocabLock/internal/engine"
)

// Listening questions are answered by ear; shipping the word would put the
// answer on screen. Other types still need it for the preview card.
func TestQuestionPayloadHidesWordForListening(t *testing.T) {
	word := &db.Word{ID: 7, Word: "隣", Reading: "となり", Meaning: "隔壁"}

	listening := &engine.Question{
		ID: "ai-listening-7", Type: engine.TypeListening,
		SubjectType: "word", SubjectID: 7, Prompt: "听音频，选择正确的词义",
		Options: []string{"隔壁", "学校"},
	}
	payload := questionPayload(listening, word)
	for _, key := range []string{"subject_word", "subject_reading", "subject_meaning"} {
		if _, ok := payload[key]; ok {
			t.Errorf("listening payload leaks %s", key)
		}
	}
	if payload["subject_id"] != int64(7) {
		t.Errorf("subject_id = %v, want 7 (the client needs it for TTS)", payload["subject_id"])
	}
	if payload["options"] == nil {
		t.Error("listening payload lost its options")
	}

	choice := &engine.Question{
		ID: "q-7", Type: engine.TypeChoice,
		SubjectType: "word", SubjectID: 7, Prompt: "选择词义",
	}
	choicePayload := questionPayload(choice, word)
	if choicePayload["subject_word"] != "隣" || choicePayload["subject_reading"] != "となり" {
		t.Errorf("choice payload lost the word preview: %v", choicePayload)
	}
}

// The answer must never travel in the payload for the types where the word,
// the reading or the meaning IS the answer — the client prints these fields
// above the input, which used to show the answer outright.
func TestQuestionPayloadHidesTheAnswer(t *testing.T) {
	word := &db.Word{ID: 9, Word: "忙しい", Reading: "いそがしい", Meaning: "忙"}

	cases := []struct {
		name     string
		qtype    engine.QuestionType
		hidden   []string
		expected []string
	}{
		{"pronounce hides the reading", engine.TypePronounce, []string{"subject_reading"}, []string{"subject_word"}},
		{"spelling hides the word", engine.TypeSpelling, []string{"subject_word", "subject_reading"}, nil},
		{"fill hides the word", engine.TypeFill, []string{"subject_word", "subject_reading"}, nil},
		{"meaning hides the translation", engine.TypeMeaning, []string{"subject_meaning"}, []string{"subject_word", "subject_reading"}},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			payload := questionPayload(&engine.Question{
				ID: "q", Type: tc.qtype, SubjectType: "word", SubjectID: 9, Prompt: "p",
			}, word)
			for _, key := range tc.hidden {
				if _, ok := payload[key]; ok {
					t.Errorf("%s: payload leaks %s", tc.qtype, key)
				}
			}
			for _, key := range tc.expected {
				if payload[key] == nil {
					t.Errorf("%s: payload lost %s", tc.qtype, key)
				}
			}
		})
	}
}

// Parse the optional AI reading/meaning used when no dictionary entry exists.
func TestParseExpandWordsKeepsFallbackFields(t *testing.T) {
	raw := []json.RawMessage{
		json.RawMessage(`{"word":"忙しい","reading":"いそがしい","meaning":"忙碌的","example":"忙しいです"}`),
		json.RawMessage(`{"word":"hello","example":"hello there"}`),
		json.RawMessage(`"plain"`),
	}
	entries := parseExpandWords(raw)
	if len(entries) != 3 {
		t.Fatalf("entries = %d, want 3", len(entries))
	}
	if entries[0].Reading != "いそがしい" || entries[0].Meaning != "忙碌的" {
		t.Errorf("fallback fields lost: %+v", entries[0])
	}
	if entries[1].Meaning != "" {
		t.Errorf("unexpected meaning on entry 1: %+v", entries[1])
	}
	if entries[2].Word != "plain" {
		t.Errorf("legacy string form lost: %+v", entries[2])
	}
}

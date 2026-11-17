package api

import (
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

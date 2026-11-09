// Package asr provides local speech-to-text for spoken quiz answers.
package asr

import "context"

// Result is one transcription of an audio file.
type Result struct {
	Text     string
	Language string
}

// Provider transcribes a 16 kHz mono WAV file to text.
//
// Implementations are deliberately small: the app ships an external
// whisper.cpp binary today, and a different local engine can be added
// without touching the quiz handlers.
type Provider interface {
	Name() string
	Transcribe(ctx context.Context, audioPath string) (*Result, error)
}

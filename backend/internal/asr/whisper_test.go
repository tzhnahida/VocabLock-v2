package asr

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/tzhnahida/VocabLock/internal/config"
)

func TestBuildWhisperArgsDefault(t *testing.T) {
	cfg := config.ASRProvider{Language: "ja", Threads: 4}
	args := buildWhisperArgs(cfg, "model.bin", "in.wav", "out")
	got := strings.Join(args, " ")
	want := "-m model.bin -f in.wav -otxt -of out -nt -l ja -t 4"
	if got != want {
		t.Fatalf("args = %q, want %q", got, want)
	}
}

func TestBuildWhisperArgsAutoAndTemplate(t *testing.T) {
	cfg := config.ASRProvider{Language: "auto"}
	args := buildWhisperArgs(cfg, "m", "a", "o")
	if strings.Contains(strings.Join(args, " "), " -l ") {
		t.Fatalf("auto language should not pass -l: %v", args)
	}

	cfg = config.ASRProvider{Args: []string{"--model", "{model}", "--file", "{audio}", "--output", "{out}", "--lang", "{language}"}, Language: "en"}
	args = buildWhisperArgs(cfg, "m", "a", "o")
	got := strings.Join(args, " ")
	want := "--model m --file a --output o --lang en"
	if got != want {
		t.Fatalf("template args = %q, want %q", got, want)
	}
}

func TestCleanTranscript(t *testing.T) {
	raw := " [00:00:00.000 --> 00:00:02.000] こんにちは\r\n[BLANK_AUDIO]\n 元気ですか？ \n"
	if got := CleanTranscript(raw); got != "こんにちは 元気ですか？" {
		t.Fatalf("CleanTranscript = %q", got)
	}
	if got := CleanTranscript("[MUSIC]\n(Silence)\n"); got != "" {
		t.Fatalf("non-speech should be empty, got %q", got)
	}
}

func TestWhisperTranscribeReadsOutputFile(t *testing.T) {
	tmp := t.TempDir()
	model := filepath.Join(tmp, "model.bin")
	if err := os.WriteFile(model, []byte("fake"), 0600); err != nil {
		t.Fatal(err)
	}
	w := &Whisper{
		name:    "whisper",
		model:   model,
		cfg:     config.ASRProvider{Language: "ja"},
		timeout: 5 * time.Second,
	}
	w.run = func(_ context.Context, args []string) ([]byte, []byte, error) {
		out := ""
		for i := 0; i+1 < len(args); i++ {
			if args[i] == "-of" {
				out = args[i+1]
				break
			}
		}
		if out == "" {
			t.Fatalf("no -of in args: %v", args)
		}
		return nil, nil, os.WriteFile(out+".txt", []byte(" こんにちは \n"), 0600)
	}
	res, err := w.Transcribe(context.Background(), "audio.wav")
	if err != nil {
		t.Fatal(err)
	}
	if res.Text != "こんにちは" || res.Language != "ja" {
		t.Fatalf("result = %+v", res)
	}
}

func TestWhisperRequiresModel(t *testing.T) {
	w := &Whisper{name: "whisper", model: filepath.Join(t.TempDir(), "missing.bin"), timeout: time.Second}
	if _, err := w.Transcribe(context.Background(), "audio.wav"); err == nil {
		t.Fatal("expected missing model error")
	}
}

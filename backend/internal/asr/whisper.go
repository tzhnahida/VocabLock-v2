package asr

import (
	"bytes"
	"context"
	"fmt"
	"github.com/tzhnahida/VocabLock/internal/proc"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/tzhnahida/VocabLock/internal/config"
)

// Whisper runs whisper.cpp's whisper-cli against a WAV file.
//
// It writes the transcript to a temp .txt file instead of parsing stdout:
// whisper.cpp versions differ in what they print, but -otxt -of is stable.
type Whisper struct {
	name    string
	cfg     config.ASRProvider
	binary  string
	model   string
	timeout time.Duration
	run     func(ctx context.Context, args []string) (stdout, stderr []byte, err error)
}

// NewWhisper validates the minimum configuration and builds a provider.
// The model file is checked lazily on the first transcription so a missing
// model does not prevent the rest of the app from starting.
func NewWhisper(name string, cfg config.ASRProvider) (*Whisper, error) {
	if strings.TrimSpace(cfg.Binary) == "" {
		return nil, fmt.Errorf("asr %s: binary is empty", name)
	}
	if strings.TrimSpace(cfg.Model) == "" {
		return nil, fmt.Errorf("asr %s: model is empty", name)
	}
	timeout := time.Duration(cfg.TimeoutSec) * time.Second
	if timeout <= 0 {
		timeout = 120 * time.Second
	}
	w := &Whisper{
		name:    name,
		cfg:     cfg,
		binary:  cfg.Binary,
		model:   cfg.Model,
		timeout: timeout,
	}
	w.run = w.runCommand
	return w, nil
}

// Name identifies the provider in logs and health output.
func (w *Whisper) Name() string { return w.name }

// Transcribe runs the binary and returns its cleaned transcript.
func (w *Whisper) Transcribe(ctx context.Context, audioPath string) (*Result, error) {
	if strings.TrimSpace(audioPath) == "" {
		return nil, fmt.Errorf("asr %s: audio path is empty", w.name)
	}
	if _, err := os.Stat(w.model); err != nil {
		return nil, fmt.Errorf("asr %s: model %s: %w", w.name, w.model, err)
	}

	tmpDir, err := os.MkdirTemp("", "vocablock-asr-*")
	if err != nil {
		return nil, fmt.Errorf("asr %s: temp dir: %w", w.name, err)
	}
	defer os.RemoveAll(tmpDir)
	outPrefix := filepath.Join(tmpDir, "transcript")

	args := buildWhisperArgs(w.cfg, w.model, audioPath, outPrefix)
	runCtx, cancel := context.WithTimeout(ctx, w.timeout)
	defer cancel()

	stdout, stderr, err := w.run(runCtx, args)
	if err != nil {
		msg := strings.TrimSpace(string(stderr))
		if msg == "" {
			msg = strings.TrimSpace(string(stdout))
		}
		if len(msg) > 300 {
			msg = msg[:300]
		}
		return nil, fmt.Errorf("asr %s: %w (output: %s)", w.name, err, msg)
	}

	textBytes, readErr := os.ReadFile(outPrefix + ".txt")
	if readErr != nil {
		// Older builds may ignore -otxt on some inputs; stdout is the fallback.
		textBytes = stdout
	}
	text := CleanTranscript(string(textBytes))
	return &Result{Text: text, Language: w.cfg.Language}, nil
}

func (w *Whisper) runCommand(ctx context.Context, args []string) ([]byte, []byte, error) {
	cmd := exec.CommandContext(ctx, w.binary, args...)
	proc.HideWindow(cmd)
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	err := cmd.Run()
	return stdout.Bytes(), stderr.Bytes(), err
}

func buildWhisperArgs(cfg config.ASRProvider, model, audioPath, outPrefix string) []string {
	if len(cfg.Args) > 0 {
		args := make([]string, len(cfg.Args))
		for i, tpl := range cfg.Args {
			arg := tpl
			arg = strings.ReplaceAll(arg, "{audio}", audioPath)
			arg = strings.ReplaceAll(arg, "{model}", model)
			arg = strings.ReplaceAll(arg, "{out}", outPrefix)
			arg = strings.ReplaceAll(arg, "{language}", cfg.Language)
			args[i] = arg
		}
		return args
	}

	args := []string{"-m", model, "-f", audioPath, "-otxt", "-of", outPrefix, "-nt"}
	if lang := strings.TrimSpace(cfg.Language); lang != "" && !strings.EqualFold(lang, "auto") {
		args = append(args, "-l", lang)
	}
	if cfg.Threads > 0 {
		args = append(args, "-t", strconv.Itoa(cfg.Threads))
	}
	args = append(args, cfg.ExtraArgs...)
	return args
}

func stripTimestampPrefix(line string) string {
	if !strings.HasPrefix(line, "[") {
		return line
	}
	end := strings.Index(line, "]")
	if end < 0 || !strings.Contains(line[1:end], "-->") {
		return line
	}
	return strings.TrimSpace(line[end+1:])
}

var whisperNonSpeech = map[string]bool{
	"[blank_audio]": true,
	"[silence]":     true,
	"[music]":       true,
	"[noise]":       true,
	"(silence)":     true,
	"(music)":       true,
}

// CleanTranscript removes whisper.cpp's non-speech markers and timestamp
// prefixes, then joins the remaining lines. It never invents text.
func CleanTranscript(raw string) string {
	raw = strings.ReplaceAll(raw, "\r\n", "\n")
	raw = strings.ReplaceAll(raw, "\r", "\n")
	var lines []string
	for _, line := range strings.Split(raw, "\n") {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		line = strings.TrimSpace(stripTimestampPrefix(line))
		if line == "" || whisperNonSpeech[strings.ToLower(line)] {
			continue
		}
		lines = append(lines, line)
	}
	return strings.TrimSpace(strings.Join(lines, " "))
}

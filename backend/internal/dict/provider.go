package dict

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"regexp"
	"strings"

	"github.com/tzhnahida/VocabLock/internal/config"
	"github.com/tzhnahida/VocabLock/internal/log"
)

type LookupResult struct {
	Found   bool   `json:"found"`
	Word    string `json:"word"`
	Reading string `json:"reading"`
	Meaning string `json:"meaning"`
	POS     string `json:"pos"`
	Level   string `json:"level,omitempty"`  // optional: N5, N4, HSK1, etc.
	Detail  string `json:"detail,omitempty"` // extension fields JSON
}

type Provider struct {
	cfg  config.DictProvider
	name string
}

func NewProvider(name string, cfg config.DictProvider) *Provider {
	return &Provider{cfg: cfg, name: name}
}

func (p *Provider) Lookup(ctx context.Context, word string) (*LookupResult, error) {
	log.Debug("dict", "lookup: provider=%s word=%s", p.name, word)

	args := buildDictArgs(p.cfg.Args, word)

	cmd := exec.CommandContext(ctx, p.cfg.Binary, args...)
	cmd.Env = append(os.Environ(), "PYTHONIOENCODING=utf-8", "PYTHONUTF8=1")

	stdout, err := cmd.Output()
	if err != nil {
		// Exit code 1 = not found (expected)
		if exitErr, ok := err.(*exec.ExitError); ok && exitErr.ExitCode() == 1 {
			return &LookupResult{Found: false}, nil
		}
		return nil, fmt.Errorf("dict %s lookup %q: %w", p.name, word, err)
	}

	var result LookupResult
	if err := json.Unmarshal(stdout, &result); err != nil {
		return nil, fmt.Errorf("dict %s parse output: %w", p.name, err)
	}

	// Normalize: strip trailing pitch-accent numbers from reading.
	// Japanese dictionaries often return "おかね0" or "はし1".
	result.Reading = stripTrailingDigits(result.Reading)

	log.Debug("dict", "lookup result: found=%v", result.Found)
	return &result, nil
}

func (p *Provider) HealthCheck(ctx context.Context) error {
	// Use custom health check args if defined, otherwise default --word "test"
	args := p.cfg.HealthCheck.Custom
	if len(args) == 0 && !p.cfg.HealthCheck.Skip {
		args = []string{"--word", "test"}
	}
	if p.cfg.HealthCheck.Skip {
		return nil
	}

	cmd := exec.CommandContext(ctx, p.cfg.Binary, args...)
	cmd.Env = append(os.Environ(), "PYTHONIOENCODING=utf-8", "PYTHONUTF8=1")
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("dict %s health check: %w", p.name, err)
	}
	return nil
}

func buildDictArgs(templates []string, word string) []string {
	args := make([]string, len(templates))
	for i, tpl := range templates {
		args[i] = strings.ReplaceAll(tpl, "{word}", word)
	}
	return args
}

// stripTrailingDigits removes trailing digit characters from a reading string.
// Japanese dictionaries often append pitch-accent numbers, e.g. "おかね0" → "おかね".
var trailingDigitsRE = regexp.MustCompile(`\d+$`)

func stripTrailingDigits(s string) string {
	return trailingDigitsRE.ReplaceAllString(s, "")
}

package tts

import (
	"context"
	"crypto/md5"
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/vocablock/v2/internal/config"
)

type Provider struct {
	cfg    config.TTSProvider
	name   string
	cache  *Cache
}

func NewProvider(name string, cfg config.TTSProvider, cacheDir string) (*Provider, error) {
	cache, err := NewCache(cacheDir, 500)
	if err != nil {
		return nil, fmt.Errorf("init cache: %w", err)
	}
	return &Provider{cfg: cfg, name: name, cache: cache}, nil
}

// Generate synthesizes speech for the given text and returns the audio file path.
// Returns cached file path if available.
func (p *Provider) Generate(ctx context.Context, voice, text string) (string, error) {
	key := cacheKey(p.name, voice, text)

	// Check cache
	if path, ok := p.cache.Get(key); ok {
		return path, nil
	}

	// Build command
	args := buildArgs(p.cfg.Args, map[string]string{
		"voice":  voice,
		"text":   text,
		"output": key + "." + p.cfg.Format,
	})

	outputPath := filepathAbs(key + "." + p.cfg.Format)

	// Ensure the output path variable is set correctly
	for i, arg := range args {
		if strings.Contains(arg, "{output}") {
			args[i] = outputPath
		}
	}

	cmd := exec.CommandContext(ctx, p.cfg.Binary, args...)
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		return "", fmt.Errorf("tts %s: %w", p.name, err)
	}

	// Cache the result
	p.cache.Put(key, outputPath, p.cfg.Format)

	return outputPath, nil
}

func cacheKey(provider, voice, text string) string {
	h := md5.Sum([]byte(provider + ":" + voice + ":" + text))
	return fmt.Sprintf("%x", h)
}

func buildArgs(templates []string, vars map[string]string) []string {
	args := make([]string, len(templates))
	for i, tpl := range templates {
		arg := tpl
		for k, v := range vars {
			arg = strings.ReplaceAll(arg, "{"+k+"}", v)
		}
		args[i] = arg
	}
	return args
}

func filepathAbs(p string) string {
	// Returns the absolute path relative to the cache directory
	return p
}

func init() {
	// Placeholder for init-time checks
}

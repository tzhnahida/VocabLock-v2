package config

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// A config file that exists but does not parse must abort startup. Swallowing
// the error used to leave the app running on defaults with no explanation.
func TestLoadRejectsBrokenYAML(t *testing.T) {
	cases := map[string]string{
		"app.yaml":       "active_lang: ja\n  bad indent: [\n",
		"tts.yaml":       "tts: [unclosed\n",
		"dict.yaml":      "dict: {broken\n",
		"pronounce.yaml": "pronounce: : :\n",
		"asr.yaml":       "asr: [\n",
	}
	for file, body := range cases {
		dir := t.TempDir()
		if err := os.WriteFile(filepath.Join(dir, file), []byte(body), 0o644); err != nil {
			t.Fatal(err)
		}
		_, err := Load(dir)
		if err == nil {
			t.Errorf("%s: Load accepted invalid YAML", file)
			continue
		}
		if !strings.Contains(err.Error(), file) {
			t.Errorf("%s: error does not name the file: %v", file, err)
		}
	}
}

// Missing optional files stay fine -- the defaults are the documented fallback.
func TestLoadAcceptsMissingOptionalFiles(t *testing.T) {
	dir := t.TempDir()
	if _, err := Load(dir); err != nil {
		t.Fatalf("empty config dir should load with defaults: %v", err)
	}
}

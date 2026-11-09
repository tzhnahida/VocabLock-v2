package config

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestSaveAppConfigKeepsAPIKeyOutOfAppYAML(t *testing.T) {
	dir := t.TempDir()
	c := &Config{}
	c.App.AI.APIKey = "sk-test-secret"
	c.App.AI.BaseURL = "https://api.deepseek.com"
	c.App.AI.Model = "deepseek-chat"

	if err := c.SaveAppConfig(dir); err != nil {
		t.Fatalf("SaveAppConfig: %v", err)
	}

	appData, err := os.ReadFile(filepath.Join(dir, "app.yaml"))
	if err != nil {
		t.Fatalf("read app.yaml: %v", err)
	}
	if strings.Contains(string(appData), "sk-test-secret") {
		t.Fatal("app.yaml still contains the API key")
	}
	secData, err := os.ReadFile(filepath.Join(dir, "secrets.yaml"))
	if err != nil {
		t.Fatalf("read secrets.yaml: %v", err)
	}
	if !strings.Contains(string(secData), "sk-test-secret") {
		t.Fatal("secrets.yaml does not contain the API key")
	}

	loaded, err := Load(dir)
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if loaded.App.AI.APIKey != "sk-test-secret" {
		t.Fatalf("loaded key = %q", loaded.App.AI.APIKey)
	}
}

func TestSaveAppConfigRemovesSecretsWhenKeyCleared(t *testing.T) {
	dir := t.TempDir()
	c := &Config{}
	c.App.AI.APIKey = "sk-test-secret"
	if err := c.SaveAppConfig(dir); err != nil {
		t.Fatalf("SaveAppConfig: %v", err)
	}
	c.App.AI.APIKey = ""
	if err := c.SaveAppConfig(dir); err != nil {
		t.Fatalf("SaveAppConfig clear: %v", err)
	}
	if _, err := os.Stat(filepath.Join(dir, "secrets.yaml")); !os.IsNotExist(err) {
		t.Fatalf("secrets.yaml still exists: %v", err)
	}
}

func TestLoadMigratesLegacyAPIKeyFromAppYAML(t *testing.T) {
	dir := t.TempDir()
	legacy := []byte("ai:\n  api_key: sk-legacy\n")
	if err := os.WriteFile(filepath.Join(dir, "app.yaml"), legacy, 0600); err != nil {
		t.Fatalf("write legacy app.yaml: %v", err)
	}

	loaded, err := Load(dir)
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if loaded.App.AI.APIKey != "sk-legacy" {
		t.Fatalf("loaded key = %q", loaded.App.AI.APIKey)
	}

	appData, err := os.ReadFile(filepath.Join(dir, "app.yaml"))
	if err != nil {
		t.Fatalf("read app.yaml: %v", err)
	}
	if strings.Contains(string(appData), "sk-legacy") {
		t.Fatal("app.yaml still contains the legacy key")
	}
	secData, err := os.ReadFile(filepath.Join(dir, "secrets.yaml"))
	if err != nil {
		t.Fatalf("read secrets.yaml: %v", err)
	}
	if !strings.Contains(string(secData), "sk-legacy") {
		t.Fatal("secrets.yaml does not contain the migrated key")
	}
}

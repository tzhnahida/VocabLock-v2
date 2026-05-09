package config

import (
	"fmt"
	"os"
	"path/filepath"

	"gopkg.in/yaml.v3"
)

type Config struct {
	ActiveLang string `yaml:"active_lang"`
	MockMode   bool   `yaml:"mock_mode"`
}

func Load(configDir string) (*Config, error) {
	cfg := &Config{
		ActiveLang: "en",
	}

	appPath := filepath.Join(configDir, "app.yaml")
	data, err := os.ReadFile(appPath)
	if err != nil {
		if os.IsNotExist(err) {
			return cfg, nil
		}
		return nil, fmt.Errorf("read app.yaml: %w", err)
	}

	if err := yaml.Unmarshal(data, cfg); err != nil {
		return nil, fmt.Errorf("parse app.yaml: %w", err)
	}

	return cfg, nil
}

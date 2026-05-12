package config

import (
	"fmt"
	"os"
	"path/filepath"

	"gopkg.in/yaml.v3"
)

// ——— App config ———

type AppConfig struct {
	ActiveLang  string   `yaml:"active_lang"`
	MockMode    bool     `yaml:"mock_mode"`
	Server      struct {
		Host string `yaml:"host"`
	} `yaml:"server"`
	DailyTarget         int      `yaml:"daily_target"`
	MinAccuracy         float64  `yaml:"min_accuracy"`
	ListeningRatio      float64  `yaml:"listening_ratio"`
	ReadingRatio        float64  `yaml:"reading_ratio"`
	GrammarRatio        float64  `yaml:"grammar_ratio"`
	ExtraRatio          float64  `yaml:"extra_ratio"`
	PassiveEnabled      bool     `yaml:"passive_enabled"`
	PassiveMinInterval  int      `yaml:"passive_min_interval"`
	PassiveMaxInterval  int      `yaml:"passive_max_interval"`
	EscapePasswordLimit int      `yaml:"escape_password_limit"`
	EscapeClickLimit    int      `yaml:"escape_click_limit"`
	AutoStart           bool     `yaml:"auto_start"`
	AutoExpandWords     bool     `yaml:"auto_expand_words"`
	ExpandBatchSize     int      `yaml:"expand_batch_size"`
	ExpandThreshold     float64  `yaml:"expand_threshold"`
	Theme               string   `yaml:"theme"`
	AI                  AIConfig `yaml:"ai"`
}

// ——— AI config ———

type AIConfig struct {
	BaseURL string `yaml:"base_url"`
	APIKey  string `yaml:"api_key"`
	Model   string `yaml:"model"`
}

// ——— TTS config ———

type TTSConfig struct {
	TTS struct {
		CacheLimit     int               `yaml:"cache_limit"`
		FallbackOrder  []string          `yaml:"fallback_order"`
		Providers      map[string]TTSProvider `yaml:"providers"`
	} `yaml:"tts"`
}

type TTSProvider struct {
	Binary  string            `yaml:"binary"`
	Args    []string          `yaml:"args"`
	Format  string            `yaml:"format"`
	Voices  map[string]string `yaml:"voices"`
}

// ——— Dict config ———

type DictConfig struct {
	Dict struct {
		Providers map[string]DictProvider `yaml:"providers"`
	} `yaml:"dict"`
}

type DictProvider struct {
	Lang    string `yaml:"lang"`
	Binary  string `yaml:"binary"`
	Args    []string `yaml:"args"`
	Format  string `yaml:"format"`
	HealthCheck struct {
		Skip   bool     `yaml:"skip"`
		Custom []string `yaml:"custom"`
	} `yaml:"health_check"`
}

// ——— Language config ———

type LanguageConfig struct {
	Lang struct {
		Code        string `yaml:"code"`
		DisplayName string `yaml:"display_name"`
		NativeName  string `yaml:"native_name"`
	} `yaml:"lang"`
	TTS struct {
		Provider string `yaml:"provider"`
		Voice    string `yaml:"voice"`
	} `yaml:"tts"`
	Dict struct {
		Provider string `yaml:"provider"`
	} `yaml:"dict"`
	QuestionTypes []string `yaml:"question_types"`
	PromptContext struct {
		TeacherRole       string            `yaml:"teacher_role"`
		ExplanationLang   string            `yaml:"explanation_lang"`
		LevelDescriptions map[string]string `yaml:"level_descriptions"`
	} `yaml:"prompt_context"`
	GrammarPoints []string `yaml:"grammar_points"`
	SeedWordsFile string   `yaml:"seed_words_file"`
}

// ——— Aggregate holder ———

type Config struct {
	App       AppConfig
	TTS       TTSConfig
	Dict      DictConfig
	Languages map[string]*LanguageConfig // key = language code
}

func Load(configDir string) (*Config, error) {
	cfg := &Config{
		App: AppConfig{
			ActiveLang:          "en",
			DailyTarget:         20,
			MinAccuracy:         0.8,
			ListeningRatio:      0.15,
			ReadingRatio:        0.15,
			GrammarRatio:        0.15,
			ExtraRatio:          0.15,
			PassiveEnabled:      true,
			PassiveMinInterval:  25,
			PassiveMaxInterval:  60,
			EscapePasswordLimit: 1,
			EscapeClickLimit:    2,
			AutoExpandWords:     true,
			ExpandBatchSize:     10,
			ExpandThreshold:     0.6,
			Theme:               "vs-dark",
		},
		Languages: make(map[string]*LanguageConfig),
	}
	cfg.App.Server.Host = "127.0.0.1"

	// app.yaml
	if err := loadYAML(filepath.Join(configDir, "app.yaml"), &cfg.App); err != nil {
		return nil, err
	}

	// Env var overrides (keeps secrets out of committed yaml)
	if v := os.Getenv("VOCABLOCK_AI_KEY"); v != "" {
		cfg.App.AI.APIKey = v
	}
	if v := os.Getenv("VOCABLOCK_AI_BASE_URL"); v != "" {
		cfg.App.AI.BaseURL = v
	}
	if v := os.Getenv("VOCABLOCK_AI_MODEL"); v != "" {
		cfg.App.AI.Model = v
	}

	// tts.yaml
	if err := loadYAML(filepath.Join(configDir, "tts.yaml"), &cfg.TTS); err != nil {
		return nil, err
	}

	// dict.yaml
	if err := loadYAML(filepath.Join(configDir, "dict.yaml"), &cfg.Dict); err != nil {
		return nil, err
	}

	// languages/*.yaml
	langDir := filepath.Join(configDir, "languages")
	entries, err := os.ReadDir(langDir)
	if err != nil {
		if !os.IsNotExist(err) {
			return nil, fmt.Errorf("read languages dir: %w", err)
		}
	} else {
		for _, e := range entries {
			if e.IsDir() || filepath.Ext(e.Name()) != ".yaml" {
				continue
			}
			var lc LanguageConfig
			if err := loadYAML(filepath.Join(langDir, e.Name()), &lc); err != nil {
				return nil, err
			}
			cfg.Languages[lc.Lang.Code] = &lc
		}
	}

	// Validation
	if errs := cfg.Validate(); len(errs) > 0 {
		for _, e := range errs {
			fmt.Fprintf(os.Stderr, "config error: %v\n", e)
		}
		return nil, fmt.Errorf("%d config validation error(s)", len(errs))
	}

	return cfg, nil
}

func loadYAML(path string, v interface{}) error {
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return fmt.Errorf("read %s: %w", filepath.Base(path), err)
	}
	if err := yaml.Unmarshal(data, v); err != nil {
		return fmt.Errorf("parse %s: %w", filepath.Base(path), err)
	}
	return nil
}

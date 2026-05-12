package api

import (
	"fmt"
	"net/http"
	"os"
	"path/filepath"

	"github.com/vocablock/v2/internal/api/mock"
	"github.com/vocablock/v2/internal/config"
	"gopkg.in/yaml.v3"
)

func (s *Server) handleConfigGet(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleConfigGet(w, r); return
	}

	langs := make([]string, 0, len(s.Config.Languages))
	for code := range s.Config.Languages {
		langs = append(langs, code)
	}

	langDetails := make(map[string]interface{})
	for code, lc := range s.Config.Languages {
		ttsVoice := lc.TTS.Voice
		ttsProvider := lc.TTS.Provider
		dictProvider := lc.Dict.Provider
		langDetails[code] = map[string]interface{}{
			"display_name": lc.Lang.DisplayName,
			"native_name":  lc.Lang.NativeName,
			"tts_provider": ttsProvider,
			"tts_voice":    ttsVoice,
			"dict_provider": dictProvider,
		}
	}

	writeJSON(w, map[string]interface{}{
		"active_lang":          s.Config.App.ActiveLang,
		"mock_mode":            s.Config.App.MockMode,
		"daily_target":         s.Config.App.DailyTarget,
		"min_accuracy":         s.Config.App.MinAccuracy,
		"listening_ratio":      s.Config.App.ListeningRatio,
		"reading_ratio":        s.Config.App.ReadingRatio,
		"grammar_ratio":        s.Config.App.GrammarRatio,
		"extra_ratio":          s.Config.App.ExtraRatio,
		"passive_enabled":      s.Config.App.PassiveEnabled,
		"passive_min_interval": s.Config.App.PassiveMinInterval,
		"passive_max_interval": s.Config.App.PassiveMaxInterval,
		"escape_password_limit": s.Config.App.EscapePasswordLimit,
		"escape_click_limit":   s.Config.App.EscapeClickLimit,
		"auto_start":           s.Config.App.AutoStart,
		"auto_expand_words":    s.Config.App.AutoExpandWords,
		"expand_batch_size":    s.Config.App.ExpandBatchSize,
		"expand_threshold":     s.Config.App.ExpandThreshold,
		"theme":                s.Config.App.Theme,
		"model":                s.Config.App.AI.Model,
		"base_url":             s.Config.App.AI.BaseURL,
		"languages":            langs,
		"language_details":     langDetails,
		"assignment": map[string]interface{}{
			"cadence_days":    s.Config.App.Assignment.CadenceDays,
			"cadence_count":   s.Config.App.Assignment.CadenceCount,
			"max_per_session": s.Config.App.Assignment.MaxPerSession,
			"ai_recommend":    s.Config.App.Assignment.AIRecommend,
		},
	})
}

func (s *Server) handleConfigGetKey(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleConfigGetKey(w, r); return
	}

	key := r.PathValue("key")
	var value interface{}

	switch key {
	case "active_lang":
		value = s.Config.App.ActiveLang
	case "daily_target":
		value = s.Config.App.DailyTarget
	case "languages":
		langs := make([]string, 0, len(s.Config.Languages))
		for code := range s.Config.Languages {
			langs = append(langs, code)
		}
		value = langs
	case "assignment":
		value = map[string]interface{}{
			"cadence_days":    s.Config.App.Assignment.CadenceDays,
			"cadence_count":   s.Config.App.Assignment.CadenceCount,
			"max_per_session": s.Config.App.Assignment.MaxPerSession,
			"ai_recommend":    s.Config.App.Assignment.AIRecommend,
		}
	default:
		writeError(w, 404, "unknown config key: "+key)
		return
	}

	writeJSON(w, map[string]interface{}{
		"key":   key,
		"value": value,
	})
}

func (s *Server) handleConfigUpdate(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleConfigUpdate(w, r); return
	}

	var req map[string]interface{}
	if err := readJSON(r, &req); err != nil {
		writeError(w, 400, "invalid request body")
		return
	}

	if v, ok := req["active_lang"]; ok {
		if lang, ok := v.(string); ok {
			s.Config.App.ActiveLang = lang
			// Initialize from _languages template on first run
			if _, exists := s.Config.Languages[lang]; !exists {
				if lc := s.tryLoadLanguageTemplate(lang); lc != nil {
					s.Config.Languages[lang] = lc
				}
			}
		}
	}

	if v, ok := req["daily_target"]; ok {
		switch n := v.(type) {
		case float64:
			if n > 0 && n <= 200 {
				s.Config.App.DailyTarget = int(n)
			}
		}
	}

	// Assignment config — support both nested "assignment" object and flat keys
	if v, ok := req["assignment"]; ok {
		if am, ok := v.(map[string]interface{}); ok {
			updateAssignmentConfig(&s.Config.App.Assignment, am)
		}
	}
	updateAssignmentConfig(&s.Config.App.Assignment, req)

	writeJSON(w, map[string]interface{}{
		"updated":      true,
		"active_lang":  s.Config.App.ActiveLang,
		"daily_target": s.Config.App.DailyTarget,
		"assignment": map[string]interface{}{
			"cadence_days":    s.Config.App.Assignment.CadenceDays,
			"cadence_count":   s.Config.App.Assignment.CadenceCount,
			"max_per_session": s.Config.App.Assignment.MaxPerSession,
			"ai_recommend":    s.Config.App.Assignment.AIRecommend,
		},
	})
}

func updateAssignmentConfig(cfg *config.AssignmentConfig, m map[string]interface{}) {
	if v, ok := m["cadence_days"]; ok {
		switch n := v.(type) {
		case float64:
			if n >= 1 && n <= 30 {
				cfg.CadenceDays = int(n)
			}
		}
	}
	if v, ok := m["cadence_count"]; ok {
		switch n := v.(type) {
		case float64:
			if n >= 1 && n <= 10 {
				cfg.CadenceCount = int(n)
			}
		}
	}
	if v, ok := m["max_per_session"]; ok {
		switch n := v.(type) {
		case float64:
			if n >= 1 && n <= 20 {
				cfg.MaxPerSession = int(n)
			}
		}
	}
	if v, ok := m["ai_recommend"]; ok {
		if b, ok := v.(bool); ok {
			cfg.AIRecommend = b
		}
	}
}

func (s *Server) tryLoadLanguageTemplate(code string) *config.LanguageConfig {
	// Look for template in configs/_languages/
	templatePath := filepath.Join(s.ConfigDir, "_languages", code+".yaml")
	data, err := os.ReadFile(templatePath)
	if err != nil {
		return nil
	}
	// Copy to active languages/
	activeDir := filepath.Join(s.ConfigDir, "languages")
	os.MkdirAll(activeDir, 0755)
	activePath := filepath.Join(activeDir, code+".yaml")
	if err := os.WriteFile(activePath, data, 0644); err != nil {
		fmt.Fprintf(os.Stderr, "init language: %v\n", err)
		return nil
	}
	// Parse and return
	var lc config.LanguageConfig
	if err := yaml.Unmarshal(data, &lc); err != nil {
		return nil
	}
	return &lc
}

func (s *Server) handleConfigPassword(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleConfigPassword(w, r); return
	}
	writeNotImplemented(w)
}

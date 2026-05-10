package api

import (
	"net/http"

	"github.com/vocablock/v2/internal/api/mock"
)

func (s *Server) handleConfigGet(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleConfigGet(w, r); return
	}

	writeJSON(w, map[string]interface{}{
		"active_lang":  s.Config.App.ActiveLang,
		"mock_mode":    s.Config.App.MockMode,
		"daily_target": s.Config.App.DailyTarget,
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
			if _, exists := s.Config.Languages[lang]; exists {
				s.Config.App.ActiveLang = lang
			} else {
				writeError(w, 400, "unknown language: "+lang)
				return
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

	writeJSON(w, map[string]interface{}{
		"updated":      true,
		"active_lang":  s.Config.App.ActiveLang,
		"daily_target": s.Config.App.DailyTarget,
	})
}

func (s *Server) handleConfigPassword(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleConfigPassword(w, r); return
	}
	writeNotImplemented(w)
}

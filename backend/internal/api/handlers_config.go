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
	writeNotImplemented(w)
}

func (s *Server) handleConfigPassword(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleConfigPassword(w, r); return
	}
	writeNotImplemented(w)
}

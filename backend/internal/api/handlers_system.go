package api

import (
	"net/http"
	"os"

	"github.com/vocablock/v2/internal/api/mock"
)

func (s *Server) handleSystemStatus(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, map[string]interface{}{
		"status":      "running",
		"locked":      false,
		"active_lang": s.Config.App.ActiveLang,
	})
}

func (s *Server) handleSystemLock(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleSystemLock(w, r); return
	}
	writeJSON(w, map[string]interface{}{
		"locked": true,
		"status": "lock screen not implemented",
	})
}

func (s *Server) handleSystemUnlock(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleSystemUnlock(w, r); return
	}
	writeJSON(w, map[string]interface{}{
		"locked": false,
	})
}

func (s *Server) handleSystemPassiveQ(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleSystemPassiveQ(w, r); return
	}
	// Return a random word card for passive display widget
	if s.DB != nil {
		words, err := s.DB.GetReviewWords(s.Config.App.ActiveLang, 1)
		if err == nil && len(words) > 0 {
			wd := words[0]
			writeJSON(w, map[string]interface{}{
				"word":    wd.Word,
				"reading": wd.Reading,
				"meaning": wd.Meaning,
			})
			return
		}
	}
	writeJSON(w, map[string]interface{}{
		"word": "", "reading": "", "meaning": "",
	})
}

func (s *Server) handleSystemPassiveSubmit(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleSystemPassiveSubmit(w, r); return
	}
	writeJSON(w, map[string]bool{"accepted": true})
}

func (s *Server) handleSystemQuit(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleSystemQuit(w, r); return
	}
	writeJSON(w, map[string]bool{"quitting": true})

	// Graceful shutdown: signal via exit
	go func() {
		s.Shutdown()
		os.Exit(0)
	}()
}

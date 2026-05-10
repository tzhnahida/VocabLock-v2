package api

import (
	"fmt"
	"net/http"
	"strconv"

	"github.com/vocablock/v2/internal/api/mock"
)

func (s *Server) handleTTSWord(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleTTSWord(w, r); return
	}

	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeError(w, 400, "invalid word id")
		return
	}

	_ = id // TODO: load word from DB, synthesize audio

	writeJSON(w, map[string]interface{}{
		"url":    fmt.Sprintf("/api/v1/tts/word/%d", id),
		"format": "mp3",
		"cached": false,
		"status": "not_configured",
	})
}

func (s *Server) handleTTSText(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleTTSText(w, r); return
	}

	writeJSON(w, map[string]interface{}{
		"url":    "",
		"format": "mp3",
		"cached": false,
		"status": "not_configured",
	})
}

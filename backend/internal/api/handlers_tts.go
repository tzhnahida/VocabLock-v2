package api

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"time"

	"github.com/vocablock/v2/internal/api/mock"
	"github.com/vocablock/v2/internal/db"
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

	if s.TTSProvider == nil {
		writeJSON(w, map[string]interface{}{
			"url":    fmt.Sprintf("/api/v1/tts/word/%d", id),
			"format": "mp3",
			"cached": false,
			"status": "not_configured",
		})
		return
	}

	// Load word from DB to get its reading and word
	if s.DB == nil {
		writeError(w, 500, "database not available")
		return
	}

	word, err := s.DB.GetWord(id)
	if err != nil || word == nil {
		writeError(w, 404, "word not found")
		return
	}

	// Determine voice from active language config
	voice := ""
	if lc, ok := s.Config.Languages[s.Config.App.ActiveLang]; ok {
		voice = lc.TTS.Voice
	}

	text := word.Word
	if word.Reading != "" {
		text = word.Reading
	}

	ctx, cancel := context.WithTimeout(r.Context(), 30*time.Second)
	defer cancel()

	path, err := s.TTSProvider.Generate(ctx, voice, text)
	if err != nil {
		writeJSON(w, map[string]interface{}{
			"url":    "",
			"format": "mp3",
			"cached": false,
			"status": "error",
			"error":  err.Error(),
		})
		return
	}

	writeJSON(w, map[string]interface{}{
		"url":    fmt.Sprintf("/data/audio/%s", filepath.Base(path)),
		"format": "mp3",
		"cached": true,
		"status": "ok",
	})
}

func (s *Server) handleTTSText(w http.ResponseWriter, r *http.Request) {
	if s.Mock {
		mock.HandleTTSText(w, r); return
	}

	if s.TTSProvider == nil {
		writeJSON(w, map[string]interface{}{
			"url":    "",
			"format": "mp3",
			"cached": false,
			"status": "not_configured",
		})
		return
	}

	var req struct {
		Text  string `json:"text"`
		Voice string `json:"voice"`
	}
	if err := readJSON(r, &req); err != nil {
		writeError(w, 400, "invalid request body")
		return
	}

	if req.Voice == "" {
		if lc, ok := s.Config.Languages[s.Config.App.ActiveLang]; ok {
			req.Voice = lc.TTS.Voice
		}
	}

	ctx, cancel := context.WithTimeout(r.Context(), 30*time.Second)
	defer cancel()

	path, err := s.TTSProvider.Generate(ctx, req.Voice, req.Text)
	if err != nil {
		writeJSON(w, map[string]interface{}{
			"url":    "",
			"format": "mp3",
			"cached": false,
			"status": "error",
			"error":  err.Error(),
		})
		return
	}

	writeJSON(w, map[string]interface{}{
		"url":    fmt.Sprintf("/data/audio/%s", filepath.Base(path)),
		"format": "mp3",
		"cached": true,
		"status": "ok",
	})
}

// preWarmTTS pre-generates TTS audio for a word's pronunciation in a background
// goroutine, so subsequent handleTTSWord calls serve instantly from cache.
func (s *Server) preWarmTTS(word *db.Word) {
	if s.TTSProvider == nil || word == nil {
		return
	}
	voice := ""
	if lc, ok := s.Config.Languages[s.Config.App.ActiveLang]; ok {
		voice = lc.TTS.Voice
	}
	text := word.Word
	if word.Reading != "" {
		text = word.Reading
	}
	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()
		if _, err := s.TTSProvider.Generate(ctx, voice, text); err != nil {
			fmt.Fprintf(os.Stderr, "[tts/prewarm] %q: %v\n", text, err)
		}
	}()
}

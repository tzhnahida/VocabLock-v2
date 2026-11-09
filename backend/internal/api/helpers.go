package api

import (
	"encoding/json"
	"net/http"

	"github.com/tzhnahida/VocabLock/internal/log"
)

// Text-field limits complement the 16 MiB request-body cap. They keep a
// single oversized string out of AI prompts, TTS binaries and SQLite.
const (
	maxAIChatMessage     = 20000
	maxAIChatHistory     = 50
	maxAIChatHistoryItem = 20000
	maxAITrainingProfile = 100000
	maxTTSChars          = 2000
	maxWordField         = 200
	maxMeaningField      = 2000
	maxImportWords       = 5000
	maxTags              = 100
	maxTagChars          = 64
	maxAssignmentAnswer  = 10000
	maxQuizAnswer        = 10000
	maxQuizAudioBase64   = 8 << 20
)

func writeNotImplemented(w http.ResponseWriter) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusNotImplemented)
	writeJSON(w, map[string]string{"error": "not implemented"})
}

func writeJSON(w http.ResponseWriter, v interface{}) {
	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(v); err != nil {
		log.Error("api", "writeJSON encode: %v", err)
	}
}

func writeError(w http.ResponseWriter, code int, msg string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	if err := json.NewEncoder(w).Encode(map[string]string{"error": msg}); err != nil {
		log.Error("api", "writeError encode: %v", err)
	}
}

func readJSON(r *http.Request, v interface{}) error {
	defer r.Body.Close()
	return json.NewDecoder(r.Body).Decode(v)
}

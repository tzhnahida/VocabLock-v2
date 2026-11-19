package api

import (
	cryptorand "crypto/rand"
	"encoding/hex"
	"encoding/json"
	"math/rand"
	"net/http"
	"sort"
	"strings"
	"time"

	"github.com/tzhnahida/VocabLock/internal/log"
)

const placementPerLevel = 6
const placementTTL = 30 * time.Minute

type placementBand struct {
	Correct int `json:"correct"`
	Total   int `json:"total"`
}

type placementSession struct {
	language  string
	createdAt time.Time
	correct   map[string]string
	level     map[string]string
}

// handlePlacementStart samples words from the installed content packs, six
// per JLPT level, and returns them with four meaning options each. The
// correct options stay on the server so a client cannot read the key.
func (s *Server) handlePlacementStart(w http.ResponseWriter, r *http.Request) {
	if s.Content == nil {
		writeError(w, http.StatusServiceUnavailable, "no content packs installed")
		return
	}
	lang := s.currentLang()
	rng := rand.New(rand.NewSource(time.Now().UnixNano()))
	picks := s.Content.SampleByLevel(lang, placementPerLevel, rng.Intn)
	if len(picks) < placementPerLevel*2 {
		writeError(w, http.StatusConflict, "not enough leveled content: install a pack with level tags")
		return
	}

	correct := map[string]string{}
	levelOf := map[string]string{}
	glosses := make([]string, 0, len(picks))
	for _, e := range picks {
		if len(e.Senses) > 0 && len(e.Senses[0].Glosses) > 0 {
			g := strings.TrimSpace(e.Senses[0].Glosses[0])
			if g != "" {
				glosses = append(glosses, g)
			}
		}
	}

	questions := make([]map[string]interface{}, 0, len(picks))
	for _, e := range picks {
		if len(e.Senses) == 0 || len(e.Senses[0].Glosses) == 0 {
			continue
		}
		answer := strings.TrimSpace(e.Senses[0].Glosses[0])
		if answer == "" {
			continue
		}
		opts := []string{answer}
		seen := map[string]bool{strings.ToLower(answer): true}
		for len(opts) < 4 && len(seen) < len(glosses) {
			g := glosses[rng.Intn(len(glosses))]
			key := strings.ToLower(strings.TrimSpace(g))
			if g == "" || seen[key] {
				continue
			}
			seen[key] = true
			opts = append(opts, g)
		}
		if len(opts) < 2 {
			continue
		}
		rng.Shuffle(len(opts), func(i, j int) { opts[i], opts[j] = opts[j], opts[i] })
		correct[e.Word] = answer
		levelOf[e.Word] = e.Level
		questions = append(questions, map[string]interface{}{
			"id":      e.Word,
			"word":    e.Word,
			"reading": e.Reading,
			"level":   e.Level,
			"options": opts,
		})
	}
	if len(questions) == 0 {
		writeError(w, http.StatusConflict, "no usable placement questions")
		return
	}

	id := make([]byte, 12)
	if _, err := cryptorand.Read(id); err != nil {
		writeError(w, http.StatusInternalServerError, "generate placement id")
		return
	}
	sid := hex.EncodeToString(id)
	s.placementMu.Lock()
	if s.placementSessions == nil {
		s.placementSessions = map[string]*placementSession{}
	}
	for k, v := range s.placementSessions {
		if time.Since(v.createdAt) > placementTTL {
			delete(s.placementSessions, k)
		}
	}
	s.placementSessions[sid] = &placementSession{
		language: lang, createdAt: time.Now(), correct: correct, level: levelOf,
	}
	s.placementMu.Unlock()

	writeJSON(w, map[string]interface{}{"id": sid, "questions": questions})
}

// handlePlacementSubmit grades the answers, estimates the learner's level and
// persists it as student_state (the same value expansion uses to skip words).
func (s *Server) handlePlacementSubmit(w http.ResponseWriter, r *http.Request) {
	var req struct {
		ID      string `json:"id"`
		Answers []struct {
			ID     string `json:"id"`
			Answer string `json:"answer"`
		} `json:"answers"`
	}
	if err := readJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid payload")
		return
	}
	s.placementMu.Lock()
	sess, ok := s.placementSessions[req.ID]
	if ok {
		delete(s.placementSessions, req.ID)
	}
	s.placementMu.Unlock()
	if !ok || time.Since(sess.createdAt) > placementTTL {
		writeError(w, http.StatusNotFound, "placement session expired")
		return
	}

	bands := map[string]placementBand{}
	for _, a := range req.Answers {
		want, exists := sess.correct[a.ID]
		level := sess.level[a.ID]
		if !exists || level == "" {
			continue
		}
		b := bands[level]
		b.Total++
		if strings.EqualFold(strings.TrimSpace(a.Answer), strings.TrimSpace(want)) {
			b.Correct++
		}
		bands[level] = b
	}

	estimated := estimateLevel(bands)
	if s.DB != nil {
		if err := s.DB.SetStudentLevel(sess.language, estimated); err != nil {
			log.Warn("placement", "save level: %v", err)
		}
		plan, _ := json.Marshal(map[string]interface{}{
			"source":          "placement",
			"estimated_level": estimated,
			"bands":           bands,
			"daily_new_words": dailyNewWords(estimated),
			"direction":       "exam",
		})
		if _, err := s.DB.InsertTrainingPlan(sess.language, "exam", 0.9, string(plan)); err != nil {
			log.Warn("placement", "save plan: %v", err)
		}
	}

	writeJSON(w, map[string]interface{}{
		"estimated_level": estimated,
		"bands":           bands,
		"daily_new_words": dailyNewWords(estimated),
	})
}

// estimateLevel walks bands from easiest to hardest: the highest band passed
// (>=70% correct) is the estimate; failing an easier band stops the walk.
func estimateLevel(bands map[string]placementBand) string {
	levels := make([]string, 0, len(bands))
	for lv := range bands {
		levels = append(levels, lv)
	}
	sort.Slice(levels, func(i, j int) bool { return levelRank(levels[i]) < levelRank(levels[j]) })
	estimate := "beginner"
	for _, lv := range levels {
		b := bands[lv]
		if b.Total == 0 {
			continue
		}
		if float64(b.Correct)/float64(b.Total) >= 0.7 {
			estimate = lv
			continue
		}
		break
	}
	return estimate
}

func dailyNewWords(level string) int {
	switch strings.ToUpper(strings.TrimSpace(level)) {
	case "N5", "BEGINNER":
		return 15
	case "N4", "N3":
		return 12
	case "N2":
		return 10
	case "N1":
		return 8
	}
	return 12
}

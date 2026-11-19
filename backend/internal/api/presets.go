package api

import (
	"net/http"
	"strings"
)

type presetInfo struct {
	ID                string   `json:"id"`
	Name              string   `json:"name"`
	Goal              string   `json:"goal"`
	Direction         string   `json:"direction"`
	Minutes           int      `json:"minutes"`
	DailyTarget       int      `json:"daily_target"`
	DailyTimeTarget   int      `json:"daily_time_target"`
	SessionTimeBudget int      `json:"session_time_budget"`
	MaxSlowTypeRatio  float64  `json:"max_slow_type_ratio"`
	ContentPack       string   `json:"content_pack,omitempty"`
	Levels            []string `json:"levels,omitempty"`
	Available         bool     `json:"available"`
	Reason            string   `json:"reason,omitempty"`
}

type rhythmPreset struct {
	id        string
	name      string
	goal      string
	direction string
	minutes   int
	slowRatio float64
	pack      string
}

var rhythmPresets = []rhythmPreset{
	{"exam_sprint", "考试冲刺", "exam", "exam", 40, 0.4, "ja-jlpt-open"},
	{"conversation", "日常会话", "conversation", "conversation", 20, 0.3, ""},
	{"reading", "兴趣阅读", "reading", "reading", 30, 0.3, ""},
	{"light", "轻度复习", "general", "general", 10, 0.2, ""},
}

func clampDailyTarget(minutes int) int {
	target := minutes / 2
	if target < 3 {
		target = 3
	}
	if target > 60 {
		target = 60
	}
	return target
}

func (s *Server) buildPresets(language string) []presetInfo {
	levels := []string{}
	if s.Content != nil {
		levels = s.Content.Levels(language)
	}
	packs := map[string]bool{}
	if s.Content != nil {
		for _, p := range s.Content.Packs() {
			packs[p.Language+"/"+p.ID] = true
		}
	}
	out := make([]presetInfo, 0, len(rhythmPresets)+1)
	for _, rp := range rhythmPresets {
		p := presetInfo{
			ID: rp.id, Name: rp.name, Goal: rp.goal, Direction: rp.direction,
			Minutes: rp.minutes, DailyTarget: clampDailyTarget(rp.minutes),
			DailyTimeTarget: rp.minutes, SessionTimeBudget: rp.minutes,
			MaxSlowTypeRatio: rp.slowRatio,
			ContentPack:      rp.pack,
			Available:        true,
		}
		if rp.pack != "" {
			p.Levels = levels
			if !packs[language+"/"+rp.pack] {
				p.Available = false
				p.Reason = "content pack " + rp.pack + " is not installed for " + language
			}
		}
		out = append(out, p)
	}
	return out
}

func (s *Server) handlePresets(w http.ResponseWriter, r *http.Request) {
	language := r.URL.Query().Get("language")
	if language == "" {
		language = s.Config.App.ActiveLang
	}
	writeJSON(w, map[string]interface{}{
		"language": language,
		"presets":  s.buildPresets(language),
	})
}

func (s *Server) handleApplyPreset(w http.ResponseWriter, r *http.Request) {
	var req struct {
		ID       string `json:"id"`
		Language string `json:"language"`
	}
	if err := readJSON(r, &req); err != nil || strings.TrimSpace(req.ID) == "" {
		writeError(w, 400, "id is required")
		return
	}
	if req.Language == "" {
		req.Language = s.Config.App.ActiveLang
	}
	var chosen *presetInfo
	for _, p := range s.buildPresets(req.Language) {
		if p.ID == req.ID {
			cp := p
			chosen = &cp
			break
		}
	}
	if chosen == nil {
		writeError(w, 404, "unknown preset")
		return
	}

	applied := map[string]interface{}{}
	skipped := []string{}
	apply := func(key string, value interface{}) {
		applied[key] = value
	}
	if chosen.Available {
		s.configMu.Lock()
		s.Config.App.DailyTarget = chosen.DailyTarget
		s.Config.App.DailyTimeTarget = chosen.DailyTimeTarget
		s.Config.App.SessionTimeBudget = chosen.SessionTimeBudget
		s.Config.App.MaxSlowTypeRatio = chosen.MaxSlowTypeRatio
		s.Config.App.LearnerGoal = chosen.Goal
		s.Config.App.LearnerDailyMinutes = chosen.Minutes
		s.configMu.Unlock()
		apply("daily_target", chosen.DailyTarget)
		apply("daily_time_target", chosen.DailyTimeTarget)
		apply("session_time_budget", chosen.SessionTimeBudget)
		apply("max_slow_type_ratio", chosen.MaxSlowTypeRatio)
		apply("learner_goal", chosen.Goal)
		if !s.Mock && s.ConfigDir != "" {
			if err := s.Config.SaveAppConfig(s.ConfigDir); err != nil {
				writeError(w, 500, "save config: "+err.Error())
				return
			}
		}
		if s.DB != nil && chosen.Direction != "" {
			if _, err := s.DB.InsertTrainingPlan(req.Language, chosen.Direction, 1.0, "{}"); err != nil {
				skipped = append(skipped, "training plan: "+err.Error())
			}
		}
	} else {
		skipped = append(skipped, chosen.Reason)
	}

	writeJSON(w, map[string]interface{}{
		"preset":    chosen.ID,
		"language":  req.Language,
		"available": chosen.Available,
		"applied":   applied,
		"skipped":   skipped,
	})
}

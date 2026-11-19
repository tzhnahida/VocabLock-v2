package api

import (
	"net/http"
	"strings"
)

var validGoals = map[string]bool{
	"exam": true, "conversation": true, "work": true, "interest": true, "general": true, "reading": true,
}

var validPreferences = map[string]bool{
	"visual": true, "auditory": true, "kinesthetic": true, "mixed": true,
}

var validLevels = map[string]bool{
	"": true, "auto": true, "beginner": true, "intermediate": true, "advanced": true,
	"n5": true, "n4": true, "n3": true, "n2": true, "n1": true,
	"hsk1": true, "hsk2": true, "hsk3": true, "hsk4": true, "hsk5": true, "hsk6": true,
	"a1": true, "a2": true, "b1": true, "b2": true, "c1": true, "c2": true,
}

func (s *Server) handleProfileGet(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, map[string]interface{}{
		"goal":              s.Config.App.LearnerGoal,
		"level":             s.Config.App.LearnerLevel,
		"daily_minutes":     s.Config.App.LearnerDailyMinutes,
		"preferences":       s.Config.App.LearnerPreferences,
		"onboarding_done":   s.Config.App.OnboardingDone,
		"daily_target":      s.Config.App.DailyTarget,
		"daily_time_target": s.Config.App.DailyTimeTarget,
		"active_language":   s.Config.App.ActiveLang,
	})
}

func (s *Server) handleProfilePut(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Goal           string   `json:"goal"`
		Level          string   `json:"level"`
		DailyMinutes   int      `json:"daily_minutes"`
		Preferences    []string `json:"preferences"`
		OnboardingDone *bool    `json:"onboarding_done"`
	}
	if err := readJSON(r, &req); err != nil {
		writeError(w, 400, "invalid request body")
		return
	}
	goal := strings.ToLower(strings.TrimSpace(req.Goal))
	if goal != "" && !validGoals[goal] {
		writeError(w, 400, "invalid goal")
		return
	}
	level := strings.ToLower(strings.TrimSpace(req.Level))
	if !validLevels[level] {
		writeError(w, 400, "invalid level")
		return
	}
	if req.DailyMinutes < 0 || req.DailyMinutes > 240 {
		writeError(w, 400, "daily_minutes must be 0-240")
		return
	}
	for _, p := range req.Preferences {
		if !validPreferences[strings.ToLower(p)] {
			writeError(w, 400, "invalid preference: "+p)
			return
		}
	}

	s.configMu.Lock()
	if goal != "" {
		s.Config.App.LearnerGoal = goal
	}
	if level != "" {
		s.Config.App.LearnerLevel = level
	}
	if req.DailyMinutes > 0 {
		s.Config.App.LearnerDailyMinutes = req.DailyMinutes
		s.Config.App.DailyTarget = clampDailyTarget(req.DailyMinutes)
		s.Config.App.DailyTimeTarget = req.DailyMinutes
	}
	if req.Preferences != nil {
		prefs := make([]string, 0, len(req.Preferences))
		for _, p := range req.Preferences {
			prefs = append(prefs, strings.ToLower(p))
		}
		s.Config.App.LearnerPreferences = prefs
	}
	if req.OnboardingDone != nil {
		s.Config.App.OnboardingDone = *req.OnboardingDone
	}
	s.configMu.Unlock()

	if !s.Mock && s.ConfigDir != "" {
		if err := s.Config.SaveAppConfig(s.ConfigDir); err != nil {
			writeError(w, 500, "save config: "+err.Error())
			return
		}
	}
	s.handleProfileGet(w, r)
}

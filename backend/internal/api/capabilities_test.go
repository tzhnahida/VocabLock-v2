package api

import (
	"strings"
	"testing"

	"github.com/tzhnahida/VocabLock/internal/config"
)

func TestCapabilitiesPresetsAndProfile(t *testing.T) {
	s := newTestServer(t)
	withJapaneseCourse(s)
	withContentLibrary(t, s)
	s.ConfigDir = t.TempDir()
	s.Config.Languages["en"] = &config.LanguageConfig{QuestionTypes: []string{"choice", "fill"}}

	rec, _ := newTestRequest(s, "GET", "/api/v1/capabilities", "")
	if rec.Code != 200 {
		t.Fatalf("capabilities = %d %s", rec.Code, rec.Body.String())
	}
	caps := decodeJSON(t, rec)
	if caps["active_language"] != "ja" {
		t.Errorf("active = %v", caps["active_language"])
	}
	langs := caps["languages"].(map[string]interface{})
	ja := langs["ja"].(map[string]interface{})
	if len(ja["packs"].([]interface{})) < 1 {
		t.Errorf("ja packs = %v", ja["packs"])
	}
	if len(ja["levels"].([]interface{})) < 2 || ja["placement"] != true {
		t.Errorf("ja levels/placement = %v/%v", ja["levels"], ja["placement"])
	}
	if len(ja["question_types"].([]interface{})) == 0 {
		t.Errorf("ja question types empty")
	}

	rec, _ = newTestRequest(s, "GET", "/api/v1/presets?language=ja", "")
	if rec.Code != 200 {
		t.Fatalf("presets = %d", rec.Code)
	}
	presets := decodeJSON(t, rec)["presets"].([]interface{})
	var exam map[string]interface{}
	for _, p := range presets {
		pm := p.(map[string]interface{})
		if pm["id"] == "exam_sprint" {
			exam = pm
		}
	}
	if exam == nil || exam["available"] != true {
		t.Fatalf("exam_sprint = %v", exam)
	}

	rec, _ = newTestRequest(s, "PUT", "/api/v1/config/preset", `{"id":"exam_sprint","language":"ja"}`)
	if rec.Code != 200 {
		t.Fatalf("apply preset = %d %s", rec.Code, rec.Body.String())
	}
	applied := decodeJSON(t, rec)["applied"].(map[string]interface{})
	if applied["session_time_budget"].(float64) != 40 || applied["daily_target"].(float64) != 20 {
		t.Errorf("applied = %v", applied)
	}
	if s.Config.App.SessionTimeBudget != 40 || s.Config.App.DailyTarget != 20 {
		t.Errorf("config not applied: %+v", s.Config.App)
	}

	// English has no content pack, so the content-bound preset is unavailable
	// but the generic rhythm presets still work.
	rec, _ = newTestRequest(s, "GET", "/api/v1/presets?language=en", "")
	for _, p := range decodeJSON(t, rec)["presets"].([]interface{}) {
		pm := p.(map[string]interface{})
		if pm["id"] == "exam_sprint" && pm["available"] == true {
			t.Errorf("exam_sprint should be unavailable for en: %v", pm)
		}
		if pm["id"] == "conversation" && pm["available"] != true {
			t.Errorf("conversation should be available for en: %v", pm)
		}
	}
	rec, _ = newTestRequest(s, "PUT", "/api/v1/config/preset", `{"id":"conversation","language":"en"}`)
	if rec.Code != 200 || s.Config.App.SessionTimeBudget != 20 {
		t.Errorf("en conversation preset: %d %+v", rec.Code, s.Config.App)
	}

	rec, _ = newTestRequest(s, "PUT", "/api/v1/profile", `{"goal":"exam","level":"N2","daily_minutes":30,"preferences":["visual"],"onboarding_done":true}`)
	if rec.Code != 200 {
		t.Fatalf("profile put = %d %s", rec.Code, rec.Body.String())
	}
	prof := decodeJSON(t, rec)
	if prof["daily_target"].(float64) != 15 || prof["daily_time_target"].(float64) != 30 {
		t.Errorf("profile derived targets = %v/%v", prof["daily_target"], prof["daily_time_target"])
	}
	if prof["onboarding_done"] != true || prof["level"] != "n2" {
		t.Errorf("profile = %v", prof)
	}
	rec, _ = newTestRequest(s, "GET", "/api/v1/profile", "")
	if rec.Code != 200 || decodeJSON(t, rec)["goal"] != "exam" {
		t.Errorf("profile get = %d %s", rec.Code, rec.Body.String())
	}

	rec, _ = newTestRequest(s, "PUT", "/api/v1/profile", `{"goal":"nonsense"}`)
	if rec.Code != 400 || !strings.Contains(rec.Body.String(), "invalid goal") {
		t.Errorf("invalid goal = %d %s", rec.Code, rec.Body.String())
	}
}

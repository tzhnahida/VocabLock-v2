package mock

import "net/http"

// ——— Quiz mock handlers ———

func HandleQuizProgress(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{"reviewed_today":8,"remaining":12,"daily_target":20}`)
}

func HandleQuizNext(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{
		"id":"c42","type":"choice","word_id":1,"word":"食べる",
		"reading":"たべる","prompt":"Select the correct meaning for: 食べる",
		"options":["to drink","to eat","to sleep","to walk"]
	}`)
}

func HandleQuizSubmit(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{"correct":true,"score":1.0,"feedback":"Correct!","source":"exact","next_review_at":"2026-05-11T00:00:00Z"}`)
}

func HandleQuizTodayStats(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{"reviewed":8,"correct":7,"accuracy":0.875,"time_spent_sec":420}`)
}

func HandleQuizComplete(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{"completed":true,"daily_target_met":false}`)
}

// ——— Words mock handlers ———

func HandleWordsList(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{
		"words": [
			{"id":1,"word":"食べる","reading":"たべる","meaning":"to eat","pos":"verb","language":"ja","source":"manual","easiness_factor":2.5,"interval":6,"repetitions":2,"total_attempts":5,"total_correct":4},
			{"id":2,"word":"飲む","reading":"のむ","meaning":"to drink","pos":"verb","language":"ja","source":"manual","easiness_factor":2.3,"interval":3,"repetitions":1,"total_attempts":3,"total_correct":2}
		],
		"total":2
	}`)
}

func HandleWordsGet(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{"id":1,"word":"食べる","reading":"たべる","meaning":"to eat","pos":"verb","language":"ja","source":"manual","easiness_factor":2.5,"interval":6,"repetitions":2,"total_attempts":5,"total_correct":4}`)
}

func HandleWordsCreate(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{"id":3,"word":"歩く","reading":"あるく","meaning":"to walk","pos":"verb"}`)
}

func HandleWordsUpdate(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{"id":1,"word":"食べる","reading":"たべる","meaning":"to eat","pos":"verb"}`)
}

func HandleWordsDelete(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{"deleted":true}`)
}

func HandleWordsReset(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{"reset":true,"word_id":1}`)
}

func HandleWordsExport(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Content-Disposition", "attachment; filename=vocablock-export.json")
	w.Write([]byte(`[{"word":"食べる","reading":"たべる","meaning":"to eat","pos":"verb"}]`))
}

func HandleWordsImport(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{"imported":5,"skipped":0,"errors":[]}`)
}

func HandleWordsExpand(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{
		"verified": [{"word":"歩く","reading":"あるく","meaning":"to walk","pos":"verb"}],
		"pending_review": []
	}`)
}

// ——— AI mock handlers ———

func HandleAIChat(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{"reply":"こんにちは！日本語の勉強を頑張りましょう。","model":"mock"}`)
}

func HandleAIProfile(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{"base_url":"https://api.deepseek.com","model":"deepseek-chat","timeout_sec":30}`)
}

func HandleAIProfileUpdate(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{"updated":true}`)
}

// ——— TTS mock handlers ———

func HandleTTSWord(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{"url":"data:audio/mp3;base64,//mock-audio-data","format":"mp3","cached":true}`)
}

func HandleTTSText(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{"url":"data:audio/mp3;base64,//mock-audio-data","format":"mp3","cached":false}`)
}

// ——— Stats mock handlers ———

func HandleStatsHeatmap(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{"2026-05-01":15,"2026-05-02":20,"2026-05-03":0,"2026-05-04":18,"2026-05-05":22}`)
}

func HandleStatsStreak(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{"streak":5,"longest_streak":12}`)
}

func HandleStatsDailyReport(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{
		"date":"2026-05-10","words_reviewed":20,"words_correct":18,"accuracy":0.9,
		"time_spent_sec":600,"new_words":3,"mastered_words":1
	}`)
}

// ——— System mock handlers ———

func HandleSystemStatus(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{"status":"running","locked":false,"uptime_sec":3600,"active_lang":"ja"}`)
}

func HandleSystemLock(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{"locked":true}`)
}

func HandleSystemUnlock(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{"locked":false}`)
}

func HandleSystemPassiveQ(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{"word":"猫","reading":"ねこ","meaning":"cat"}`)
}

func HandleSystemPassiveSubmit(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{"accepted":true}`)
}

func HandleSystemQuit(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{"quitting":true}`)
}

// ——— Config mock handlers ———

func HandleConfigGet(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{"active_lang":"ja","mock_mode":true,"daily_target":20}`)
}

func HandleConfigGetKey(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{"key":"active_lang","value":"ja"}`)
}

func HandleConfigUpdate(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{"updated":true}`)
}

func HandleConfigPassword(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{"set":true}`)
}

func writeJSON(w http.ResponseWriter, json string) {
	w.Header().Set("Content-Type", "application/json")
	w.Write([]byte(json))
}

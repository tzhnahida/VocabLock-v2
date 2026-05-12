package mock

import "net/http"

// ——— Quiz mock handlers ———

func HandleQuizProgress(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{"reviewed_today":8,"remaining":12,"daily_target":20}`)
}

func HandleQuizNext(w http.ResponseWriter, r *http.Request) {
	lang := r.URL.Query().Get("language")
	if lang == "" {
		lang = "ja"
	}
	writeJSON(w, quizQuestion(lang))
}

func HandleQuizSubmit(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{"correct":true,"score":1.0,"feedback":"Correct!","source":"exact","next_review_at":"2026-05-11T00:00:00Z"}`)
}

func HandleQuizTodayStats(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{"reviewed":8,"correct":7,"accuracy":0.875}`)
}

func HandleQuizComplete(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{"completed":true,"daily_target_met":false}`)
}

// ——— Words mock handlers ———

func HandleWordsList(w http.ResponseWriter, r *http.Request) {
	lang := r.URL.Query().Get("language")
	if lang == "" {
		lang = "ja"
	}
	writeJSON(w, wordsList(lang))
}

func HandleWordsGet(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	writeJSON(w, wordByID(id))
}

func HandleWordsCreate(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{"id":999,"word":"newword","reading":"newreading","meaning":"new meaning","pos":"noun"}`)
}

func HandleWordsUpdate(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{"id":1,"word":"updated","reading":"updated","meaning":"updated","pos":"verb"}`)
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
	w.Write([]byte(`[{"word":"hello","reading":"heˈloʊ","meaning":"a greeting","pos":"interjection"}]`))
}

func HandleWordsImport(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{"imported":5,"skipped":0}`)
}

func HandleWordsExpand(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{"verified":[],"pending_review":[]}`)
}

// ——— AI mock handlers ———

func HandleAIChat(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{"reply":"Hello! I'm your language learning assistant. How can I help you today?","model":"mock"}`)
}

func HandleAIProfile(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{"base_url":"https://api.deepseek.com","model":"deepseek-v4-pro","configured":true}`)
}

func HandleAIProfileUpdate(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{"saved":true,"language":"zh","direction":"general"}`)
}

// ——— TTS mock handlers ———

func HandleTTSWord(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{"url":"/data/audio/mock.mp3","format":"mp3","cached":true,"status":"ok"}`)
}

func HandleTTSText(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{"url":"/data/audio/mock.mp3","format":"mp3","cached":false,"status":"ok"}`)
}

// ——— Stats mock handlers ———

func HandleStatsHeatmap(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{"2026-05-01":15,"2026-05-02":20,"2026-05-03":0,"2026-05-04":18,"2026-05-05":22,"2026-05-06":12,"2026-05-07":25}`)
}

func HandleStatsStreak(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{"streak":5}`)
}

func HandleStatsDailyReport(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{"date":"today","words_reviewed":20,"words_correct":18,"accuracy":0.9}`)
}

// ——— System mock handlers ———

func HandleSystemStatus(w http.ResponseWriter, r *http.Request) {
	lang := r.URL.Query().Get("language")
	if lang == "" {
		lang = "zh"
	}
	writeJSON(w, `{"status":"running","locked":false,"active_lang":"`+lang+`"}`)
}

func HandleSystemLock(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{"locked":true}`)
}

func HandleSystemUnlock(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{"locked":false}`)
}

func HandleSystemPassiveQ(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{"word":"hello","reading":"heˈloʊ","meaning":"a greeting"}`)
}

func HandleSystemPassiveSubmit(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{"accepted":true}`)
}

func HandleSystemQuit(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{"quitting":true}`)
}

// ——— Config mock handlers ———

var mockConfigured bool

func HandleConfigGet(w http.ResponseWriter, r *http.Request) {
	if !mockConfigured {
		writeJSON(w, `{
  "active_lang": "zh",
  "mock_mode": true,
  "daily_target": 20,
  "min_accuracy": 0.8,
  "listening_ratio": 0.15,
  "reading_ratio": 0.15,
  "grammar_ratio": 0.15,
  "extra_ratio": 0.15,
  "passive_enabled": true,
  "passive_min_interval": 25,
  "passive_max_interval": 60,
  "escape_password_limit": 1,
  "escape_click_limit": 2,
  "auto_start": false,
  "auto_expand_words": true,
  "expand_batch_size": 10,
  "expand_threshold": 0.6,
  "theme": "vs-dark",
  "model": "deepseek-v4-pro",
  "base_url": "https://api.deepseek.com",
  "custom_models": "",
  "languages": [],
  "assignment": {"cadence_days":3,"cadence_count":2,"max_per_session":1,"ai_recommend":true}
}`)
		return
	}
	writeJSON(w, `{
  "active_lang": "zh",
  "mock_mode": true,
  "daily_target": 20,
  "min_accuracy": 0.8,
  "listening_ratio": 0.15,
  "reading_ratio": 0.15,
  "grammar_ratio": 0.15,
  "extra_ratio": 0.15,
  "passive_enabled": true,
  "passive_min_interval": 25,
  "passive_max_interval": 60,
  "escape_password_limit": 1,
  "escape_click_limit": 2,
  "auto_start": false,
  "auto_expand_words": true,
  "expand_batch_size": 10,
  "expand_threshold": 0.6,
  "theme": "vs-dark",
  "model": "deepseek-v4-pro",
  "base_url": "https://api.deepseek.com",
  "custom_models": "",
  "languages": ["zh"],
  "assignment": {"cadence_days":3,"cadence_count":2,"max_per_session":1,"ai_recommend":true}
}`)
}

func HandleConfigGetKey(w http.ResponseWriter, r *http.Request) {
	key := r.PathValue("key")
	switch key {
	case "languages":
		writeJSON(w, `{"key":"languages","value":["zh"]}`)
	case "active_lang":
		writeJSON(w, `{"key":"active_lang","value":"zh"}`)
	case "daily_target":
		writeJSON(w, `{"key":"daily_target","value":20}`)
	case "min_accuracy":
		writeJSON(w, `{"key":"min_accuracy","value":0.8}`)
	case "listening_ratio":
		writeJSON(w, `{"key":"listening_ratio","value":0.15}`)
	case "reading_ratio":
		writeJSON(w, `{"key":"reading_ratio","value":0.15}`)
	case "grammar_ratio":
		writeJSON(w, `{"key":"grammar_ratio","value":0.15}`)
	case "passive_enabled":
		writeJSON(w, `{"key":"passive_enabled","value":true}`)
	case "passive_min_interval":
		writeJSON(w, `{"key":"passive_min_interval","value":25}`)
	case "passive_max_interval":
		writeJSON(w, `{"key":"passive_max_interval","value":60}`)
	case "escape_password_limit":
		writeJSON(w, `{"key":"escape_password_limit","value":1}`)
	case "escape_click_limit":
		writeJSON(w, `{"key":"escape_click_limit","value":2}`)
	case "auto_start":
		writeJSON(w, `{"key":"auto_start","value":false}`)
	case "auto_expand_words":
		writeJSON(w, `{"key":"auto_expand_words","value":true}`)
	case "expand_batch_size":
		writeJSON(w, `{"key":"expand_batch_size","value":10}`)
	case "expand_threshold":
		writeJSON(w, `{"key":"expand_threshold","value":0.6}`)
	case "model":
		writeJSON(w, `{"key":"model","value":"deepseek-v4-pro"}`)
	case "base_url":
		writeJSON(w, `{"key":"base_url","value":"https://api.deepseek.com"}`)
	case "assignment":
		writeJSON(w, `{"key":"assignment","value":{"cadence_days":3,"cadence_count":2,"max_per_session":1,"ai_recommend":true}}`)
	default:
		writeJSON(w, `{"error":"unknown config key"}`)
	}
}

func HandleConfigUpdate(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{"updated":true,"assignment":{"cadence_days":3,"cadence_count":2,"max_per_session":1,"ai_recommend":true}}`)
}

func HandleConfigPassword(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, `{"set":true}`)
}

func writeJSON(w http.ResponseWriter, json string) {
	w.Header().Set("Content-Type", "application/json")
	w.Write([]byte(json))
}

// ——— Multi-language mock data ———

func wordByID(id string) string {
	m := map[string]string{
		"1":  `{"id":1,"word":"hello","reading":"heˈloʊ","meaning":"a greeting","pos":"interjection","language":"en","easiness_factor":2.5,"interval":6,"repetitions":2,"total_attempts":5,"total_correct":4}`,
		"2":  `{"id":2,"word":"world","reading":"wɜːld","meaning":"the earth","pos":"noun","language":"en","easiness_factor":2.3,"interval":3,"repetitions":1,"total_attempts":3,"total_correct":2}`,
		"101": `{"id":101,"word":"食べる","reading":"たべる","meaning":"to eat","pos":"verb","language":"ja","easiness_factor":2.5,"interval":6,"repetitions":2,"total_attempts":5,"total_correct":4}`,
		"201": `{"id":201,"word":"学习","reading":"xuéxí","meaning":"to study","pos":"verb","language":"zh","easiness_factor":2.5,"interval":6,"repetitions":2,"total_attempts":5,"total_correct":4}`,
		"301": `{"id":301,"word":"공부하다","reading":"gongbuhada","meaning":"to study","pos":"verb","language":"ko","easiness_factor":2.5,"interval":6,"repetitions":2,"total_attempts":5,"total_correct":4}`,
	}
	if v, ok := m[id]; ok {
		return v
	}
	return `{"id":1,"word":"hello","reading":"heˈloʊ","meaning":"a greeting","pos":"interjection","language":"en","easiness_factor":2.5,"interval":6,"repetitions":2,"total_attempts":5,"total_correct":4}`
}

func wordsList(lang string) string {
	switch lang {
	case "en":
		return `{"words":[
			{"id":1,"word":"hello","reading":"heˈloʊ","meaning":"a greeting","pos":"interjection","language":"en","easiness_factor":2.5,"interval":6,"repetitions":2,"total_attempts":5,"total_correct":4},
			{"id":2,"word":"world","reading":"wɜːld","meaning":"the earth","pos":"noun","language":"en","easiness_factor":2.3,"interval":3,"repetitions":1,"total_attempts":3,"total_correct":2},
			{"id":3,"word":"abandon","reading":"əˈbændən","meaning":"to leave behind","pos":"verb","language":"en","easiness_factor":2.5,"interval":0,"repetitions":0,"total_attempts":0,"total_correct":0},
			{"id":4,"word":"benefit","reading":"ˈbɛnɪfɪt","meaning":"an advantage","pos":"noun","language":"en","easiness_factor":2.5,"interval":0,"repetitions":0,"total_attempts":0,"total_correct":0}
		],"total":4}`
	case "ja":
		return `{"words":[
			{"id":101,"word":"食べる","reading":"たべる","meaning":"to eat","pos":"verb","language":"ja","easiness_factor":2.5,"interval":6,"repetitions":2,"total_attempts":5,"total_correct":4},
			{"id":102,"word":"飲む","reading":"のむ","meaning":"to drink","pos":"verb","language":"ja","easiness_factor":2.3,"interval":3,"repetitions":1,"total_attempts":3,"total_correct":2},
			{"id":103,"word":"歩く","reading":"あるく","meaning":"to walk","pos":"verb","language":"ja","easiness_factor":2.5,"interval":0,"repetitions":0,"total_attempts":0,"total_correct":0},
			{"id":104,"word":"学校","reading":"がっこう","meaning":"school","pos":"noun","language":"ja","easiness_factor":2.5,"interval":0,"repetitions":0,"total_attempts":0,"total_correct":0}
		],"total":4}`
	case "zh":
		return `{"words":[
			{"id":201,"word":"学习","reading":"xuéxí","meaning":"to study","pos":"verb","language":"zh","easiness_factor":2.5,"interval":6,"repetitions":2,"total_attempts":5,"total_correct":4},
			{"id":202,"word":"工作","reading":"gōngzuò","meaning":"to work","pos":"verb","language":"zh","easiness_factor":2.3,"interval":3,"repetitions":1,"total_attempts":3,"total_correct":2},
			{"id":203,"word":"美丽","reading":"měilì","meaning":"beautiful","pos":"adj","language":"zh","easiness_factor":2.5,"interval":0,"repetitions":0,"total_attempts":0,"total_correct":0},
			{"id":204,"word":"电脑","reading":"diànnǎo","meaning":"computer","pos":"noun","language":"zh","easiness_factor":2.5,"interval":0,"repetitions":0,"total_attempts":0,"total_correct":0}
		],"total":4}`
	case "ko":
		return `{"words":[
			{"id":301,"word":"공부하다","reading":"gongbuhada","meaning":"to study","pos":"verb","language":"ko","easiness_factor":2.5,"interval":6,"repetitions":2,"total_attempts":5,"total_correct":4},
			{"id":302,"word":"아름답다","reading":"areumdapda","meaning":"beautiful","pos":"adj","language":"ko","easiness_factor":2.3,"interval":3,"repetitions":1,"total_attempts":3,"total_correct":2},
			{"id":303,"word":"학교","reading":"hakgyo","meaning":"school","pos":"noun","language":"ko","easiness_factor":2.5,"interval":0,"repetitions":0,"total_attempts":0,"total_correct":0},
			{"id":304,"word":"사랑","reading":"sarang","meaning":"love","pos":"noun","language":"ko","easiness_factor":2.5,"interval":0,"repetitions":0,"total_attempts":0,"total_correct":0}
		],"total":4}`
	default:
		return `{"words":[],"total":0}`
	}
}

func quizQuestion(lang string) string {
	switch lang {
	case "en":
		return `{"id":"c1","type":"choice","word_id":1,"word":"hello","reading":"heˈloʊ","prompt":"What does 'hello' mean?","options":["a greeting","goodbye","thank you","sorry"]}`
	case "ja":
		return `{"id":"c101","type":"choice","word_id":101,"word":"食べる","reading":"たべる","prompt":"「食べる」的意思是什么？","options":["吃","喝","睡","走"]}`
	case "zh":
		return `{"id":"c201","type":"choice","word_id":201,"word":"学习","reading":"xuéxí","prompt":"'学习' 的正确拼音是？","options":["xuéxí","xiūxi","gōngzuò","wánshuǎ"]}`
	case "ko":
		return `{"id":"c301","type":"choice","word_id":301,"word":"공부하다","reading":"gongbuhada","prompt":"'공부하다' 的意思是什么？","options":["学习","睡觉","吃饭","跑步"]}`
	default:
		return `{"id":"c1","type":"choice","word_id":1,"word":"hello","reading":"heˈloʊ","prompt":"What does 'hello' mean?","options":["a greeting","goodbye","thank you","sorry"]}`
	}
}

package api

import (
	"net/http"
	"sort"

	"github.com/tzhnahida/VocabLock/internal/content"
)

type languageCapability struct {
	Code          string   `json:"code"`
	Packs         []string `json:"packs"`
	Levels        []string `json:"levels"`
	Placement     bool     `json:"placement"`
	TTS           bool     `json:"tts"`
	Dict          bool     `json:"dict"`
	ASR           bool     `json:"asr"`
	Pronounce     bool     `json:"pronounce"`
	QuestionTypes []string `json:"question_types"`
}

// handleCapabilities reports what the installed assets can actually do, so
// onboarding and settings only offer options that exist.
func (s *Server) handleCapabilities(w http.ResponseWriter, r *http.Request) {
	langs := map[string]languageCapability{}
	codes := make([]string, 0)
	if s.Config != nil {
		for code := range s.Config.Languages {
			codes = append(codes, code)
		}
	}
	packs := []content.PackInfo{}
	contentRoot := ""
	if s.Content != nil {
		contentRoot = s.Content.Root()
		packs = s.Content.Packs()
		for _, p := range packs {
			if p.Language != "" {
				codes = appendUnique(codes, p.Language)
			}
		}
	}
	sort.Strings(codes)

	for _, code := range codes {
		var lc = s.Config.Languages[code]
		cap := languageCapability{Code: code, Packs: []string{}, Levels: []string{}, QuestionTypes: []string{}}
		if s.Content != nil {
			cap.Levels = s.Content.Levels(code)
		}
		for _, p := range packs {
			if p.Language == code {
				cap.Packs = append(cap.Packs, p.ID)
			}
		}
		cap.Placement = len(cap.Levels) >= 2
		if lc != nil {
			cap.TTS = lc.TTS.Provider != "" && s.TTSProvider != nil
			cap.Dict = lc.Dict.Provider != "" && s.DictProvider != nil
			for _, t := range planTypes(langQuestionTypes(code, s.Config), s.AI() != nil, s.HasPronounce(), s.HasASR()) {
				cap.QuestionTypes = append(cap.QuestionTypes, string(t))
			}
		}
		cap.ASR = s.ASRProvider != nil
		cap.Pronounce = s.PronounceProvider != nil
		langs[code] = cap
	}

	writeJSON(w, map[string]interface{}{
		"active_language": s.Config.App.ActiveLang,
		"ai":              s.AI() != nil,
		"tts":             s.TTSProvider != nil,
		"dict":            s.DictProvider != nil,
		"asr":             s.ASRProvider != nil,
		"pronounce":       s.PronounceProvider != nil,
		"content": map[string]interface{}{
			"root":  contentRoot,
			"packs": packs,
		},
		"languages": langs,
	})
}

func appendUnique(list []string, v string) []string {
	for _, x := range list {
		if x == v {
			return list
		}
	}
	return append(list, v)
}

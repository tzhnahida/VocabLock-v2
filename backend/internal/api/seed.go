package api

import (
	"encoding/json"
	"context"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/vocablock/v2/internal/db"
)

// seedWord represents a word in a seed JSON file.
type seedWord struct {
	Word    string `json:"word"`
	Reading string `json:"reading"`
	Meaning string `json:"meaning"`
	POS     string `json:"pos"`
}

// loadSeedWords reads seed words from configs/languages/seeds/<lang>.json and
// inserts any that do not already exist in the database. Returns the number of
// newly inserted words.
func loadSeedWords(s *Server, lang string) (int, error) {
	path := filepath.Join(s.ConfigDir, "languages", "seeds", lang+".json")
	data, err := os.ReadFile(path)
	if err != nil {
		return 0, fmt.Errorf("read seed file %s: %w", path, err)
	}

	var seeds []seedWord
	if err := json.Unmarshal(data, &seeds); err != nil {
		return 0, fmt.Errorf("parse seed file %s: %w", path, err)
	}

	inserted := 0
	for _, sw := range seeds {
		if sw.Word == "" {
			continue
		}
		exists, err := s.DB.WordExists(lang, sw.Word)
		if err != nil {
			return inserted, fmt.Errorf("check word exists: %w", err)
		}
		if exists {
			continue
		}
		_, err = s.DB.InsertWord(&db.Word{
			Word:     sw.Word,
			Reading:  sw.Reading,
			Meaning:  sw.Meaning,
			POS:      sw.POS,
			Language: lang,
			Source:   "seed",
			Status:   "active",
		})
		if err != nil {
			return inserted, fmt.Errorf("insert seed word %q: %w", sw.Word, err)
		}
		inserted++
	}
	return inserted, nil
}

// loadGrammarPoints reads grammar points from the language config and inserts
// any that do not already exist in the database. Returns the number of newly
// inserted grammar points.
func loadGrammarPoints(s *Server, lang string) (int, error) {
	lc, ok := s.Config.Languages[lang]
	if !ok {
		return 0, nil
	}

	inserted := 0
	for _, title := range lc.GrammarPoints {
		if title == "" {
			continue
		}
		exists, err := s.DB.GrammarPointExists(lang, title)
		if err != nil {
			return inserted, fmt.Errorf("check grammar point exists: %w", err)
		}
		if exists {
			continue
		}
		_, err = s.DB.InsertGrammarPoint(&db.GrammarPoint{
			Title:    title,
			Language: lang,
			Source:   "seed",
			Status:   "active",
		})
		if err != nil {
			return inserted, fmt.Errorf("insert grammar point %q: %w", title, err)
		}
		inserted++
	}
	return inserted, nil
}

// EnsureBootstrap checks whether the given language has any words or grammar
// points in the database; if not, it loads seed data from the seed file and
// language config. It is safe to call multiple times — duplicate inserts are
// prevented by existence checks.
func (s *Server) EnsureBootstrap(lang string) {
	if s.Mock {
		return
	}
	if s.DB == nil {
		return
	}

	// Check word count.
	_, total, err := s.DB.ListWords(lang, 1, 0)
	if err != nil {
		fmt.Fprintf(os.Stderr, "bootstrap: list words: %v\n", err)
		return
	}

	if total == 0 {
		n, err := loadSeedWords(s, lang)
		if err != nil {
			fmt.Fprintf(os.Stderr, "bootstrap: load seed words: %v\n", err)
		} else if n > 0 {
			fmt.Fprintf(os.Stderr, "bootstrap: loaded %d seed words for %s\n", n, lang)
		}
	}

	// Fill missing detail fields for words that lack them (runs in background)
	if s.AI != nil {
		go s.fillMissingDetails(lang)
	}

	// Check grammar point count.
	_, gTotal, err := s.DB.ListGrammarPoints(lang, 1, 0)
	if err != nil {
		fmt.Fprintf(os.Stderr, "bootstrap: list grammar points: %v\n", err)
		return
	}

	if gTotal == 0 {
		n, err := loadGrammarPoints(s, lang)
		if err != nil {
			fmt.Fprintf(os.Stderr, "bootstrap: load grammar points: %v\n", err)
		} else if n > 0 {
			fmt.Fprintf(os.Stderr, "bootstrap: loaded %d grammar points for %s\n", n, lang)
		}
	}
}

// fillMissingDetails finds words that have reading/meaning but no detail JSON,
// and fills them via AI in the background.
func (s *Server) fillMissingDetails(lang string) {
	if s.AI == nil || s.DB == nil {
		return
	}
	words, _, err := s.DB.ListWords(lang, 100, 0)
	if err != nil {
		return
	}
	_, level, _, _ := s.expandLangContext(lang)
	filled := 0
	for _, w := range words {
		if w.Meaning == "" || (w.Detail != "" && w.Detail != "{}" && len(w.Detail) > 10) {
			continue
		}
		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		aiDetail := s.generateDetail(ctx, w.Word, w.Reading, w.Meaning, w.POS, level, lang)
		cancel()
		if aiDetail == "" || aiDetail == "{}" {
			continue
		}
		if w.Detail != "" && w.Detail != "{}" {
			aiDetail = mergeJSON(w.Detail, aiDetail)
		}
		w.Detail = aiDetail
		if lv := extractFieldFromDetail(aiDetail, "level"); lv != "" && w.Level == "" {
			w.Level = lv
		}
		if s.DB.UpdateWord(w) == nil {
			filled++
		}
		time.Sleep(500 * time.Millisecond)
	}
	if filled > 0 {
		fmt.Fprintf(os.Stderr, "bootstrap: filled detail for %d words in %s\n", filled, lang)
	}
}

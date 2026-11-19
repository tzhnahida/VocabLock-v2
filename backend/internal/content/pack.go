// Package content loads installable content packs: dictionaries, personal
// word lists, graded lists. The framework only defines the format and the
// merge rules; the data lives in content/packs/<id>/ and never inside the
// binary.
package content

import (
	"bufio"
	"compress/gzip"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

type Example struct {
	Text   string `json:"text"`
	Source string `json:"source,omitempty"`
}

type Sense struct {
	POS      []string  `json:"pos,omitempty"`
	Glosses  []string  `json:"glosses,omitempty"`
	Examples []Example `json:"examples,omitempty"`
	// Provenance is filled during merging, not read from the pack file.
	Source  string `json:"source,omitempty"`
	License string `json:"license,omitempty"`
}

type Entry struct {
	Word      string   `json:"word"`
	Reading   string   `json:"reading,omitempty"`
	POS       []string `json:"pos,omitempty"`
	Senses    []Sense  `json:"senses,omitempty"`
	Source    string   `json:"source,omitempty"`
	License   string   `json:"license,omitempty"`
	Frequency int      `json:"frequency,omitempty"`
	// Level is an optional proficiency tag (N5..N1, HSK1..HSK6, beginner,
	// intermediate, advanced). The expansion pipeline uses it to skip words
	// below the learner's level.
	Level string `json:"level,omitempty"`
}

type Manifest struct {
	Schema      int    `json:"schema"`
	ID          string `json:"id"`
	Name        string `json:"name"`
	Language    string `json:"language"`
	GlossLang   string `json:"gloss_lang"`
	Version     string `json:"version"`
	License     string `json:"license"`
	Attribution string `json:"attribution"`
	Priority    int    `json:"priority"`
}

type Pack struct {
	Manifest
	Dir     string
	Entries []Entry
}

// PackInfo is the API-facing summary.
type PackInfo struct {
	ID        string `json:"id"`
	Name      string `json:"name"`
	Version   string `json:"version"`
	Language  string `json:"language"`
	GlossLang string `json:"gloss_lang"`
	License   string `json:"license"`
	Priority  int    `json:"priority"`
	Entries   int    `json:"entries"`
}

type Library struct {
	root  string
	packs []*Pack
	index map[string]map[string][]*Entry // language -> lemma -> refs (priority order)
}

// Load scans <root>/packs/* for manifests and entries. A missing directory is
// not an error: the framework simply runs without content packs.
func Load(root string) (*Library, error) {
	lib := &Library{root: root, index: map[string]map[string][]*Entry{}}
	packsDir := filepath.Join(root, "packs")
	entries, err := os.ReadDir(packsDir)
	if err != nil {
		if os.IsNotExist(err) {
			return lib, nil
		}
		return nil, fmt.Errorf("read packs dir: %w", err)
	}
	for _, de := range entries {
		if !de.IsDir() {
			continue
		}
		pack, err := loadPack(filepath.Join(packsDir, de.Name()))
		if err != nil {
			// One broken pack must not take the whole library down.
			continue
		}
		lib.packs = append(lib.packs, pack)
	}
	// Highest priority first, so it wins display fields during merging.
	sort.SliceStable(lib.packs, func(i, j int) bool { return lib.packs[i].Priority > lib.packs[j].Priority })
	lib.reindex()
	return lib, nil
}

func loadPack(dir string) (*Pack, error) {
	raw, err := os.ReadFile(filepath.Join(dir, "manifest.json"))
	if err != nil {
		return nil, err
	}
	var m Manifest
	if err := json.Unmarshal(raw, &m); err != nil {
		return nil, fmt.Errorf("parse manifest: %w", err)
	}
	if m.ID == "" {
		m.ID = filepath.Base(dir)
	}
	if m.Language == "" {
		return nil, fmt.Errorf("%s: manifest.language is required", m.ID)
	}
	// Prefer compressed entries: a full N5–N1 pack is ~3 MB raw, ~0.5 MB
	// gzipped. entries.jsonl stays supported for small hand-written packs.
	var reader io.Reader
	if gf, err := os.Open(filepath.Join(dir, "entries.jsonl.gz")); err == nil {
		defer gf.Close()
		gz, err := gzip.NewReader(gf)
		if err != nil {
			return nil, fmt.Errorf("open gzip entries: %w", err)
		}
		defer gz.Close()
		reader = gz
	} else {
		f, err := os.Open(filepath.Join(dir, "entries.jsonl"))
		if err != nil {
			return nil, err
		}
		defer f.Close()
		reader = f
	}

	pack := &Pack{Manifest: m, Dir: dir}
	sc := bufio.NewScanner(reader)
	sc.Buffer(make([]byte, 0, 64*1024), 4*1024*1024)
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if line == "" {
			continue
		}
		var e Entry
		if err := json.Unmarshal([]byte(line), &e); err != nil {
			continue
		}
		if e.Word == "" {
			continue
		}
		if e.Source == "" {
			e.Source = m.ID
		}
		if e.License == "" {
			e.License = m.License
		}
		pack.Entries = append(pack.Entries, e)
	}
	return pack, sc.Err()
}

func (l *Library) reindex() {
	l.index = map[string]map[string][]*Entry{}
	for _, p := range l.packs {
		byWord := l.index[p.Language]
		if byWord == nil {
			byWord = map[string][]*Entry{}
			l.index[p.Language] = byWord
		}
		for i := range p.Entries {
			e := &p.Entries[i]
			key := normalize(e.Word)
			byWord[key] = append(byWord[key], e)
		}
	}
}

func normalize(s string) string { return strings.ToLower(strings.TrimSpace(s)) }

// Lookup merges every pack that defines the lemma: the highest-priority pack
// supplies word/reading/POS, and all packs contribute senses (deduplicated by
// gloss). Returns nil when no pack has the word.
func (l *Library) Lookup(language, word string) *Entry {
	if l == nil {
		return nil
	}
	refs := l.index[language][normalize(word)]
	if len(refs) == 0 {
		return nil
	}
	merged := &Entry{Word: refs[0].Word}
	seen := map[string]bool{}
	for _, e := range refs {
		if merged.Reading == "" {
			merged.Reading = e.Reading
		}
		if merged.Level == "" {
			merged.Level = e.Level
		}
		merged.POS = appendUnique(merged.POS, e.POS...)
		if merged.Frequency == 0 || (e.Frequency > 0 && e.Frequency < merged.Frequency) {
			merged.Frequency = e.Frequency
		}
		for _, s := range e.Senses {
			key := strings.Join(s.Glosses, "|")
			if key != "" && seen[key] {
				continue
			}
			seen[key] = true
			if s.Source == "" {
				s.Source = e.Source
			}
			if s.License == "" {
				s.License = e.License
			}
			merged.Senses = append(merged.Senses, s)
		}
	}
	return merged
}

func appendUnique(dst []string, items ...string) []string {
	for _, it := range items {
		it = strings.TrimSpace(it)
		if it == "" {
			continue
		}
		dup := false
		for _, d := range dst {
			if d == it {
				dup = true
				break
			}
		}
		if !dup {
			dst = append(dst, it)
		}
	}
	return dst
}

func (l *Library) Packs() []PackInfo {
	if l == nil {
		return nil
	}
	out := make([]PackInfo, 0, len(l.packs))
	for _, p := range l.packs {
		out = append(out, PackInfo{
			ID: p.ID, Name: p.Name, Version: p.Version, Language: p.Language,
			GlossLang: p.GlossLang, License: p.License, Priority: p.Priority, Entries: len(p.Entries),
		})
	}
	return out
}

// SampleByLevel returns up to perLevel entries for every level present for
// the language, each with at least one gloss. Used by the placement test.
func (l *Library) SampleByLevel(language string, perLevel int, pick func(n int) int) []*Entry {
	if l == nil || perLevel <= 0 {
		return nil
	}
	byLevel := map[string][]*Entry{}
	for _, p := range l.packs {
		if p.Language != language {
			continue
		}
		for i := range p.Entries {
			e := &p.Entries[i]
			if e.Level == "" || len(e.Senses) == 0 || len(e.Senses[0].Glosses) == 0 {
				continue
			}
			byLevel[e.Level] = append(byLevel[e.Level], e)
		}
	}
	levels := make([]string, 0, len(byLevel))
	for lv := range byLevel {
		levels = append(levels, lv)
	}
	sort.Slice(levels, func(i, j int) bool { return levelOrder(levels[i]) < levelOrder(levels[j]) })
	var out []*Entry
	for _, lv := range levels {
		pool := byLevel[lv]
		for len(pool) > 0 && len(out) < len(levels)*perLevel {
			idx := pick(len(pool))
			out = append(out, pool[idx])
			pool = append(pool[:idx], pool[idx+1:]...)
			if len(out)%perLevel == 0 {
				break
			}
		}
	}
	return out
}

// levelOrder gives a stable sort key for known level labels.
func levelOrder(level string) int {
	l := strings.ToUpper(strings.TrimSpace(level))
	if strings.HasPrefix(l, "N") && len(l) == 2 && l[1] >= '1' && l[1] <= '5' {
		return int('5' - l[1]) // N5=0 … N1=4
	}
	if strings.HasPrefix(l, "HSK") && len(l) == 4 && l[3] >= '1' && l[3] <= '6' {
		return int(l[3] - '1')
	}
	return 99
}

// Root reports where packs were loaded from (for the API and logs).
func (l *Library) Root() string {
	if l == nil {
		return ""
	}
	return l.root
}

package engine

import (
	"math/rand"
	"strings"
)

// QuestionType enumerates all supported question types.
type QuestionType string

const (
	TypeChoice      QuestionType = "choice"
	TypeFill        QuestionType = "fill"
	TypeSpelling    QuestionType = "spelling"
	TypeReading     QuestionType = "reading"
	TypeListening   QuestionType = "listening"
	TypeReadingComp QuestionType = "reading_comp"
	TypeGrammar     QuestionType = "grammar"
)

// Question represents a single quiz question.
type Question struct {
	ID       string       `json:"id"`
	Type     QuestionType `json:"type"`
	WordID   int64        `json:"word_id"`
	Word     string       `json:"word"`
	Reading  string       `json:"reading"`
	Prompt   string       `json:"prompt"`
	Options  []string     `json:"options,omitempty"`
	Answer   string       `json:"-"` // not sent to client
}

// GenerateChoice creates a multiple-choice question given a word and distractors.
func GenerateChoice(word *WordInfo, distractors []*WordInfo) *Question {
	options := make([]string, 0, 4)
	options = append(options, word.Meaning)

	// Pick up to 3 distractors
	for i := 0; i < len(distractors) && len(options) < 4; i++ {
		if distractors[i].Meaning != word.Meaning {
			options = append(options, distractors[i].Meaning)
		}
	}

	// Shuffle
	rand.Shuffle(len(options), func(i, j int) {
		options[i], options[j] = options[j], options[i]
	})

	return &Question{
		ID:      genID("choice", word.ID),
		Type:    TypeChoice,
		WordID:  word.ID,
		Word:    word.Word,
		Reading: word.Reading,
		Prompt:  "Select the correct meaning for: " + word.Word,
		Options: options,
		Answer:  word.Meaning,
	}
}

// GenerateFill creates a fill-in-the-blank question.
func GenerateFill(word *WordInfo) *Question {
	blank := maskWord(word.Word)
	return &Question{
		ID:      genID("fill", word.ID),
		Type:    TypeFill,
		WordID:  word.ID,
		Word:    word.Word,
		Reading: word.Reading,
		Prompt:  "Fill in the blank: " + blank + " (" + word.Meaning + ")",
		Answer:  word.Word,
	}
}

// GenerateSpelling creates a spelling dictation question.
func GenerateSpelling(word *WordInfo) *Question {
	return &Question{
		ID:      genID("spelling", word.ID),
		Type:    TypeSpelling,
		WordID:  word.ID,
		Word:    word.Word,
		Reading: word.Reading,
		Prompt:  "Spell the word for: " + word.Meaning,
		Answer:  word.Word,
	}
}

// GenerateReading creates a reading pronunciation question.
func GenerateReading(word *WordInfo) *Question {
	return &Question{
		ID:      genID("reading", word.ID),
		Type:    TypeReading,
		WordID:  word.ID,
		Word:    word.Word,
		Reading: word.Reading,
		Prompt:  "Read this word: " + word.Word,
		Answer:  word.Reading,
	}
}

// WordInfo is the minimal word data needed for question generation.
type WordInfo struct {
	ID      int64
	Word    string
	Reading string
	Meaning string
	POS     string
}

func maskWord(s string) string {
	if len(s) <= 1 {
		return "_"
	}
	runes := []rune(s)
	n := len(runes)
	reveal := n / 3
	if reveal < 1 {
		reveal = 1
	}
	masked := make([]rune, n)
	for i := range masked {
		masked[i] = '_'
	}
	// Reveal a few positions (first, and evenly spaced)
	masked[0] = runes[0]
	for i := 1; i < reveal; i++ {
		pos := i * n / reveal
		if pos < n {
			masked[pos] = runes[pos]
		}
	}
	return strings.TrimSpace(string(masked))
}

func genID(qtype string, wordID int64) string {
	// Simple unique-enough ID for a session question
	return string(qtype[0]) + itoa(wordID)
}

func itoa(n int64) string {
	if n == 0 {
		return "0"
	}
	s := ""
	for n > 0 {
		s = string(rune('0'+n%10)) + s
		n /= 10
	}
	return s
}

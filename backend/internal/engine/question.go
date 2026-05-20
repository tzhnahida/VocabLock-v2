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
	TypePronounce   QuestionType = "pronounce"     // recall the pronunciation (type kana/pinyin)
	TypeListening   QuestionType = "listening"     // hear audio, answer
	TypeReadingComp QuestionType = "reading_comp"  // read passage, answer questions
	TypeGrammar     QuestionType = "grammar"
)

// promptTemplates maps language code → question type → prompt prefix.
// The "lang" key is the primary subtag of explanation_lang (e.g. "zh" from "zh-CN", "ko" from "ko").
var promptTemplates = map[string]map[string]string{
	"zh": {
		"choice":    "选择正确释义: ",
		"fill":      "填空: ",
		"spelling":  "拼写单词: ",
		"pronounce": "输入读音: ",
	},
	"en": {
		"choice":    "Select the correct meaning for: ",
		"fill":      "Fill in the blank: ",
		"spelling":  "Spell the word for: ",
		"pronounce": "Enter the pronunciation of: ",
	},
	"ko": {
		"choice":    "올바른 뜻을 고르세요: ",
		"fill":      "빈칸 채우기: ",
		"spelling":  "단어 철자 쓰기: ",
		"pronounce": "발음 입력: ",
	},
	"ja": {
		"choice":    "正しい意味を選んでください: ",
		"fill":      "空欄を埋めてください: ",
		"spelling":  "単語の綴りを入力: ",
		"pronounce": "読み方を入力: ",
	},
}

// promptPrefix returns the localized prompt prefix for a question type and explanation language.
// Falls back to "en" if the language is not in the map.
func promptPrefix(qType, explLang string) string {
	lang := explLang
	if idx := strings.Index(explLang, "-"); idx > 0 {
		lang = explLang[:idx]
	}
	tmpl, ok := promptTemplates[lang]
	if !ok {
		tmpl = promptTemplates["en"]
	}
	if s, ok := tmpl[qType]; ok {
		return s
	}
	return ""
}

// Question represents a single quiz question.
type Question struct {
	ID          string       `json:"id"`
	Type        QuestionType `json:"type"`
	SubjectType string       `json:"subject_type"` // "word" | "grammar"
	SubjectID   int64        `json:"subject_id"`
	Prompt      string       `json:"prompt"`
	Options     []string     `json:"options,omitempty"`
	Answer      string       `json:"-"` // not sent to client
}

// GenerateChoice creates a multiple-choice question given a word and distractors.
// explLang is the explanation_lang from the active language config (e.g. "zh-CN", "ko", "en").
func GenerateChoice(word *WordInfo, distractors []*WordInfo, explLang string) *Question {
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
		ID:          genID("word", "choice", word.ID),
		Type:        TypeChoice,
		SubjectType: "word",
		SubjectID:   word.ID,
		Prompt:      promptPrefix("choice", explLang) + word.Word,
		Options:     options,
		Answer:      word.Meaning,
	}
}

// GenerateFill creates a fill-in-the-blank question.
func GenerateFill(word *WordInfo, explLang string) *Question {
	blank := maskWord(word.Word)
	return &Question{
		ID:          genID("word", "fill", word.ID),
		Type:        TypeFill,
		SubjectType: "word",
		SubjectID:   word.ID,
		Prompt:      promptPrefix("fill", explLang) + blank + " (" + word.Meaning + ")",
		Answer:      word.Word,
	}
}

// GenerateSpelling creates a spelling dictation question.
func GenerateSpelling(word *WordInfo, explLang string) *Question {
	return &Question{
		ID:          genID("word", "spelling", word.ID),
		Type:        TypeSpelling,
		SubjectType: "word",
		SubjectID:   word.ID,
		Prompt:      promptPrefix("spelling", explLang) + word.Meaning,
		Answer:      word.Word,
	}
}

// GeneratePronounce creates a pronunciation recall question.
func GeneratePronounce(word *WordInfo, explLang string) *Question {
	return &Question{
		ID:          genID("word", "pronounce", word.ID),
		Type:        TypePronounce,
		SubjectType: "word",
		SubjectID:   word.ID,
		Prompt:      promptPrefix("pronounce", explLang) + word.Word,
		Answer:      word.Reading,
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

func genID(subjectType string, qtype string, subjectID int64) string {
	// wc42 = word-choice-42, gf7 = grammar-fill-7
	return string(subjectType[0]) + string(qtype[0]) + itoa(subjectID)
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

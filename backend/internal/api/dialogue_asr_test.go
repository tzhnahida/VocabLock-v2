package api

import (
	"context"
	"encoding/base64"
	"encoding/binary"
	"encoding/json"
	"errors"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/tzhnahida/VocabLock/internal/asr"
	"github.com/tzhnahida/VocabLock/internal/db"
	"github.com/tzhnahida/VocabLock/internal/engine"
)

type fakeASR struct {
	text      string
	err       error
	calls     int
	remaining time.Duration
}

func (f *fakeASR) Name() string { return "fake" }

func (f *fakeASR) Transcribe(ctx context.Context, _ string) (*asr.Result, error) {
	f.calls++
	if deadline, ok := ctx.Deadline(); ok {
		f.remaining = time.Until(deadline)
	}
	if f.err != nil {
		return nil, f.err
	}
	return &asr.Result{Text: f.text, Language: "en"}, nil
}

func newDialogueServer(t *testing.T) (*Server, int64) {
	t.Helper()
	s := newTestServer(t)
	s.Config.App.AI.APIKey = "test-key"
	s.WireAI()
	id, err := s.DB.InsertWord(&db.Word{
		Word: "ubiquitous", Reading: "juːˈbɪkwɪtəs", Meaning: "无处不在的",
		POS: "adjective", Language: "en", Source: "seed", Status: "active",
	})
	if err != nil {
		t.Fatalf("insert word: %v", err)
	}
	return s, id
}

// minimalWAV is a valid 44-byte RIFF/WAVE header with an empty data chunk.
// The dialogue handler rejects anything that is not a WAV container, so tests
// must pass a header even though fakeASR never decodes the samples.
func minimalWAV() string {
	data := make([]byte, 44)
	copy(data[0:4], "RIFF")
	binary.LittleEndian.PutUint32(data[4:8], 36)
	copy(data[8:12], "WAVE")
	copy(data[12:16], "fmt ")
	binary.LittleEndian.PutUint32(data[16:20], 16)
	binary.LittleEndian.PutUint16(data[20:22], 1) // PCM
	binary.LittleEndian.PutUint16(data[22:24], 1) // mono
	binary.LittleEndian.PutUint32(data[24:28], 16000)
	binary.LittleEndian.PutUint32(data[28:32], 32000)
	binary.LittleEndian.PutUint16(data[32:34], 2)
	binary.LittleEndian.PutUint16(data[34:36], 16)
	copy(data[36:40], "data")
	binary.LittleEndian.PutUint32(data[40:44], 0)
	return base64.StdEncoding.EncodeToString(data)
}

func cacheDialogueQuestion(s *Server, id int64, qid string) {
	s.cacheQuestion(&engine.Question{
		ID:          qid,
		Type:        engine.TypeDialogueSpeak,
		SubjectType: "word",
		SubjectID:   id,
		Prompt:      "What is ubiquitous in modern life?",
		Answer:      "Smartphones have become ubiquitous in modern life.",
	})
}

func submitDialogue(t *testing.T, s *Server, id int64, qid, audio string) map[string]interface{} {
	t.Helper()
	rec := httptest.NewRecorder()
	req := httptest.NewRequest("POST", "/api/v1/quiz/submit", nil)
	s.handleDialogueSubmit(rec, req, string(engine.TypeDialogueSpeak), "word", id, qid, "", audio, false)
	if rec.Code != 200 {
		t.Fatalf("status = %d, body = %s", rec.Code, rec.Body.String())
	}
	var out map[string]interface{}
	if err := json.Unmarshal(rec.Body.Bytes(), &out); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	return out
}

func TestResolveASRLanguage(t *testing.T) {
	cases := []struct{ configured, active, want string }{
		{"auto", "ja", "ja"},
		{"", "zh", "zh"},
		{"en", "ja", "en"},
		{"AUTO", "zh-CN", "zh"},
		{"auto", "", "auto"},
	}
	for _, c := range cases {
		if got := resolveASRLanguage(c.configured, c.active); got != c.want {
			t.Errorf("resolveASRLanguage(%q, %q) = %q, want %q", c.configured, c.active, got, c.want)
		}
	}
}

func TestDialogueASRGets90SecondDeadline(t *testing.T) {
	s, id := newDialogueServer(t)
	cacheDialogueQuestion(s, id, "deadline")
	fake := &fakeASR{err: errors.New("boom")}
	s.ASRProvider = fake

	out := submitDialogue(t, s, id, "deadline", minimalWAV())
	if fake.calls != 1 {
		t.Fatalf("ASR calls = %d, want 1", fake.calls)
	}
	if fake.remaining < 89*time.Second || fake.remaining > 90*time.Second {
		t.Fatalf("ASR deadline remaining = %v, want ~90s", fake.remaining)
	}
	if out["source"] != "asr_error" {
		t.Fatalf("source = %v, want asr_error", out["source"])
	}
}

func TestDialogueASRFailureBranchesDoNotWrite(t *testing.T) {
	validAudio := minimalWAV()
	notWAV := base64.StdEncoding.EncodeToString([]byte("not a wav"))
	cases := []struct {
		name    string
		audio   string
		provide bool
		fake    *fakeASR
		want    string
	}{
		{"no_asr", validAudio, false, nil, "no_asr"},
		{"bad_base64", "%%%", true, &fakeASR{text: "hello"}, "bad_audio"},
		{"bad_wav", notWAV, true, &fakeASR{text: "hello"}, "bad_audio"},
		{"asr_error", validAudio, true, &fakeASR{err: errors.New("whisper exploded")}, "asr_error"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			s, id := newDialogueServer(t)
			cacheDialogueQuestion(s, id, "failure")
			if c.provide {
				s.ASRProvider = c.fake
			}
			out := submitDialogue(t, s, id, "failure", c.audio)
			if out["source"] != c.want {
				t.Fatalf("source = %v, want %s", out["source"], c.want)
			}
			logs, err := s.DB.GetReviewLogs("word", id, 10)
			if err != nil {
				t.Fatalf("review logs: %v", err)
			}
			if len(logs) != 0 {
				t.Fatalf("failure branch wrote %d review logs, want 0", len(logs))
			}
		})
	}
}

func TestDialogueASREmptyTranscriptWritesWrongAttempt(t *testing.T) {
	s, id := newDialogueServer(t)
	cacheDialogueQuestion(s, id, "empty")
	s.ASRProvider = &fakeASR{text: "   "}
	out := submitDialogue(t, s, id, "empty", minimalWAV())
	if out["source"] != "asr_empty" {
		t.Fatalf("source = %v, want asr_empty", out["source"])
	}
	if out["correct"] != false {
		t.Fatalf("correct = %v, want false", out["correct"])
	}
	logs, err := s.DB.GetReviewLogs("word", id, 10)
	if err != nil {
		t.Fatalf("review logs: %v", err)
	}
	if len(logs) != 1 || logs[0].Source != "asr_empty" {
		t.Fatalf("logs = %+v, want one asr_empty row", logs)
	}
}

func TestDialogueCacheMissSkipsASR(t *testing.T) {
	s, id := newDialogueServer(t)
	fake := &fakeASR{text: "hello"}
	s.ASRProvider = fake
	out := submitDialogue(t, s, id, "missing", base64.StdEncoding.EncodeToString([]byte("RIFF")))
	if out["source"] != "cache_miss" {
		t.Fatalf("source = %v, want cache_miss", out["source"])
	}
	if fake.calls != 0 {
		t.Fatalf("cache miss called ASR %d times", fake.calls)
	}
}

package api

import (
	"encoding/json"
	"testing"
)

// FuzzParseExpandWords feeds arbitrary JSON into the expansion parser: it must
// never panic, regardless of shape or field types.
func FuzzParseExpandWords(f *testing.F) {
	f.Add(`[{"word":"水","reading":"みず","meaning":"water"}]`)
	f.Add(`[{}]`)
	f.Add(`[]`)
	f.Fuzz(func(t *testing.T, raw string) {
		if len(raw) > 10000 {
			t.Skip()
		}
		var msgs []json.RawMessage
		if err := json.Unmarshal([]byte(raw), &msgs); err != nil {
			return
		}
		_ = parseExpandWords(msgs)
	})
}

package judge

import "testing"

// FuzzJudge checks that no input combination panics the exact/regex tiers.
// The AI tier is nil here: it is covered by the fake OpenAI server in api tests.
func FuzzJudge(f *testing.F) {
	f.Add("water", "water")
	f.Add("Water!", "water")
	f.Add("", "x")
	f.Add("とても長い答え", "x")
	f.Fuzz(func(t *testing.T, user, expected string) {
		if len(user) > 4096 || len(expected) > 4096 {
			t.Skip()
		}
		got := Judge(user, []string{expected}, Normal, nil)
		if got == nil {
			t.Fatal("Judge returned nil")
		}
	})
}

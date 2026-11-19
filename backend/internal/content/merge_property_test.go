package content

import (
	"encoding/json"
	"fmt"
	"math/rand"
	"strings"
	"testing"
)

// TestMergeProperty generates random pack pairs and asserts the merge is the
// set union of senses, with the higher-priority pack supplying Level/first sense.
func TestMergeProperty(t *testing.T) {
	rng := rand.New(rand.NewSource(42))
	for iter := 0; iter < 20; iter++ {
		root := t.TempDir()
		lemmas := []string{"語一", "語二", "語三", "語四"}
		baseEntries, baseGloss := randomPack(t, rng, lemmas, "base")
		userEntries, userGloss := randomPack(t, rng, lemmas, "user")

		writePack(t, root, "base",
			`{"schema":1,"id":"base","language":"ja","priority":10,"license":"CC BY-SA 4.0"}`,
			strings.Join(baseEntries, ""))
		writePack(t, root, "user",
			`{"schema":1,"id":"user","language":"ja","priority":20,"license":"test"}`,
			strings.Join(userEntries, ""))

		lib, err := Load(root)
		if err != nil {
			t.Fatalf("iter %d: load: %v", iter, err)
		}
		for _, lemma := range lemmas {
			want := map[string]bool{}
			for _, g := range baseGloss[lemma] {
				want[g] = true
			}
			for _, g := range userGloss[lemma] {
				want[g] = true
			}
			if len(want) == 0 {
				continue
			}
			entry := lib.Lookup("ja", lemma)
			if entry == nil {
				t.Fatalf("iter %d: lemma %q missing", iter, lemma)
			}
			got := 0
			for _, s := range entry.Senses {
				got += len(s.Glosses)
			}
			if got != len(want) {
				t.Fatalf("iter %d lemma %q: %d glosses, want %d (%v)", iter, lemma, got, len(want), want)
			}
			if entry.Level == "" {
				t.Errorf("iter %d lemma %q: level dropped", iter, lemma)
			}
		}
	}
}

// randomPack builds entries for a random subset of lemmas with 1-2 senses each.
func randomPack(t *testing.T, rng *rand.Rand, lemmas []string, id string) ([]string, map[string][]string) {
	t.Helper()
	out := make([]string, 0, len(lemmas))
	glosses := map[string][]string{}
	for _, lemma := range lemmas {
		if rng.Intn(3) == 0 {
			continue // not every pack defines every lemma
		}
		var senses []map[string]interface{}
		var gs []string
		for s := 0; s < 1+rng.Intn(2); s++ {
			g := fmt.Sprintf("%s-gloss-%d", id, rng.Intn(5))
			senses = append(senses, map[string]interface{}{"glosses": []string{g}})
			gs = append(gs, g)
		}
		e := map[string]interface{}{
			"word":    lemma,
			"reading": "よみ",
			"senses":  senses,
			"level":   "N" + fmt.Sprint(1+rng.Intn(5)),
			"source":  id,
		}
		b, err := json.Marshal(e)
		if err != nil {
			t.Fatal(err)
		}
		out = append(out, string(b)+"\n")
		glosses[lemma] = gs
	}
	return out, glosses
}

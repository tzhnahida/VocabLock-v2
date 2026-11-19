package content

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func writePack(t *testing.T, root, id, manifest, entries string) {
	t.Helper()
	dir := filepath.Join(root, "packs", id)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "manifest.json"), []byte(manifest), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "entries.jsonl"), []byte(entries), 0o644); err != nil {
		t.Fatal(err)
	}
}

// Two packs defining the same lemma must merge: the higher-priority pack
// supplies display fields, both contribute senses, and provenance survives.
func TestLookupMergesPacks(t *testing.T) {
	root := t.TempDir()
	writePack(t, root, "base",
		"{\"schema\":1,\"id\":\"base\",\"language\":\"ja\",\"priority\":10,\"license\":\"CC BY-SA 4.0\"}",
		"{\"word\":\"泳ぐ\",\"reading\":\"およぐ\",\"pos\":[\"v5g\"],\"senses\":[{\"glosses\":[\"to swim\"]}],\"source\":\"jmdict\"}\n")
	writePack(t, root, "user",
		"{\"schema\":1,\"id\":\"user\",\"language\":\"ja\",\"priority\":20,\"license\":\"sample\"}",
		"{\"word\":\"泳ぐ\",\"reading\":\"およぐ\",\"senses\":[{\"glosses\":[\"游泳\"]}],\"source\":\"user\"}\n"+
			"{\"word\":\"学校\",\"reading\":\"がっこう\",\"senses\":[{\"glosses\":[\"学校\"]}],\"source\":\"user\"}\n")

	lib, err := Load(root)
	if err != nil {
		t.Fatalf("load: %v", err)
	}
	got := lib.Lookup("ja", "泳ぐ")
	if got == nil {
		t.Fatal("merged entry missing")
	}
	if got.Reading != "およぐ" {
		t.Errorf("reading = %q", got.Reading)
	}
	if len(got.Senses) != 2 {
		t.Fatalf("senses = %d, want 2 (one per pack)", len(got.Senses))
	}
	sources := got.Senses[0].Source + "," + got.Senses[1].Source
	if !strings.Contains(sources, "jmdict") || !strings.Contains(sources, "user") {
		t.Errorf("provenance lost: %s", sources)
	}
	if got.Senses[0].Glosses[0] != "游泳" {
		t.Errorf("display sense = %v, want the higher-priority pack first", got.Senses[0].Glosses)
	}
	if lib.Lookup("ja", "学校") == nil {
		t.Error("学校 from the user pack not found")
	}
	if lib.Lookup("ja", "存在しない") != nil {
		t.Error("unknown word should return nil")
	}
}

func TestLoadMissingDirIsEmpty(t *testing.T) {
	lib, err := Load(filepath.Join(t.TempDir(), "nope"))
	if err != nil {
		t.Fatalf("missing dir should not error: %v", err)
	}
	if lib.Lookup("ja", "泳ぐ") != nil {
		t.Error("empty library returned an entry")
	}
}

// A broken pack must be reported, not silently dropped: otherwise a typo
// looks exactly like "no packs installed".
func TestLoadReportsBrokenPacks(t *testing.T) {
	root := t.TempDir()
	writePack(t, root, "good",
		"{\"schema\":1,\"id\":\"good\",\"language\":\"ja\"}",
		"{\"word\":\"水\",\"reading\":\"みず\",\"senses\":[{\"glosses\":[\"water\"]}]}\n")
	writePack(t, root, "bad-schema",
		"{\"schema\":2,\"id\":\"bad-schema\",\"language\":\"ja\"}",
		"{\"word\":\"火\"}\n")
	writePack(t, root, "no-language",
		"{\"schema\":1,\"id\":\"no-language\"}",
		"{\"word\":\"山\"}\n")
	writePack(t, root, "empty",
		"{\"schema\":1,\"id\":\"empty\",\"language\":\"ja\"}",
		"")

	lib, err := Load(root)
	if err != nil {
		t.Fatalf("load: %v", err)
	}
	if len(lib.Packs()) != 1 || lib.Packs()[0].ID != "good" {
		t.Errorf("packs = %+v, want just good", lib.Packs())
	}
	if len(lib.Errors) != 3 {
		t.Fatalf("errors = %d, want 3: %v", len(lib.Errors), lib.Errors)
	}
}

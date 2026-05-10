package dict

import "testing"

func TestBuildDictArgs(t *testing.T) {
	args := buildDictArgs([]string{"--word", "{word}"}, "hello")
	if len(args) != 2 {
		t.Fatalf("len = %d, want 2", len(args))
	}
	if args[0] != "--word" {
		t.Errorf("args[0] = %q, want --word", args[0])
	}
	if args[1] != "hello" {
		t.Errorf("args[1] = %q, want hello", args[1])
	}
}

func TestBuildDictArgsMultiplePlaceholders(t *testing.T) {
	args := buildDictArgs([]string{"-d", "{word}", "--query", "{word}"}, "test")
	if len(args) != 4 {
		t.Fatalf("len = %d, want 4", len(args))
	}
	if args[1] != "test" || args[3] != "test" {
		t.Errorf("expected both placeholders replaced: %v", args)
	}
}

func TestBuildDictArgsNoPlaceholders(t *testing.T) {
	args := buildDictArgs([]string{"--version"}, "hello")
	if len(args) != 1 || args[0] != "--version" {
		t.Errorf("unexpected args: %v", args)
	}
}

func TestBuildDictArgsEmpty(t *testing.T) {
	args := buildDictArgs([]string{}, "hello")
	if len(args) != 0 {
		t.Errorf("expected empty args, got %d", len(args))
	}
}

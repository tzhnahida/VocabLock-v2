package main

import (
	"os"
	"path/filepath"
	"testing"
)

func touch(t *testing.T, path string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatalf("mkdir %s: %v", filepath.Dir(path), err)
	}
	if err := os.WriteFile(path, []byte("x"), 0o644); err != nil {
		t.Fatalf("write %s: %v", path, err)
	}
}

// A packaged build wins over a development checkout sitting next to it.
func TestResolveElectronPrefersPackagedBuild(t *testing.T) {
	dir := t.TempDir()
	touch(t, filepath.Join(dir, "vocablock-desktop.exe"))
	touch(t, filepath.Join(dir, "electron", "node_modules", "electron", "dist", "electron.exe"))
	touch(t, filepath.Join(dir, "electron", "package.json"))

	target, ok := resolveElectron(dir)
	if !ok {
		t.Fatal("expected a target")
	}
	if !target.Packed {
		t.Errorf("Packed = false, want the packaged exe")
	}
	if filepath.Base(target.Bin) != "vocablock-desktop.exe" {
		t.Errorf("Bin = %s", target.Bin)
	}
}

// During development the shell lives in ../electron relative to the service.
func TestResolveElectronFindsCheckout(t *testing.T) {
	root := t.TempDir()
	exeDir := filepath.Join(root, "backend")
	if err := os.MkdirAll(exeDir, 0o755); err != nil {
		t.Fatal(err)
	}
	app := filepath.Join(root, "electron")
	touch(t, filepath.Join(app, "node_modules", "electron", "dist", "electron.exe"))
	touch(t, filepath.Join(app, "package.json"))

	target, ok := resolveElectron(exeDir)
	if !ok {
		t.Fatal("expected the electron/ checkout to be found")
	}
	if target.AppDir != app {
		t.Errorf("AppDir = %s, want %s", target.AppDir, app)
	}
	if target.Packed {
		t.Error("Packed = true for a dev checkout")
	}
}

// A directory holding an electron binary but no package.json is not a shell.
func TestResolveElectronRejectsIncompleteCheckout(t *testing.T) {
	root := t.TempDir()
	exeDir := filepath.Join(root, "backend")
	if err := os.MkdirAll(exeDir, 0o755); err != nil {
		t.Fatal(err)
	}
	touch(t, filepath.Join(root, "electron", "node_modules", "electron", "dist", "electron.exe"))

	if _, ok := resolveElectron(exeDir); ok {
		t.Error("expected no target without package.json")
	}
}

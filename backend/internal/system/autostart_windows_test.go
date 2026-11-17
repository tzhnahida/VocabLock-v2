//go:build windows

package system

import (
	"os/exec"
	"strings"
	"testing"
)

// Registry helpers are exercised under a throwaway value name so the real
// "VocabLock" entry is never touched by tests.
func runKeyValue(t *testing.T, name string) (string, bool) {
	t.Helper()
	out, err := exec.Command("reg", "query", "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run", "/v", name).Output()
	if err != nil {
		return "", false
	}
	for _, line := range strings.Split(string(out), "\n") {
		if strings.Contains(line, "REG_SZ") {
			fields := strings.Fields(line)
			if len(fields) >= 3 {
				return strings.Join(fields[2:], " "), true
			}
		}
	}
	return "", false
}

func TestRunValueWriteAndDelete(t *testing.T) {
	const name = "VocabLockTestOnly"
	t.Cleanup(func() { _ = deleteRunValue(name) })
	_ = deleteRunValue(name)

	command := "\"C:/Program Files/VocabLock/vocablock.exe\""
	if err := setRunValue(name, command); err != nil {
		t.Fatalf("setRunValue: %v", err)
	}
	got, ok := runKeyValue(t, name)
	if !ok {
		t.Fatal("value not written")
	}
	if !strings.Contains(got, "Program Files") {
		t.Errorf("value = %q, want the quoted path", got)
	}
	if !strings.HasPrefix(strings.TrimSpace(got), "\"") {
		t.Errorf("value is not quoted: %q", got)
	}

	if err := deleteRunValue(name); err != nil {
		t.Fatalf("deleteRunValue: %v", err)
	}
	if _, ok := runKeyValue(t, name); ok {
		t.Error("value still present after delete")
	}
	if err := deleteRunValue(name); err != nil {
		t.Errorf("second delete should be a no-op: %v", err)
	}
}

//go:build !windows

package proc

import "os/exec"

// HideWindow is a no-op on platforms without console windows.
func HideWindow(cmd *exec.Cmd) {}

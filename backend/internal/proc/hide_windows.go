//go:build windows

package proc

import (
	"os/exec"
	"syscall"
)

// HideWindow starts the child without a console window. Without it every TTS
// and dictionary lookup flashes a black console on Windows, and a pre-warm
// burst can exhaust process/desktop resources.
func HideWindow(cmd *exec.Cmd) {
	cmd.SysProcAttr = &syscall.SysProcAttr{
		HideWindow:    true,
		CreationFlags: 0x08000000, // CREATE_NO_WINDOW
	}
}

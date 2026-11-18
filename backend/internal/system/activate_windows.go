//go:build windows

package system

import (
	"syscall"
	"unsafe"

	"golang.org/x/sys/windows"
)

var (
	procFindWindow = windows.NewLazySystemDLL("user32.dll").NewProc("FindWindowW")
)

// ActivateMainWindow brings the already running shell window to the front.
// Both the main window and the lock kiosk are titled "VocabLock"; either one
// is a fine target, and the lock kiosk is what the user would otherwise miss.
func ActivateMainWindow() {
	title, err := syscall.UTF16PtrFromString("VocabLock")
	if err != nil {
		return
	}
	hwnd, _, _ := procFindWindow.Call(0, uintptr(unsafe.Pointer(title)))
	if hwnd == 0 {
		return
	}
	procShowWindow.Call(hwnd, 9) // SW_RESTORE
	procSetForeground.Call(hwnd)
}

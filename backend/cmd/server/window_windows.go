//go:build windows

package main

import "syscall"

// restoreWindow brings the shell window to the foreground (tray "show").
func restoreWindow(hwnd uintptr) {
	user32 := syscall.NewLazyDLL("user32.dll")
	user32.NewProc("SetForegroundWindow").Call(hwnd)
	user32.NewProc("ShowWindow").Call(hwnd, 9) // SW_RESTORE
}

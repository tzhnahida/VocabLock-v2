//go:build !windows

package main

// restoreWindow is a no-op where there is no Win32 window to restore.
func restoreWindow(uintptr) {}

//go:build !windows

package system

// ActivateMainWindow is a no-op outside Windows; the single-instance lock is
// only enforced on Windows today.
func ActivateMainWindow() {}

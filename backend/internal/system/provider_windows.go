//go:build windows

package system

import "fmt"

type windowsProvider struct{}

func newProvider() SystemProvider {
	return &windowsProvider{}
}

func (p *windowsProvider) EnterLockMode(hwnd uintptr) error {
	// TODO: Win32 TOPMOST fullscreen window
	return fmt.Errorf("not implemented")
}

func (p *windowsProvider) ExitLockMode() error {
	// TODO: Destroy lock window
	return fmt.Errorf("not implemented")
}

func (p *windowsProvider) OnWindowClosing() bool {
	return true
}

func (p *windowsProvider) StartTray(onShow, onQuit func()) error {
	// TODO: System tray icon (Shell_NotifyIconW)
	return fmt.Errorf("not implemented")
}

func (p *windowsProvider) StopTray() error {
	return fmt.Errorf("not implemented")
}

func (p *windowsProvider) AcquireLock() (bool, error) {
	// TODO: Single-instance mutex
	return true, nil
}

func (p *windowsProvider) SetAutoStart(enabled bool) error {
	return fmt.Errorf("not implemented")
}

func (p *windowsProvider) FindFlutterWindow() (uintptr, error) {
	return 0, fmt.Errorf("not implemented")
}

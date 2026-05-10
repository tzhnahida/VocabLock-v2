//go:build linux

package system

import "fmt"

type linuxProvider struct{}

func newProvider() SystemProvider {
	return &linuxProvider{}
}

func (p *linuxProvider) EnterLockMode(hwnd uintptr) error {
	return fmt.Errorf("not implemented on linux")
}

func (p *linuxProvider) ExitLockMode() error {
	return fmt.Errorf("not implemented on linux")
}

func (p *linuxProvider) OnWindowClosing() bool { return true }

func (p *linuxProvider) StartTray(onShow, onQuit func()) error {
	return fmt.Errorf("not implemented on linux")
}

func (p *linuxProvider) StopTray() error {
	return fmt.Errorf("not implemented on linux")
}

func (p *linuxProvider) AcquireLock() (bool, error) {
	return true, nil
}

func (p *linuxProvider) SetAutoStart(enabled bool) error {
	return fmt.Errorf("not implemented on linux")
}

func (p *linuxProvider) FindFlutterWindow() (uintptr, error) {
	return 0, fmt.Errorf("not implemented on linux")
}

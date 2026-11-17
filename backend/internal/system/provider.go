package system

type SystemProvider interface {
	EnterLockMode(hwnd uintptr) error
	ExitLockMode() error
	OnWindowClosing() bool
	StartTray(onShow, onQuit func()) error
	StopTray() error
	AcquireLock() (bool, error)
	SetAutoStart(enabled bool) error
	FindFlutterWindow() (uintptr, error)
	// Runtime configuration
	SetServerInfo(healthURL string, flutterPID int)
	// Flutter window control
	FullscreenFlutterWindow() error
	RestoreFlutterWindow() error
	// Keyboard shield: installs the low-level hooks that swallow Alt+Tab, Win
	// and friends without creating a native lock window. Used by the Electron
	// shell, which draws the lock UI itself.
	EnterLockShield() error
	ExitLockShield() error
	// SetLockEscapeHandler is called when the user presses the emergency escape
	// hotkey while a lock or shield is active.
	SetLockEscapeHandler(fn func())
	// Passive quiz
	SetPassiveInterval(minutes int)
	StartPassiveQuiz()
	StopPassiveQuiz()
}

// Default returns the platform-specific SystemProvider.
var Default SystemProvider = newProvider()

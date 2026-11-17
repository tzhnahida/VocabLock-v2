//go:build windows

package system

import (
	"fmt"
	"net/http"
	"os"
	"runtime"
	"sync"
	"syscall"
	"time"
	"unsafe"

	"github.com/tzhnahida/VocabLock/internal/log"
	"golang.org/x/sys/windows"
)

var (
	user32   = windows.NewLazySystemDLL("user32.dll")
	kernel32 = windows.NewLazySystemDLL("kernel32.dll")
	shell32  = windows.NewLazySystemDLL("shell32.dll")
	advapi32 = windows.NewLazySystemDLL("advapi32.dll")

	// Window
	procRegisterClassEx  = user32.NewProc("RegisterClassExW")
	procCreateWindowEx   = user32.NewProc("CreateWindowExW")
	procDefWindowProc    = user32.NewProc("DefWindowProcW")
	procGetSystemMetrics = user32.NewProc("GetSystemMetrics")
	procSetWindowPos     = user32.NewProc("SetWindowPos")
	procDestroyWindow    = user32.NewProc("DestroyWindow")
	procGetMessage       = user32.NewProc("GetMessageW")
	procTranslateMsg     = user32.NewProc("TranslateMessage")
	procDispatchMsg      = user32.NewProc("DispatchMessageW")
	procPostQuitMessage  = user32.NewProc("PostQuitMessage")
	procGetWindowLong    = user32.NewProc("GetWindowLongPtrW")
	procSetWindowLong    = user32.NewProc("SetWindowLongPtrW")
	procShowWindow       = user32.NewProc("ShowWindow")
	procInvalidateRect   = user32.NewProc("InvalidateRect")
	procGetDC            = user32.NewProc("GetDC")
	procReleaseDC        = user32.NewProc("ReleaseDC")
	procFillRect         = user32.NewProc("FillRect")
	procBeginPaint       = user32.NewProc("BeginPaint")
	procEndPaint         = user32.NewProc("EndPaint")
	procDrawText         = user32.NewProc("DrawTextW")
	procCreateSolidBrush = user32.NewProc("CreateSolidBrush")
	procDeleteObject     = user32.NewProc("DeleteObject")
	procSetBkMode        = user32.NewProc("SetBkMode")
	procSetTextColor     = user32.NewProc("SetTextColor")
	procCreateFont       = user32.NewProc("CreateFontW")
	procSelectObject     = user32.NewProc("SelectObject")
	procGetClientRect    = user32.NewProc("GetClientRect")
	procLoadIcon         = user32.NewProc("LoadIconW")
	procEnumWindows      = user32.NewProc("EnumWindows")
	procGetWindowThread  = user32.NewProc("GetWindowThreadProcessId")
	procSetTimer         = user32.NewProc("SetTimer")
	procKillTimer        = user32.NewProc("KillTimer")
	procSetForeground    = user32.NewProc("SetForegroundWindow")
	procGetCursorPos     = user32.NewProc("GetCursorPos")
	procTrackPopupMenu   = user32.NewProc("TrackPopupMenu")
	procCreatePopupMenu  = user32.NewProc("CreatePopupMenu")
	procAppendMenu       = user32.NewProc("AppendMenuW")
	procDestroyMenu      = user32.NewProc("DestroyMenu")

	// Hotkey / hooks
	procRegisterHotKey    = user32.NewProc("RegisterHotKey")
	procUnregisterHotKey  = user32.NewProc("UnregisterHotKey")
	procSetWindowsHookEx  = user32.NewProc("SetWindowsHookExW")
	procUnhookWindowsHook = user32.NewProc("UnhookWindowsHookEx")
	procCallNextHookEx    = user32.NewProc("CallNextHookEx")
	procGetAsyncKeyState  = user32.NewProc("GetAsyncKeyState")
	procPostMessage       = user32.NewProc("PostMessageW")

	// Tray
	procShellNotifyIcon = shell32.NewProc("Shell_NotifyIconW")

	// Mutex
	procCreateMutex  = kernel32.NewProc("CreateMutexW")
	procCloseHandle  = kernel32.NewProc("CloseHandle")
	procGetLastError = kernel32.NewProc("GetLastError")

	// Process
	procOpenProcess      = kernel32.NewProc("OpenProcess")
	procGetExitCode      = kernel32.NewProc("GetExitCodeProcess")
	procTerminateProcess = kernel32.NewProc("TerminateProcess")

	// Registry
	procRegOpenKeyEx   = advapi32.NewProc("RegOpenKeyExW")
	procRegSetValueEx  = advapi32.NewProc("RegSetValueExW")
	procRegDeleteValue = advapi32.NewProc("RegDeleteValueW")
	procRegCloseKey    = advapi32.NewProc("RegCloseKey")
)

const (
	// Window styles
	WS_VISIBLE     = 0x10000000
	WS_CAPTION     = 0x00C00000
	WS_SYSMENU     = 0x00080000
	WS_THICKFRAME  = 0x00040000
	WS_MINIMIZEBOX = 0x00020000
	WS_MAXIMIZEBOX = 0x00010000
	WS_BORDER      = 0x00800000
	WS_DLGFRAME    = 0x00400000

	// Extended window styles
	WS_EX_TOPMOST    = 0x00000008
	WS_EX_TOOLWINDOW = 0x00000080
	WS_EX_APPWINDOW  = 0x00040000

	// Show window
	SW_MAXIMIZE = 3
	SW_SHOW     = 5

	// Class styles
	CS_HREDRAW = 0x0002
	CS_VREDRAW = 0x0001

	// Messages
	WM_DESTROY       = 0x0002
	WM_CLOSE         = 0x0010
	WM_PAINT         = 0x000F
	WM_TIMER         = 0x0113
	WM_HOTKEY        = 0x0312
	WM_SYSCOMMAND    = 0x0112
	WM_APP           = 0x8000
	WM_TRAYICON      = WM_APP + 1
	WM_APP_LOCK_EXIT = WM_APP + 10
	WM_COMMAND       = 0x0111
	WM_NCHITTEST     = 0x0084
	WM_KEYDOWN       = 0x0100
	WM_SYSKEYDOWN    = 0x0104

	SC_CLOSE = 0xF060

	// System metrics
	SM_CXSCREEN = 0
	SM_CYSCREEN = 1

	// Tray
	NIM_ADD         = 0x00000000
	NIM_DELETE      = 0x00000002
	NIF_MESSAGE     = 0x00000001
	NIF_ICON        = 0x00000002
	NIF_TIP         = 0x00000004
	IDI_APPLICATION = 32512

	// Mutex
	ERROR_ALREADY_EXISTS = 183

	// Process
	PROCESS_QUERY_INFORMATION = 0x0400
	PROCESS_TERMINATE         = 0x0001
	STILL_ACTIVE              = 259

	// Hotkey / low-level hooks
	MOD_CONTROL    = 0x0002
	MOD_SHIFT      = 0x0004
	MOD_NOREPEAT   = 0x4000
	VK_Q           = 0x51
	VK_CONTROL     = 0x11
	VK_SHIFT       = 0x10
	WH_KEYBOARD_LL = 13
	WH_MOUSE_LL    = 14

	// Colors
	COLOR_BTNFACE = 15

	// DrawText
	DT_CENTER    = 0x00000001
	DT_VCENTER   = 0x00000004
	DT_WORDBREAK = 0x00000010

	// Window long (int32, cast through uintptr)
	gwlStyleConst = ^uintptr(15) // -16 as uintptr
	// Hit test
	htTransparentConst = ^uintptr(0) // -1 as uintptr

	// Track popup
	TPM_RETURNCMD   = 0x0100
	TPM_RIGHTBUTTON = 0x0002

	// Timer
	TIMER_HEALTH    = 1
	TIMER_COUNTDOWN = 2
	TIMER_PASSIVE   = 3

	// Tray menu
	IDM_SHOW = 1
	IDM_QUIT = 2

	// Registry
	HKEY_CURRENT_USER = 0x80000001
	KEY_SET_VALUE     = 0x0002

	// Font
	FW_NORMAL         = 400
	CLEARTYPE_QUALITY = 5
)

type windowsProvider struct {
	mu            sync.Mutex
	instanceMutex windows.Handle
	lockClassName string
	lockHwnd      windows.HWND
	lockRunning   bool
	// shieldOnly runs the lock loop's keyboard shield without a visible window.
	shieldOnly bool
	lockEscape func()

	trayClassName string
	trayHwnd      windows.HWND
	trayCreated   bool
	trayOnShow    func()
	trayOnQuit    func()

	hotkeyID         int32
	hotkeyRegistered bool

	// Runtime info set after server start
	healthURL     string
	flutterPID    int
	deadCount     int
	lockShowExit  bool
	lockCountdown int

	// Passive quiz
	passiveInterval int // minutes
	passiveRunning  bool

	quitChan    chan struct{}
	msgLoopDone chan struct{}

	keyboardHook     uintptr
	mouseHook        uintptr
	keyboardHookProc uintptr
	mouseHookProc    uintptr
}

func newProvider() SystemProvider {
	return &windowsProvider{
		lockClassName: "VocabLock_LockWindow",
		trayClassName: "VocabLock_TrayWindow",
		hotkeyID:      1,
	}
}

// ——— SystemProvider interface ———

func (p *windowsProvider) AcquireLock() (bool, error) {
	mutexName, _ := windows.UTF16PtrFromString("Global\\VocabLock_SingleInstance")
	h, _, err := procCreateMutex.Call(0, 0, uintptr(unsafe.Pointer(mutexName)))
	if h == 0 {
		return false, fmt.Errorf("CreateMutex: %v", err)
	}
	p.instanceMutex = windows.Handle(h)
	le, _, _ := procGetLastError.Call()
	if uint32(le) == ERROR_ALREADY_EXISTS {
		procCloseHandle.Call(uintptr(p.instanceMutex))
		return false, nil
	}
	return true, nil
}

func (p *windowsProvider) EnterLockMode(hwnd uintptr) error {
	p.mu.Lock()
	if p.lockRunning {
		p.mu.Unlock()
		return fmt.Errorf("lock already active")
	}
	oldDone := p.msgLoopDone
	p.mu.Unlock()

	// A previous lock loop may still be unwinding after emergencyEscape.
	if oldDone != nil {
		select {
		case <-oldDone:
		case <-time.After(2 * time.Second):
			log.Warn("system", "previous lock loop did not exit; starting a new one")
		}
	}

	p.mu.Lock()
	if p.lockRunning {
		p.mu.Unlock()
		return fmt.Errorf("lock already active")
	}
	done := make(chan struct{})
	p.lockRunning = true
	p.deadCount = 0
	p.lockShowExit = false
	p.lockCountdown = 0
	p.msgLoopDone = done
	p.mu.Unlock()

	go p.lockMessageLoop(done)
	return nil
}

// EnterLockShield installs the same low-level hooks as the lock window but
// without covering the screen: the Electron shell owns the lock UI, this only
// makes Alt+Tab / Win / Alt+F4 unreachable.
func (p *windowsProvider) EnterLockShield() error {
	p.mu.Lock()
	if p.lockRunning {
		p.mu.Unlock()
		return fmt.Errorf("lock already active")
	}
	p.shieldOnly = true
	p.mu.Unlock()
	if err := p.EnterLockMode(0); err != nil {
		p.mu.Lock()
		p.shieldOnly = false
		p.mu.Unlock()
		return err
	}
	return nil
}

// ExitLockShield tears the shield down (and the lock loop with it).
func (p *windowsProvider) ExitLockShield() error {
	return p.ExitLockMode()
}

// SetLockEscapeHandler registers the callback fired by the emergency hotkey.
func (p *windowsProvider) SetLockEscapeHandler(fn func()) {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.lockEscape = fn
}

func (p *windowsProvider) ExitLockMode() error {
	p.mu.Lock()
	if !p.lockRunning && p.msgLoopDone == nil {
		p.mu.Unlock()
		return nil
	}
	p.lockRunning = false
	p.lockShowExit = false
	hwnd := p.lockHwnd
	done := p.msgLoopDone
	p.mu.Unlock()

	// PostQuitMessage is thread-affine: ask the lock loop to quit instead of
	// calling it from this HTTP goroutine.
	if hwnd != 0 {
		procPostMessage.Call(uintptr(hwnd), WM_APP_LOCK_EXIT, 0, 0)
	}
	if done != nil {
		select {
		case <-done:
		case <-time.After(2 * time.Second):
		}
	}
	return nil
}

func (p *windowsProvider) OnWindowClosing() bool {
	return false
}

func (p *windowsProvider) StartTray(onShow, onQuit func()) error {
	p.mu.Lock()
	if p.trayCreated {
		p.mu.Unlock()
		return nil
	}
	p.trayOnShow = onShow
	p.trayOnQuit = onQuit
	p.mu.Unlock()

	go p.trayMessageLoop()
	return nil
}

func (p *windowsProvider) StopTray() error {
	p.mu.Lock()
	defer p.mu.Unlock()
	if !p.trayCreated || p.trayHwnd == 0 {
		return nil
	}
	p.removeTrayIcon(p.trayHwnd)
	procDestroyWindow.Call(uintptr(p.trayHwnd))
	p.trayCreated = false
	return nil
}

// autoStartValueName is the HKCU\...\Run value the app owns.
const autoStartValueName = "VocabLock"

// runKeyPath is the per-user startup key.
const runKeyPath = `Software\Microsoft\Windows\CurrentVersion\Run`

func (p *windowsProvider) SetAutoStart(enabled bool) error {
	if !enabled {
		return deleteRunValue(autoStartValueName)
	}
	exe, err := os.Executable()
	if err != nil {
		return fmt.Errorf("locate executable: %w", err)
	}
	// The Run key is parsed as a command line: an unquoted path with spaces
	// ("C:\Program Files\VocabLock\vocablock.exe") would launch
	// "C:\Program" instead. Quote it.
	return setRunValue(autoStartValueName, "\""+exe+"\"")
}

// setRunValue writes a REG_SZ under HKCU\...\Run.
func setRunValue(name, command string) error {
	hKey, err := openRunKey()
	if err != nil {
		return err
	}
	defer procRegCloseKey.Call(uintptr(hKey))

	valName, _ := windows.UTF16PtrFromString(name)
	valData, _ := windows.UTF16PtrFromString(command)
	ret, _, _ := procRegSetValueEx.Call(
		uintptr(hKey),
		uintptr(unsafe.Pointer(valName)),
		0,
		1, // REG_SZ
		uintptr(unsafe.Pointer(valData)),
		uintptr(len(command)*2+2),
	)
	if ret != 0 {
		return fmt.Errorf("RegSetValueEx: %d", ret)
	}
	return nil
}

// deleteRunValue removes a value; a missing value is not an error.
func deleteRunValue(name string) error {
	hKey, err := openRunKey()
	if err != nil {
		return err
	}
	defer procRegCloseKey.Call(uintptr(hKey))

	valName, _ := windows.UTF16PtrFromString(name)
	ret, _, _ := procRegDeleteValue.Call(uintptr(hKey), uintptr(unsafe.Pointer(valName)))
	// 2 = ERROR_FILE_NOT_FOUND: already absent, which is the desired state.
	if ret != 0 && ret != 2 {
		return fmt.Errorf("RegDeleteValue: %d", ret)
	}
	return nil
}

func openRunKey() (windows.Handle, error) {
	keyName, _ := windows.UTF16PtrFromString(runKeyPath)
	var hKey windows.Handle
	ret, _, _ := procRegOpenKeyEx.Call(
		uintptr(HKEY_CURRENT_USER),
		uintptr(unsafe.Pointer(keyName)),
		0,
		uintptr(KEY_SET_VALUE),
		uintptr(unsafe.Pointer(&hKey)),
	)
	if ret != 0 {
		return 0, fmt.Errorf("RegOpenKeyEx: %d", ret)
	}
	return hKey, nil
}

func (p *windowsProvider) FindFlutterWindow() (uintptr, error) {
	if p.flutterPID == 0 {
		return 0, fmt.Errorf("flutter PID unknown")
	}
	var found windows.HWND
	p.mu.Lock()
	pid := p.flutterPID
	p.mu.Unlock()

	callback := syscall.NewCallback(func(hwnd windows.HWND, lParam uintptr) uintptr {
		var wpid uint32
		procGetWindowThread.Call(uintptr(hwnd), uintptr(unsafe.Pointer(&wpid)))
		if wpid == uint32(pid) {
			style, _, _ := procGetWindowLong.Call(uintptr(hwnd), gwlStyleConst)
			if int32(style)&WS_VISIBLE != 0 {
				found = hwnd
				return 0 // stop
			}
		}
		return 1 // continue
	})
	procEnumWindows.Call(callback, 0)
	if found == 0 {
		return 0, fmt.Errorf("flutter window not found")
	}
	return uintptr(found), nil
}

// SetServerInfo stores runtime info for health monitoring.
func (p *windowsProvider) SetServerInfo(healthURL string, flutterPID int) {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.healthURL = healthURL
	p.flutterPID = flutterPID
}

// SetPassiveInterval configures the passive quiz popup interval (minutes).
func (p *windowsProvider) FullscreenFlutterWindow() error {
	hwnd, err := p.FindFlutterWindow()
	if err != nil {
		return err
	}

	// Strip title bar, borders, system menu — user can't close or resize
	style, _, _ := procGetWindowLong.Call(hwnd, gwlStyleConst)
	style &^= uintptr(WS_CAPTION | WS_SYSMENU | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX | WS_BORDER | WS_DLGFRAME)
	procSetWindowLong.Call(hwnd, gwlStyleConst, style)

	// Make fullscreen
	cx, _, _ := procGetSystemMetrics.Call(uintptr(SM_CXSCREEN))
	cy, _, _ := procGetSystemMetrics.Call(uintptr(SM_CYSCREEN))
	procSetWindowPos.Call(hwnd, 0, 0, 0, cx, cy, 0x0040) // SWP_SHOWWINDOW=0x0040

	// Force repaint
	procShowWindow.Call(hwnd, uintptr(SW_MAXIMIZE))
	return nil
}

func (p *windowsProvider) RestoreFlutterWindow() error {
	hwnd, err := p.FindFlutterWindow()
	if err != nil {
		// Window might not exist yet or already closed — not an error
		return nil
	}

	// Restore normal window with caption, system menu, borders
	style, _, _ := procGetWindowLong.Call(hwnd, gwlStyleConst)
	style |= uintptr(WS_CAPTION | WS_SYSMENU | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX)
	procSetWindowLong.Call(hwnd, gwlStyleConst, style)

	// Restore to a reasonable size (not fullscreen)
	cx, _, _ := procGetSystemMetrics.Call(uintptr(SM_CXSCREEN))
	cy, _, _ := procGetSystemMetrics.Call(uintptr(SM_CYSCREEN))
	ww := cx * 4 / 5
	wh := cy * 4 / 5
	wx := (cx - ww) / 2
	wy := (cy - wh) / 2
	procSetWindowPos.Call(hwnd, 0, wx, wy, ww, wh, 0x0040)

	procShowWindow.Call(hwnd, uintptr(SW_SHOW))
	return nil
}

func (p *windowsProvider) SetPassiveInterval(minutes int) {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.passiveInterval = minutes
}

// ——— Lock screen ———

func (p *windowsProvider) registerGlobalHotkey() error {
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.lockHwnd == 0 {
		return fmt.Errorf("no lock window")
	}
	ret, _, _ := procRegisterHotKey.Call(
		uintptr(p.lockHwnd),
		uintptr(p.hotkeyID),
		uintptr(MOD_CONTROL|MOD_SHIFT|MOD_NOREPEAT),
		uintptr(VK_Q),
	)
	if ret == 0 {
		return fmt.Errorf("RegisterHotKey failed")
	}
	p.hotkeyRegistered = true
	return nil
}

func (p *windowsProvider) installLockHooks() error {
	if p.keyboardHookProc == 0 {
		p.keyboardHookProc = syscall.NewCallback(p.lockKeyboardProc)
	}
	if p.mouseHookProc == 0 {
		p.mouseHookProc = syscall.NewCallback(p.lockMouseProc)
	}
	kb, _, err := procSetWindowsHookEx.Call(uintptr(WH_KEYBOARD_LL), p.keyboardHookProc, 0, 0)
	if kb == 0 {
		return fmt.Errorf("SetWindowsHookEx(WH_KEYBOARD_LL): %v", err)
	}
	p.keyboardHook = kb
	mouse, _, merr := procSetWindowsHookEx.Call(uintptr(WH_MOUSE_LL), p.mouseHookProc, 0, 0)
	if mouse == 0 {
		return fmt.Errorf("SetWindowsHookEx(WH_MOUSE_LL): %v", merr)
	}
	p.mouseHook = mouse
	return nil
}

func (p *windowsProvider) uninstallLockHooks() {
	if p.keyboardHook != 0 {
		procUnhookWindowsHook.Call(p.keyboardHook)
		p.keyboardHook = 0
	}
	if p.mouseHook != 0 {
		procUnhookWindowsHook.Call(p.mouseHook)
		p.mouseHook = 0
	}
}

// uptrToPtr converts a Win32 LPARAM back to a pointer without triggering
// vet's unsafeptr heuristic (the value is a real pointer supplied by Windows).
func uptrToPtr(p uintptr) unsafe.Pointer {
	return *(*unsafe.Pointer)(unsafe.Pointer(&p))
}

// lockKeyboardProc swallows every key while the lock screen is active, so
// Alt+Tab, Win, Alt+F4, Ctrl+Esc and Ctrl+Shift+Esc never reach the shell.
// Ctrl+Shift+Q remains the deliberate emergency exit.
func (p *windowsProvider) lockKeyboardProc(nCode int, wParam, lParam uintptr) uintptr {
	if nCode < 0 {
		ret, _, _ := procCallNextHookEx.Call(0, uintptr(nCode), wParam, lParam)
		return ret
	}
	if wParam == WM_KEYDOWN || wParam == WM_SYSKEYDOWN {
		vk := *(*uint32)(uptrToPtr(lParam))
		ctrl, _, _ := procGetAsyncKeyState.Call(uintptr(VK_CONTROL))
		shift, _, _ := procGetAsyncKeyState.Call(uintptr(VK_SHIFT))
		if vk == VK_Q && ctrl&0x8000 != 0 && shift&0x8000 != 0 {
			p.mu.Lock()
			escape := p.lockEscape
			p.mu.Unlock()
			if escape != nil {
				// Release the server-side lock too, otherwise the shell would
				// immediately re-arm the shield.
				go escape()
			}
			p.emergencyEscape()
		}
	}
	return 1
}

func (p *windowsProvider) lockMouseProc(nCode int, wParam, lParam uintptr) uintptr {
	if nCode < 0 {
		ret, _, _ := procCallNextHookEx.Call(0, uintptr(nCode), wParam, lParam)
		return ret
	}
	return 1
}

func (p *windowsProvider) lockMessageLoop(done chan struct{}) {
	// Win32 message loops and low-level hooks are thread-affine. Without this
	// the goroutine can migrate and PostQuitMessage/UnhookWindowsHookEx hit
	// the wrong thread.
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()
	defer close(done)

	className, _ := windows.UTF16PtrFromString(p.lockClassName)
	windowName, _ := windows.UTF16PtrFromString("VocabLock")

	var wc wndclassW
	wc.cbSize = uint32(unsafe.Sizeof(wc))
	wc.style = CS_HREDRAW | CS_VREDRAW
	wc.lpfnWndProc = syscall.NewCallback(p.lockWndProc)
	wc.hbrBackground = windows.Handle(COLOR_BTNFACE + 1)
	wc.lpszClassName = className

	procRegisterClassEx.Call(uintptr(unsafe.Pointer(&wc)))

	p.mu.Lock()
	shield := p.shieldOnly
	p.mu.Unlock()

	cx, _, _ := procGetSystemMetrics.Call(uintptr(SM_CXSCREEN))
	cy, _, _ := procGetSystemMetrics.Call(uintptr(SM_CYSCREEN))
	exStyle := uintptr(WS_EX_TOPMOST | WS_EX_TOOLWINDOW)
	style := uintptr(WS_VISIBLE)
	if shield {
		// No window on screen: the shell draws the lock UI. The message-only
		// window exists so the loop has a thread to own the hooks and a target
		// for WM_APP_LOCK_EXIT.
		exStyle = uintptr(WS_EX_TOOLWINDOW)
		style = 0
		cx, cy = 1, 1
	}

	hwnd, _, _ := procCreateWindowEx.Call(
		exStyle,
		uintptr(unsafe.Pointer(className)),
		uintptr(unsafe.Pointer(windowName)),
		style,
		0, 0, cx, cy,
		0, 0, 0, 0,
	)

	if hwnd == 0 {
		p.finishLockLoop(done, 0)
		return
	}

	p.mu.Lock()
	if !p.lockRunning {
		p.mu.Unlock()
		procDestroyWindow.Call(hwnd)
		p.finishLockLoop(done, 0)
		return
	}
	p.lockHwnd = windows.HWND(hwnd)
	p.mu.Unlock()

	if !shield {
		procShowWindow.Call(hwnd, SW_SHOW)
		procSetForeground.Call(hwnd)
	}

	if err := p.installLockHooks(); err != nil {
		log.Warn("system", "lock hooks: %v", err)
	}

	// Timers
	procSetTimer.Call(hwnd, TIMER_HEALTH, 10000, 0)   // health check every 10s
	procSetTimer.Call(hwnd, TIMER_COUNTDOWN, 1000, 0) // countdown tick every 1s

	// Keep RegisterHotKey as a fallback if the low-level hook cannot be
	// installed. With hooks active the hook itself handles Ctrl+Shift+Q.
	p.registerGlobalHotkey()

	// Message loop
	var msg msgW
	for {
		ret, _, _ := procGetMessage.Call(uintptr(unsafe.Pointer(&msg)), 0, 0, 0)
		if ret == 0 {
			break
		}
		procTranslateMsg.Call(uintptr(unsafe.Pointer(&msg)))
		procDispatchMsg.Call(uintptr(unsafe.Pointer(&msg)))
	}

	// Cleanup. Hooks must be removed on the thread that installed them.
	p.uninstallLockHooks()
	p.mu.Lock()
	p.shieldOnly = false
	p.mu.Unlock()
	p.mu.Lock()
	if p.hotkeyRegistered {
		procUnregisterHotKey.Call(hwnd, uintptr(p.hotkeyID))
		p.hotkeyRegistered = false
	}
	procKillTimer.Call(hwnd, TIMER_HEALTH)
	procKillTimer.Call(hwnd, TIMER_COUNTDOWN)
	procDestroyWindow.Call(hwnd)
	if p.lockHwnd == windows.HWND(hwnd) {
		p.lockHwnd = 0
	}
	if p.msgLoopDone == done {
		p.lockRunning = false
		p.lockShowExit = false
		p.msgLoopDone = nil
	}
	p.mu.Unlock()
}

func (p *windowsProvider) finishLockLoop(done chan struct{}, hwnd uintptr) {
	if hwnd != 0 {
		procDestroyWindow.Call(hwnd)
	}
	p.mu.Lock()
	if p.lockHwnd == windows.HWND(hwnd) {
		p.lockHwnd = 0
	}
	if p.msgLoopDone == done {
		p.lockRunning = false
		p.lockShowExit = false
		p.msgLoopDone = nil
	}
	p.mu.Unlock()
}

func (p *windowsProvider) lockWndProc(hwnd windows.HWND, msg uint32, wParam, lParam uintptr) uintptr {
	switch msg {
	case WM_PAINT:
		p.lockPaint(hwnd)
		return 0
	case WM_TIMER:
		switch wParam {
		case TIMER_HEALTH:
			p.lockHealthTick()
		case TIMER_COUNTDOWN:
			p.lockCountdownTick()
		}
		return 0
	case WM_HOTKEY:
		if wParam == uintptr(p.hotkeyID) {
			p.emergencyEscape()
		}
		return 0
	case WM_APP_LOCK_EXIT:
		// ExitLockMode posts this so the quit happens on the lock thread.
		procPostQuitMessage.Call(0)
		return 0
	case WM_CLOSE:
		// Block Alt+F4 / taskbar close — lock must go through escape
		return 0
	case WM_SYSCOMMAND:
		if wParam == SC_CLOSE {
			// Block system menu close
			return 0
		}
	case WM_DESTROY:
		procPostQuitMessage.Call(0)
		return 0
	case WM_NCHITTEST:
		return htTransparentConst
	}
	ret, _, _ := procDefWindowProc.Call(uintptr(hwnd), uintptr(msg), wParam, lParam)
	return ret
}

func (p *windowsProvider) lockPaint(hwnd windows.HWND) {
	var ps paintstructW
	hdc, _, _ := procBeginPaint.Call(uintptr(hwnd), uintptr(unsafe.Pointer(&ps)))
	if hdc == 0 {
		return
	}
	defer procEndPaint.Call(uintptr(hwnd), uintptr(unsafe.Pointer(&ps)))

	var rect rectW
	procGetClientRect.Call(uintptr(hwnd), uintptr(unsafe.Pointer(&rect)))

	// Dark navy background
	bg, _, _ := procCreateSolidBrush.Call(0x001A1A2E)
	procFillRect.Call(hdc, uintptr(unsafe.Pointer(&rect)), bg)
	procDeleteObject.Call(bg)

	procSetBkMode.Call(hdc, 1) // TRANSPARENT
	procSetTextColor.Call(hdc, 0x00CCCCCC)

	fontName, _ := windows.UTF16PtrFromString("Segoe UI")
	font, _, _ := procCreateFont.Call(
		48, 0, 0, 0, FW_NORMAL, 0, 0, 0, 1, 0, 0, CLEARTYPE_QUALITY, 0,
		uintptr(unsafe.Pointer(fontName)),
	)
	oldFont, _, _ := procSelectObject.Call(hdc, font)
	defer procSelectObject.Call(hdc, oldFont)
	defer procDeleteObject.Call(font)

	p.mu.Lock()
	showExit := p.lockShowExit
	countdown := p.lockCountdown
	p.mu.Unlock()

	var text string
	if showExit {
		text = fmt.Sprintf("VocabLock \346\234\215\345\212\241\346\227\240\345\223\215\345\272\224\n%d \347\247\222\345\220\216\350\207\252\345\212\250\350\247\243\351\224\201", countdown)
	} else {
		text = "VocabLock\n\345\255\246\344\271\240\344\270\255...\nCtrl+Shift+Q \347\264\247\346\200\245\351\200\200\345\207\272"
	}
	textPtr, _ := windows.UTF16PtrFromString(text)
	procDrawText.Call(hdc, uintptr(unsafe.Pointer(textPtr)), htTransparentConst, uintptr(unsafe.Pointer(&rect)),
		DT_CENTER|DT_VCENTER|DT_WORDBREAK)
}

func (p *windowsProvider) lockHealthTick() {
	p.mu.Lock()
	if !p.lockRunning {
		p.mu.Unlock()
		return
	}
	healthURL := p.healthURL
	flutterPID := p.flutterPID
	p.mu.Unlock()

	// Network and process probes must not hold p.mu: the HTTP client can take
	// up to 2s and ExitLockMode/timers need the lock concurrently.
	healthOK := false
	if healthURL != "" {
		healthOK = checkHTTPHealth(healthURL)
	}
	flutterAlive := false
	if flutterPID > 0 {
		flutterAlive = isProcessAlive(flutterPID)
	}

	p.mu.Lock()
	defer p.mu.Unlock()
	if !p.lockRunning {
		return
	}

	if !healthOK || !flutterAlive {
		if p.shieldOnly && p.deadCount >= 2 {
			// The shield has no window to show an exit button on. If the
			// service is gone, release the keyboard rather than trapping the
			// user behind hooks with no UI.
			go p.ExitLockShield()
			return
		}
		p.deadCount++
	} else {
		p.deadCount = 0
	}

	if p.deadCount >= 3 && !p.lockShowExit {
		p.lockShowExit = true
		p.lockCountdown = 30
		if p.lockHwnd != 0 {
			procInvalidateRect.Call(uintptr(p.lockHwnd), 0, 1)
		}
	}

	// Flutter dead + 5 ticks of health failure → auto-unlock
	if !flutterAlive && p.deadCount >= 5 {
		p.lockRunning = false
		procPostQuitMessage.Call(0)
	}
}

func (p *windowsProvider) lockCountdownTick() {
	p.mu.Lock()
	defer p.mu.Unlock()
	if !p.lockShowExit || p.lockCountdown <= 0 {
		return
	}
	p.lockCountdown--
	if p.lockHwnd != 0 {
		procInvalidateRect.Call(uintptr(p.lockHwnd), 0, 1)
	}
	if p.lockCountdown <= 0 {
		p.lockRunning = false
		p.lockShowExit = false
		procPostQuitMessage.Call(0)
	}
}

func (p *windowsProvider) emergencyEscape() {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.lockRunning = false
	p.lockShowExit = false
	p.deadCount = 0
	procPostQuitMessage.Call(0)
}

// ——— System tray ———

func (p *windowsProvider) trayMessageLoop() {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()

	className, _ := windows.UTF16PtrFromString(p.trayClassName)

	var wc wndclassW
	wc.cbSize = uint32(unsafe.Sizeof(wc))
	wc.lpfnWndProc = syscall.NewCallback(p.trayWndProc)
	wc.lpszClassName = className

	procRegisterClassEx.Call(uintptr(unsafe.Pointer(&wc)))

	hwnd, _, _ := procCreateWindowEx.Call(
		0,
		uintptr(unsafe.Pointer(className)),
		uintptr(unsafe.Pointer(windows.StringToUTF16Ptr(""))),
		0,
		0, 0, 0, 0,
		0, 0, 0, 0,
	)

	p.mu.Lock()
	p.trayHwnd = windows.HWND(hwnd)
	p.mu.Unlock()

	p.addTrayIcon(windows.HWND(hwnd))
	p.mu.Lock()
	p.trayCreated = true
	p.mu.Unlock()

	var msg msgW
	for {
		ret, _, _ := procGetMessage.Call(uintptr(unsafe.Pointer(&msg)), 0, 0, 0)
		if ret == 0 {
			break
		}
		procTranslateMsg.Call(uintptr(unsafe.Pointer(&msg)))
		procDispatchMsg.Call(uintptr(unsafe.Pointer(&msg)))
	}
}

func (p *windowsProvider) trayWndProc(hwnd windows.HWND, msg uint32, wParam, lParam uintptr) uintptr {
	switch msg {
	case WM_COMMAND:
		switch uint32(wParam) {
		case IDM_SHOW:
			p.mu.Lock()
			onShow := p.trayOnShow
			p.mu.Unlock()
			if onShow != nil {
				onShow()
			}
		case IDM_QUIT:
			p.mu.Lock()
			onQuit := p.trayOnQuit
			p.mu.Unlock()
			if onQuit != nil {
				onQuit()
			}
		}
		return 0
	case WM_TRAYICON:
		switch uint32(lParam) {
		case 0x0205: // WM_RBUTTONUP
			p.showTrayMenu(hwnd)
		case 0x0201: // WM_LBUTTONUP
			p.mu.Lock()
			onShow := p.trayOnShow
			p.mu.Unlock()
			if onShow != nil {
				onShow()
			}
		}
		return 0
	case WM_DESTROY:
		procPostQuitMessage.Call(0)
		return 0
	}
	ret, _, _ := procDefWindowProc.Call(uintptr(hwnd), uintptr(msg), wParam, lParam)
	return ret
}

func (p *windowsProvider) addTrayIcon(hwnd windows.HWND) {
	var nid notifyIconDataW
	nid.cbSize = uint32(unsafe.Sizeof(nid))
	nid.hWnd = hwnd
	nid.uID = 1
	nid.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP
	nid.uCallbackMessage = WM_TRAYICON
	iconHandle, _, _ := procLoadIcon.Call(0, uintptr(IDI_APPLICATION))
	nid.hIcon = windows.Handle(iconHandle)
	copy(nid.szTip[:], windows.StringToUTF16("VocabLock"))
	procShellNotifyIcon.Call(uintptr(NIM_ADD), uintptr(unsafe.Pointer(&nid)))
}

func (p *windowsProvider) removeTrayIcon(hwnd windows.HWND) {
	var nid notifyIconDataW
	nid.cbSize = uint32(unsafe.Sizeof(nid))
	nid.hWnd = hwnd
	nid.uID = 1
	procShellNotifyIcon.Call(uintptr(NIM_DELETE), uintptr(unsafe.Pointer(&nid)))
}

func (p *windowsProvider) showTrayMenu(hwnd windows.HWND) {
	menu, _, _ := procCreatePopupMenu.Call()
	if menu == 0 {
		return
	}
	defer procDestroyMenu.Call(menu)

	showPtr, _ := windows.UTF16PtrFromString("\346\230\276\347\244\272\344\270\273\347\252\227\345\217\243")
	quitPtr, _ := windows.UTF16PtrFromString("\351\200\200\345\207\272")
	procAppendMenu.Call(menu, 0, IDM_SHOW, uintptr(unsafe.Pointer(showPtr)))
	procAppendMenu.Call(menu, 0, IDM_QUIT, uintptr(unsafe.Pointer(quitPtr)))

	var pt pointW
	procGetCursorPos.Call(uintptr(unsafe.Pointer(&pt)))

	procSetForeground.Call(uintptr(hwnd))
	procTrackPopupMenu.Call(menu, TPM_RIGHTBUTTON|TPM_RETURNCMD, uintptr(pt.x), uintptr(pt.y), 0, uintptr(hwnd), 0)
}

// ——— Passive quiz ———

func (p *windowsProvider) StartPassiveQuiz() {
	p.mu.Lock()
	if p.passiveRunning || p.passiveInterval <= 0 {
		p.mu.Unlock()
		return
	}
	p.passiveRunning = true
	interval := p.passiveInterval
	p.mu.Unlock()

	go func() {
		// Random interval: between passiveMinInterval and passiveMaxInterval (minutes)
		for {
			p.mu.Lock()
			running := p.passiveRunning
			p.mu.Unlock()
			if !running {
				return
			}
			// Wait for the interval (with some randomization)
			sleepSec := interval*60 + int(time.Now().UnixNano())%(interval*30)
			select {
			case <-time.After(time.Duration(sleepSec) * time.Second):
				p.triggerPassivePopup()
			case <-p.quitChan:
				return
			}
		}
	}()
}

func (p *windowsProvider) StopPassiveQuiz() {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.passiveRunning = false
}

func (p *windowsProvider) triggerPassivePopup() {
	// Create a simple popup window with the word
	// This is a lightweight notification-style window
	go func() {
		runtime.LockOSThread()
		defer runtime.UnlockOSThread()

		className, _ := windows.UTF16PtrFromString("VocabLock_PassivePopup")
		titleName, _ := windows.UTF16PtrFromString("VocabLock \350\257\215\346\261\207\345\244\215\344\271\240")

		var wc wndclassW
		wc.cbSize = uint32(unsafe.Sizeof(wc))
		wc.style = CS_HREDRAW | CS_VREDRAW
		wc.lpfnWndProc = syscall.NewCallback(p.passiveWndProc)
		wc.hbrBackground = windows.Handle(COLOR_BTNFACE + 1)
		wc.lpszClassName = className
		procRegisterClassEx.Call(uintptr(unsafe.Pointer(&wc)))

		// Small popup window (300x200) at bottom-right of screen
		cx, _, _ := procGetSystemMetrics.Call(uintptr(SM_CXSCREEN))
		cy, _, _ := procGetSystemMetrics.Call(uintptr(SM_CYSCREEN))
		popupW := uintptr(320)
		popupH := uintptr(200)
		popupX := cx - popupW - 40
		popupY := cy - popupH - 80

		hwnd, _, _ := procCreateWindowEx.Call(
			uintptr(WS_EX_TOPMOST|WS_EX_TOOLWINDOW),
			uintptr(unsafe.Pointer(className)),
			uintptr(unsafe.Pointer(titleName)),
			uintptr(WS_VISIBLE),
			popupX, popupY, popupW, popupH,
			0, 0, 0, 0,
		)

		if hwnd == 0 {
			return
		}

		// Auto-close after 30 seconds. DestroyWindow is thread-affine, so ask
		// the window own message loop to close it.
		go func() {
			time.Sleep(30 * time.Second)
			procPostMessage.Call(hwnd, WM_CLOSE, 0, 0)
		}()

		// Mini message loop for this popup
		var msg msgW
		for {
			ret, _, _ := procGetMessage.Call(uintptr(unsafe.Pointer(&msg)), 0, 0, 0)
			if ret == 0 {
				break
			}
			procTranslateMsg.Call(uintptr(unsafe.Pointer(&msg)))
			procDispatchMsg.Call(uintptr(unsafe.Pointer(&msg)))
		}
	}()
}

func (p *windowsProvider) passiveWndProc(hwnd windows.HWND, msg uint32, wParam, lParam uintptr) uintptr {
	switch msg {
	case WM_PAINT:
		var ps paintstructW
		hdc, _, _ := procBeginPaint.Call(uintptr(hwnd), uintptr(unsafe.Pointer(&ps)))
		if hdc != 0 {
			var rect rectW
			procGetClientRect.Call(uintptr(hwnd), uintptr(unsafe.Pointer(&rect)))

			bg, _, _ := procCreateSolidBrush.Call(0x002B2B2B)
			procFillRect.Call(hdc, uintptr(unsafe.Pointer(&rect)), bg)
			procDeleteObject.Call(bg)

			procSetBkMode.Call(hdc, 1)
			procSetTextColor.Call(hdc, 0x00FFFFFF)
			fontName, _ := windows.UTF16PtrFromString("Segoe UI")
			font, _, _ := procCreateFont.Call(
				24, 0, 0, 0, FW_NORMAL, 0, 0, 0, 1, 0, 0, CLEARTYPE_QUALITY, 0,
				uintptr(unsafe.Pointer(fontName)),
			)
			oldFont, _, _ := procSelectObject.Call(hdc, font)
			defer procSelectObject.Call(hdc, oldFont)
			defer procDeleteObject.Call(font)

			textPtr, _ := windows.UTF16PtrFromString("\345\244\215\344\271\240\346\217\220\351\206\222\n\n\350\257\267\346\211\223\345\274\200\344\270\273\347\225\214\351\235\242\345\256\214\346\210\220\345\244\215\344\271\240")
			procDrawText.Call(hdc, uintptr(unsafe.Pointer(textPtr)), htTransparentConst, uintptr(unsafe.Pointer(&rect)),
				DT_CENTER|DT_VCENTER|DT_WORDBREAK)
			procEndPaint.Call(uintptr(hwnd), uintptr(unsafe.Pointer(&ps)))
		}
		return 0
	case WM_CLOSE:
		procDestroyWindow.Call(uintptr(hwnd))
		return 0
	case WM_DESTROY:
		procPostQuitMessage.Call(0)
		return 0
	}
	ret, _, _ := procDefWindowProc.Call(uintptr(hwnd), uintptr(msg), wParam, lParam)
	return ret
}

// ——— Helpers ———

func isProcessAlive(pid int) bool {
	handle, _, _ := procOpenProcess.Call(uintptr(PROCESS_QUERY_INFORMATION), 0, uintptr(pid))
	if handle == 0 {
		return false
	}
	defer procCloseHandle.Call(handle)
	var code uint32
	ret, _, _ := procGetExitCode.Call(handle, uintptr(unsafe.Pointer(&code)))
	if ret == 0 {
		return false
	}
	return code == STILL_ACTIVE
}

var healthHTTPClient = &http.Client{Timeout: 2 * time.Second}

func checkHTTPHealth(url string) bool {
	resp, err := healthHTTPClient.Get(url)
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	return resp.StatusCode == http.StatusOK
}

// ——— Win32 structs ———

type wndclassW struct {
	cbSize        uint32
	style         uint32
	lpfnWndProc   uintptr
	cbClsExtra    int32
	cbWndExtra    int32
	hInstance     uintptr
	hIcon         windows.Handle
	hCursor       windows.Handle
	hbrBackground windows.Handle
	lpszMenuName  *uint16
	lpszClassName *uint16
}

type msgW struct {
	hwnd    windows.HWND
	message uint32
	wParam  uintptr
	lParam  uintptr
	time    uint32
	pt      pointW
}

type pointW struct {
	x int32
	y int32
}

type rectW struct {
	left   int32
	top    int32
	right  int32
	bottom int32
}

type paintstructW struct {
	hdc         windows.Handle
	fErase      int32
	rcPaint     rectW
	fRestore    int32
	fIncUpdate  int32
	rgbReserved [32]byte
}

type notifyIconDataW struct {
	cbSize            uint32
	hWnd              windows.HWND
	uID               uint32
	uFlags            uint32
	uCallbackMessage  uint32
	hIcon             windows.Handle
	szTip             [128]uint16
	dwState           uint32
	dwStateMask       uint32
	szInfo            [256]uint16
	uTimeoutOrVersion uint32
	szInfoTitle       [64]uint16
	dwInfoFlags       uint32
}

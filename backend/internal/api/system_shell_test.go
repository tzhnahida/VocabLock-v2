package api

import (
	"encoding/json"
	"net/http/httptest"
	"testing"

	"github.com/tzhnahida/VocabLock/internal/config"
)

type recordingSystem struct {
	enter, exit, fullscreen, restore, find int
}

func (r *recordingSystem) EnterLockMode(uintptr) error { r.enter++; return nil }
func (r *recordingSystem) ExitLockMode() error         { r.exit++; return nil }
func (r *recordingSystem) OnWindowClosing() bool       { return false }
func (r *recordingSystem) StartTray(func(), func()) error {
	return nil
}
func (r *recordingSystem) StopTray() error            { return nil }
func (r *recordingSystem) AcquireLock() (bool, error) { return true, nil }
func (r *recordingSystem) SetAutoStart(bool) error    { return nil }
func (r *recordingSystem) FindFlutterWindow() (uintptr, error) {
	r.find++
	return 0, nil
}
func (r *recordingSystem) SetServerInfo(string, int) {}
func (r *recordingSystem) FullscreenFlutterWindow() error {
	r.fullscreen++
	return nil
}
func (r *recordingSystem) RestoreFlutterWindow() error { r.restore++; return nil }
func (r *recordingSystem) SetPassiveInterval(int)      {}
func (r *recordingSystem) StartPassiveQuiz()           {}
func (r *recordingSystem) StopPassiveQuiz()            {}

func newShellTestServer(native bool) (*Server, *recordingSystem) {
	s := NewServer(false, &config.Config{}, nil)
	sys := &recordingSystem{}
	s.System = sys
	s.NativeShell = native
	return s, sys
}

// The Electron shell has no OS-level lock window. Locking from the server must
// not touch window handles there (previously every answer called
// RestoreFlutterWindow against a window that does not exist).
func TestSystemLockSkipsWindowCallsWithoutNativeShell(t *testing.T) {
	s, sys := newShellTestServer(false)

	rec := httptest.NewRecorder()
	s.handleSystemLock(rec, httptest.NewRequest("POST", "/api/v1/system/lock", nil))
	var body map[string]interface{}
	_ = json.Unmarshal(rec.Body.Bytes(), &body)
	if body["locked"] != true || body["native"] != false {
		t.Errorf("lock response = %v, want locked=true native=false", body)
	}
	if sys.enter != 0 || sys.fullscreen != 0 || sys.find != 0 {
		t.Errorf("native window calls used without a native shell: %+v", sys)
	}

	rec = httptest.NewRecorder()
	s.handleSystemUnlock(rec, httptest.NewRequest("POST", "/api/v1/system/unlock", nil))
	if sys.exit != 0 || sys.restore != 0 {
		t.Errorf("native unlock ran without a native shell: %+v", sys)
	}
}

// The Flutter shell still gets the full native path.
func TestSystemLockDrivesNativeWindowWithFlutterShell(t *testing.T) {
	s, sys := newShellTestServer(true)

	rec := httptest.NewRecorder()
	s.handleSystemLock(rec, httptest.NewRequest("POST", "/api/v1/system/lock", nil))
	if sys.fullscreen != 1 || sys.find != 1 || sys.enter != 1 {
		t.Errorf("native lock not driven: %+v", sys)
	}

	rec = httptest.NewRecorder()
	s.handleSystemUnlock(rec, httptest.NewRequest("POST", "/api/v1/system/unlock", nil))
	if sys.exit != 1 || sys.restore != 1 {
		t.Errorf("native unlock not driven: %+v", sys)
	}
}

// The Electron shell follows /system/status, so the server must publish the
// lock state it decided on (startup auto-lock, tray lock, emergency escape).
func TestSystemStatusReportsLockState(t *testing.T) {
	s, _ := newShellTestServer(false)

	rec := httptest.NewRecorder()
	s.handleSystemStatus(rec, httptest.NewRequest("GET", "/api/v1/system/status", nil))
	var body map[string]interface{}
	_ = json.Unmarshal(rec.Body.Bytes(), &body)
	if body["locked"] != false {
		t.Errorf("initial locked = %v, want false", body["locked"])
	}

	s.handleSystemLock(httptest.NewRecorder(), httptest.NewRequest("POST", "/api/v1/system/lock", nil))
	if !s.IsLocked() {
		t.Fatal("MarkLocked(true) not applied by lock handler")
	}
	rec = httptest.NewRecorder()
	s.handleSystemStatus(rec, httptest.NewRequest("GET", "/api/v1/system/status", nil))
	body = nil
	_ = json.Unmarshal(rec.Body.Bytes(), &body)
	if body["locked"] != true {
		t.Errorf("locked = %v after lock, want true", body["locked"])
	}

	s.handleSystemUnlock(httptest.NewRecorder(), httptest.NewRequest("POST", "/api/v1/system/unlock", nil))
	if s.IsLocked() {
		t.Error("unlock handler left the server locked")
	}
}

package main

import (
	"flag"
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"

	"github.com/tzhnahida/VocabLock/internal/log"

	"github.com/tzhnahida/VocabLock/internal/api"
	"github.com/tzhnahida/VocabLock/internal/config"
	"github.com/tzhnahida/VocabLock/internal/db"
	"github.com/tzhnahida/VocabLock/internal/dict"
	"github.com/tzhnahida/VocabLock/internal/pronounce"
	"github.com/tzhnahida/VocabLock/internal/system"
	"github.com/tzhnahida/VocabLock/internal/tts"
)

func main() {
	mockMode := flag.Bool("mock", false, "Run with mock handlers (no AI, no SQLite, no external processes)")
	flag.Parse()

	configDir := "configs"
	cfg, err := config.Load(configDir)
	if err != nil {
		log.Error("config", "%v", err)
		os.Exit(1)
	}

	if *mockMode {
		cfg.App.MockMode = true
	}

	// Allow empty languages on first run
	var lang *config.LanguageConfig
	if cfg.App.ActiveLang != "" {
		var ok bool
		lang, ok = cfg.Languages[cfg.App.ActiveLang]
		if !ok && len(cfg.Languages) > 0 {
			log.Error("config", "active language %q not configured", cfg.App.ActiveLang)
			os.Exit(1)
		}
	}

	var database *db.Database
	if !cfg.App.MockMode {
		database, err = db.Open("data")
		if err != nil {
			log.Error("db", "%v", err)
			os.Exit(1)
		}
		defer database.Close()
	}

	srv := api.NewServer(cfg.App.MockMode, cfg, database)
	srv.ConfigDir = configDir

	// ——— System-level features (P4: lock screen, tray, single instance) ———
	systemProvider := system.Default

	// Single-instance lock
	acquired, err := systemProvider.AcquireLock()
	if err != nil {
		log.Warn("system", "single-instance lock error: %v", err)
	} else if !acquired {
		log.Error("system", "another instance is already running")
		os.Exit(1)
	}
	srv.System = systemProvider

	// Wire AI client (if configured)
	srv.WireAI()

	// Wire TTS provider (if configured for active language)
	if lang != nil && lang.TTS.Provider != "" && !cfg.App.MockMode {
		provCfg, ok := cfg.TTS.TTS.Providers[lang.TTS.Provider]
		if ok {
			provider, err := tts.NewProvider(lang.TTS.Provider, provCfg, "data/audio")
			if err != nil {
				log.Warn("tts", "init: %v", err)
			} else {
				srv.TTSProvider = provider
				log.Info("server", "tts: %s (%s)", lang.TTS.Provider, lang.TTS.Voice)
			}
		}
	}

	// Wire Dict provider (if configured for active language)
	if lang != nil && lang.Dict.Provider != "" && !cfg.App.MockMode {
		provCfg, ok := cfg.Dict.Dict.Providers[lang.Dict.Provider]
		if ok {
			srv.DictProvider = dict.NewProvider(lang.Dict.Provider, provCfg)
			log.Info("server", "dict: %s", lang.Dict.Provider)
		}
	}

	// Wire Pronounce provider (if configured for active language; optional)
	if lang != nil && lang.Pronounce.Provider != "" && !cfg.App.MockMode {
		provCfg, ok := cfg.Pronounce.Pronounce.Providers[lang.Pronounce.Provider]
		if ok {
			srv.PronounceProvider = pronounce.NewProvider(lang.Pronounce.Provider, provCfg)
			log.Info("server", "pronounce: %s", lang.Pronounce.Provider)
		}
	}

	if err := srv.Start(); err != nil {
		log.Error("server", "start: %v", err)
		os.Exit(1)
	}

	// Bootstrap seed words + grammar points for active language on first run
	srv.EnsureBootstrap(cfg.App.ActiveLang)

	flutterPID := spawnFlutter(srv.Port, srv.Token)

	// Set runtime info for health monitoring
	healthURL := fmt.Sprintf("http://127.0.0.1:%d/health", srv.Port)
	systemProvider.SetServerInfo(healthURL, flutterPID)

	// Wait for Flutter window to appear
	time.Sleep(500 * time.Millisecond)

	// Auto-lock if daily target not met
	if database != nil {
		reviewed, err := database.GetUniqueSubjectsReviewed(cfg.App.ActiveLang)
		if err != nil {
			log.Warn("system", "check daily target: %v", err)
		}
		log.Info("system", "startup check: reviewed=%d target=%d lang=%s", reviewed, cfg.App.DailyTarget, cfg.App.ActiveLang)
		if reviewed < cfg.App.DailyTarget {
			log.Info("system", "auto-lock: fullscreen + lock")
			systemProvider.FullscreenFlutterWindow()
			systemProvider.EnterLockMode(0)
		} else {
			log.Info("system", "daily target met — skip lock")
		}
	}

	// Passive quiz (if enabled)
	if cfg.App.PassiveEnabled {
		interval := cfg.App.PassiveMinInterval
		if interval <= 0 {
			interval = 25
		}
		systemProvider.SetPassiveInterval(interval)
		systemProvider.StartPassiveQuiz()
	}

	// System tray (always start)
	systemProvider.StartTray(
		func() {
			// onShow: bring Flutter window to foreground
			if hwnd, err := systemProvider.FindFlutterWindow(); err == nil {
				user32 := syscall.NewLazyDLL("user32.dll")
				user32.NewProc("SetForegroundWindow").Call(hwnd)
				user32.NewProc("ShowWindow").Call(hwnd, 9) // SW_RESTORE
			}
		},
		func() {
			// onQuit: clean shutdown
			log.Info("server", "tray quit requested")
			srv.Shutdown()
			os.Exit(0)
		},
	)

	if lang != nil {
		log.Info("server", "VocabLock v2 — %s (%s)", lang.Lang.DisplayName, lang.Lang.NativeName)
	} else {
		log.Info("server", "VocabLock v2 — first run")
	}
	log.Info("server", "http://127.0.0.1:%d", srv.Port)
	log.Info("server", "token: %s", srv.Token)
	log.Info("server", "mock: %v", cfg.App.MockMode)

	sig := make(chan os.Signal, 1)
	signal.Notify(sig, syscall.SIGINT, syscall.SIGTERM)
	<-sig

	log.Info("server", "Shutting down...")
	srv.Shutdown()
}

func spawnFlutter(port int, token string) int {
	exe, err := os.Executable()
	if err != nil {
		return 0
	}
	dir := filepath.Dir(exe)
	candidates := []string{
		filepath.Join(dir, "frontend", "vocablock_ui.exe"),
		filepath.Join(dir, "vocablock_ui.exe"),
		filepath.Join(dir, "backend", "frontend", "build", "windows", "x64", "runner", "Release", "vocablock_ui.exe"),
		filepath.Join(dir, "frontend", "build", "windows", "x64", "runner", "Release", "vocablock_ui.exe"),
	}
	flutterExe := ""
	for _, c := range candidates {
		if _, err := os.Stat(c); err == nil {
			flutterExe = c
			break
		}
	}
	if flutterExe == "" {
		return 0
	}

	cmd := exec.Command(flutterExe,
		"--api-port", fmt.Sprintf("%d", port),
		"--auth-token", token,
	)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Start(); err != nil {
		log.Warn("server", "flutter spawn: %v", err)
		return 0
	}
	log.Info("server", "flutter pid=%d", cmd.Process.Pid)
	return cmd.Process.Pid
}

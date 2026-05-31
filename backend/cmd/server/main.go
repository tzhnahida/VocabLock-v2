package main

import (
	"flag"
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"syscall"

	"github.com/vocablock/v2/internal/log"

	"github.com/vocablock/v2/internal/api"
	"github.com/vocablock/v2/internal/config"
	"github.com/vocablock/v2/internal/db"
	"github.com/vocablock/v2/internal/dict"
	"github.com/vocablock/v2/internal/pronounce"
	"github.com/vocablock/v2/internal/tts"
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

	spawnFlutter(srv.Port, srv.Token)

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

func spawnFlutter(port int, token string) {
	exe, err := os.Executable()
	if err != nil {
		return
	}
	dir := filepath.Dir(exe)
	// Try both layouts: project-root and backend-directory
	candidates := []string{
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
		return
	}

	cmd := exec.Command(flutterExe,
		"--api-port", fmt.Sprintf("%d", port),
		"--auth-token", token,
	)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Start(); err != nil {
		log.Warn("server", "flutter spawn: %v", err)
		return
	}
	log.Info("server", "flutter pid=%d", cmd.Process.Pid)
}

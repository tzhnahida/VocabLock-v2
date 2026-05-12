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

	"github.com/vocablock/v2/internal/ai"
	"github.com/vocablock/v2/internal/api"
	"github.com/vocablock/v2/internal/config"
	"github.com/vocablock/v2/internal/db"
	"github.com/vocablock/v2/internal/dict"
	"github.com/vocablock/v2/internal/tts"
)

func main() {
	mockMode := flag.Bool("mock", false, "Run with mock handlers (no AI, no SQLite, no external processes)")
	flag.Parse()

	cfg, err := config.Load("configs")
	if err != nil {
		fmt.Fprintf(os.Stderr, "config error: %v\n", err)
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
			fmt.Fprintf(os.Stderr, "active language %q not configured\n", cfg.App.ActiveLang)
			os.Exit(1)
		}
	}

	var database *db.Database
	if !cfg.App.MockMode {
		database, err = db.Open("data")
		if err != nil {
			fmt.Fprintf(os.Stderr, "database error: %v\n", err)
			os.Exit(1)
		}
		defer database.Close()
	}

	srv := api.NewServer(cfg.App.MockMode, cfg, database)

	// Wire AI client (if configured)
	if cfg.App.AI.APIKey != "" && !cfg.App.MockMode {
		srv.AI = ai.NewClient(ai.Config{
			BaseURL: cfg.App.AI.BaseURL,
			APIKey:  cfg.App.AI.APIKey,
			Model:   cfg.App.AI.Model,
			Timeout: 30 * time.Second,
		})
		fmt.Println("  AI: configured")
	}

	// Wire TTS provider (if configured for active language)
	if lang != nil && lang.TTS.Provider != "" && !cfg.App.MockMode {
		provCfg, ok := cfg.TTS.TTS.Providers[lang.TTS.Provider]
		if ok {
			provider, err := tts.NewProvider(lang.TTS.Provider, provCfg, "data/audio")
			if err != nil {
				fmt.Fprintf(os.Stderr, "tts init warning: %v\n", err)
			} else {
				srv.TTSProvider = provider
				fmt.Printf("  TTS: %s (%s)\n", lang.TTS.Provider, lang.TTS.Voice)
			}
		}
	}

	// Wire Dict provider (if configured for active language)
	if lang != nil && lang.Dict.Provider != "" && !cfg.App.MockMode {
		provCfg, ok := cfg.Dict.Dict.Providers[lang.Dict.Provider]
		if ok {
			srv.DictProvider = dict.NewProvider(lang.Dict.Provider, provCfg)
			fmt.Printf("  Dict: %s\n", lang.Dict.Provider)
		}
	}

	if err := srv.Start(); err != nil {
		fmt.Fprintf(os.Stderr, "server start error: %v\n", err)
		os.Exit(1)
	}

	spawnFlutter(srv.Port, srv.Token)

	if lang != nil {
		fmt.Printf("VocabLock v2 — %s (%s)\n", lang.Lang.DisplayName, lang.Lang.NativeName)
	} else {
		fmt.Println("VocabLock v2 — first run")
	}
	fmt.Printf("  HTTP: http://127.0.0.1:%d\n", srv.Port)
	fmt.Printf("  Token: %s\n", srv.Token)
	fmt.Printf("  Mock: %v\n", cfg.App.MockMode)

	sig := make(chan os.Signal, 1)
	signal.Notify(sig, syscall.SIGINT, syscall.SIGTERM)
	<-sig

	fmt.Println("\nShutting down...")
	srv.Shutdown()
}

func spawnFlutter(port int, token string) {
	exe, err := os.Executable()
	if err != nil {
		return
	}
	dir := filepath.Dir(exe)
	flutterExe := filepath.Join(dir, "frontend", "build", "windows", "x64", "runner", "Release", "vocablock_ui.exe")
	if _, err := os.Stat(flutterExe); os.IsNotExist(err) {
		return
	}

	cmd := exec.Command(flutterExe,
		"--api-port", fmt.Sprintf("%d", port),
		"--auth-token", token,
	)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Start(); err != nil {
		fmt.Fprintf(os.Stderr, "flutter spawn warning: %v\n", err)
		return
	}
	fmt.Printf("  Flutter: pid=%d\n", cmd.Process.Pid)
}

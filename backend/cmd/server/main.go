package main

import (
	"flag"
	"fmt"
	"os"

	"github.com/vocablock/v2/internal/config"
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
		fmt.Println("Running in mock mode")
	}

	fmt.Printf("VocabLock v2 starting (lang=%s, daily_target=%d)\n",
		cfg.App.ActiveLang, cfg.App.DailyTarget)

	lang, ok := cfg.Languages[cfg.App.ActiveLang]
	if !ok {
		fmt.Fprintf(os.Stderr, "active language %q not configured\n", cfg.App.ActiveLang)
		os.Exit(1)
	}
	fmt.Printf("  Language: %s (%s)\n", lang.Lang.DisplayName, lang.Lang.NativeName)

	// TODO: start HTTP server, lock screen, tray, spawn Flutter
}

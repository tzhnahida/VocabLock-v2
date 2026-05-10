package main

import (
	"flag"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"github.com/vocablock/v2/internal/api"
	"github.com/vocablock/v2/internal/config"
	"github.com/vocablock/v2/internal/db"
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

	lang, ok := cfg.Languages[cfg.App.ActiveLang]
	if !ok {
		fmt.Fprintf(os.Stderr, "active language %q not configured\n", cfg.App.ActiveLang)
		os.Exit(1)
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
	if err := srv.Start(); err != nil {
		fmt.Fprintf(os.Stderr, "server start error: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("VocabLock v2 — %s (%s)\n", lang.Lang.DisplayName, lang.Lang.NativeName)
	fmt.Printf("  HTTP: http://127.0.0.1:%d\n", srv.Port)
	fmt.Printf("  Token: %s\n", srv.Token)
	fmt.Printf("  Mock: %v\n", cfg.App.MockMode)

	sig := make(chan os.Signal, 1)
	signal.Notify(sig, syscall.SIGINT, syscall.SIGTERM)
	<-sig

	fmt.Println("\nShutting down...")
	srv.Shutdown()
}

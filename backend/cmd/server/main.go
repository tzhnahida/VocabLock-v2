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
		fmt.Println("Running in mock mode")
	}

	fmt.Printf("VocabLock v2 starting (lang=%s)\n", cfg.ActiveLang)

	// TODO: start HTTP server, lock screen, tray, spawn Flutter
}

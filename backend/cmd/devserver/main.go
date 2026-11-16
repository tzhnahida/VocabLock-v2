// Command devserver runs the HTTP API without spawning a UI.
//
// The desktop shell owns the window, so during front-end work the Go service is
// started on its own and its {port, token} handed to the shell:
//
//	go run ./cmd/devserver --config-dir=../configs --db-dir=../data
//
// It prints one JSON line ("{"port":...,"token":...}") and then serves until
// interrupted. It deliberately does not touch the lock screen, the tray or the
// passive pop-up — those belong to the packaged app, not to a dev session.
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"github.com/tzhnahida/VocabLock/internal/api"
	"github.com/tzhnahida/VocabLock/internal/config"
	"github.com/tzhnahida/VocabLock/internal/db"
	"github.com/tzhnahida/VocabLock/internal/dict"
	"github.com/tzhnahida/VocabLock/internal/log"
	"github.com/tzhnahida/VocabLock/internal/pronounce"
	"github.com/tzhnahida/VocabLock/internal/tts"
)

func main() {
	configDir := flag.String("config-dir", "configs", "directory holding app.yaml and friends")
	dbDir := flag.String("db-dir", "data", "directory holding vocablock.db")
	flag.Parse()

	cfg, err := config.Load(*configDir)
	if err != nil {
		fmt.Fprintln(os.Stderr, "config:", err)
		os.Exit(1)
	}

	var database *db.Database
	if !cfg.App.MockMode {
		database, err = db.Open(*dbDir)
		if err != nil {
			fmt.Fprintln(os.Stderr, "db:", err)
			os.Exit(1)
		}
		defer database.Close()
	}

	srv := api.NewServer(cfg.App.MockMode, cfg, database)
	srv.ConfigDir = *configDir
	srv.WireAI()

	lang := cfg.Languages[cfg.App.ActiveLang]
	if lang != nil && !cfg.App.MockMode {
		if lang.TTS.Provider != "" {
			if provCfg, ok := cfg.TTS.TTS.Providers[lang.TTS.Provider]; ok {
				if provider, err := tts.NewProvider(lang.TTS.Provider, provCfg, "data/audio"); err == nil {
					srv.TTSProvider = provider
				} else {
					log.Warn("devserver", "tts: %v", err)
				}
			}
		}
		if lang.Dict.Provider != "" {
			if provCfg, ok := cfg.Dict.Dict.Providers[lang.Dict.Provider]; ok {
				srv.DictProvider = dict.NewProvider(lang.Dict.Provider, provCfg)
			}
		}
		if lang.Pronounce.Provider != "" {
			if provCfg, ok := cfg.Pronounce.Pronounce.Providers[lang.Pronounce.Provider]; ok {
				srv.PronounceProvider = pronounce.NewProvider(lang.Pronounce.Provider, provCfg)
			}
		}
	}
	srv.WireASR()

	if err := srv.Start(); err != nil {
		fmt.Fprintln(os.Stderr, "start:", err)
		os.Exit(1)
	}

	payload, _ := json.Marshal(map[string]interface{}{
		"port": srv.Port,
		"token": srv.Token,
		"lang": cfg.App.ActiveLang,
	})
	fmt.Println(string(payload))
	os.Stdout.Sync()

	sig := make(chan os.Signal, 1)
	signal.Notify(sig, syscall.SIGINT, syscall.SIGTERM)
	<-sig
	srv.Shutdown()
}

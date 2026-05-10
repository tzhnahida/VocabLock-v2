package api

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"net"
	"net/http"
	"time"

	"github.com/vocablock/v2/internal/config"
	"github.com/vocablock/v2/internal/db"
)

type Server struct {
	http   *http.Server
	Port   int
	Token  string
	Mock   bool
	Config *config.Config
	DB     *db.Database
}

func NewServer(mock bool, cfg *config.Config, database *db.Database) *Server {
	token := make([]byte, 16)
	rand.Read(token)

	return &Server{
		Token:  hex.EncodeToString(token),
		Mock:   mock,
		Config: cfg,
		DB:     database,
	}
}

func (s *Server) Start() error {
	mux := http.NewServeMux()
	s.registerRoutes(mux)

	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return fmt.Errorf("bind: %w", err)
	}

	s.Port = listener.Addr().(*net.TCPAddr).Port
	s.http = &http.Server{
		Handler:      withMiddleware(mux, s.Token),
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 30 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	go func() {
		if err := s.http.Serve(listener); err != nil && err != http.ErrServerClosed {
			fmt.Printf("http server error: %v\n", err)
		}
	}()

	return nil
}

func (s *Server) Shutdown() error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	return s.http.Shutdown(ctx)
}

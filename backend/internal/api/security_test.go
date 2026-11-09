package api

import (
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestAuthTokenQueryScopedToAudio(t *testing.T) {
	ok := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})
	h := authMiddleware(ok, "secret")

	tests := []struct {
		name   string
		method string
		path   string
		want   int
	}{
		{"bearer", http.MethodGet, "/api/v1/stats", http.StatusOK},
		{"audio query", http.MethodGet, "/data/audio/a.mp3?token=secret", http.StatusOK},
		{"audio head query", http.MethodHead, "/data/audio/a.mp3?token=secret", http.StatusOK},
		{"api query rejected", http.MethodGet, "/api/v1/stats?token=secret", http.StatusUnauthorized},
		{"audio post rejected", http.MethodPost, "/data/audio/a.mp3?token=secret", http.StatusUnauthorized},
		{"wrong token", http.MethodGet, "/data/audio/a.mp3?token=nope", http.StatusUnauthorized},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := httptest.NewRequest(tt.method, tt.path, nil)
			if tt.name == "bearer" {
				req.Header.Set("Authorization", "Bearer secret")
			}
			rr := httptest.NewRecorder()
			h.ServeHTTP(rr, req)
			if rr.Code != tt.want {
				t.Fatalf("status = %d, want %d", rr.Code, tt.want)
			}
		})
	}
}

func TestBodyLimitMiddlewareRejectsOversizedBody(t *testing.T) {
	h := bodyLimitMiddleware(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, err := io.ReadAll(r.Body)
		if err != nil {
			w.WriteHeader(http.StatusRequestEntityTooLarge)
			return
		}
		w.WriteHeader(http.StatusOK)
	}))
	body := strings.NewReader(strings.Repeat("x", maxRequestBodyBytes+1))
	req := httptest.NewRequest(http.MethodPost, "/api/v1/import", body)
	rr := httptest.NewRecorder()
	h.ServeHTTP(rr, req)
	if rr.Code != http.StatusRequestEntityTooLarge {
		t.Fatalf("status = %d, want 413", rr.Code)
	}
}

package ai

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/tzhnahida/VocabLock/internal/log"
)

type Client struct {
	http    *http.Client
	baseURL string
	apiKey  string
	model   string
}

type Config struct {
	BaseURL string `json:"base_url" yaml:"base_url"`
	APIKey  string `json:"api_key" yaml:"api_key"`
	Model   string `json:"model" yaml:"model"`
	Timeout time.Duration
}

type Message struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type chatRequest struct {
	Model       string    `json:"model"`
	Messages    []Message `json:"messages"`
	Temperature float64   `json:"temperature,omitempty"`
}

type chatResponse struct {
	Choices []struct {
		Message struct {
			Content string `json:"content"`
		} `json:"message"`
	} `json:"choices"`
}

func NewClient(cfg Config) *Client {
	transport := &http.Transport{
		Proxy: http.ProxyFromEnvironment,
	}
	return &Client{
		http: &http.Client{
			Transport: transport,
			Timeout:   cfg.Timeout,
		},
		baseURL: cfg.BaseURL,
		apiKey:  cfg.APIKey,
		model:   cfg.Model,
	}
}

func (c *Client) Chat(ctx context.Context, messages []Message, temperature float64) (string, error) {
	// Debug: log AI input
	var sysPrompt, userPrompt string
	for _, m := range messages {
		switch m.Role {
		case "system":
			sysPrompt = m.Content
		case "user":
			userPrompt = m.Content
		}
	}
	log.Debug("ai", "request model=%s temp=%.2f system_len=%d user_len=%d", c.model, temperature, len(sysPrompt), len(userPrompt))
	if len(sysPrompt) > 0 {
		log.Debug("ai", "system:\n%s", truncateLog(sysPrompt, 2000))
	}
	if len(userPrompt) > 0 {
		log.Debug("ai", "user:\n%s", truncateLog(userPrompt, 500))
	}

	var lastErr error
	for attempt := 1; attempt <= 3; attempt++ {
		reply, err := c.chatOnce(ctx, messages, temperature)
		if err == nil {
			log.Debug("ai", "response len=%d:\n%s", len(reply), truncateLog(reply, 2000))
			return reply, nil
		}
		lastErr = err
		log.Warn("ai", "attempt %d/3 failed: %v", attempt, err)
		if attempt < 3 {
			select {
			case <-ctx.Done():
				return "", ctx.Err()
			case <-time.After(time.Duration(attempt) * time.Second):
			}
		}
	}
	log.Error("ai", "failed after 3 attempts: %v", lastErr)
	return "", fmt.Errorf("chat failed after 3 attempts: %w", lastErr)
}

func truncateLog(s string, maxLen int) string {
	s = strings.TrimSpace(s)
	if len(s) <= maxLen {
		return s
	}
	return s[:maxLen] + fmt.Sprintf("\n... [truncated, total %d chars]", len(s))
}

func (c *Client) chatOnce(ctx context.Context, messages []Message, temperature float64) (string, error) {
	reqBody := chatRequest{
		Model:       c.model,
		Messages:    messages,
		Temperature: temperature,
	}

	body, err := json.Marshal(reqBody)
	if err != nil {
		return "", fmt.Errorf("marshal request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, "POST", c.baseURL+"/v1/chat/completions", bytes.NewReader(body))
	if err != nil {
		return "", fmt.Errorf("create request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+c.apiKey)

	resp, err := c.http.Do(req)
	if err != nil {
		return "", fmt.Errorf("http do: %w", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("read response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("api error %d: %s", resp.StatusCode, string(respBody))
	}

	var cr chatResponse
	if err := json.Unmarshal(respBody, &cr); err != nil {
		return "", fmt.Errorf("unmarshal response: %w", err)
	}

	if len(cr.Choices) == 0 {
		return "", fmt.Errorf("no choices in response")
	}

	return cr.Choices[0].Message.Content, nil
}

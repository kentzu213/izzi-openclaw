// Package installer handles provisioning from the Izzi API server
// and configuring OpenClaw with the received model configurations.
package installer

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"time"
)

const (
	provisionURL = "https://api.izziapi.com/v1/provision"
	timeout      = 30 * time.Second
)

// ProvisionResult contains the parsed server response
type ProvisionResult struct {
	ModelCount    int
	Plan          string
	Email         string
	LatestVersion string
	Warnings      []string
	RawConfig     map[string]interface{}
}

// provisionResponse is the raw JSON structure from the API
type provisionResponse struct {
	Version         string                   `json:"version"`
	Provider        map[string]interface{}   `json:"provider"`
	AgentModels     []map[string]interface{} `json:"agent_models"`
	InstallerLatest string                   `json:"installer_latest"`
	Checksums       map[string]string        `json:"checksums"`
	UserInfo        struct {
		Plan        string `json:"plan"`
		Role        string `json:"role"`
		EmailMasked string `json:"email_masked"`
	} `json:"user_info"`
	Meta struct {
		ProvisionRemaining int    `json:"provision_remaining"`
		Timestamp          string `json:"timestamp"`
	} `json:"_meta"`
	Warnings []string `json:"warnings"`
	Error    *struct {
		Type    string `json:"type"`
		Message string `json:"message"`
	} `json:"error"`
}

// Provision fetches configuration from the Izzi API server
func Provision(apiKey, deviceID, installerVersion string) (*ProvisionResult, error) {
	client := &http.Client{Timeout: timeout}

	body := strings.NewReader(`{"installer_version":"` + installerVersion + `","platform":"` + runtime.GOOS + `"}`)
	req, err := http.NewRequest("POST", provisionURL, body)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("x-api-key", apiKey)
	req.Header.Set("X-Device-ID", deviceID)
	req.Header.Set("X-Installer-Version", installerVersion)
	req.Header.Set("X-Platform", runtime.GOOS+"/"+runtime.GOARCH)
	req.Header.Set("User-Agent", "izzi-cli/"+installerVersion)

	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("connection failed: %w", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response: %w", err)
	}

	if resp.StatusCode == 401 {
		return nil, fmt.Errorf("invalid API key. Check your key at https://izziapi.com/dashboard")
	}
	if resp.StatusCode == 429 {
		return nil, fmt.Errorf("rate limited. Please wait a moment and try again")
	}
	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("server error (HTTP %d): %s", resp.StatusCode, string(respBody))
	}

	var pr provisionResponse
	if err := json.Unmarshal(respBody, &pr); err != nil {
		return nil, fmt.Errorf("failed to parse server response: %w", err)
	}

	if pr.Error != nil {
		return nil, fmt.Errorf("server error: %s", pr.Error.Message)
	}

	// Store raw config for OpenClaw configuration
	var rawConfig map[string]interface{}
	json.Unmarshal(respBody, &rawConfig)

	return &ProvisionResult{
		ModelCount:    len(pr.AgentModels),
		Plan:          pr.UserInfo.Plan,
		Email:         pr.UserInfo.EmailMasked,
		LatestVersion: pr.InstallerLatest,
		Warnings:      pr.Warnings,
		RawConfig:     rawConfig,
	}, nil
}

// ConfigureOpenClaw writes the Izzi provider configuration to openclaw.json
func ConfigureOpenClaw(config *ProvisionResult) error {
	configPath := findOpenClawConfig()
	if configPath == "" {
		return fmt.Errorf("OpenClaw config not found. Is OpenClaw installed?")
	}

	// Read existing config (strip UTF-8 BOM if present — common on Windows)
	data, err := os.ReadFile(configPath)
	if err != nil {
		return fmt.Errorf("failed to read openclaw.json: %w", err)
	}
	data = bytes.TrimPrefix(data, []byte{0xEF, 0xBB, 0xBF})

	var ocConfig map[string]interface{}
	if err := json.Unmarshal(data, &ocConfig); err != nil {
		return fmt.Errorf("failed to parse openclaw.json: %w", err)
	}

	// Build Izzi provider config from server response
	provider := config.RawConfig["provider"]
	if provider == nil {
		return fmt.Errorf("no provider config in server response")
	}

	// Update providers list
	providers, ok := ocConfig["mcpServers"]
	if !ok {
		providers = map[string]interface{}{}
	}

	// Add Izzi as API provider
	providerMap, ok := providers.(map[string]interface{})
	if !ok {
		providerMap = map[string]interface{}{}
	}
	providerMap["izzi"] = provider
	ocConfig["mcpServers"] = providerMap

	// Write back
	output, err := json.MarshalIndent(ocConfig, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to serialize config: %w", err)
	}

	if err := os.WriteFile(configPath, output, 0644); err != nil {
		return fmt.Errorf("failed to write openclaw.json: %w", err)
	}

	return nil
}

// findOpenClawConfig searches for openclaw.json in standard locations
func findOpenClawConfig() string {
	homeDir, _ := os.UserHomeDir()

	candidates := []string{}

	switch runtime.GOOS {
	case "windows":
		if appData := os.Getenv("APPDATA"); appData != "" {
			candidates = append(candidates, filepath.Join(appData, "openclaw", "openclaw.json"))
		}
		candidates = append(candidates, filepath.Join(homeDir, ".openclaw", "openclaw.json"))
	case "darwin":
		candidates = append(candidates,
			filepath.Join(homeDir, "Library", "Application Support", "openclaw", "openclaw.json"),
			filepath.Join(homeDir, ".openclaw", "openclaw.json"),
		)
	default: // linux
		if xdg := os.Getenv("XDG_CONFIG_HOME"); xdg != "" {
			candidates = append(candidates, filepath.Join(xdg, "openclaw", "openclaw.json"))
		}
		candidates = append(candidates,
			filepath.Join(homeDir, ".config", "openclaw", "openclaw.json"),
			filepath.Join(homeDir, ".openclaw", "openclaw.json"),
		)
	}

	for _, path := range candidates {
		if _, err := os.Stat(path); err == nil {
			return path
		}
	}
	return ""
}

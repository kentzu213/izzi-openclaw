// Package security provides device fingerprinting and self-integrity verification.
package security

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"runtime"
	"strings"
	"time"
)

// GetDeviceFingerprint generates a SHA256 hash of the machine hostname
// Used for abuse detection (tracking key sharing across devices)
func GetDeviceFingerprint() string {
	hostname, err := os.Hostname()
	if err != nil {
		hostname = "unknown"
	}

	// Include OS info for richer fingerprint
	raw := fmt.Sprintf("%s-%s-%s", hostname, runtime.GOOS, runtime.GOARCH)
	hash := sha256.Sum256([]byte(raw))
	return hex.EncodeToString(hash[:])
}

// GetSelfChecksum returns the SHA256 hash of the running binary
func GetSelfChecksum() (string, error) {
	exePath, err := os.Executable()
	if err != nil {
		return "", fmt.Errorf("cannot determine executable path: %w", err)
	}

	// Resolve symlinks
	exePath, err = resolveSymlinks(exePath)
	if err != nil {
		return "", fmt.Errorf("cannot resolve executable path: %w", err)
	}

	f, err := os.Open(exePath)
	if err != nil {
		return "", fmt.Errorf("cannot open executable: %w", err)
	}
	defer f.Close()

	h := sha256.New()
	if _, err := io.Copy(h, f); err != nil {
		return "", fmt.Errorf("cannot hash executable: %w", err)
	}

	return hex.EncodeToString(h.Sum(nil)), nil
}

// SelfVerify checks the running binary's SHA256 against the server checksums
func SelfVerify() error {
	selfHash, err := GetSelfChecksum()
	if err != nil {
		return fmt.Errorf("cannot compute self checksum: %w", err)
	}

	// Fetch checksums from server
	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Get("https://api.izziapi.com/v1/checksums")
	if err != nil {
		return fmt.Errorf("cannot reach checksum server: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return fmt.Errorf("checksum server returned %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("cannot read checksum response: %w", err)
	}

	// Check if our hash matches any known binary
	bodyStr := string(body)
	if strings.Contains(bodyStr, selfHash) {
		return nil // Match found
	}

	// Binary may not be in the checksum list yet (compiled locally)
	// This is a soft check — don't fail hard
	return fmt.Errorf("binary checksum not found in server registry (may be a dev build)")
}

// resolveSymlinks follows symlinks to get the real path
func resolveSymlinks(path string) (string, error) {
	if runtime.GOOS == "windows" {
		return path, nil // Windows doesn't commonly use symlinks for binaries
	}

	cmd := exec.Command("readlink", "-f", path)
	out, err := cmd.Output()
	if err != nil {
		return path, nil // Fallback to original path
	}
	return strings.TrimSpace(string(out)), nil
}

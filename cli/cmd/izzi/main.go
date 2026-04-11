// Izzi OpenClaw Installer CLI
// Compiled binary installer that replaces shell/PowerShell scripts.
// Built with Garble obfuscation to prevent casual reverse engineering.
package main

import (
	"fmt"
	"os"
	"strings"

	"github.com/kentzu213/izzi-openclaw/cli/internal/installer"
	"github.com/kentzu213/izzi-openclaw/cli/internal/security"
)

// Set via ldflags at build time
var (
	Version   = "dev"
	BuildTime = "unknown"
	GitCommit = "unknown"
)

func main() {
	fmt.Println()
	fmt.Println("╔══════════════════════════════════════════════════════╗")
	fmt.Println("║       🚀 Izzi x OpenClaw Installer (Binary)        ║")
	fmt.Println("║          Powered by izziapi.com                     ║")
	fmt.Printf("║          Version: %-33s  ║\n", Version)
	fmt.Println("╚══════════════════════════════════════════════════════╝")
	fmt.Println()

	// Parse arguments
	if len(os.Args) < 2 {
		printUsage()
		os.Exit(1)
	}

	cmd := os.Args[1]
	switch cmd {
	case "install":
		if len(os.Args) < 3 {
			fmt.Println("[ERROR] Missing API key")
			fmt.Println("Usage: izzi install <API_KEY>")
			os.Exit(1)
		}
		apiKey := os.Args[2]
		if !strings.HasPrefix(apiKey, "izzi-") {
			fmt.Println("[ERROR] Invalid API key format. Key must start with 'izzi-'")
			os.Exit(1)
		}
		runInstall(apiKey)

	case "verify":
		runVerify()

	case "version":
		fmt.Printf("Version:    %s\n", Version)
		fmt.Printf("Build Time: %s\n", BuildTime)
		fmt.Printf("Git Commit: %s\n", GitCommit)
		fmt.Printf("Device ID:  %s\n", security.GetDeviceFingerprint())

	case "checksum":
		runChecksum()

	default:
		fmt.Printf("[ERROR] Unknown command: %s\n", cmd)
		printUsage()
		os.Exit(1)
	}
}

func printUsage() {
	fmt.Println("Usage: izzi <command> [args]")
	fmt.Println()
	fmt.Println("Commands:")
	fmt.Println("  install <API_KEY>  Install/configure OpenClaw with Izzi provider")
	fmt.Println("  verify             Verify installer integrity")
	fmt.Println("  checksum           Show checksums of local installer files")
	fmt.Println("  version            Show version info")
	fmt.Println()
	fmt.Println("Examples:")
	fmt.Println("  izzi install izzi-abc123def456")
	fmt.Println("  izzi verify")
}

func runInstall(apiKey string) {
	// Step 1: Self-integrity check
	fmt.Println("[1/5] Verifying installer integrity...")
	if err := security.SelfVerify(); err != nil {
		fmt.Printf("  [WARN] %s\n", err)
		fmt.Println("  Continuing anyway...")
	} else {
		fmt.Println("  [OK] Installer integrity verified")
	}

	// Step 2: Device fingerprint
	fmt.Println("[2/5] Generating device fingerprint...")
	deviceID := security.GetDeviceFingerprint()
	fmt.Printf("  [OK] Device ID: %s...%s\n", deviceID[:8], deviceID[len(deviceID)-4:])

	// Step 3: Provision from server
	fmt.Println("[3/5] Fetching configuration from server...")
	config, err := installer.Provision(apiKey, deviceID, Version)
	if err != nil {
		fmt.Printf("  [ERROR] %s\n", err)
		os.Exit(1)
	}
	fmt.Printf("  [OK] Received %d models (plan: %s)\n", config.ModelCount, config.Plan)

	// Handle warnings
	for _, w := range config.Warnings {
		fmt.Printf("  [WARN] %s\n", w)
	}

	// Step 4: Find and configure OpenClaw
	fmt.Println("[4/5] Configuring OpenClaw...")
	if err := installer.ConfigureOpenClaw(config); err != nil {
		fmt.Printf("  [ERROR] %s\n", err)
		os.Exit(1)
	}
	fmt.Println("  [OK] OpenClaw configured successfully")

	// Step 5: Version check
	fmt.Println("[5/5] Checking for updates...")
	if config.LatestVersion != "" && config.LatestVersion != Version {
		fmt.Printf("  [WARN] Installer v%s is outdated. Latest: v%s\n", Version, config.LatestVersion)
		fmt.Println("  Download: https://github.com/kentzu213/izzi-openclaw/releases/latest")
	} else {
		fmt.Println("  [OK] Installer is up to date")
	}

	fmt.Println()
	fmt.Println("╔══════════════════════════════════════════════════════╗")
	fmt.Println("║  ✅ Installation complete!                          ║")
	fmt.Printf("║  Models: %-43d ║\n", config.ModelCount)
	fmt.Printf("║  Plan:   %-43s ║\n", config.Plan)
	fmt.Println("║  Restart OpenClaw to apply changes.                 ║")
	fmt.Println("╚══════════════════════════════════════════════════════╝")
}

func runVerify() {
	fmt.Println("Verifying installer integrity...")
	if err := security.SelfVerify(); err != nil {
		fmt.Printf("[FAIL] %s\n", err)
		fmt.Println("Download official: https://github.com/kentzu213/izzi-openclaw/releases/latest")
		os.Exit(1)
	}
	fmt.Println("[OK] Installer integrity verified (SHA256 match)")
}

func runChecksum() {
	hash, err := security.GetSelfChecksum()
	if err != nil {
		fmt.Printf("[ERROR] %s\n", err)
		os.Exit(1)
	}
	fmt.Printf("Self SHA256: %s\n", hash)
	fmt.Printf("Binary:      %s\n", os.Args[0])
}

#!/usr/bin/env bash
# Generate SHA256 checksums for all installer files
# Run this locally before creating a release or to verify file integrity
set -e

echo "=== SHA256 Checksums for izzi-openclaw ==="
echo ""

FILES=(
  "install.ps1"
  "install.sh"
  "install-vps.sh"
  "install.bat"
  "fix.ps1"
  "fix.sh"
  "fix.bat"
  "startup.ps1"
  "startup.bat"
)

OUTFILE="SHA256SUMS.txt"
> "$OUTFILE"

for f in "${FILES[@]}"; do
  if [ -f "$f" ]; then
    HASH=$(sha256sum "$f" | cut -d' ' -f1)
    echo "$HASH  $f" >> "$OUTFILE"
    echo "  ✅ $HASH  $f"
  else
    echo "  ⚠️  SKIP: $f (not found)"
  fi
done

echo ""
echo "  Written to: $OUTFILE"
echo ""
cat "$OUTFILE"

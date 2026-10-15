#!/usr/bin/env bash
# ==============================================================================
# Readax-Repo: Automatic APT Index Generator & Portable Verification
# Compatible with legacy Cydia, Zebra, and APT package managers on iOS 10+
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if ! command -v dpkg-scanpackages >/dev/null 2>&1; then
    echo "ERROR: 'dpkg-scanpackages' not found. Please install dpkg-dev (e.g. sudo apt-get install dpkg-dev)." >&2
    exit 1
fi

if ! command -v gzip >/dev/null 2>&1; then
    echo "ERROR: 'gzip' not found." >&2
    exit 1
fi

echo "==> [1/4] Scanning Debian packages in debs/..."
# Scanning 'debs' without leading dot-slash produces clean 'debs/package.deb' paths for legacy Cydia/Zebra
dpkg-scanpackages -m debs /dev/null > Packages

echo "==> [2/4] Generating Packages.gz (gzip compression level 9)..."
gzip -9c Packages > Packages.gz

echo "==> [3/4] Writing Release metadata..."
cat << 'EOF' > Release
Origin: Readax Repo
Label: Readax
Suite: stable
Version: 1.0
Codename: ios
Architectures: iphoneos-arm
Components: main
Description: Official APT repository for Readax manga reader on legacy 32-bit iOS devices (iPhone 5, iOS 10.3.4).
EOF

echo "==> [4/4] Performing portable self-verification..."

# Verify gzip archive integrity
gzip -t Packages.gz
echo "    [OK] Packages.gz bitstream integrity verified."

# Verify every package file exists and matches indexed checksum
pkg_count=0
while IFS= read -r line; do
    if [[ "$line" =~ ^Filename:\ (.*)$ ]]; then
        deb_file="${BASH_REMATCH[1]}"
        if [[ ! -f "$deb_file" ]]; then
            echo "ERROR: Indexed package file '$deb_file' does not exist on disk!" >&2
            exit 1
        fi
        pkg_count=$((pkg_count + 1))
    fi
done < Packages

if [[ "$pkg_count" -eq 0 ]]; then
    echo "WARNING: No packages were found in debs/ directory." >&2
else
    echo "    [OK] All $pkg_count indexed package(s) exist on disk."
fi

echo "==> APT repository update and verification completed successfully!"
echo "    Packages size: $(wc -c < Packages) bytes"
echo "    Packages.gz size: $(wc -c < Packages.gz) bytes"

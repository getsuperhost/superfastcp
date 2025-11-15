#!/usr/bin/env bash
set -euo pipefail

# Installs GitHub CLI (gh) into $HOME/.local/bin without requiring sudo
LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"
PATH="$LOCAL_BIN:$PATH"

if command -v gh >/dev/null 2>&1; then
  echo "gh already installed: $(gh --version)"
  exit 0
fi

echo "Fetching latest gh release info from GitHub API..."
LATEST_JSON=$(curl -sL "https://api.github.com/repos/cli/cli/releases/latest")
TAG_NAME=$(echo "$LATEST_JSON" | grep -m1 -oP '"tag_name":\s*"\K[^"]+')
TAG_NO_V=${TAG_NAME#v}
if [ -z "$TAG_NAME" ]; then
  echo "Could not determine latest GitHub CLI release. Aborting." >&2
  exit 1
fi
echo "Latest release: $TAG_NAME"

ARCH="$(uname -m)"
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
case "$ARCH" in
  x86_64|amd64) ARCH_AMD=amd64 ;;
  aarch64|arm64) ARCH_AMD=arm64 ;;
  *) echo "Unsupported arch: $ARCH" && exit 1 ;;
esac

ASSET_NAME="gh_${TAG_NO_V}_${OS}_${ARCH_AMD}.tar.gz"
echo "Looking for asset: $ASSET_NAME"
ASSET_URL=$(echo "$LATEST_JSON" | grep -oP '"browser_download_url": "\K[^"]+' | grep "$ASSET_NAME" || true)
if [ -z "$ASSET_URL" ]; then
  echo "Exact asset not found, trying a best-effort match for OS/arch..."
  ASSET_URL=$(echo "$LATEST_JSON" | grep -oP '"browser_download_url": "\K[^"]+' | grep -E "${OS}.*${ARCH_AMD}\.tar\.gz" || true)
  if [ -n "$ASSET_URL" ]; then
    echo "Found asset via fallback: $ASSET_URL"
  fi
fi

if [ -z "$ASSET_URL" ]; then
  echo "Could not find a release asset for $ASSET_NAME. Aborting." >&2
  exit 1
fi

TMP_DIR=$(mktemp -d)
echo "Downloading $ASSET_NAME to $TMP_DIR"
curl -sL "$ASSET_URL" -o "$TMP_DIR/$ASSET_NAME"

echo "Extracting..."
tar -xzf "$TMP_DIR/$ASSET_NAME" -C "$TMP_DIR"

BIN_PATH="$TMP_DIR/gh_${TAG_NO_V}_${OS}_${ARCH_AMD}/bin/gh"
if [ ! -f "$BIN_PATH" ]; then
  # Some releases place binary in subdir like 'gh_2.x.y_linux_amd64/bin/gh'
  BIN_PATH=$(find "$TMP_DIR" -type f -name gh -print -quit || true)
fi
if [ ! -f "$BIN_PATH" ]; then
  echo "gh binary not found in extracted tarball" >&2
  exit 1
fi

echo "Installing gh to $LOCAL_BIN"
install -m 0755 "$BIN_PATH" "$LOCAL_BIN/gh"
hash -r || true

echo "Installed gh: $($LOCAL_BIN/gh --version || echo 'unknown')"
echo "Cleaning up..."
rm -rf "$TMP_DIR"

echo "Done. Add $LOCAL_BIN to PATH if not already set. Example: export PATH=\"$LOCAL_BIN:$PATH\""
exit 0

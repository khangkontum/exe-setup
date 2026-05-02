#!/usr/bin/env bash
set -euo pipefail

# exe.dev VM setup — only installs what's NOT already in the exeuntu image.
# bootstrap.sh fetches this repo and runs this script on first boot.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
LOG_DIR="$HOME/.cache/exe-setup"
LOG_FILE="$LOG_DIR/setup-$(date +%Y%m%d-%H%M%S).log"

mkdir -p "$LOG_DIR"
ln -sfn "$LOG_FILE" "$LOG_DIR/latest.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/common.sh"

echo "[exe-setup] Starting..."
echo "[exe-setup] Source: $SCRIPT_DIR"
echo "[exe-setup] Log: $LOG_FILE"

require_cmds awk curl jq mktemp tar tee

# ── Node.js LTS ────────────────────────────────────────────────
# Install Node.js directly from tarball — no nvm overhead (~33MB saved).
# If nvm is present and already manages node, use it; otherwise install standalone.
export NVM_DIR="$HOME/.nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
  # shellcheck disable=SC1091
  . "$NVM_DIR/nvm.sh"
  nvm install --lts
  nvm alias default 'lts/*'
  nvm use default
elif command -v node >/dev/null 2>&1; then
  echo "[exe-setup] Node.js already installed: $(node --version), skipping"
else
  NODE_VERSION=$(curl -fsSL https://nodejs.org/dist/index.json | jq -r '[.[] | select(.lts != false)][0].version')
  echo "[exe-setup] Installing Node.js $NODE_VERSION (standalone)..."
  NODE_ARCH=$(uname -m)
  NODE_TAR="${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz"
  TMPDIR=$(mktemp -d /tmp/node-install.XXXXXX)
  trap 'rm -rf "$TMPDIR"' EXIT
  curl -fL --retry 3 "https://nodejs.org/dist/${NODE_VERSION}/${NODE_TAR}" -o "$TMPDIR/${NODE_TAR}"
  tar xJf "$TMPDIR/${NODE_TAR}" -C "$TMPDIR"
  sudo cp -a "$TMPDIR/node-${NODE_VERSION}-linux-${NODE_ARCH}"/* /usr/local/
  echo "[exe-setup] Installed $(node --version) to /usr/local"

# ── pnpm ────────────────────────────────────────────────────────
if command -v corepack >/dev/null 2>&1 && corepack enable && corepack prepare pnpm@latest --activate; then
  echo "[exe-setup] pnpm activated via Corepack"
else
  echo "[exe-setup] WARNING: Corepack unavailable or failed; falling back to npm install -g pnpm"
  npm install -g pnpm
fi

# ── Shell helpers and defaults ─────────────────────────────────
mkdir -p "$HOME/.config/exe-setup"
cp "$SCRIPT_DIR/lib/shell.sh" "$HOME/.config/exe-setup/shell.sh"
upsert_bashrc_source

# Load the freshly written shell defaults for this setup session too.
# shellcheck disable=SC1091
. "$HOME/.config/exe-setup/shell.sh"

# ── Summary ────────────────────────────────────────────────────
echo "[exe-setup] Versions:"
echo "[exe-setup]   node:  $(node --version 2>/dev/null || echo unavailable)"
echo "[exe-setup]   npm:   $(npm --version 2>/dev/null || echo unavailable)"
echo "[exe-setup]   pnpm:  $(pnpm --version 2>/dev/null || echo unavailable)"
echo "[exe-setup]   pi:    $(pi --version 2>/dev/null || echo unavailable)"
echo "[exe-setup]   codex: $(codex --version 2>/dev/null || echo unavailable)"

echo "[exe-setup] Done! Open a new shell or run 'source ~/.bashrc'."
echo "[exe-setup] Helpers: update-pi [release-tag], update-codex [release-tag], list-models [DB_PATH]"

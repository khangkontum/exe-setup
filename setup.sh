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

# ── Node.js LTS (nvm is pre-installed, but no node version) ────
export NVM_DIR="$HOME/.nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
  # shellcheck disable=SC1091
  . "$NVM_DIR/nvm.sh"
else
  echo "[exe-setup] ERROR: nvm not found at $NVM_DIR/nvm.sh" >&2
  exit 1
fi

if ! command -v nvm >/dev/null 2>&1; then
  echo "[exe-setup] ERROR: nvm did not load correctly" >&2
  exit 1
fi

nvm install --lts
nvm alias default 'lts/*'
nvm use default

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
echo "[exe-setup] Helpers: update-pi [release-tag], update-codex [release-tag], shelley_models [DB_PATH]"

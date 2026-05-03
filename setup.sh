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
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/shelley-models.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/shelley-notifications.sh"

echo "[exe-setup] Starting..."
echo "[exe-setup] Source: $SCRIPT_DIR"
echo "[exe-setup] Log: $LOG_FILE"

require_cmds awk curl git jq mktemp tar tee

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
elif command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
  echo "[exe-setup] Node.js already installed: $(node --version), npm: $(npm --version), skipping"
else
  if command -v node >/dev/null 2>&1; then
    echo "[exe-setup] Node.js found without npm; installing standalone Node.js LTS..."
  fi
  NODE_VERSION=$(curl -fsSL https://nodejs.org/dist/index.json | jq -r '[.[] | select(.lts != false)][0].version')
  echo "[exe-setup] Installing Node.js $NODE_VERSION (standalone)..."
  case "$(uname -m)" in
    x86_64) NODE_ARCH="x64" ;;
    aarch64) NODE_ARCH="arm64" ;;
    *) NODE_ARCH="$(uname -m)" ;;
  esac
  NODE_TAR="node-${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz"
  NODE_TMPDIR=$(mktemp -d /tmp/node-install.XXXXXX)
  trap 'rm -rf "$NODE_TMPDIR"' EXIT
  curl -fL --retry 3 "https://nodejs.org/dist/${NODE_VERSION}/${NODE_TAR}" -o "$NODE_TMPDIR/${NODE_TAR}"
  tar xJf "$NODE_TMPDIR/${NODE_TAR}" -C "$NODE_TMPDIR"
  sudo cp -a "$NODE_TMPDIR/node-${NODE_VERSION}-linux-${NODE_ARCH}"/* /usr/local/
  echo "[exe-setup] Installed $(node --version) to /usr/local"
fi

# ── pnpm ────────────────────────────────────────────────────────
mkdir -p "$HOME/.local/bin"
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

if command -v corepack >/dev/null 2>&1 && corepack enable --install-directory "$HOME/.local/bin" && corepack prepare pnpm@latest --activate; then
  echo "[exe-setup] pnpm activated via Corepack in ~/.local/bin"
else
  echo "[exe-setup] WARNING: Corepack unavailable or failed; falling back to npm install -g --prefix ~/.local pnpm"
  if ! command -v npm >/dev/null 2>&1; then
    echo "[exe-setup] ERROR: npm is unavailable; cannot install pnpm" >&2
    exit 1
  fi
  npm install -g --prefix "$HOME/.local" pnpm
fi

# ── Git global config and hooks ───────────────────────────────
git config --global user.email "git@nhkhang.com"
git config --global user.name "Hoang-Khang Nguyen"
mkdir -p "$HOME/.config/git/hooks"
cp "$SCRIPT_DIR/lib/git-hooks/commit-msg" "$HOME/.config/git/hooks/commit-msg"
chmod +x "$HOME/.config/git/hooks/commit-msg"
git config --global core.hooksPath "$HOME/.config/git/hooks"
echo "[exe-setup] git config: user.email=git@nhkhang.com, user.name=Hoang-Khang Nguyen"
echo "[exe-setup] git hooks: core.hooksPath=$HOME/.config/git/hooks (strips Co-Authored-by trailers)"

# ── Shell helpers and defaults ─────────────────────────────────
mkdir -p "$HOME/.config/exe-setup"
cp "$SCRIPT_DIR/lib/shell.sh" "$HOME/.config/exe-setup/shell.sh"
if [ -f "$SCRIPT_DIR/models.json" ] && [ ! -f "$HOME/.config/exe-setup/models.json" ]; then
  cp "$SCRIPT_DIR/models.json" "$HOME/.config/exe-setup/models.json"
fi
if [ -f "$SCRIPT_DIR/AGENTS.append.md" ]; then
  cp "$SCRIPT_DIR/AGENTS.append.md" "$HOME/.config/exe-setup/AGENTS.append.md"
fi
upsert_bashrc_source

# Load the freshly written shell defaults for this setup session too.
# shellcheck disable=SC1091
. "$HOME/.config/exe-setup/shell.sh"

# ── mise ────────────────────────────────────────────────────────
install-mise

# ── Codex defaults ──────────────────────────────────────────────
install_codex_config

# ── Shelley custom models ──────────────────────────────────────
SUB_AGENTS_MODEL=""
if [ -f "$HOME/.config/exe-setup/models.json" ]; then
  sync_shelley_models "$HOME/.config/exe-setup/models.json" || \
    echo "[exe-setup] WARNING: Shelley custom model sync failed; edit ~/.config/exe-setup/models.json and rerun setup.sh later"
  SUB_AGENTS_MODEL=$(resolve_sub_agent_model_id "$HOME/.config/exe-setup/models.json") || \
    echo "[exe-setup] WARNING: Shelley sub-agent model resolution failed"
fi

# ── Shelley server notifications ─────────────────────────────
sync_shelley_notifications || \
  echo "[exe-setup] WARNING: Shelley notification setup failed; check ntfy settings and rerun setup.sh later"

# ── Shelley AGENTS instructions ────────────────────────────────
if [ -f "$HOME/.config/exe-setup/AGENTS.append.md" ]; then
  apply_shelley_agents_append "$HOME/.config/exe-setup/AGENTS.append.md" "$SUB_AGENTS_MODEL" || \
    echo "[exe-setup] WARNING: Shelley AGENTS instruction update failed"
fi

# ── Shelley restart ────────────────────────────────────────────
restart_shelley_after_setup_changes || \
  echo "[exe-setup] WARNING: Shelley restart failed; setup changes may require a manual restart"

# ── Summary ────────────────────────────────────────────────────
echo "[exe-setup] Versions:"
echo "[exe-setup]   node:  $(node --version 2>/dev/null || echo unavailable)"
echo "[exe-setup]   npm:   $(npm --version 2>/dev/null || echo unavailable)"
echo "[exe-setup]   pnpm:  $(pnpm --version 2>/dev/null || echo unavailable)"
echo "[exe-setup]   rustc: $(rustc --version 2>/dev/null || echo unavailable)"
echo "[exe-setup]   cargo: $(cargo --version 2>/dev/null || echo unavailable)"
echo "[exe-setup]   mise:  $(mise --version 2>/dev/null || echo unavailable)"
echo "[exe-setup]   pi:    $(pi --version 2>/dev/null || echo unavailable)"
echo "[exe-setup]   codex: $(codex --version 2>/dev/null || echo unavailable)"

echo "[exe-setup] Done! Open a new shell or run 'source ~/.bashrc'."
echo "[exe-setup] Helpers: update-pi [release-tag], update-codex [release-tag], list-models [DB_PATH], install-rust [toolchain], install-mise [version], install-tailscale, join-tailscale"

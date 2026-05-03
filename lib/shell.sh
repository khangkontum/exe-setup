# exe.dev VM shell helpers and defaults.
# Managed by exe-setup. Edit the source repo instead: https://github.com/khangkontum/exe-setup

_exe_path_prepend() {
  [ -n "${1:-}" ] || return 0
  case ":$PATH:" in
    *":$1:"*) ;;
    *) export PATH="$1:$PATH" ;;
  esac
}

_exe_require_cmds() {
  local missing=0
  local cmd
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "[exe-setup] ERROR: required command not found: $cmd" >&2
      missing=1
    fi
  done
  [ "$missing" -eq 0 ]
}

_exe_github_release_tag() {
  local repo="$1"
  local requested="${2:-}"
  local json tag

  if [ -n "$requested" ]; then
    printf '%s\n' "$requested"
    return 0
  fi

  json=$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest") || return 1
  tag=$(printf '%s' "$json" | jq -r '.tag_name') || return 1
  if [ -z "$tag" ] || [ "$tag" = "null" ]; then
    return 1
  fi
  printf '%s\n' "$tag"
}

export CARGO_HOME="${CARGO_HOME:-$HOME/.cargo}"
export RUSTUP_HOME="${RUSTUP_HOME:-$HOME/.rustup}"

_exe_path_prepend "$CARGO_HOME/bin"
_exe_path_prepend "$HOME/.local/bin"
_exe_path_prepend "$HOME/.local/pi"

export EDITOR="${EDITOR:-vim}"
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

# List available Shelley models from local SQLite DB.
# Usage: list-models [DB_PATH]
#   DB_PATH defaults to /home/exedev/.config/shelley/shelley.db
list-models() {
  local db_path="${1:-/home/exedev/.config/shelley/shelley.db}"

  _exe_require_cmds sqlite3 || return 1

  if [ ! -f "$db_path" ]; then
    echo "[exe-setup] ERROR: Shelley DB not found at $db_path" >&2
    return 1
  fi

  sqlite3 -header -column "$db_path" "SELECT model_id, display_name, provider_type, model_name, max_tokens, tags, reasoning_effort FROM models ORDER BY model_id;"
}


# Install Rust via rustup with common developer components.
# Usage: install-rust [toolchain]
#   toolchain defaults to stable.
#   RUST_COMPONENTS defaults to: rustfmt clippy rust-src rust-analyzer
install-rust() {
  local toolchain="${1:-stable}"
  local components="${RUST_COMPONENTS:-rustfmt clippy rust-src rust-analyzer}"
  local tmpdir installer current component

  if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    cat <<'EOF'
Usage: install-rust [toolchain]

Installs/updates rustup, selects the requested toolchain (default: stable), and
adds common components: rustfmt, clippy, rust-src, rust-analyzer.

Set RUST_COMPONENTS="rustfmt clippy" to override the component list.
EOF
    return 0
  fi

  export CARGO_HOME="${CARGO_HOME:-$HOME/.cargo}"
  export RUSTUP_HOME="${RUSTUP_HOME:-$HOME/.rustup}"
  _exe_path_prepend "$CARGO_HOME/bin"

  if command -v rustup >/dev/null 2>&1; then
    current=$(rustup --version 2>/dev/null | head -n 1 || echo "installed")
    echo "[install-rust] rustup already installed: $current"
  else
    _exe_require_cmds curl mktemp sh || return 1

    tmpdir=$(mktemp -d /tmp/install-rust.XXXXXX) || return 1
    trap 'rm -rf "$tmpdir"; trap - RETURN' RETURN
    installer="$tmpdir/rustup-init.sh"

    echo "[install-rust] Downloading official rustup installer..."
    curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs -o "$installer" || return 1

    echo "[install-rust] Installing Rust toolchain: $toolchain..."
    sh "$installer" -y --no-modify-path --default-toolchain "$toolchain" || return 1
  fi

  hash -r 2>/dev/null || true
  if ! command -v rustup >/dev/null 2>&1; then
    echo "[install-rust] ERROR: rustup command was not found after install" >&2
    return 1
  fi

  echo "[install-rust] Ensuring toolchain '$toolchain' is installed and default..."
  rustup toolchain install "$toolchain" || return 1
  rustup default "$toolchain" || return 1

  if [ -n "$components" ]; then
    for component in $components; do
      echo "[install-rust] Adding component: $component"
      rustup component add "$component" --toolchain "$toolchain" || return 1
    done
  fi

  hash -r 2>/dev/null || true

  echo "[install-rust] Ready:"
  echo "[install-rust]   rustc:  $(rustc --version 2>/dev/null || echo unavailable)"
  echo "[install-rust]   cargo:  $(cargo --version 2>/dev/null || echo unavailable)"
  echo "[install-rust]   rustup: $(rustup --version 2>/dev/null | head -n 1 || echo unavailable)"
}

_exe_tailscale_hostname() {
  local raw

  raw="${TAILSCALE_HOSTNAME:-}"
  if [ -z "$raw" ]; then
    raw=$(hostname -s 2>/dev/null || hostname 2>/dev/null || printf 'exe-vm')
  fi

  raw=$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g; s/--*/-/g; s/^-//; s/-$//')
  [ -n "$raw" ] || raw="exe-vm"
  printf '%s\n' "$raw"
}

# Install Tailscale without joining a tailnet.
# Usage: install-tailscale
install-tailscale() {
  local tmpdir installer current

  if command -v tailscale >/dev/null 2>&1; then
    current=$(tailscale version 2>/dev/null | head -n 1 || echo "installed")
    echo "[install-tailscale] Tailscale already installed: $current"
  else
    _exe_require_cmds curl mktemp sudo sh || return 1

    tmpdir=$(mktemp -d /tmp/install-tailscale.XXXXXX) || return 1
    trap 'rm -rf "$tmpdir"; trap - RETURN' RETURN
    installer="$tmpdir/install.sh"

    echo "[install-tailscale] Downloading official Tailscale installer..."
    curl -fsSL https://tailscale.com/install.sh -o "$installer" || return 1

    echo "[install-tailscale] Installing Tailscale..."
    sudo sh "$installer" || return 1
  fi

  if ! command -v tailscale >/dev/null 2>&1; then
    echo "[install-tailscale] ERROR: tailscale command was not found after install" >&2
    return 1
  fi

  if command -v systemctl >/dev/null 2>&1; then
    echo "[install-tailscale] Enabling and starting tailscaled..."
    sudo systemctl enable --now tailscaled || return 1
  fi

  echo "[install-tailscale] Ready: $(tailscale version 2>/dev/null | head -n 1 || echo installed)"
}

# Join this VM to Tailscale using a reusable auth key.
# Usage: join-tailscale [AUTH_KEY] [tailscale up args...]
# Recommended: run join-tailscale with no AUTH_KEY and paste the key at the hidden prompt.
# Set TAILSCALE_HOSTNAME to override the default hostname.
join-tailscale() {
  local auth_key=""
  local hostname=""
  local xtrace_was_on=0
  local status=0

  if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    cat <<'EOF'
Usage: join-tailscale [AUTH_KEY] [tailscale up args...]

Installs Tailscale if needed, prompts for a reusable auth key when AUTH_KEY is
omitted, then runs tailscale up with --auth-key and --hostname.

Examples:
  join-tailscale
  TAILSCALE_HOSTNAME=my-vm join-tailscale
  join-tailscale --ssh --accept-routes
EOF
    return 0
  fi

  if [ $# -gt 0 ] && [ "${1#-}" = "$1" ]; then
    auth_key="$1"
    shift
    echo "[join-tailscale] WARNING: passing auth keys as arguments may leave them in shell history; prefer the hidden prompt." >&2
  fi

  install-tailscale || return 1
  _exe_require_cmds sudo || return 1

  if sudo tailscale status --self >/dev/null 2>&1; then
    echo "[join-tailscale] Already joined to Tailscale:"
    sudo tailscale status --self
    return 0
  fi

  if [ -z "$auth_key" ]; then
    printf '[join-tailscale] Paste reusable Tailscale auth key (input hidden): ' >&2
    if [ -t 0 ]; then
      IFS= read -r -s auth_key
      printf '\n' >&2
    else
      IFS= read -r auth_key
    fi
  fi

  if [ -z "$auth_key" ]; then
    echo "[join-tailscale] ERROR: empty auth key" >&2
    return 1
  fi

  case "$auth_key" in
    tskey-auth-*|tskey-client-*) ;;
    *) echo "[join-tailscale] WARNING: auth key does not look like a Tailscale key" >&2 ;;
  esac

  hostname=$(_exe_tailscale_hostname)
  echo "[join-tailscale] Joining tailnet as $hostname..."

  case "$-" in
    *x*) xtrace_was_on=1; set +x ;;
  esac

  if sudo tailscale up --auth-key="$auth_key" --hostname="$hostname" "$@"; then
    status=0
  else
    status=$?
  fi

  auth_key=""
  unset auth_key
  [ "$xtrace_was_on" -eq 1 ] && set -x

  [ "$status" -eq 0 ] || return "$status"

  echo "[join-tailscale] Joined. Self:"
  sudo tailscale status --self
}

update-pi() {
  local REPO="badlogic/pi-mono"
  local ASSET="pi-linux-x64.tar.gz"
  local INSTALL_DIR="$HOME/.local"
  local TARGET="${1:-}"
  local RELEASE CURRENT TMPDIR EXTRACT_DIR BACKUP_DIR

  _exe_require_cmds curl jq tar mktemp || return 1

  RELEASE=$(_exe_github_release_tag "$REPO" "$TARGET") || {
    echo "[update-pi] ERROR: Could not resolve release tag" >&2
    return 1
  }

  if command -v pi >/dev/null 2>&1; then
    CURRENT=$(pi --version 2>/dev/null || echo "unknown")
  elif [ -x "$INSTALL_DIR/pi/pi" ]; then
    CURRENT=$("$INSTALL_DIR/pi/pi" --version 2>/dev/null || echo "unknown")
  else
    CURRENT="none"
  fi

  echo "[update-pi] Current: $CURRENT  Target: $RELEASE"

  TMPDIR=$(mktemp -d /tmp/update-pi.XXXXXX) || return 1
  trap 'rm -rf "$TMPDIR"; trap - RETURN' RETURN
  EXTRACT_DIR="$TMPDIR/extract"
  mkdir -p "$EXTRACT_DIR" "$INSTALL_DIR"

  echo "[update-pi] Downloading $ASSET..."
  curl -fL --retry 3 "https://github.com/$REPO/releases/download/$RELEASE/$ASSET" -o "$TMPDIR/$ASSET"

  echo "[update-pi] Extracting..."
  tar xzf "$TMPDIR/$ASSET" -C "$EXTRACT_DIR"

  if [ ! -x "$EXTRACT_DIR/pi/pi" ]; then
    echo "[update-pi] ERROR: archive did not contain executable pi/pi" >&2
    return 1
  fi

  chmod +x "$EXTRACT_DIR/pi/pi"
  BACKUP_DIR="$INSTALL_DIR/pi.backup.$(date +%Y%m%d-%H%M%S)"

  if [ -e "$INSTALL_DIR/pi" ]; then
    mv "$INSTALL_DIR/pi" "$BACKUP_DIR"
  fi

  if mv "$EXTRACT_DIR/pi" "$INSTALL_DIR/pi"; then
    rm -rf "$BACKUP_DIR"
  else
    echo "[update-pi] ERROR: install failed; restoring previous install" >&2
    rm -rf "$INSTALL_DIR/pi"
    if [ -e "$BACKUP_DIR" ]; then
      mv "$BACKUP_DIR" "$INSTALL_DIR/pi"
    fi
    return 1
  fi

  echo "[update-pi] Updated to $("$INSTALL_DIR/pi/pi" --version)"
}

update-codex() {
  local REPO="openai/codex"
  local ASSET="codex-x86_64-unknown-linux-musl.tar.gz"
  local BINARY="codex-x86_64-unknown-linux-musl"
  local INSTALL_DIR="/usr/local/bin"
  local TARGET="${1:-}"
  local RELEASE CURRENT TMPDIR

  _exe_require_cmds curl jq tar mktemp sudo install || return 1

  RELEASE=$(_exe_github_release_tag "$REPO" "$TARGET") || {
    echo "[update-codex] ERROR: Could not resolve release tag" >&2
    return 1
  }

  if command -v codex >/dev/null 2>&1; then
    CURRENT=$(codex --version 2>/dev/null || echo "unknown")
  else
    CURRENT="none"
  fi

  echo "[update-codex] Current: $CURRENT  Target: $RELEASE"

  TMPDIR=$(mktemp -d /tmp/update-codex.XXXXXX) || return 1
  trap 'rm -rf "$TMPDIR"; trap - RETURN' RETURN

  echo "[update-codex] Downloading $ASSET..."
  curl -fL --retry 3 "https://github.com/$REPO/releases/download/$RELEASE/$ASSET" -o "$TMPDIR/$ASSET"

  echo "[update-codex] Extracting..."
  tar xzf "$TMPDIR/$ASSET" -C "$TMPDIR" "$BINARY"

  if [ ! -x "$TMPDIR/$BINARY" ]; then
    echo "[update-codex] ERROR: archive did not contain executable $BINARY" >&2
    return 1
  fi

  sudo install -m 0755 "$TMPDIR/$BINARY" "$INSTALL_DIR/codex"
  echo "[update-codex] Updated to $(codex --version)"
}

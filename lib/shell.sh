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

_exe_path_prepend "$HOME/.local/bin"
_exe_path_prepend "$HOME/.local/pi"

export EDITOR="${EDITOR:-vim}"
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

# List available Shelley models from local SQLite DB.
# Usage: shelley_models [DB_PATH]
#   DB_PATH defaults to /home/exedev/.config/shelley/shelley.db
shelley_models() {
  local db_path="${1:-/home/exedev/.config/shelley/shelley.db}"

  _exe_require_cmds sqlite3 || return 1

  if [ ! -f "$db_path" ]; then
    echo "[exe-setup] ERROR: Shelley DB not found at $db_path" >&2
    return 1
  fi

  sqlite3 -header -column "$db_path" "SELECT model_id, display_name, provider_type, model_name, max_tokens, tags, reasoning_effort FROM models ORDER BY model_id;"
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

#!/usr/bin/env bash
# Common setup helpers for exe-setup.

require_cmds() {
  local missing=0
  local cmd
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "[exe-setup] ERROR: required command not found: $cmd" >&2
      missing=1
    fi
  done
  if [ "$missing" -ne 0 ]; then
    exit 1
  fi
}

upsert_bashrc_source() {
  local bashrc="$HOME/.bashrc"
  local start_marker="# >>> exe-setup >>>"
  local end_marker="# <<< exe-setup <<<"
  local tmpfile

  touch "$bashrc"
  tmpfile=$(mktemp /tmp/exe-bashrc.XXXXXX)
  awk -v start="$start_marker" -v end="$end_marker" '
    $0 == start { skip = 1; next }
    $0 == end { skip = 0; next }
    !skip { print }
  ' "$bashrc" > "$tmpfile"
  mv "$tmpfile" "$bashrc"

  cat >> "$bashrc" <<EOF

$start_marker
[ -r "\$HOME/.config/exe-setup/shell.sh" ] && . "\$HOME/.config/exe-setup/shell.sh"
$end_marker
EOF
}

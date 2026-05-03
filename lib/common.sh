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


_toml_quote() {
  jq -Rn -r --arg value "$1" '$value | @json'
}

install_codex_config() {
  local config_dir="$HOME/.codex"
  local config_file="$config_dir/config.toml"
  local model="${CODEX_MODEL:-gpt-5.5}"
  local provider="${CODEX_MODEL_PROVIDER:-proxy}"
  local provider_name="${CODEX_PROXY_NAME:-plexus}"
  local base_url="${CODEX_PROXY_BASE_URL:-https://plexus.int.exe.xyz/v1}"
  local env_key="${CODEX_PROXY_ENV_KEY:-OPENAI_API_KEY}"
  local wire_api="${CODEX_PROXY_WIRE_API:-responses}"

  mkdir -p "$config_dir"

  cat > "$config_file" <<EOF
# Managed by exe-setup. Re-run setup.sh to restore these defaults.
# The proxy expects an OpenAI-compatible bearer token from \$${env_key}.
model = $(_toml_quote "$model")
model_provider = $(_toml_quote "$provider")

[model_providers.$provider]
name = $(_toml_quote "$provider_name")
base_url = $(_toml_quote "$base_url")
env_key = $(_toml_quote "$env_key")
wire_api = $(_toml_quote "$wire_api")
EOF

  chmod 600 "$config_file"
  echo "[exe-setup] codex config: $config_file (model=$model, provider=$provider_name, base_url=$base_url, wire_api=$wire_api)"
}

#!/usr/bin/env bash
# Startup-only Shelley custom model sync for exe-setup.

shelley_api() {
  local method="$1"
  local path="$2"
  local body="${3:-}"
  local url="${SHELLEY_URL:-http://127.0.0.1:9999}$path"
  local user_id="${SHELLEY_USER_ID:-exe-setup}"

  if [ -n "$body" ]; then
    curl -fsS \
      -H 'Content-Type: application/json' \
      -H "X-Exedev-Userid: $user_id" \
      -X "$method" \
      --data "$body" \
      "$url"
  else
    curl -fsS \
      -H "X-Exedev-Userid: $user_id" \
      -X "$method" \
      "$url"
  fi
}

wait_for_shelley() {
  local attempts="${SHELLEY_WAIT_ATTEMPTS:-30}"
  local delay="${SHELLEY_WAIT_DELAY:-1}"
  local i

  for i in $(seq 1 "$attempts"); do
    if shelley_api GET /api/version >/dev/null 2>&1 || shelley_api GET /api/custom-models >/dev/null 2>&1; then
      return 0
    fi
    sleep "$delay"
  done

  echo "[exe-setup] ERROR: Shelley API did not become ready at ${SHELLEY_URL:-http://127.0.0.1:9999}" >&2
  return 1
}

shelley_model_payload() {
  local model_json="$1"
  local api_key api_key_env model_label

  model_label=$(printf '%s' "$model_json" | jq -r '.display_name // .model_name // "unnamed"') || return 1
  api_key=$(printf '%s' "$model_json" | jq -r '.api_key // ""') || return 1
  api_key_env=$(printf '%s' "$model_json" | jq -r '.api_key_env // ""') || return 1

  if [ -z "$api_key" ] && [ -n "$api_key_env" ]; then
    api_key=$(printenv "$api_key_env" || true)
    if [ -z "$api_key" ]; then
      echo "[exe-setup] WARNING: skipping $model_label: environment variable $api_key_env is empty" >&2
      return 2
    fi
  fi

  if [ -z "$api_key" ]; then
    echo "[exe-setup] WARNING: skipping $model_label: api_key or api_key_env is required" >&2
    return 2
  fi

  printf '%s' "$model_json" | jq -c --arg api_key "$api_key" '{
    display_name: .display_name,
    provider_type: .provider_type,
    endpoint: .endpoint,
    api_key: $api_key,
    model_name: .model_name,
    max_tokens: (.max_tokens // 200000),
    tags: (.tags // ""),
    reasoning_effort: (.reasoning_effort // "")
  }'
}

restart_shelley_after_setup_changes() {
  if ! command -v systemctl >/dev/null 2>&1; then
    echo "[exe-setup] WARNING: systemctl not found; Shelley restart skipped" >&2
    return 0
  fi

  echo "[exe-setup] Restarting Shelley to load setup changes..."
  if sudo systemctl restart shelley.service; then
    echo "[exe-setup] Shelley restarted"
  else
    echo "[exe-setup] WARNING: Shelley restart failed; setup changes may require a manual restart" >&2
    return 1
  fi
}



resolve_sub_agent_model_id() {
  local models_file="$1"
  local display_name model_list model_id

  display_name=$(jq -r '.subAgentModel // ""' "$models_file") || return 1
  if [ -z "$display_name" ]; then
    return 0
  fi

  echo "[exe-setup] Resolving Shelley sub-agent model: $display_name" >&2
  wait_for_shelley || return 1

  model_list=$(shelley_api GET /api/models) || return 1
  model_id=$(printf '%s' "$model_list" | jq -r --arg name "$display_name" '.[] | select(.display_name == $name) | .id' | head -n 1)

  if [ -z "$model_id" ]; then
    echo "[exe-setup] ERROR: subAgentModel '$display_name' was not found in Shelley model list" >&2
    return 1
  fi

  printf '%s\n' "$model_id"
}

strip_exact_file_block() {
  local source_file="$1"
  local block_file="$2"
  local output_file="$3"

  if [ ! -s "$block_file" ]; then
    cp "$source_file" "$output_file"
    return 0
  fi

  awk '
    FNR == NR { n++; block[n] = $0; next }
    { lines[++m] = $0 }
    END {
      i = 1
      while (i <= m) {
        start = i
        if (lines[i] == "" && i < m) {
          start = i + 1
        }

        matched = (n > 0 && start + n - 1 <= m)
        if (matched) {
          for (j = 1; j <= n; j++) {
            if (lines[start + j - 1] != block[j]) {
              matched = 0
              break
            }
          }
        }

        if (matched) {
          i = start + n
          continue
        }

        print lines[i]
        i++
      }
    }
  ' "$block_file" "$source_file" > "$output_file"
}

trim_trailing_blank_lines() {
  local source_file="$1"
  local output_file="$2"

  awk '
    { lines[NR] = $0 }
    END {
      end = NR
      while (end > 0 && lines[end] == "") {
        end--
      }
      for (i = 1; i <= end; i++) {
        print lines[i]
      }
    }
  ' "$source_file" > "$output_file"
}

apply_shelley_agents_append() {
  local append_file="$1"
  local sub_agents_model="${2:-}"
  local agents_file="${SHELLEY_AGENTS_FILE:-$HOME/.config/shelley/AGENTS.md}"
  local start_marker="<!-- exe-setup additions >>> -->"
  local end_marker="<!-- <<< exe-setup additions -->"
  local previous_rendered="$HOME/.config/exe-setup/AGENTS.rendered.md"
  local tmpfile rendered_file stripped_file

  if [ ! -f "$append_file" ]; then
    echo "[exe-setup] Shelley AGENTS append file not found; skipping: $append_file"
    return 0
  fi

  mkdir -p "$(dirname "$agents_file")" "$(dirname "$previous_rendered")"
  touch "$agents_file"

  tmpfile=$(mktemp /tmp/exe-agents.XXXXXX)
  rendered_file=$(mktemp /tmp/exe-agents-rendered.XXXXXX)
  stripped_file=$(mktemp /tmp/exe-agents-stripped.XXXXXX)

  awk -v value="$sub_agents_model" '{ gsub(/{{subAgentsModel}}/, value); print }' "$append_file" > "$rendered_file"

  # Drop the old visible marker block from earlier exe-setup versions.
  awk -v start="$start_marker" -v end="$end_marker" '
    $0 == start { skip = 1; next }
    $0 == end { skip = 0; next }
    !skip { print }
  ' "$agents_file" > "$tmpfile"

  if [ -s "$previous_rendered" ]; then
    strip_exact_file_block "$tmpfile" "$previous_rendered" "$stripped_file"
    mv "$stripped_file" "$tmpfile"
    stripped_file=$(mktemp /tmp/exe-agents-stripped.XXXXXX)
  fi

  strip_exact_file_block "$tmpfile" "$rendered_file" "$stripped_file"
  mv "$stripped_file" "$tmpfile"
  stripped_file=$(mktemp /tmp/exe-agents-stripped.XXXXXX)

  trim_trailing_blank_lines "$tmpfile" "$stripped_file"
  mv "$stripped_file" "$tmpfile"

  {
    if [ -s "$tmpfile" ]; then
      cat "$tmpfile"
      printf '\n'
    fi
    cat "$rendered_file"
    printf '\n'
  } > "$agents_file"

  cp "$rendered_file" "$previous_rendered"
  rm -f "$tmpfile" "$rendered_file" "$stripped_file"

  echo "[exe-setup] Updated Shelley AGENTS instructions: $agents_file"
}

sync_shelley_models() {
  local models_file="$1"
  local count existing model_json model_id display_name payload existing_id created=0 updated=0 skipped=0 changed=0

  if [ ! -f "$models_file" ]; then
    echo "[exe-setup] ERROR: models file not found: $models_file" >&2
    return 1
  fi

  if ! jq -e '.models | type == "array"' "$models_file" >/dev/null; then
    echo "[exe-setup] ERROR: $models_file must contain a top-level models array" >&2
    return 1
  fi

  count=$(jq '.models | length' "$models_file") || return 1
  if [ "$count" -eq 0 ]; then
    echo "[exe-setup] No custom Shelley models in $models_file; skipping"
    return 0
  fi

  echo "[exe-setup] Waiting for Shelley API..."
  wait_for_shelley || return 1

  existing=$(shelley_api GET /api/custom-models) || return 1

  while IFS= read -r model_json; do
    [ -n "$model_json" ] || continue
    display_name=$(printf '%s' "$model_json" | jq -r '.display_name // ""') || return 1
    model_id=$(printf '%s' "$model_json" | jq -r '.model_id // ""') || return 1

    payload=$(shelley_model_payload "$model_json")
    case $? in
      0) ;;
      2) skipped=$((skipped + 1)); continue ;;
      *) return 1 ;;
    esac

    if [ -n "$model_id" ]; then
      existing_id=$(printf '%s' "$existing" | jq -r --arg id "$model_id" '.[] | select(.model_id == $id) | .model_id' | head -n 1)
    else
      existing_id=$(printf '%s' "$existing" | jq -r --arg name "$display_name" '.[] | select(.display_name == $name) | .model_id' | head -n 1)
    fi

    if [ -n "$existing_id" ]; then
      echo "[exe-setup] Updating Shelley model: $display_name ($existing_id)"
      shelley_api PUT "/api/custom-models/$existing_id" "$payload" >/dev/null || return 1
      updated=$((updated + 1))
      changed=1
    else
      echo "[exe-setup] Creating Shelley model: $display_name"
      shelley_api POST /api/custom-models "$payload" >/dev/null || return 1
      created=$((created + 1))
      changed=1
    fi
  done < <(jq -c '.models[]' "$models_file")

  echo "[exe-setup] Shelley model sync done: created=$created updated=$updated skipped=$skipped"

  return 0
}

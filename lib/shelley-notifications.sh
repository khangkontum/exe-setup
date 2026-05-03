#!/usr/bin/env bash
# Shelley notification channel sync for exe-setup.

sync_shelley_notifications() {
  local display_name="${SHELLEY_NTFY_DISPLAY_NAME:-ntfy: shelley}"
  local server="${SHELLEY_NTFY_SERVER:-https://ntfy.0xee.de}"
  local topic="${SHELLEY_NTFY_TOPIC:-shelley}"
  local token="${SHELLEY_NTFY_TOKEN:-dummy}"
  local done_priority="${SHELLEY_NTFY_DONE_PRIORITY:-default}"
  local error_priority="${SHELLEY_NTFY_ERROR_PRIORITY:-high}"
  local channels existing_id payload
  local enabled=1

  echo "[exe-setup] Configuring Shelley ntfy notifications: $server/$topic"
  wait_for_shelley || return 1

  channels=$(shelley_api GET /api/notification-channels) || return 1
  existing_id=$(printf '%s' "$channels" | jq -r --arg name "$display_name" --arg server "$server" --arg topic "$topic" '
    .[]
    | select(.channel_type == "ntfy")
    | select(.display_name == $name or (.config.server == $server and .config.topic == $topic))
    | .channel_id
  ' | head -n 1)

  payload=$(jq -cn \
    --arg display_name "$display_name" \
    --arg server "$server" \
    --arg topic "$topic" \
    --arg token "$token" \
    --arg done_priority "$done_priority" \
    --arg error_priority "$error_priority" \
    --argjson enabled "$enabled" \
    '{
      channel_type: "ntfy",
      display_name: $display_name,
      enabled: ($enabled == 1),
      config: {
        server: $server,
        topic: $topic,
        token: $token,
        done_priority: $done_priority,
        error_priority: $error_priority
      }
    }') || return 1

  if [ -n "$existing_id" ]; then
    echo "[exe-setup] Updating Shelley notification channel: $display_name ($existing_id)"
    shelley_api PUT "/api/notification-channels/$existing_id" "$payload" >/dev/null || return 1
  else
    echo "[exe-setup] Creating Shelley notification channel: $display_name"
    shelley_api POST /api/notification-channels "$payload" >/dev/null || return 1
  fi

  echo "[exe-setup] Shelley ntfy notifications ready"
}

#!/usr/bin/env bash
set -euo pipefail

decode_file() {
  local encoded="$1"
  local target="$2"

  if [[ -n "$encoded" ]]; then
    mkdir -p "$(dirname "$target")"
    printf '%s' "$encoded" | base64 --decode > "$target"
  fi
}

decode_file "${SECRETS_ENV_BASE64:-}" "secrets.env"
decode_file "${GOOGLE_SERVICES_JSON_BASE64:-}" "android/app/google-services.json"
decode_file "${ANDROID_KEYSTORE_BASE64:-}" "android/strumok-release.jks"
decode_file "${ANDROID_KEYSTORE_PROPERTIES_BASE64:-}" "android/keystore.properties"

if [[ ! -f secrets.env ]]; then
  cp secrets.env.example secrets.env
fi

if [[ -f android/keystore.properties && ! -f android/strumok-release.jks ]]; then
  echo "Android keystore properties were provided without the keystore." >&2
  exit 1
fi

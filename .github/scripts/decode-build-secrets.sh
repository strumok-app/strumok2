#!/usr/bin/env bash
set -euo pipefail

decode_file() {
  local secret_name="$1"
  local encoded="$2"
  local target="$3"

  if [[ -n "$encoded" ]]; then
    mkdir -p "$(dirname "$target")"
    if ! printf '%s' "$encoded" | base64 --decode > "$target"; then
      rm -f "$target"
      echo "Invalid Base64 in $secret_name. Create it from the file contents, not the file path or decoded text." >&2
      exit 1
    fi
  fi
}

decode_file "SECRETS_ENV_BASE64" "${SECRETS_ENV_BASE64:-}" "secrets.env"
decode_file "GOOGLE_SERVICES_JSON_BASE64" "${GOOGLE_SERVICES_JSON_BASE64:-}" "android/app/google-services.json"
decode_file "ANDROID_KEYSTORE_BASE64" "${ANDROID_KEYSTORE_BASE64:-}" "android/strumok-release.jks"
decode_file "ANDROID_KEYSTORE_PROPERTIES_BASE64" "${ANDROID_KEYSTORE_PROPERTIES_BASE64:-}" "android/keystore.properties"

if [[ ! -f secrets.env ]]; then
  cp secrets.env.example secrets.env
fi

if [[ -f android/keystore.properties && ! -f android/strumok-release.jks ]]; then
  echo "Android keystore properties were provided without the keystore." >&2
  exit 1
fi

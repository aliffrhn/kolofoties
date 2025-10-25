#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${HOME}/Library/Application Support/CursorCompanion"
CONFIG_FILE="${CONFIG_DIR}/config.json"

mask_key() {
  local key="$1"
  local length=${#key}
  if (( length <= 6 )); then
    printf '%s' "${key:0:1}***${key:length-1:1}"
  else
    printf '%s' "${key:0:4}…${key: -4}"
  fi
}

source_label=""
key_value=""
model_value=""
base_value=""
voice_value=""
rate_value=""
pitch_value=""

if [[ -n "${OPENAI_API_KEY:-}" ]]; then
  source_label="environment variable"
  key_value="${OPENAI_API_KEY}"
  model_value="${OPENAI_MODEL:-}"
  base_value="${OPENAI_BASE_URL:-}"
  voice_value="${VOICE_IDENTIFIER:-}"
  rate_value="${VOICE_RATE:-}"
  pitch_value="${VOICE_PITCH:-}"
else
  if [[ -f "${CONFIG_FILE}" ]]; then
    mapfile -t config_lines < <(python3 - "$CONFIG_FILE" <<'PY'
import json, sys
path = sys.argv[1]
with open(path, "r") as fh:
    data = json.load(fh)
print(data.get("openAIAPIKey", ""))
print(data.get("openAIModel", ""))
print(data.get("openAIBaseURL", ""))
print(data.get("voiceIdentifier", ""))
print(data.get("voiceRate", ""))
print(data.get("voicePitch", ""))
PY
)
    key_value="${config_lines[0]:-}"
    model_value="${config_lines[1]:-}"
    base_value="${config_lines[2]:-}"
    voice_value="${config_lines[3]:-}"
    rate_value="${config_lines[4]:-}"
    pitch_value="${config_lines[5]:-}"
    if [[ -n "${key_value}" ]]; then
      source_label="config file"
    fi
  fi
fi

if [[ -z "${source_label}" || -z "${key_value}" ]]; then
  echo "No OpenAI API key configured." >&2
  echo "Use 'bash scripts/set_api_key.sh' to store one, or export OPENAI_API_KEY before launching." >&2
  exit 1
fi

masked_key=$(mask_key "${key_value}")
model_display=${model_value:-gpt-4o-mini}
base_display=${base_value:-https://api.openai.com/v1}
voice_display=${voice_value:-auto}
rate_display=${rate_value:-auto}
pitch_display=${pitch_value:-auto}

cat <<OUT
Source       : ${source_label}
API Key      : ${masked_key}
Model        : ${model_display}
Base URL     : ${base_display}
Config file  : ${CONFIG_FILE}
Voice ID     : ${voice_display}
Voice Rate   : ${rate_display}
Voice Pitch  : ${pitch_display}
OUT

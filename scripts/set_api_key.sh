#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${HOME}/Library/Application Support/CursorCompanion"
CONFIG_FILE="${CONFIG_DIR}/config.json"

mkdir -p "${CONFIG_DIR}"

printf 'Enter your OpenAI API key: ' >&2
read -r API_KEY
if [[ -z "${API_KEY}" ]]; then
  echo "API key cannot be empty." >&2
  exit 1
fi

printf 'Optional model name [gpt-4o-mini]: ' >&2
read -r MODEL_NAME

printf 'Optional base URL [https://api.openai.com/v1]: ' >&2
read -r BASE_URL

printf 'Optional voice identifier (e.g., com.apple.ttsbundle.Samantha-premium): ' >&2
read -r VOICE_IDENTIFIER

printf 'Optional speech rate (0.2 – 0.7 recommended) [0.47]: ' >&2
read -r VOICE_RATE

printf 'Optional speech pitch (0.5 – 2.0) [1.05]: ' >&2
read -r VOICE_PITCH

export CONFIG_FILE API_KEY MODEL_NAME BASE_URL VOICE_IDENTIFIER VOICE_RATE VOICE_PITCH

python3 <<'PY'
import json
import os
from pathlib import Path

def optional(value: str | None):
    if value is None:
        return None
    value = value.strip()
    return value or None

def optional_float(value: str | None):
    value = optional(value)
    if value is None:
        return None
    try:
        return float(value)
    except ValueError:
        print(f"Warning: could not parse '{value}' as a number; ignoring.")
        return None

config = {
    "openAIAPIKey": os.environ["API_KEY"].strip(),
    "openAIModel": optional(os.environ.get("MODEL_NAME")),
    "openAIBaseURL": optional(os.environ.get("BASE_URL")),
    "voiceIdentifier": optional(os.environ.get("VOICE_IDENTIFIER")),
    "voiceRate": optional_float(os.environ.get("VOICE_RATE")),
    "voicePitch": optional_float(os.environ.get("VOICE_PITCH"))
}

path = Path(os.environ["CONFIG_FILE"]).expanduser()
path.write_text(json.dumps(config, indent=2), encoding="utf-8")
path.chmod(0o600)
print(f"Configuration saved to {path}")
PY

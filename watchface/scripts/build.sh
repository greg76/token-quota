#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/sdk.sh"
mkdir -p bin "$PROJECT_DIR/../.local"
KEY_PATH="${CIQ_DEVELOPER_KEY:-$PROJECT_DIR/../.local/developer_key.der}"
if [[ ! -f "$KEY_PATH" ]]; then
    if [[ -n "${CIQ_DEVELOPER_KEY:-}" ]]; then
        echo "Developer key does not exist: $KEY_PATH" >&2
        exit 1
    fi
    # Local sideload signing identity, intentionally excluded from version control.
    (umask 077; openssl genrsa 4096 | openssl pkcs8 -topk8 -inform PEM -outform DER -nocrypt -out "$KEY_PATH")
fi
"$CIQ_SDK_HOME/bin/monkeyc" -f monkey.jungle -d instinct2x -o "${CIQ_OUTPUT:-bin/TokenQuota.prg}" -y "$KEY_PATH" -w "$@"

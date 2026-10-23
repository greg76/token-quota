#!/bin/bash
# Source this file from the build/run scripts.
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -z "${CIQ_SDK_HOME:-}" ]]; then
    SDK_CONFIG="$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg"
    if [[ ! -f "$SDK_CONFIG" ]]; then
        echo 'Set CIQ_SDK_HOME to the Connect IQ SDK directory.' >&2
        exit 1
    fi
    CIQ_SDK_HOME="$(cat "$SDK_CONFIG")"
fi
CIQ_SDK_HOME="${CIQ_SDK_HOME%/}"
if [[ ! -x "$CIQ_SDK_HOME/bin/monkeyc" ]]; then
    echo "Cannot find monkeyc in $CIQ_SDK_HOME/bin" >&2
    exit 1
fi
cd "$PROJECT_DIR"

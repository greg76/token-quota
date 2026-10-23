#!/bin/bash
# Copy the built watchface and configured settings to a mounted watch.
set -euo pipefail

if [[ $# -ne 1 || "$1" == "--help" || "$1" == "-h" ]]; then
    echo "Usage: $0 WATCH_ROOT"
    echo "Example: $0 /Volumes/GARMIN"
    echo "WATCH_ROOT must contain GARMIN/APPS. Existing TokenQuota files are replaced."
    echo "Copies are verified before ejecting the watch with macOS diskutil."
    if [[ $# -eq 1 && ( "$1" == "--help" || "$1" == "-h" ) ]]; then
        exit 0
    fi
    exit 1
fi

WATCHFACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROGRAM="$WATCHFACE_DIR/bin/TokenQuota.prg"
SETTINGS="$WATCHFACE_DIR/bin/TokenQuota.SET"
APPS_DIR="$1/GARMIN/APPS"
SETTINGS_DIR="$APPS_DIR/SETTINGS"

# Check both inputs and destinations before copying either file.
if [[ ! -s "$PROGRAM" || ! -f "$PROGRAM" ]]; then
    echo "Missing or empty watchface program: $PROGRAM" >&2
    echo "Save the prebuilt TokenQuota.prg to $WATCHFACE_DIR/bin/, or build it with $WATCHFACE_DIR/scripts/build.sh -r" >&2
    exit 1
fi
if [[ ! -s "$SETTINGS" || ! -f "$SETTINGS" ]]; then
    echo "Missing or empty settings file: $SETTINGS" >&2
    echo "For the included Codex collector, run: \"$WATCHFACE_DIR/../collector/setup-collector.py\"" >&2
    echo "Generate it first with your collector's public quota URL:" >&2
    echo "\"$WATCHFACE_DIR/scripts/generate-settings.py\" --url YOUR_PUBLIC_QUOTA_URL" >&2
    exit 1
fi
if [[ ! -d "$APPS_DIR" ]]; then
    echo "Watch folder not found: $APPS_DIR" >&2
    echo "Pass the mounted watch root containing GARMIN/APPS." >&2
    exit 1
fi
if [[ -e "$SETTINGS_DIR" && ! -d "$SETTINGS_DIR" ]]; then
    echo "Settings path is not a directory: $SETTINGS_DIR" >&2
    exit 1
fi
for destination in "$APPS_DIR/TokenQuota.prg" "$SETTINGS_DIR/TokenQuota.SET"; do
    if [[ -d "$destination" ]]; then
        echo "Destination is a directory: $destination" >&2
        exit 1
    fi
done

mkdir -p "$SETTINGS_DIR"
# Install the settings before the program, preserving matching basenames.
cp "$SETTINGS" "$SETTINGS_DIR/TokenQuota.SET"
cp "$PROGRAM" "$APPS_DIR/TokenQuota.prg"
echo "Copied $SETTINGS_DIR/TokenQuota.SET"
echo "Copied $APPS_DIR/TokenQuota.prg"
cmp "$SETTINGS" "$SETTINGS_DIR/TokenQuota.SET"
cmp "$PROGRAM" "$APPS_DIR/TokenQuota.prg"
echo "Verified both copies."

if ! command -v diskutil >/dev/null 2>&1; then
    echo "Automatic ejection requires macOS diskutil. Safely eject the watch manually before disconnecting."
    exit 0
fi
if ! diskutil eject "$1"; then
    echo "Deployment succeeded, but ejection failed. Close any files open on the watch and eject it manually before disconnecting." >&2
    exit 1
fi
echo "Watch ejected. Disconnect it, then select Token Quota."

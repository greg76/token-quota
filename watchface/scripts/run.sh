#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/sdk.sh"
BUILD=false
TEST=false
for argument in "$@"; do
    case "$argument" in
        --build) BUILD=true ;;
        --test) TEST=true ;;
        *) echo 'Usage: ./scripts/run.sh [--build] [--test]' >&2; exit 1 ;;
    esac
done
PROGRAM=bin/TokenQuota.prg
if [[ "$TEST" == true ]]; then
    PROGRAM=bin/TokenQuotaTests.prg
fi
if [[ "$BUILD" == true ]]; then
    if [[ "$TEST" == true ]]; then
        CIQ_OUTPUT="$PROGRAM" ./scripts/build.sh -t
    else
        ./scripts/build.sh
    fi
fi
if [[ ! -f "$PROGRAM" ]]; then
    echo "Missing $PROGRAM. Run again with --build to compile it first." >&2
    exit 1
fi
if [[ "$TEST" == false && ! -f bin/TokenQuota-settings.json ]]; then
    echo 'Missing settings schema. Run again with --build to generate it first.' >&2
    exit 1
fi
"$CIQ_SDK_HOME/bin/connectiq"
# The simulator takes a moment to expose its local runner socket on first launch.
for attempt in {1..20}; do
    if nc -z 127.0.0.1 1234 2>/dev/null; then
        if [[ "$TEST" == true ]]; then
            # Some SDK runners return 1 even when all tests pass. Trust the
            # explicit test summary, and keep the full output for inspection.
            "$CIQ_SDK_HOME/bin/monkeydo" "$PROGRAM" instinct2x -t 2>&1 | tee bin/test-results.log || true
            grep -Eq '^PASSED \(passed=[1-9][0-9]*, failed=0, errors=0\)$' bin/test-results.log
            exit $?
        fi
        # Send both the editor schema and the configured properties, when present.
        # SDK 9.3.0 parses only one file per -a, despite the wrapper's help text.
        SIMULATOR_FILES=(-a "bin/TokenQuota-settings.json:GARMIN/Settings/TOKENQUOTA-settings.json")
        if [[ -f bin/TokenQuota.SET ]]; then
            SIMULATOR_FILES+=(-a "bin/TokenQuota.SET:GARMIN/APPS/SETTINGS/TOKENQUOTA.SET")
            echo 'Loading simulator settings from bin/TokenQuota.SET.'
        else
            echo 'No bin/TokenQuota.SET; using saved simulator settings or app defaults.'
            echo 'To configure live data, run ./scripts/generate-settings.py --url YOUR_PUBLIC_QUOTA_URL.'
        fi
        exec "$CIQ_SDK_HOME/bin/monkeydo" "$PROGRAM" instinct2x "${SIMULATOR_FILES[@]}"
    fi
    sleep 0.5
done
echo 'Simulator did not start within 10 seconds. Open Connect IQ and run this script again.' >&2
exit 1

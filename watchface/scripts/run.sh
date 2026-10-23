#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/sdk.sh"
PROGRAM=bin/TokenQuota.prg
if [[ "${1:-}" == "--test" ]]; then
    PROGRAM=bin/TokenQuotaTests.prg
    CIQ_OUTPUT="$PROGRAM" ./scripts/build.sh -t
elif [[ $# -eq 0 ]]; then
    ./scripts/build.sh
else
    echo 'Usage: ./scripts/run.sh [--test]' >&2
    exit 1
fi
"$CIQ_SDK_HOME/bin/connectiq"
# The simulator takes a moment to expose its local runner socket on first launch.
for attempt in {1..20}; do
    if nc -z 127.0.0.1 1234 2>/dev/null; then
        if [[ "${1:-}" == "--test" ]]; then
            # Some SDK runners return 1 even when all tests pass. Trust the
            # explicit test summary, and keep the full output for inspection.
            "$CIQ_SDK_HOME/bin/monkeydo" "$PROGRAM" instinct2x -t 2>&1 | tee bin/test-results.log || true
            grep -Eq '^PASSED \(passed=[1-9][0-9]*, failed=0, errors=0\)$' bin/test-results.log
            exit $?
        fi
        # The simulator's properties editor needs the compiler-generated schema.
        exec "$CIQ_SDK_HOME/bin/monkeydo" "$PROGRAM" instinct2x -a \
            "bin/TokenQuota-settings.json:GARMIN/Settings/TOKENQUOTA-settings.json"
    fi
    sleep 0.5
done
echo 'Simulator did not start within 10 seconds. Open Connect IQ and run this script again.' >&2
exit 1

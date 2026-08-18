#!/usr/bin/env bash
# Builds a checked out LiquidBounce.
#
# Retries because the mavens it pulls from go down often enough to fail a run on their own, and
# gradle disables a whole repository for the rest of the build when one of them does, so a single
# outage takes out every dependency that repository serves.
#
# On giving up it sets failed=true as a step output, so a workflow can report a build that never
# produced a jar as what it is rather than as a compatibility finding.
set -uo pipefail

dir=${1:-liquidbounce}
attempts=${2:-3}

for attempt in $(seq 1 "$attempts"); do
    if (cd "$dir" && ./gradlew jar --no-daemon); then
        exit 0
    fi
    echo "build attempt $attempt of $attempts failed"
    if [ "$attempt" -lt "$attempts" ]; then
        sleep 30
    fi
done

echo "LiquidBounce did not build after $attempts attempts, so nothing was checked"
if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "failed=true" >> "$GITHUB_OUTPUT"
fi
exit 1

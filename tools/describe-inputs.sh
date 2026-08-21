#!/usr/bin/env bash
# Print what a check actually read, so a report says which builds it is a statement about.
#
# Usage: describe-inputs.sh <liquidbounce.jar> <lunar-okhttp.jar.meta> [liquidbounce checkout]
set -uo pipefail

JAR="${1:-}"
META="${2:-}"
CHECKOUT="${3:-}"

if [ -n "$JAR" ] && [ -f "$JAR" ]; then
    version="$(unzip -p "$JAR" fabric.mod.json 2>/dev/null \
        | python3 -c 'import json,sys; print(json.load(sys.stdin).get("version","unknown"))' 2>/dev/null)"
    line="LiquidBounce ${version:-unknown}"
    if [ -n "$CHECKOUT" ] && [ -d "$CHECKOUT/.git" ]; then
        commit="$(git -C "$CHECKOUT" rev-parse --short=9 HEAD 2>/dev/null)"
        branch="$(git -C "$CHECKOUT" rev-parse --abbrev-ref HEAD 2>/dev/null)"
        [ "$branch" = "HEAD" ] && branch=""   # a detached checkout names no branch
        [ -n "$commit" ] && line="$line (${branch:+$branch }$commit)"
    fi
    echo "$line"
    # The jar names carry the versions; nothing inside them states it as reliably.
    bundled="$(unzip -Z1 "$JAR" 2>/dev/null | grep -oE 'META-INF/jars/(okhttp|okio)[^/]*\.jar' \
        | sed 's|META-INF/jars/||;s|\.jar$||' | sort | tr '\n' ' ')"
    [ -n "$bundled" ] && echo "  bundles $bundled"
fi

if [ -n "$META" ] && [ -f "$META" ]; then
    mc=$(grep '^mc_version=' "$META" | cut -d= -f2)
    branch=$(grep '^branch=' "$META" | cut -d= -f2)
    launcher=$(grep '^launcher=' "$META" | cut -d= -f2)
    okhttp=$(grep '^okhttp=' "$META" | cut -d= -f2)
    echo "Lunar MC $mc, branch $branch, launcher $launcher"
    echo "  okhttp $okhttp"
    # The launch API names every artifact 0.1.0-SNAPSHOT and gives no build id, so the checksum
    # is the only thing that says which build this was.
    grep '^artifact=' "$META" | sed 's/^artifact=/  from /'
fi

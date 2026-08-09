#!/usr/bin/env bash
# Write the okhttp and okio a Lunar Client build ships to the given path.
#
# Uses the same public launch API the launcher does, so no account is needed and the result
# tracks whatever Lunar serves today. Only the jars are fetched; the game is never started.
set -euo pipefail

MC_VERSION="${1:-26.2}"
OUT="${2:-lunar-okhttp.jar}"
BRANCH="${LUNAR_BRANCH:-master}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "[lunar] MC=$MC_VERSION branch=$BRANCH"
LVER="3.4.9"
curl -fsSL --max-time 60 -X POST https://api.lunarclientprod.com/launcher/launch \
  -H 'Content-Type: application/json' -H "User-Agent: Lunar Client Launcher v$LVER" \
  -d "{\"os\":\"linux\",\"os_release\":\"$(uname -r)\",\"arch\":\"x64\",\
\"hwid\":\"$(cat /proc/sys/kernel/random/uuid)\",\"hwid_private\":\"$(cat /proc/sys/kernel/random/uuid)\",\
\"installation_id\":\"$(cat /proc/sys/kernel/random/uuid)\",\"launcher_version\":\"$LVER\",\
\"version\":\"$MC_VERSION\",\"branch\":\"$BRANCH\",\"launch_type\":\"OFFLINE\",\"module\":\"fabric\"}" \
  -o "$WORK/launch.json"

python3 - "$WORK" <<'PY'
import json, sys
work = sys.argv[1]
data = json.load(open(f"{work}/launch.json"))
arts = data.get("launchTypeData", {}).get("artifacts") or data.get("artifacts") or []
names = [a for a in arts if a.get("type") == "CLASS_PATH"]
open(f"{work}/urls", "w").write("\n".join(f"{a['name']} {a['url']}" for a in names))
PY

mkdir -p "$WORK/jars" "$WORK/x"
while read -r name url; do
  [ -n "$name" ] || continue
  case "$name" in */*|"") echo "[lunar] refusing odd artifact name: $name"; exit 2;; esac
  curl -fsS -o "$WORK/jars/$name" "$url"
done < "$WORK/urls"

for jar in "$WORK"/jars/*.jar; do
  unzip -qo "$jar" 'okhttp3/*' 'okio/*' -d "$WORK/x" 2>/dev/null || true
done

[ -d "$WORK/x/okhttp3" ] || { echo "[lunar] no okhttp in this build"; exit 1; }
OUT_ABS="$(cd "$(dirname "$OUT")" && pwd)/$(basename "$OUT")"
(cd "$WORK/x" && zip -qr "$OUT_ABS" okhttp3 okio)
echo "[lunar] wrote $OUT_ABS ($(unzip -l "$OUT_ABS" | tail -1 | awk '{print $2}') entries)"

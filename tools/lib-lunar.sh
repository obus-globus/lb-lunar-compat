#!/usr/bin/env bash
# Shared helpers for the Lunar compatibility checks (static bake + runtime boot). Everything here is
# derived at run time so the checks survive Lunar updates and LiquidBounce version bumps with no edits:
#   * the Minecraft version comes from LiquidBounce's own gradle/libs.versions.toml
#   * the Lunar build is always the current one for that MC version (public launch API, no account)
#   * the fabric-language-kotlin version comes from LiquidBounce's own fabric.mod.json dependency
# The single most update-fragile thing (Lunar's launch API request shape) lives ONLY here, so if Lunar
# changes it there is exactly one place to fix for both checks.

LUNAR_LAUNCH_API="https://api.lunarclientprod.com/launcher/launch"
LUNAR_LATEST_LAUNCHER_YML="https://launcherupdates.lunarclientcdn.com/latest.yml"

# Reject a version/branch string that isn't a plain identifier, before it reaches a JSON body, a python
# snippet or a filesystem path (the MC version can come from a workflow-dispatch input). Args: <label> <value>
lunar_safe_token() {
    case "$2" in
        *[!A-Za-z0-9._+-]* | "") echo "invalid $1: '$2'" >&2; return 1 ;;
        *) return 0 ;;
    esac
}

# Repo root = two levels up from this script (.../lunar-compat/scripts/lib-lunar.sh).
lunar_repo_root() { cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd; }

# The Minecraft version LiquidBounce currently targets, read from its version catalog.
detect_mc_version() {
    local toml; toml="$(lunar_repo_root)/gradle/libs.versions.toml"
    grep -E '^\s*minecraft\s*=\s*"' "$toml" | head -1 | sed -E 's/.*"([^"]+)".*/\1/'
}

# The current Lunar launcher version (for the User-Agent + request); falls back to a recent value.
detect_launcher_version() {
    curl -fsSL --max-time 20 "$LUNAR_LATEST_LAUNCHER_YML" 2>/dev/null \
        | head -1 | sed 's/version: *//;s/[^0-9.].*//' | grep . || echo "3.7.12"
}

# The fabric-language-kotlin version LiquidBounce requires, parsed from a built LB jar's fabric.mod.json.
# LiquidBounce declares e.g. ">=1.13.12+kotlin.2.4.0"; we take the exact floor so we fetch what it built
# against. Prints nothing if it can't be determined (caller should fall back).
detect_flk_version() {
    local lbjar="$1"
    unzip -p "$lbjar" fabric.mod.json 2>/dev/null | python3 -c '
import sys, json, re
try:
    dep = json.load(sys.stdin).get("depends", {}).get("fabric-language-kotlin", "")
except Exception:
    dep = ""
dep = dep[0] if isinstance(dep, list) and dep else dep
m = re.search(r"(\d+\.\d+\.\d+\+kotlin\.\d+\.\d+\.\d+)", str(dep))
print(m.group(1) if m else "")
'
}

# POST the Lunar launch API and write the response json. Args: <mc_version> <branch> <launcher_version> <out.json>
# Only the public "master" branch is reachable without a Lunar account (beta/staging -> NO_PERMISSION_PRIVATE_BRANCH).
lunar_launch_json() {
    local mc="$1" branch="$2" lver="$3" out="$4"
    lunar_safe_token "MC version" "$mc" || return 1
    lunar_safe_token "Lunar branch" "$branch" || return 1
    local hwid iid osrel; hwid="$(cat /proc/sys/kernel/random/uuid)"; iid="$(cat /proc/sys/kernel/random/uuid)"; osrel="$(uname -r)"
    curl -fsSL --max-time 60 -X POST "$LUNAR_LAUNCH_API" \
        -H 'Content-Type: application/json' -H "User-Agent: Lunar Client Launcher v$lver" \
        -d "{\"os\":\"linux\",\"os_release\":\"$osrel\",\"arch\":\"x64\",\"hwid\":\"$hwid\",\"hwid_private\":\"$hwid\",\"installation_id\":\"$iid\",\"launcher_version\":\"$lver\",\"version\":\"$mc\",\"branch\":\"$branch\",\"launch_type\":\"OFFLINE\",\"module\":\"fabric\"}" \
        -o "$out"
    python3 - "$out" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
if d.get("success") is False:
    sys.exit(f"Lunar launch API error: {json.dumps(d)[:300]}")
PY
}

# Download CLASS_PATH + NATIVES + EXTERNAL_FILE artifacts from a launch response into <dest>/, unpack
# native zips into <dest>/natives/, and write <dest>/.mainclass and <dest>/.externalfiles (the comma-
# separated relative EXTERNAL_FILE list for --ichorExternalFiles). Args: <resp.json> <dest_dir>
lunar_download_artifacts() {
    local resp="$1" dest="$2"
    mkdir -p "$dest/natives"
    python3 -c "import json;print(json.load(open('$resp'))['launchTypeData']['mainClass'])" > "$dest/.mainclass"
    python3 - "$resp" > "$dest/.artifacts.tsv" <<'PY'
import json, sys
for a in json.load(open(sys.argv[1]))["launchTypeData"]["artifacts"]:
    if a["type"] in ("CLASS_PATH", "NATIVES", "EXTERNAL_FILE"):
        print(a["type"] + "\t" + a["name"] + "\t" + a["url"])
PY
    : > "$dest/.externalfiles"
    local t n u
    while IFS=$'\t' read -r t n u; do
        # Reject a traversal/absolute artifact name from the API before writing it anywhere.
        case "$n" in ""|/*|*..*) echo "skipping unsafe artifact name: '$n'" >&2; continue ;; esac
        mkdir -p "$dest/$(dirname "$n")"
        if ! curl -fsSL --max-time 240 -o "$dest/$n" "$u"; then
            # A missing classpath jar or native breaks the run; a missing data file is tolerable.
            case "$t" in
                CLASS_PATH|NATIVES) echo "failed to download required $t artifact: $n" >&2; return 1 ;;
                *) echo "skipping unavailable EXTERNAL_FILE: $n" >&2; continue ;;
            esac
        fi
        case "$t" in
            NATIVES) unzip -o -q "$dest/$n" -d "$dest/natives/" 2>/dev/null || true ;;
            EXTERNAL_FILE) printf '%s,' "$n" >> "$dest/.externalfiles" ;;
        esac
    done < "$dest/.artifacts.tsv"
    sed -i 's/,$//' "$dest/.externalfiles"
    # native jars (e.g. jtracy) unpack too
    for j in "$dest"/*natives*.jar; do [ -f "$j" ] && unzip -o -q "$j" -d "$dest/natives/" 2>/dev/null || true; done
}

# Download a fabric-language-kotlin jar from FabricMC maven into <dest>/. Args: <version> <dest_dir>
fetch_flk() {
    local v="$1" dest="$2"
    lunar_safe_token "fabric-language-kotlin version" "$v" || return 1
    curl -fsSL --max-time 120 -o "$dest/fabric-language-kotlin-$v.jar" \
        "https://maven.fabricmc.net/net/fabricmc/fabric-language-kotlin/$v/fabric-language-kotlin-$v.jar"
}

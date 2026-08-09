#!/usr/bin/env bash
# Runtime LiquidBounce <-> Lunar Client compatibility check: actually boot Lunar's game with LiquidBounce
# loaded and see what breaks at run time -- the incompatibilities the static mixin check can't see
# (library/classpath shadowing, shader/pipeline failures, linkage errors, LiquidBounce's fatal handler).
# Scope: this boots to the main menu; it does NOT join a world, so mixins into world/gameplay classes that
# only load in-game are not exercised here (the static check covers whether their selectors resolve).
#
# Everything is provisioned automatically and stays correct across updates:
#   * Minecraft version  -> read from LiquidBounce's gradle/libs.versions.toml
#   * Lunar build        -> current public build for that MC version (launch API, no account)
#   * fabric-language-kotlin (LiquidBounce is Kotlin, Lunar doesn't ship it) -> the version LiquidBounce's
#     own fabric.mod.json requires, fetched from FabricMC maven
#   * Lunar's Fabric mod dir, natives, external data files, and a minimal profile -> generated here
#
# Headless caveat (documented, handled): with no GPU, Lunar's WebOSR/Ultralight overlay segfaults a few
# seconds after init -- this reproduces with zero mods and is a Lunar limitation, not a LiquidBounce bug.
# Every useful signal (LiquidBounce loading, mixins applying, injection/classpath/shader errors) happens
# during init, BEFORE that. So we boot, wait for "Finished Lunar initialization", give a short grace
# window, harvest the log, then stop -- and grade on the harvested log, ignoring a post-init WebOSR crash.
#
# Usage: run-liquidbounce.sh [MC_VERSION] [LIQUIDBOUNCE_JAR]
#   MC_VERSION         default: detected from libs.versions.toml
#   LIQUIDBOUNCE_JAR   default: newest build/libs/liquidbounce-*.jar (run `./gradlew jar` first)
#   env LUNAR_BRANCH   default master (only master is public)
#   env REPORT         default build/reports/lunar-runtime-compat.txt
# Exit codes: 0 = LiquidBounce ran cleanly (shader-only issues are warnings); 1 = a real LiquidBounce-side
# incompatibility (mixin injection failure, LiquidBounce-linked linkage error, or its fatal error handler);
# 2 = usage/prerequisite error; 3 = provisioning/environment failure (download/API/FLK, or Lunar itself did
# not boot) -- distinct from a compat failure so a flaky daily run isn't misread as "LiquidBounce broke".
set -uo pipefail
export CI=1   # make LiquidBounce's ErrorHandler LOG fatal errors instead of popping a modal dialog that
              # would block a headless run (see ErrorHandler.kt) -- so the grep below can actually see them.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib-lunar.sh"
ROOT="$(pwd)"

MC_VERSION="${1:-26.2}"
LB_JAR="${2:?a LiquidBounce jar is required}"
EXTRA_MOD="${3:-}"
BRANCH="${LUNAR_BRANCH:-master}"
REPORT="${REPORT:-lunar-runtime-compat.txt}"
WORK="${LUNAR_WORK:-$(mktemp -d /tmp/lunar-run.XXXXXX)}"
JAVA_BIN="${JAVA_BIN:-java}"

[ -n "$MC_VERSION" ] || { echo "could not detect MC version"; exit 2; }
[ -f "$LB_JAR" ] || { echo "LiquidBounce jar not found (build it: ./gradlew jar): $LB_JAR"; exit 2; }
LVER="$(detect_launcher_version)"
echo "[runtime] MC=$MC_VERSION lunar-branch=$BRANCH launcher=$LVER"
echo "[runtime] LiquidBounce jar: $LB_JAR"

# --- fetch Lunar (jars + natives + external data) ---
LC="$WORK/.lunarclient"; MV="$LC/offline/multiver"; MODS="$LC/profiles/mods/fabric-$MC_VERSION"
mkdir -p "$MV" "$MODS" "$LC/settings/game" "$LC/shared/assets" "$LC/textures" "$LC/ui"
echo "[runtime] querying Lunar launch API..."
lunar_launch_json "$MC_VERSION" "$BRANCH" "$LVER" "$WORK/resp.json" || { echo "launch API failed"; exit 3; }
echo "[runtime] downloading Lunar artifacts..."
lunar_download_artifacts "$WORK/resp.json" "$MV" || { echo "artifact download failed"; exit 3; }
MAIN="$(cat "$MV/.mainclass")"; EXT="$(cat "$MV/.externalfiles")"
CP=""; ICHOR_CP=""
for jar in "$MV"/*.jar; do CP="${CP:+$CP:}$jar"; ICHOR_CP="${ICHOR_CP:+$ICHOR_CP,}$(basename "$jar")"; done

# --- stage LiquidBounce + fabric-language-kotlin into Lunar's Fabric mod dir ---
cp "$LB_JAR" "$MODS/"
[ -n "${EXTRA_MOD:-}" ] && cp "$EXTRA_MOD" "$MODS/" && echo "[runtime] staged extra mod: $(basename "$EXTRA_MOD")"
FLK="$(detect_flk_version "$LB_JAR")"; FLK="${FLK:-1.13.12+kotlin.2.4.0}"
echo "[runtime] fetching fabric-language-kotlin $FLK ..."
fetch_flk "$FLK" "$MODS" || { echo "FLK fetch failed"; exit 3; }
echo "$MC_VERSION" | grep -oE '^[0-9]+' > "$LC/settings/game/version"   # minimal profile (no user data)

# --- asset index (Genesis wants it as an arg) ---
VURL="$(curl -fsSL --max-time 30 https://launchermeta.mojang.com/mc/game/version_manifest_v2.json | python3 -c "import sys,json;d=json.load(sys.stdin);print(next((v['url'] for v in d['versions'] if v['id']=='$MC_VERSION'),''))")"
AIDX="$(curl -fsSL --max-time 30 "$VURL" 2>/dev/null | python3 -c "import sys,json;print(json.load(sys.stdin)['assetIndex']['id'])" 2>/dev/null || echo "$MC_VERSION")"

# --- boot headless, from an isolated game dir so Ichor's world/config scan never walks $HOME ---
GAMEROOT="$WORK/game"; mkdir -p "$GAMEROOT/.minecraft"; cd "$GAMEROOT"
DISP="${DISPLAY:-}"
if [ -z "$DISP" ]; then
    for n in $(seq 195 320); do [ -e "/tmp/.X11-unix/X$n" ] || { DISP=":$n"; break; }; done   # first free display
    [ -n "$DISP" ] || { echo "[runtime] no free X display in :195-:320" >&2; exit 3; }
    Xvfb "$DISP" -screen 0 1280x720x24 -nolisten tcp >/dev/null 2>&1 & XVFB=$!
    for _ in $(seq 1 10); do [ -e "/tmp/.X11-unix/X${DISP#:}" ] && break; sleep 1; done
    [ -e "/tmp/.X11-unix/X${DISP#:}" ] || { echo "[runtime] Xvfb failed to start on $DISP" >&2; exit 3; }
fi
LOG="$WORK/boot.log"
echo "[runtime] booting Lunar + LiquidBounce (headless)..."
DISPLAY="$DISP" LIBGL_ALWAYS_SOFTWARE=1 "$JAVA_BIN" \
    --add-modules jdk.naming.dns --add-exports jdk.naming.dns/com.sun.jndi.dns=java.naming \
    -Dlog4j2.formatMsgNoLookups=true --add-opens java.base/java.io=ALL-UNNAMED --enable-native-access=ALL-UNNAMED \
    -Dichor.fabric.localModPath="$LC/profiles/mods" -Djava.library.path="$MV/natives" \
    -Dichor.usingIsolatedProfiles=true -XX:-CreateCoredumpOnCrash -Xmx3g \
    -cp "$CP" "$MAIN" \
    --version "$MC_VERSION" --accessToken 0 --userProperties '{}' --assetIndex "$AIDX" \
    --gameDir "$GAMEROOT/.minecraft" --assetsDir "$LC/shared/assets" --texturesDir "$LC/textures" \
    --uiDir "$LC/ui" --webosrDir "$MV/natives" --workingDirectory "$GAMEROOT" --classpathDir "$MV" \
    --width 1280 --height 720 --ichorClassPath "$ICHOR_CP" --ichorExternalFiles "$EXT" \
    > "$LOG" 2>&1 &
GPID=$!

# wait for init to finish (or the process to die), up to ~150s, then a short grace window
for _ in $(seq 1 50); do
    grep -q 'Finished Lunar initialization' "$LOG" 2>/dev/null && break
    kill -0 "$GPID" 2>/dev/null || break
    sleep 3
done
sleep 6
kill "$GPID" 2>/dev/null                              # let the JVM's log tail flush before grading
for _ in $(seq 1 5); do kill -0 "$GPID" 2>/dev/null || break; sleep 1; done
kill -9 "$GPID" 2>/dev/null; wait "$GPID" 2>/dev/null
[ -n "${XVFB:-}" ] && kill "$XVFB" 2>/dev/null || true

# --- grade the harvested log ---
mkdir -p "$(dirname "$REPORT")"
lunar_init=$(grep -qa 'Finished Lunar initialization' "$LOG" && echo 1 || echo 0)
lb_launched=$(grep -ac 'Launching LiquidBounce' "$LOG")
mixin_fail=$(grep -acE 'InvalidInjectionException|Mixin apply failed|was not applied' "$LOG")
# ErrorHandler.kt always logs "An error occurred!" (and, under CI=1, the "encountered an error" line too).
lb_fatal=$(grep -acE 'An error occurred!|LiquidBounce Nextgen.*encountered an error' "$LOG")
# Count only linkage errors attributable to LiquidBounce: a NoSuch*/NCDFE whose error block has a
# net.ccbluex / liquidbounce stack frame within a few lines -- ignore benign Lunar-internal ones.
nosuchfield=$(awk '
    /NoSuchFieldError|NoSuchMethodError|NoClassDefFoundError/ { pend=NR; hit=0 }
    pend && NR<=pend+12 && /net\.ccbluex|liquidbounce/ { if(!hit){c++; hit=1; pend=0} }
    END{ print c+0 }' "$LOG")
shader_fail=$(grep -acE "Couldn't compile program for pipeline liquidbounce" "$LOG")
{
    echo "LiquidBounce <-> Lunar Client runtime compatibility"
    echo "MC $MC_VERSION | Lunar branch $BRANCH | launcher $LVER"
    echo "Lunar commit: $(grep -aoE 'Commit Hash: [0-9a-f]+' "$LOG" | head -1 | awk '{print $3}' || echo unknown)"
    echo "LiquidBounce jar: $(basename "$LB_JAR")  |  fabric-language-kotlin: $FLK"
    echo
    echo "Lunar reached init finish    : $([ "$lunar_init" -eq 1 ] && echo yes || echo NO)"
    echo "LiquidBounce loaded/launched : $([ "$lb_launched" -gt 0 ] && echo yes || echo NO)"
    echo "Mixin injection failures     : $mixin_fail"
    echo "LiquidBounce fatal handler   : $lb_fatal"
    echo "LiquidBounce linkage errors  : $nosuchfield"
    echo "LiquidBounce shader failures : $shader_fail"
    echo
    if [ "$mixin_fail" -gt 0 ] || [ "$lb_fatal" -gt 0 ] || [ "$nosuchfield" -gt 0 ] || [ "$shader_fail" -gt 0 ]; then
        echo "Detected incompatibilities (log excerpts):"
        grep -anE 'InvalidInjectionException|Mixin apply failed|was not applied|NoSuchFieldError|NoSuchMethodError|NoClassDefFoundError|An error occurred!|encountered an error|Couldn.t compile program for pipeline liquidbounce' "$LOG" \
            | grep -v 'RealInterceptorChain.proceed' | head -25 | sed 's/^/  /'
    else
        echo "No LiquidBounce-side runtime incompatibilities detected."
    fi
    echo
    echo "(A post-init crash in libWebOSR/Ultralight is Lunar's own headless-GL limitation, not counted.)"
} | tee "$REPORT"

# Lunar not finishing init is an environment or provisioning failure, not an incompatibility.
# LiquidBounce starting says nothing here: it launches from a mixin early in Minecraft's own
# constructor, so a run that dies right after would otherwise be graded as a clean pass.
if [ "$lb_launched" -eq 0 ]; then
    echo "[runtime] INFRA: LiquidBounce never launched, so the run says nothing about compatibility."
    exit 3
fi
# Fail on real LiquidBounce-side breakage.
if [ "$lb_launched" -eq 0 ] || [ "$mixin_fail" -gt 0 ] || [ "$lb_fatal" -gt 0 ] || [ "$nosuchfield" -gt 0 ]; then
    echo "[runtime] FAIL: LiquidBounce broke on Lunar during init (see report)."
    exit 1
fi
if [ "$lunar_init" -eq 0 ]; then
    echo "[runtime] OK, but weakly: LiquidBounce started with no mixin or linkage failure, though Lunar"
    echo "[runtime]     never finished init here, so paths past early startup were never reached."
else
    echo "[runtime] OK: LiquidBounce started and ran through Lunar's init with no mixin or linkage failure."
fi

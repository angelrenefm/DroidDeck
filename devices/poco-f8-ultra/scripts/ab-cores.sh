#!/bin/bash
# ab-cores.sh: A/B test of core pinning with a Steam game, alternating A B B A.
# A = default (all cores); B = game on 6,7 and the Steam client on 0-5 (SM8850 layout).
# Before each step it closes the game and waits until the battery is below MAXTEMP (default 38 C).
# Each step: start Steam, launch APP, wait, then two 30 s `droiddeckctl pacing` captures plus per-core load.
# At the end it restores the session prefs it changed and prints any difference from before.
# Run from the repository root. Needs `droiddeckctl pacing` (#843). Usage: ab-cores.sh [appid] [maxtemp]
set -u
APP=${1:-1145360}; MAXTEMP=${2:-38}; D="python3 tools/droiddeckctl"
temp() { adb shell dumpsys battery | awk '/temperature/{print $2/10}'; }
prefs() { $D prefs get session 2>/dev/null | python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin)["values"], sort_keys=True))'; }
measure() {
  local s0 s1 out; s0=$(adb shell cat /proc/stat | grep '^cpu[0-9]')
  out=$($D pacing --seconds 30 2>/dev/null); s1=$(adb shell cat /proc/stat | grep '^cpu[0-9]')
  python3 - "$1" "$out" "$s0" "$s1" "$(temp)" <<'PY'
import json, sys
d = json.loads(sys.argv[2]); a = sys.argv[3].split("\n"); b = sys.argv[4].split("\n"); load = []
for x, y in zip(a, b):
    x = list(map(int, x.split()[1:])); y = list(map(int, y.split()[1:]))
    total = sum(y) - sum(x); idle = (y[3] + y[4]) - (x[3] + x[4]); load.append(round(100 * (1 - idle / max(total, 1))))
print("%s: %.1f fps on screen, %.1f %% off-cadence, Hz %s, core load %s, battery %s C"
      % (sys.argv[1], d.get("fpsOnScreen") or 0, d.get("offCadencePercent") or 0, d.get("refreshRates"), load, sys.argv[5]))
PY
}
before=$(prefs); fps_before=$($D prefs get session 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["values"].get("fpsLimit.steam", ""))')
for step in A B B A; do
  $D quit "$APP" --timeout 60 >/dev/null 2>&1; $D stop --timeout 90 >/dev/null 2>&1
  for i in $(seq 80); do t=$(temp); python3 -c "import sys; sys.exit(0 if float('${t:-99}') < $MAXTEMP else 1)" && break; sleep 30; done
  python3 -c "import sys; sys.exit(0 if float('${t:-99}') < $MAXTEMP else 1)" || { echo "stopped: battery stays at ${t} C"; break; }
  $D prefs set session fpsLimit.steam 0 --type int >/dev/null 2>&1
  if [ $step = A ]; then
    $D prefs set session clientCpusOverride false --type bool >/dev/null 2>&1
    for k in clientCpus gameCpus; do $D prefs set session $k --type remove >/dev/null 2>&1; done
  else
    $D prefs set session clientCpusOverride true --type bool >/dev/null 2>&1
    $D prefs set session clientCpus 0,1,2,3,4,5 >/dev/null 2>&1; $D prefs set session gameCpus 6,7 >/dev/null 2>&1
  fi
  $D start steam --wait --timeout 300 >/dev/null 2>&1 || { echo "start failed"; break; }
  $D launch "$APP" --wait --timeout 300 >/dev/null 2>&1; $D wait focused "$APP" --timeout 180 >/dev/null 2>&1
  sleep 50   # past the title screen; adjust per game
  measure "$step-1"; measure "$step-2"
done
$D quit "$APP" --timeout 60 >/dev/null 2>&1; $D stop --timeout 90 >/dev/null 2>&1
if [ -n "$fps_before" ]; then $D prefs set session fpsLimit.steam "$fps_before" --type int >/dev/null 2>&1; else $D prefs set session fpsLimit.steam --type remove >/dev/null 2>&1; fi
for k in clientCpusOverride clientCpus gameCpus; do
  echo "$before" | python3 -c "import json,sys; sys.exit(0 if '$k' in json.load(sys.stdin) else 1)" || $D prefs set session $k --type remove >/dev/null 2>&1
done
python3 - "$before" "$(prefs)" <<'PY'
import json, sys
a, b = json.loads(sys.argv[1]), json.loads(sys.argv[2])
print("prefs changed by this run:", {k: (a.get(k), b.get(k)) for k in set(a) | set(b) if a.get(k) != b.get(k)} or "none")
PY

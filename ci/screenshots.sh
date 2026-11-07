#!/bin/bash
# Takes the App Store screenshots on Simulators, using the fictional data in ScreenshotMode.swift.
# Expects a Debug simulator build at build/Build/Products/Debug-iphonesimulator/IntervalTimer.app.
set -euo pipefail

APP=build/Build/Products/Debug-iphonesimulator/IntervalTimer.app
BUNDLE=com.sethsander.intervals
OUT=screenshots
# Numbered in the order they should appear on the store.
SCREENS=(1:timers 2:running 3:overview 4:log 5:finished 6:editor 7:settings)

# Newest available simulator whose name matches, e.g. "iPhone 17 Pro Max".
udid_for() {
  xcrun simctl list devices available -j | python3 -c '
import json, re, sys
pattern = re.compile(sys.argv[1])
runtimes = json.load(sys.stdin)["devices"]
def version(key):
    return [int(n) for n in re.findall(r"\d+", key)]
for key in sorted((k for k in runtimes if "iOS" in k), key=version, reverse=True):
    matches = sorted((d for d in runtimes[key] if pattern.fullmatch(d["name"])), key=lambda d: d["name"], reverse=True)
    if matches:
        print(matches[0]["udid"], matches[0]["name"], sep="\t")
        break
' "$1"
}

capture() {
  local folder=$1 pattern=$2 line udid name
  line=$(udid_for "$pattern")
  if [ -z "$line" ]; then echo "::error::No simulator matching $pattern"; exit 1; fi
  udid=${line%%$'\t'*}
  name=${line#*$'\t'}
  echo "== $name ($folder)"
  mkdir -p "$OUT/$folder"

  xcrun simctl boot "$udid" || true
  xcrun simctl bootstatus "$udid" -b >/dev/null
  xcrun simctl ui "$udid" appearance light
  xcrun simctl status_bar "$udid" override --time "9:41" --batteryState charged --batteryLevel 100 \
    --cellularBars 4 --wifiBars 3 --dataNetwork wifi
  xcrun simctl install "$udid" "$APP"

  for entry in "${SCREENS[@]}"; do
    local number=${entry%%:*} screen=${entry#*:}
    xcrun simctl terminate "$udid" "$BUNDLE" 2>/dev/null || true
    xcrun simctl launch "$udid" "$BUNDLE" -screenshot "$screen" >/dev/null
    sleep 8
    xcrun simctl io "$udid" screenshot --type=png "$OUT/$folder/$number-$screen.png" >/dev/null
  done

  xcrun simctl terminate "$udid" "$BUNDLE" 2>/dev/null || true
  xcrun simctl shutdown "$udid"
}

# App Store Connect requires the medium Dynamic Island size (1206 x 2622) and the iPad 13-inch size.
capture iphone-6.3-inch 'iPhone \d+ Pro'
capture iphone-6.9-inch 'iPhone \d+ Pro Max'
capture ipad-13-inch 'iPad Pro 13-inch.*'

python3 - "$OUT" <<'PY'
import pathlib, struct, sys
for path in sorted(pathlib.Path(sys.argv[1]).rglob("*.png")):
    width, height = struct.unpack(">II", path.read_bytes()[16:24])
    print(f"{path}: {width} x {height}")
PY

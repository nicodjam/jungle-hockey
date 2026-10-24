#!/usr/bin/env bash
# Jungle Hockey logs from the tablet, without the noise.
#
#   tool/logs.sh            # what is in the log buffer now
#   tool/logs.sh -f         # live (Ctrl+C to stop)
#   tool/logs.sh --clear    # empty the buffer (then reproduce the problem)
#   tool/logs.sh --all      # unfiltered, saved to a file for analysis
#
# Kept: Dart messages (tag flutter), crashes, and Android messages about the app.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
source "$(dirname "$0")/env.sh" --quiet
pick_device

filter='flutter|AndroidRuntime|FATAL|com\.nicodjam\.junglehockey'
case ${1:-} in
  --clear)
    adb logcat -c && ok "Log buffer emptied on $ANDROID_SERIAL: reproduce the problem, then tool/logs.sh" ;;
  -f|--follow)
    adb logcat | grep --line-buffered -E "$filter" ;;
  --all)
    file="logcat-$(date +%Y%m%d-%H%M%S).txt"
    adb logcat -d >"$file" && ok "Saved to $file ($(wc -l <"$file") lines)" ;;
  "")
    adb logcat -d | grep -E "$filter" || warn "Nothing from Jungle Hockey in the buffer" ;;
  *)
    die "Unknown option: $1 (see the top of tool/logs.sh)" ;;
esac

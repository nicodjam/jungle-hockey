#!/usr/bin/env bash
# Installs the last build (tool/build.sh) on the tablet, as an update: the
# app keeps its data.
#
#   tool/install.sh           # on the tablet remembered by tool/connect.sh
#
# Typical: tool/build.sh && tool/install.sh
set -euo pipefail
source "$(dirname "$0")/lib.sh"
source "$(dirname "$0")/env.sh" --quiet
cd "$ROOT"

apk=build/app/outputs/flutter-apk/app-release.apk
[[ -f $apk ]] || die "$apk not found: run tool/build.sh first"
# Only the sources: Gradle rewrites its caches (android/.gradle, build
# folders, local.properties) just after a build, which is not a change.
# Paths that do not exist (no assets/ yet, say) are skipped: find would
# fail on them, and with "set -e" the script would stop without a word.
sources=()
for path in lib assets pubspec.yaml android/app/src \
  android/build.gradle.kts android/app/build.gradle.kts android/settings.gradle.kts \
  android/gradle.properties; do
  [[ -e $path ]] && sources+=("$path")
done
changed=$(find "${sources[@]}" -newer "$apk" -type f | head -1 || true)
if [[ -n $changed ]]; then
  warn "The code changed since this build ($changed): run tool/build.sh to install the latest version"
  confirm "Install this older build anyway?" n || exit 1
fi

pick_device
model=$(adb shell getprop ro.product.model 2>/dev/null | tr -d '\r')
echo "== Installing on $ANDROID_SERIAL ($model)"
if out=$(adb install -r "$apk" 2>&1); then
  ok "Installed"
  exit 0
fi
echo "$out"
case $out in
  *UPDATE_INCOMPATIBLE*)
    err "The installed app is signed with another key (debug vs release)."
    hint "Uninstall it: adb uninstall com.nicodjam.junglehockey, then run again." ;;
  *VERSION_DOWNGRADE*)
    err "The installed version is newer than this build."
    hint "Pull the latest code and rebuild, or uninstall first." ;;
  *INSUFFICIENT_STORAGE*)
    err "Not enough space on the tablet." ;;
  *)
    err "Installation failed (see the message above)." ;;
esac
exit 1

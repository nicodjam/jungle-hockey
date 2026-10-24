# shellcheck shell=bash
# Development environment of Jungle Hockey: finds the tools, puts them in
# the PATH, checks that nothing is missing and says how to install it.
#
#   source tool/env.sh           # exports for this terminal + check (bash or zsh)
#   tool/env.sh                  # check only
#   tool/env.sh --print          # export lines to paste into ~/.bashrc
#   source tool/env.sh --quiet   # exports only (used by the other scripts)
#
# Tools: git, Flutter (with Dart), Java (keytool), Android SDK (adb,
# apksigner), Python 3.

# Sourced from zsh (or another shell): bash does the work, this shell only
# imports the exports. (zsh reads a script command by command, so it never
# reaches the bash-only code below the "return".)
if [ -z "${BASH_VERSION:-}" ]; then
  if [ -n "${ZSH_VERSION:-}" ]; then
    # zsh: folder of the file being sourced.
    # shellcheck disable=SC2296,SC2298
    _rh_dir="${${(%):-%x}:A:h}"
  else
    _rh_dir="$PWD/tool"   # other shells: run it from the project root
  fi
  if [ "${1:-}" != "--quiet" ]; then bash "$_rh_dir/env.sh" "$@"; fi
  eval "$(bash "$_rh_dir/env.sh" --print)"
  unset _rh_dir
  return 0 2>/dev/null || exit 0
fi

_rh_sourced=0; [[ ${BASH_SOURCE[0]} != "$0" ]] && _rh_sourced=1
_rh_print=0; [[ ${1:-} == --print ]] && _rh_print=1
_rh_quiet=0; [[ ${1:-} == --quiet ]] && _rh_quiet=1
# shellcheck source=tool/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# (Both end with "return 0": the calling scripts run with "set -e".)
_rh_orig_path="$PATH"
_rh_first_dir() { for d in "$@"; do [[ -d $d ]] && { echo "$d"; return 0; }; done; return 0; }
_rh_add_path() { [[ -d $1 && ":$PATH:" != *":$1:"* ]] && PATH="$1:$PATH"; return 0; }

# --- Locate -------------------------------------------------------------------

# Flutter: already in the PATH, or a usual install folder.
if ! command -v flutter >/dev/null; then
  _rh_flutter=$(_rh_first_dir "$HOME/flutter/bin" "$HOME/development/flutter/bin" \
    "$HOME/dev/flutter/bin" /opt/flutter/bin /usr/local/flutter/bin)
  [[ -n $_rh_flutter ]] && _rh_add_path "$_rh_flutter"
fi
_rh_add_path "$HOME/.pub-cache/bin"   # dart pub global tools

# Android SDK.
export ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$(_rh_first_dir "$HOME/Android/Sdk" "$HOME/Android/sdk" /opt/android-sdk)}}"
if [[ -n $ANDROID_HOME ]]; then
  _rh_add_path "$ANDROID_HOME/platform-tools"
  _rh_add_path "$ANDROID_HOME/cmdline-tools/latest/bin"
  _rh_bt=$(ls -d "$ANDROID_HOME"/build-tools/*/ 2>/dev/null | sort -V | tail -1)
  [[ -n $_rh_bt ]] && _rh_add_path "${_rh_bt%/}"
fi

# Java: JAVA_HOME, else the one shipped with Android Studio.
if [[ -z ${JAVA_HOME:-} ]]; then
  _rh_java=$(_rh_first_dir "$HOME/android-studio/jbr" /opt/android-studio/jbr \
    /snap/android-studio/current/jbr /usr/local/android-studio/jbr)
  [[ -n $_rh_java ]] && export JAVA_HOME="$_rh_java"
fi
[[ -n ${JAVA_HOME:-} ]] && _rh_add_path "$JAVA_HOME/bin"

export PATH

if [[ $_rh_print == 1 ]]; then
  echo "# Jungle Hockey development tools (from tool/env.sh --print)"
  [[ -n $ANDROID_HOME ]] && echo "export ANDROID_HOME=\"$ANDROID_HOME\""
  [[ -n ${JAVA_HOME:-} ]] && echo "export JAVA_HOME=\"$JAVA_HOME\""
  _rh_added=""
  IFS=: read -ra _rh_dirs <<<"$PATH"
  for d in "${_rh_dirs[@]}"; do
    [[ ":$_rh_orig_path:" != *":$d:"* ]] && _rh_added="$_rh_added$d:"
  done
  [[ -n $_rh_added ]] && echo "export PATH=\"$_rh_added\$PATH\""
  [[ $_rh_sourced == 1 ]] && return 0 || exit 0
fi

if [[ $_rh_quiet == 1 ]]; then
  unset -f _rh_first_dir _rh_add_path
  return 0 2>/dev/null || exit 0
fi

# --- Check --------------------------------------------------------------------

_rh_missing=0
_rh_check() {   # name, command, version command, install hint...
  local name=$1 cmd=$2 version=$3; shift 3
  if command -v "$cmd" >/dev/null; then
    ok "$name: $(eval "$version" 2>/dev/null | head -1)"
  else
    err "$name not found"
    for h in "$@"; do hint "$h"; done
    _rh_missing=$((_rh_missing + 1))
  fi
}

echo "== Jungle Hockey tools"
_rh_check git git "git --version" "sudo apt install git"
_rh_check Flutter flutter "flutter --version --machine 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d[\"frameworkVersion\"], \"(\" + d[\"channel\"] + \"), Dart\", d[\"dartSdkVersion\"])' || flutter --version | head -1" \
  "sudo snap install flutter --classic   (or unpack the SDK in ~/flutter)" \
  "https://docs.flutter.dev/get-started/install/linux/android"
_rh_check "Java (keytool)" keytool "java -version 2>&1 | grep -v '^Picked up' | head -1" \
  "Android Studio ships one in ~/android-studio/jbr (found automatically)" \
  "or: sudo apt install openjdk-17-jdk-headless"
_rh_check "Android SDK: adb" adb "adb --version | head -1" \
  "Android Studio → SDK Manager → SDK Tools → Android SDK Platform-Tools" \
  "or: sudo apt install android-sdk-platform-tools"
_rh_check "Android SDK: apksigner" apksigner "echo \"$_rh_bt\" | sed 's|.*/build-tools/||; s|/$||; s|^|build-tools |'" \
  "Android Studio → SDK Manager → SDK Tools → Android SDK Build-Tools"
_rh_check "Python 3" python3 "python3 --version" "sudo apt install python3"

echo "== Project"
if [[ -n $ANDROID_HOME ]]; then ok "ANDROID_HOME=$ANDROID_HOME"
else err "Android SDK not found"; hint "install Android Studio, or set ANDROID_HOME"; _rh_missing=$((_rh_missing + 1)); fi
if [[ -f $ROOT/android/key.properties ]]; then ok "release key: android/key.properties"
else warn "no android/key.properties: release builds use the debug key (README.md, "Release key")"; fi

if [[ $_rh_missing -gt 0 ]]; then
  err "$_rh_missing tool(s) missing"
else
  ok "everything is there"
fi
[[ $_rh_sourced == 0 ]] && echo "${C_DIM}(tip: 'source tool/env.sh' also sets the PATH of this terminal)${C_END}"
unset -f _rh_first_dir _rh_add_path _rh_check
[[ $_rh_sourced == 1 ]] && return 0 || exit $(( _rh_missing > 0 ))

#!/usr/bin/env bash
# Android builds from the command line (D-13). See ANDROID.md for one-time setup.
#
#   tools/android.sh check      verify Java 17, Android SDK, Godot, export templates, phone
#   tools/android.sh debug      build a debug APK and install it on a USB-connected phone
#   tools/android.sh keystore   create your Play upload key (once; kept outside the repo, C-10)
#   tools/android.sh release    build the signed AAB for Google Play (builds/hollow-king.aab)
#
# Override the Godot command with GODOT=..., e.g.  GODOT="flatpak run org.godotengine.Godot" tools/android.sh debug
set -euo pipefail

cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
KEY_DIR="${HOME}/.android-keys"
UPLOAD_KEYSTORE="${KEY_DIR}/hollowking-upload.keystore"
UPLOAD_ALIAS="hollowking"
DEBUG_KEYSTORE="${HOME}/.android/debug.keystore"
PKG="com.jlyle.hollowking"

ok()   { printf '  \e[32mOK\e[0m   %s\n' "$*"; }
bad()  { printf '  \e[31mFIX\e[0m  %s\n' "$*"; FAILED=1; }
info() { printf '\e[33m==>\e[0m %s\n' "$*"; }

check() {
	FAILED=0
	info "Checking Android build setup"
	if $GODOT --version >/dev/null 2>&1; then
		ok "Godot $($GODOT --version 2>/dev/null | head -1)"
	else
		bad "Godot not found. Install it or set GODOT=... (see ANDROID.md step 1)"
	fi
	if command -v java >/dev/null && java -version 2>&1 | grep -q '"17\.'; then
		ok "Java 17 ($(command -v java))"
	elif [ -n "${JAVA_HOME:-}" ] && "$JAVA_HOME/bin/java" -version 2>&1 | grep -q '"17\.'; then
		ok "Java 17 via JAVA_HOME=$JAVA_HOME"
	else
		bad "Java 17 not found as 'java' or in JAVA_HOME (ANDROID.md step 2)"
	fi
	if [ -n "${ANDROID_HOME:-}" ] && [ -x "$ANDROID_HOME/platform-tools/adb" ]; then
		ok "Android SDK at ANDROID_HOME=$ANDROID_HOME"
		for p in "build-tools/35.0.0" "platforms/android-35" "platforms/android-36" "ndk/28.1.13356709" "cmake/3.10.2.4988404"; do
			if [ -d "$ANDROID_HOME/$p" ]; then ok "  SDK package $p"; else bad "  SDK package $p missing (ANDROID.md step 3)"; fi
		done
	else
		bad "ANDROID_HOME not set or adb missing (ANDROID.md step 3)"
	fi
	local ver
	ver="$($GODOT --version 2>/dev/null | head -1 | sed -E 's/^([0-9.]+[0-9]\.(stable|rc[0-9]*|beta[0-9]*|dev[0-9]*)).*/\1/' || true)"   # e.g. 4.5.stable, 4.5.1.stable
	if [ -n "$ver" ] && { [ -d "$HOME/.local/share/godot/export_templates/$ver" ] || \
		[ -d "$HOME/.var/app/org.godotengine.Godot/data/godot/export_templates/$ver" ]; }; then
		ok "Export templates for $ver"
	else
		bad "Export templates for '${ver:-?}' not installed (ANDROID.md step 4)"
	fi
	if [ -f "$DEBUG_KEYSTORE" ]; then ok "Debug keystore $DEBUG_KEYSTORE"; else info "  debug keystore will be created on first 'debug' build"; fi
	if [ -f "$UPLOAD_KEYSTORE" ]; then ok "Upload keystore $UPLOAD_KEYSTORE"; else info "  no upload keystore yet (only needed for 'release'; run: tools/android.sh keystore)"; fi
	if command -v adb >/dev/null || [ -x "${ANDROID_HOME:-/nonexistent}/platform-tools/adb" ]; then
		local adb_bin; adb_bin="$(command -v adb || echo "$ANDROID_HOME/platform-tools/adb")"
		if "$adb_bin" devices | sed 1d | grep -q 'device$'; then ok "Phone connected over USB"; else info "  no phone connected (needed only to install the debug APK)"; fi
	fi
	[ "$FAILED" = 0 ] && info "All set." || { info "Fix the items marked FIX, then run this again."; return 1; }
}

ensure_debug_keystore() {
	if [ ! -f "$DEBUG_KEYSTORE" ]; then
		info "Creating debug keystore at $DEBUG_KEYSTORE"
		mkdir -p "$(dirname "$DEBUG_KEYSTORE")"
		keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore "$DEBUG_KEYSTORE" \
			-storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12
	fi
}

import_assets() {
	info "Importing assets"
	$GODOT --headless --path . --import >/dev/null 2>&1 || true
}

debug() {
	ensure_debug_keystore
	import_assets
	mkdir -p builds
	info "Exporting debug APK"
	GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$DEBUG_KEYSTORE" \
	GODOT_ANDROID_KEYSTORE_DEBUG_USER="androiddebugkey" \
	GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="android" \
		$GODOT --headless --path . --export-debug "Android Debug (APK)" builds/hollow-king-debug.apk
	ls -lh builds/hollow-king-debug.apk
	local adb_bin; adb_bin="$(command -v adb || echo "${ANDROID_HOME:-}/platform-tools/adb")"
	if [ -x "$adb_bin" ] && "$adb_bin" devices | sed 1d | grep -q 'device$'; then
		info "Installing on phone"
		"$adb_bin" install -r builds/hollow-king-debug.apk
		"$adb_bin" shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 || true
		info "Launched on phone. Live logs:  adb logcat -s godot"
	else
		info "No phone connected. Copy builds/hollow-king-debug.apk to the phone and open it, or connect USB and run again."
	fi
}

keystore() {
	if [ -f "$UPLOAD_KEYSTORE" ]; then
		info "Upload keystore already exists: $UPLOAD_KEYSTORE (not overwriting)"
		return
	fi
	mkdir -p "$KEY_DIR"
	chmod 700 "$KEY_DIR"
	info "Creating your upload key. Use letters and numbers only for the password; you'll type it twice."
	info "Keystore password and key password must be the SAME (Godot requirement)."
	keytool -genkeypair -v -keystore "$UPLOAD_KEYSTORE" -alias "$UPLOAD_ALIAS" -keyalg RSA -keysize 2048 -validity 10000
	chmod 600 "$UPLOAD_KEYSTORE"
	info "Saved $UPLOAD_KEYSTORE"
	info "BACK IT UP NOW (USB stick / password manager) together with the password. See C-10."
}

release() {
	[ -f "$UPLOAD_KEYSTORE" ] || { info "No upload keystore. Run: tools/android.sh keystore"; exit 1; }
	import_assets
	if [ ! -d android/build ]; then
		info "Installing the Android Gradle build template (one time)"
		$GODOT --headless --path . --install-android-build-template
	fi
	read -r -s -p "Upload keystore password: " PASS; echo
	mkdir -p builds
	info "Exporting release AAB"
	# Note: don't set any GODOT_ANDROID_KEYSTORE_DEBUG_* vars here (Godot bug #109551).
	env -u GODOT_ANDROID_KEYSTORE_DEBUG_PATH -u GODOT_ANDROID_KEYSTORE_DEBUG_USER -u GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD \
		GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$UPLOAD_KEYSTORE" \
		GODOT_ANDROID_KEYSTORE_RELEASE_USER="$UPLOAD_ALIAS" \
		GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$PASS" \
		$GODOT --headless --path . --export-release "Android Release (AAB)" builds/hollow-king.aab
	unset PASS
	ls -lh builds/hollow-king.aab
	info "Upload builds/hollow-king.aab in Play Console. Before the NEXT upload, raise version/code in export_presets.cfg (D-12)."
}

case "${1:-}" in
	check) check ;;
	debug) debug ;;
	keystore) keystore ;;
	release) release ;;
	*) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac

#!/usr/bin/env bash
# Linux build, run and install (D-14). Nothing here needs root.
#
#   tools/build.sh check       verify Godot and the Linux export templates
#   tools/build.sh build       export builds/hollow-king.x86_64 (one self-contained binary)
#   tools/build.sh run         build if needed, then run the binary
#   tools/build.sh install     build, then install for your user with an app-menu entry
#   tools/build.sh uninstall   remove the installed binary, icon and menu entry (keeps saves)
#
# Override the Godot command with GODOT=..., e.g.  GODOT="flatpak run org.godotengine.Godot" tools/build.sh build
set -euo pipefail

SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"   # absolute path, before we cd
cd "$(dirname "$SELF")/.."
GODOT="${GODOT:-godot}"
BIN="builds/hollow-king.x86_64"
INSTALL_BIN="$HOME/.local/bin/hollow-king"
INSTALL_ICON="$HOME/.local/share/icons/hicolor/512x512/apps/hollow-king.png"
INSTALL_DESKTOP="$HOME/.local/share/applications/hollow-king.desktop"
SAVE_DIR="$HOME/.local/share/godot/app_userdata/Depths of the Hollow King"

ok()   { printf '  \e[32mOK\e[0m   %s\n' "$*"; }
bad()  { printf '  \e[31mFIX\e[0m  %s\n' "$*"; FAILED=1; }
info() { printf '\e[33m==>\e[0m %s\n' "$*"; }

godot_version() {   # e.g. 4.7.1.stable
	$GODOT --version 2>/dev/null | head -1 | sed -E 's/^([0-9.]+[0-9]\.(stable|rc[0-9]*|beta[0-9]*|dev[0-9]*)).*/\1/'
}

check() {
	FAILED=0
	info "Checking Linux build setup"
	if $GODOT --version >/dev/null 2>&1; then
		ok "Godot $($GODOT --version 2>/dev/null | head -1)"
	else
		bad "Godot not found. Install it or set GODOT=..."
	fi
	local ver found=""
	ver="$(godot_version || true)"
	for d in "$HOME/.local/share/godot/export_templates/$ver" "$HOME/.var/app/org.godotengine.Godot/data/godot/export_templates/$ver"; do
		[ -f "$d/linux_release.x86_64" ] && found="$d"
	done
	if [ -n "$found" ]; then
		ok "Linux export templates for $ver"
	else
		bad "Linux export templates for '${ver:-?}' not found. Install them (README: Build & install)."
	fi
	if [ -x "$BIN" ]; then ok "Built binary: $BIN"; else info "  not built yet (run: tools/build.sh build)"; fi
	if [ -x "$INSTALL_BIN" ]; then ok "Installed: $INSTALL_BIN"; else info "  not installed (run: tools/build.sh install)"; fi
	case ":$PATH:" in *":$HOME/.local/bin:"*) ok "~/.local/bin is on your PATH" ;; *) info "  ~/.local/bin is not on PATH (the app-menu entry still works)" ;; esac
	[ "$FAILED" = 0 ] && info "All set." || { info "Fix the items marked FIX, then run this again."; return 1; }
}

build() {
	mkdir -p builds
	info "Importing assets"
	$GODOT --headless --path . --import >/dev/null 2>&1 || true
	info "Exporting Linux binary"
	$GODOT --headless --path . --export-release "Linux" "$BIN"
	chmod +x "$BIN"
	ls -lh "$BIN"
}

run() {
	# Rebuild when any game file is newer than the binary.
	if [ ! -x "$BIN" ] || [ -n "$(find scripts scenes art audio project.godot -newer "$BIN" -print -quit)" ]; then
		build
	fi
	exec "./$BIN"
}

install() {
	build
	info "Installing for $USER"
	mkdir -p "$(dirname "$INSTALL_BIN")" "$(dirname "$INSTALL_ICON")" "$(dirname "$INSTALL_DESKTOP")"
	cp "$BIN" "$INSTALL_BIN"
	chmod +x "$INSTALL_BIN"
	cp art/icon_512.png "$INSTALL_ICON"
	sed "s|@BIN@|$INSTALL_BIN|" packaging/hollow-king.desktop > "$INSTALL_DESKTOP"
	command -v update-desktop-database >/dev/null && update-desktop-database "$(dirname "$INSTALL_DESKTOP")" >/dev/null 2>&1 || true
	command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -q "$HOME/.local/share/icons/hicolor" >/dev/null 2>&1 || true
	ok "Binary   $INSTALL_BIN"
	ok "Icon     $INSTALL_ICON"
	ok "Menu     $INSTALL_DESKTOP"
	info "Start it from your app menu (Games → Depths of the Hollow King) or run: hollow-king"
}

uninstall() {
	rm -f "$INSTALL_BIN" "$INSTALL_ICON" "$INSTALL_DESKTOP"
	command -v update-desktop-database >/dev/null && update-desktop-database "$(dirname "$INSTALL_DESKTOP")" >/dev/null 2>&1 || true
	info "Removed the game, icon and menu entry."
	info "Your saves and settings are still in: $SAVE_DIR"
}

case "${1:-}" in
	check) check ;;
	build) build ;;
	run) run ;;
	install) install ;;
	uninstall) uninstall ;;
	*) sed -n '2,10p' "$SELF" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac

#!/usr/bin/env bash
# Linux build, run and install (D-14). Nothing here needs root.
#
#   tools/build.sh check       verify Godot and the Linux export templates
#   tools/build.sh build       export builds/hollow-king.x86_64 (one self-contained binary)
#   tools/build.sh run         build if needed, then run the binary
#   tools/build.sh install     build, then install for your user with an app-menu entry
#   tools/build.sh uninstall   remove the installed binary, icon and menu entry (keeps saves)
#   tools/build.sh flatpak     build builds/hollow-king.flatpak (one file for any x86_64 distro) and install it for you
#   tools/build.sh flatpak-run run the installed Flatpak
#   tools/build.sh release     build both downloads for itch.io / GitHub Releases into builds/release/ (R-25)
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
APP_ID="io.github.jlyle.HollowKing"                       # D-16 - never change once shared
RUNTIME_VER="25.08"                                       # org.freedesktop.Platform branch (D-16)
FLATHUB="https://dl.flathub.org/repo/flathub.flatpakrepo"

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
	if command -v flatpak-builder >/dev/null; then ok "flatpak-builder (for: tools/build.sh flatpak)"; else info "  flatpak-builder not installed (only needed for the Flatpak: sudo dnf install flatpak-builder)"; fi
	case ":$PATH:" in *":$HOME/.local/bin:"*) ok "~/.local/bin is on your PATH" ;; *) info "  ~/.local/bin is not on PATH (the app-menu entry still works)" ;; esac
	[ "$FAILED" = 0 ] && info "All set." || { info "Fix the items marked FIX, then run this again."; return 1; }
}

## Keep Godot out of build output and Flatpak build trees (they contain links into /proc,
## which makes the import scan loop forever).
gdignore() {
	mkdir -p builds
	touch builds/.gdignore
	[ -d .flatpak-builder ] && touch .flatpak-builder/.gdignore
	return 0
}

build() {
	gdignore
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

# --- Flatpak (R-24, D-16) ---------------------------------------------------------------

flatpak_build() {
	command -v flatpak >/dev/null || { info "Flatpak isn't installed: sudo dnf install flatpak"; exit 1; }
	command -v flatpak-builder >/dev/null || { info "flatpak-builder isn't installed: sudo dnf install flatpak-builder"; exit 1; }
	info "Making sure the Flathub remote and the $RUNTIME_VER runtime + SDK are installed (first time: ~1 GB)"
	flatpak remote-add --user --if-not-exists flathub "$FLATHUB"
	flatpak install --user --noninteractive flathub "org.freedesktop.Platform//$RUNTIME_VER" "org.freedesktop.Sdk//$RUNTIME_VER"

	build
	info "Staging Flatpak sources in builds/flatpak/src"
	rm -rf builds/flatpak/src
	mkdir -p builds/flatpak/src
	cp packaging/flatpak/* builds/flatpak/src/
	cp "$BIN" builds/flatpak/src/hollow-king.x86_64
	cp art/icon_512.png builds/flatpak/src/

	info "Building the Flatpak and installing it for $USER"
	flatpak-builder --user --install --force-clean --disable-rofiles-fuse --state-dir=builds/flatpak/state \
		--repo=builds/flatpak/repo builds/flatpak/build-dir "builds/flatpak/src/$APP_ID.yml"

	info "Writing the single-file bundle"
	flatpak build-bundle --runtime-repo="$FLATHUB" builds/flatpak/repo builds/hollow-king.flatpak "$APP_ID"
	ls -lh builds/hollow-king.flatpak
	ok "Installed on this PC: start it from the app menu or run  tools/build.sh flatpak-run"
	info "To give it to someone: send builds/hollow-king.flatpak. They run:"
	info "    flatpak install --user hollow-king.flatpak"
	info "(the runtime it needs is downloaded from Flathub automatically)"
}

flatpak_run() {
	exec flatpak run "$APP_ID"
}

# --- Free public release (R-25, D-17) ----------------------------------------------------

release() {
	local ver dir name
	ver="$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)"
	[ -n "$ver" ] || { info "No config/version in project.godot"; exit 1; }
	flatpak_build
	dir="builds/release"
	name="hollow-king-$ver-linux-x86_64"
	info "Packing release $ver into $dir"
	rm -rf "$dir"; mkdir -p "$dir/$name"
	cp "$BIN" "$dir/$name/hollow-king.x86_64"
	chmod +x "$dir/$name/hollow-king.x86_64"
	cp LICENSE LICENSES.md "$dir/$name/"
	cp art/icon_512.png "$dir/$name/icon.png"
	cat > "$dir/$name/README.txt" <<EOF
Depths of the Hollow King $ver - free and open source (see LICENSES.md)

Run:   ./hollow-king.x86_64
Needs: 64-bit Linux with OpenGL 3.3 graphics. Saves go in
       ~/.local/share/godot/app_userdata/Depths of the Hollow King/

Prefer a sandboxed app-menu install? Use hollow-king-$ver.flatpak instead:
       flatpak install --user hollow-king-$ver.flatpak

Source: https://github.com/jlyle/hollow-king
EOF
	tar -C "$dir" -czf "$dir/$name.tar.gz" "$name"     # tar keeps the executable bit; zip may not
	rm -rf "${dir:?}/$name"
	cp builds/hollow-king.flatpak "$dir/hollow-king-$ver.flatpak"
	(cd "$dir" && sha256sum ./*.tar.gz ./*.flatpak > SHA256SUMS)
	ls -lh "$dir"
	ok "Release $ver ready in $dir"
	info "itch.io (butler):"
	info "    butler push $dir/$name.tar.gz jlyle/hollow-king:linux --userversion $ver"
	info "    butler push $dir/hollow-king-$ver.flatpak jlyle/hollow-king:linux-flatpak --userversion $ver"
	info "GitHub Release (gh CLI):"
	info "    gh release create v$ver $dir/* --title \"v$ver\" --notes \"Free download for Linux\""
}

case "${1:-}" in
	check) check ;;
	build) build ;;
	run) run ;;
	install) install ;;
	uninstall) uninstall ;;
	flatpak) flatpak_build ;;
	flatpak-run) flatpak_run ;;
	release) release ;;
	*) sed -n '2,13p' "$SELF" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac

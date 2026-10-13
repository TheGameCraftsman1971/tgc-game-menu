#!/usr/bin/env bash
# install-into.sh — copies the add-on into a Godot project, or updates the copy there.
#
#   tools/install-into.sh <godot project folder>
#
# Copies addons/tgc_game_menu/ over the project's own, removing the files the add-on no
# longer has. The files Godot generates (*.uid, *.import, *.translation) are neither copied
# nor removed: the project keeps its own. Then: open the project once (or run
# `godot --headless --path <project> --editor --quit-after 150`) so that Godot imports the
# catalogue, enable the plugin if it is new there, and run the project's bench.

set -euo pipefail
SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/addons/tgc_game_menu/"
TARGET="${1:-}"
[ -n "$TARGET" ] || { echo "usage: $0 <godot project folder>" >&2; exit 2; }
[ -f "$TARGET/project.godot" ] || { echo "not a Godot project (no project.godot): $TARGET" >&2; exit 1; }
mkdir -p "$TARGET/addons/tgc_game_menu"
rsync -a --delete --exclude '*.uid' --exclude '*.import' --exclude '*.translation' \
  "$SOURCE" "$TARGET/addons/tgc_game_menu/"
echo "TGC Game Menu $(sed -n 's/^version="\(.*\)"/\1/p' "$SOURCE/plugin.cfg") -> $TARGET/addons/tgc_game_menu/" >&2
if ! grep -q 'tgc_game_menu/plugin.cfg' "$TARGET/project.godot"; then
  echo "The plugin is not enabled there yet: Project > Project Settings > Plugins." >&2
fi

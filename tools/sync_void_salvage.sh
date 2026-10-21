#!/usr/bin/env bash
# Copies the shared part of Void Salvage into shared/void_salvage/ at a pinned commit.
# Owned by the Shared Components thread. Never edit the copies: change Void Salvage, re-sync.
# The only change made on the way in: res://shaders/ includes are re-pointed at the copies.
# Usage:  tools/sync_void_salvage.sh <path to a void-salvage checkout> [commit]
#   commit defaults to the checkout's HEAD; the checkout must have no local changes.
set -euo pipefail
cd "$(dirname "$0")/.."

SRC="${1:?usage: tools/sync_void_salvage.sh <void-salvage checkout> [commit]}"
COMMIT="${2:-$(git -C "$SRC" rev-parse HEAD)}"
DEST=shared/void_salvage

# The files BSX uses, with no links into the rest of Void Salvage (checked by tracing class
# references). Add a file only with everything it refers to.
FILES=(
	scripts/parts/frame_parts.gd
	scripts/parts/hull_builder.gd
	scripts/parts/mesh_kit.gd
	scripts/parts/part_shapes.gd
	scripts/parts/ship_parts.gd
	scripts/parts/wreck_parts.gd
	scripts/salvage/connection_data.gd
	scripts/salvage/frame_hull.gd
	scripts/salvage/frame_member.gd
	scripts/salvage/frame_style.gd
	scripts/salvage/frame_target.gd
	scripts/salvage/glazing.gd
	scripts/salvage/joint_batch.gd
	scripts/salvage/joint_view.gd
	scripts/salvage/materials.gd
	scripts/salvage/part_data.gd
	scripts/salvage/part_model.gd
	scripts/salvage/surface_detail.gd
	scripts/salvage/surface_finish.gd
	scripts/salvage/surface_zones.gd
	scripts/salvage/wiring_loom.gd
	scripts/ship/ship_kit.gd
	scripts/ship/ship_recorder.gd
	scripts/ship/ship_surface.gd
	data/ship_format/vsship-1.schema.json
	data/wreck_format/vswreck-1.schema.json
	shaders/salvage_surface.gdshader
	shaders/joint_head.gdshader
	shaders/survey_glass.gdshaderinc
)

if [ -n "$(git -C "$SRC" status --porcelain)" ]; then
	echo "$SRC has local changes; sync from a clean checkout." >&2
	exit 1
fi

# Wipe what the last sync copied (keep the README), then copy from the commit itself.
find "$DEST" -mindepth 1 ! -name README.md -delete
for f in "${FILES[@]}"; do
	mkdir -p "$DEST/$(dirname "$f")"
	git -C "$SRC" show "$COMMIT:$f" > "$DEST/$f"
	if git -C "$SRC" cat-file -e "$COMMIT:$f.uid" 2>/dev/null; then
		git -C "$SRC" show "$COMMIT:$f.uid" > "$DEST/$f.uid"
	fi
done
# The one change a sync makes: Void Salvage paths inside the copies point at the copies.
grep -rl 'res://shaders/' "$DEST" | xargs -r sed -i "s#res://shaders/#res://$DEST/shaders/#g"
git -C "$SRC" rev-parse "$COMMIT" > "$DEST/SOURCE_COMMIT"
git -C "$SRC" show -s --format=%ci "$COMMIT" > "$DEST/SOURCE_DATE"
echo "Synced ${#FILES[@]} files from Void Salvage $(cut -c1-7 "$DEST/SOURCE_COMMIT")."

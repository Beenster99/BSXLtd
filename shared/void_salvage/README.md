# Void Salvage files (synced, do not edit)

Files copied from the Void Salvage repo at a pinned commit by `tools/sync_void_salvage.sh`
(owned by the Shared Components thread). Nothing here is edited by hand: change it in Void
Salvage and re-sync. Every module may use `res://shared/`.

BSX must never define a `class_name` or autoload with the same name as a Void Salvage class
(`Hud`, `PartData`, `MeshKit`, ...); `tools/check_boundaries.py` fails the build if it does.

`ShipParts` (the player ships' fittings) builds on a `ShipKit` made for any body (the
MegaKit assets and `KitParts` are gone from Void Salvage since its A3 phase).

Since Void Salvage 0.96.0 a `ShipKit` is a `FrameTarget`: it holds a `PartModel` (parts and
joints on any `RigidBody3D`, drawn by `JointBatch`/`JointView`), and `FrameHull` builds a hull
on it as parts and joints in a `FrameStyle` (the Kestrel's node style, the wrecks' mitred
one). `ShipRecorder` records a build for the `vsship` file. The two JSON schemas under
`data/` (`vsship-1`, `vswreck-1`) are the file formats BSX imports; the prose is Void
Salvage's docs/SHIP_FORMAT_PLAN.md and docs/WRECK_FORMAT.md.

Since 0.101.0 (F3 of docs/SHIP_FRAME_PLAN.md) `FrameHull` is the one hull pipeline: the
wrecks' `SalvageHull` is `FrameHull` in the mitred style, the frame Kestrel is the node style
with flush cladding (`groove`), bolted linings, framed openings (jambs) and subtle heads
(`FrameStyle.SUBTLE`, `JointView.painted_material`). Every part and joint it makes carries a
stable `path` (`PartData.path`, `ConnectionData.path`: what it is, not when it was built), the
handle BSX will read, write and diff in `vsship` 2.0. `HullBuilder` is still here for BSX's
hand-built Kestrel but Void Salvage deletes it at F6b: move to `FrameHull` before then.

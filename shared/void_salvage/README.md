# Void Salvage files (synced, do not edit)

Files copied from the Void Salvage repo at a pinned commit by `tools/sync_void_salvage.sh`
(owned by the Shared Components thread). Nothing here is edited by hand: change it in Void
Salvage and re-sync. Every module may use `res://shared/`.

BSX must never define a `class_name` or autoload with the same name as a Void Salvage class
(`Hud`, `PartData`, `MeshKit`, ...); `tools/check_boundaries.py` fails the build if it does.

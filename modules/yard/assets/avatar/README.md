# The suit, from Void Salvage

Copied from Void Salvage at commit 6523ae5 (stage 1.3 of the shipbuilder plan, with Dan's
agreement of 18 Nov 2026). Never edited here by hand: re-copy from Void Salvage to update.

| Here | Void Salvage |
|---|---|
| kestrel.glb, hands.glb | assets/players/ (the Kestrel suit, baked in Blender, and the hands) |
| player_assets.json | data/player_assets.json |
| player_finish.gdshader, player_visor.gdshader, light_beam.gdshader, distress_point.gdshader | shaders/ |
| paintedmetal002/, metal010/, rubber004/ | assets/materials/ (only the maps the suit's finish reads) |

The code is in `internal/avatar/` under yard names: YardAvatar (Void Salvage's PlayerModel),
YardSuitLook (SuitLook), YardSuitAssets (PlayerAssets) and YardCameraFeel (CameraFeel).

No recorded sound from Void Salvage is used anywhere (those are on Dan's own licence).

## Credits

The scans are CC0 1.0 from ambientCG (ambientcg.com/license), prepared by Void Salvage's
`tools/materials/prepare_scan.py`:

- paintedmetal002: "PaintedMetal002" (ambientcg.com/view?id=PaintedMetal002)
- metal010: "Metal010" (ambientcg.com/view?id=Metal010)
- rubber004: "Rubber004" (ambientcg.com/view?id=Rubber004)

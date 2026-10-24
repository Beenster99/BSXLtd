class_name UpgradePriceList
extends Resource
## What BSX's component upgrades cost and sell for (internal/data/upgrades.tres): per unit
## family, per tier, the BSX-only add-on parts it takes and roughly how many joints fitting
## them is. Part ids are the add-on ids of Shared Components' upgrade rules (quantum_core_1,
## field_emitter_1, control_board...), so one id runs from the crate to the certificate; the
## rated figures a tier reaches are theirs too. This only prices the work.

@export var version := 1
## Unit id ("attractor_coil") -> {"name": String, "unit_value": int (CR, a stock unit),
## "tiers": {tier (int): {"parts": {part: qty}, "joints": int}}}.
@export var units: Dictionary = {}
## Markup on the add-on parts BSX charges a client, percent.
@export_range(0, 200) var parts_markup_percent := 25
## Labour charged per joint fitted, CR.
@export var labour_per_joint := 150
## Quality: a unit tested at exactly its rated figures sells at this share of full price;
## each 1% it beats them adds `beat_step` more, up to `best_share`. Below rated it fails.
@export var scrape_share := 0.85
@export var beat_step := 0.03
@export var best_share := 1.2


## The quality share of full price for a tested/rated ratio: 0 when it falls short.
func quality_share(ratio: float) -> float:
	if ratio < 1.0 - 0.0001:
		return 0.0
	return minf(best_share, scrape_share + beat_step * (ratio - 1.0) * 100.0)

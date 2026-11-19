class_name SupplyVendor
extends Resource
## A vendor of ship parts on the parts market (internal/data/vendors/*.tres): what it stocks,
## how it prices, how fast and how reliably it delivers, and what a good account with it is
## worth. Prices, deals and history follow from these numbers (SupplyMarket).

@export var version := 1
@export var id := ""
@export var display_name := ""
## One line on the screen under its name.
@export var tagline := ""
@export var colour := Color(0.6, 0.8, 1.0)
## Design catalogue categories it stocks (DesignCatalog.CATEGORIES ids), plus the parts list's
## own: "hull" (frame, skin, fasteners, decks), "services" (wiring and pipe runs), "fitout"
## (rooms fitted out by the square metre). Empty = everything.
@export var categories: PackedStringArray = PackedStringArray()
## Grades it sells graded parts in (DesignGrades.GRADE_ORDER codes).
@export var grades: PackedStringArray = PackedStringArray(["S"])
## Price against the catalogue's (1.0 = list price).
@export_range(0.3, 2.0) var price_factor := 1.0
## How far its own price sits from its average, part by part (0.08 = +/- 8%).
@export_range(0.0, 0.4) var spread := 0.06
## How much its prices move about day to day on top of the market's own swings (0.05 = +/- 5%).
@export_range(0.0, 0.3) var volatility := 0.04
## Chance (0-1) an order arrives complete and on time, before standing and volume.
@export_range(0.0, 1.0) var reliability := 0.9
## Days added to (or taken off) a part's own supplier wait.
@export var lead_days := 0
## Units of one part it holds; beyond that each further batch waits `restock_days` more.
@export var stock := 6
@export var restock_days := 3
## Volume discount: units of one line -> percent off ({10: 4, 25: 8}).
@export var volume_percent: Dictionary = {10: 3, 25: 6, 50: 10}
## Deals it runs each week: how many, and the percent off (a range).
@export var deals_per_week := 2
@export var deal_percent := Vector2i(8, 22)
## Standing (0-100) a new company starts on with it.
@export_range(0, 100) var standing_start := 20


func stocks(category: String) -> bool:
	return categories.is_empty() or categories.has(category)


func sells_grade(grade: String) -> bool:
	return grades.has(grade if grade != "" else "S")


## Percent off for `units` of one line.
func volume_off(units: int) -> int:
	var best := 0
	for n in volume_percent:
		if units >= int(n):
			best = maxi(best, int(volume_percent[n]))
	return best

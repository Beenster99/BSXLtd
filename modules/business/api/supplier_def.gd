class_name SupplierDef
extends Resource
## A parts supplier (internal/data/suppliers/*.tres).

@export var version := 1
@export var id := ""
@export var display_name := ""
## Part name -> price multiplier on the PriceList base price: staples (fasteners) always on
## its counter, new, in any quantity.
@export var parts: Dictionary = {}
## Market catalogue categories it deals in ("engines", "hull", ...); its daily listings
## are drawn from these.
@export var categories: PackedStringArray = []
## Conditions it sells, with the weight of each in its daily listings.
@export var conditions: Dictionary = {"new": 1.0}
## How many market listings it puts up each day.
@export var listings_per_day := 0
## Trade price as a share of Void Salvage's value, before condition and the day's swing.
@export_range(0.1, 2.0) var trade_factor := 0.85
## How long its deliveries take to arrive, real seconds (a range: each listing rolls its
## own). Kept short so nobody waits on a truck.
@export var lead_seconds := Vector2i(10, 40)
## Chance (0-1) an order arrives on time and intact. A miss holds it up a few seconds
## (Books.DELAY_SECONDS) the first time and damages one item the second.
@export_range(0.0, 1.0) var reliability := 0.9
## Hidden until the company's reputation reaches this.
@export var min_reputation := 0.0
## Share of the cost refunded when an order is cancelled before it arrives.
@export_range(0, 100) var cancellation_refund_percent := 50
## Bulk buys: order at least this many of one listing -> percent off ({10: 5, 25: 10}).
@export var bulk_percent: Dictionary = {10: 5, 25: 10, 50: 15}
## Deals it runs each day: listings marked down by `deal_percent` (a range, % off).
@export var deals_per_day := 3
@export var deal_percent := Vector2i(15, 35)
## What it pays for parts the company sells it, as a share of Void Salvage's value, before
## condition and the day's swing. Only for the categories it deals in.
@export_range(0.0, 1.5) var buy_factor := 0.5
## How far its own prices sit from the trade price, part by part (0.1 = +/- 10%).
@export_range(0.0, 0.5) var price_spread := 0.1


## The bulk discount (percent off) for buying `qty` of one listing.
func bulk_off(qty: int) -> int:
	var best := 0
	for n in bulk_percent:
		if qty >= int(n):
			best = maxi(best, int(bulk_percent[n]))
	return best


## "10+ 5%  25+ 10%" for a listing's line; "" with no bulk prices.
func bulk_text() -> String:
	var keys := bulk_percent.keys()
	keys.sort()
	var parts_out := PackedStringArray()
	for n in keys:
		parts_out.append("%d+ %d%%" % [int(n), int(bulk_percent[n])])
	return "  ".join(parts_out)


func sells(part: String) -> bool:
	return parts.has(part)


func deals_in(category: String) -> bool:
	return categories.has(category)

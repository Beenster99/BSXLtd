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
@export var lead_hours := 24
## Chance (0-1) an order arrives on time and intact. A miss delays it a day the first
## time and damages one item the second.
@export_range(0.0, 1.0) var reliability := 0.9
## Hidden until the company's reputation reaches this.
@export var min_reputation := 0.0
## Share of the cost refunded when an order is cancelled before it arrives.
@export_range(0, 100) var cancellation_refund_percent := 50


func sells(part: String) -> bool:
	return parts.has(part)


func deals_in(category: String) -> bool:
	return categories.has(category)

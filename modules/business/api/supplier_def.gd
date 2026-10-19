class_name SupplierDef
extends Resource
## A parts supplier (internal/data/suppliers/*.tres).

@export var version := 1
@export var id := ""
@export var display_name := ""
## Part name (as in Shared Components) -> price multiplier on the PriceList base price.
@export var parts: Dictionary = {}
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

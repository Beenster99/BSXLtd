class_name PriceList
extends Resource
## Base price per part (internal/data/prices.tres). Kept on the BSX side so the component
## library shared with Void Salvage stays free of BSX economics.

@export var version := 1
## Part name -> base price in credits.
@export var prices: Dictionary = {}
## Part name -> what players read, for staples the market catalogue doesn't list.
@export var names: Dictionary = {}


func price_of(part: String) -> int:
	return int(prices.get(part, -1))

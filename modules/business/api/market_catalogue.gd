class_name MarketCatalogue
extends Resource
## The parts a ship yard can buy (internal/data/market_catalogue.tres), keyed by Void
## Salvage's part_name. Built from Void Salvage's PartCatalog and measured designs by
## internal/tools/build_market_catalogue.py; never edited by hand.

@export var version := 1
## The Void Salvage commit the list was built from.
@export var source_commit := ""
## part_name -> {name, category, value (credits, clean and new), mass (kg), blurb}.
@export var parts: Dictionary = {}


func has_part(part: String) -> bool:
	return parts.has(part)


func display_name(part: String) -> String:
	return str(parts.get(part, {}).get("name", part))


func category_of(part: String) -> String:
	return str(parts.get(part, {}).get("category", ""))


## What Void Salvage values the part at, new and clean; -1 for an unknown part.
func value_of(part: String) -> int:
	return int(parts.get(part, {}).get("value", -1))


func mass_of(part: String) -> float:
	return float(parts.get(part, {}).get("mass", 0.0))


func blurb_of(part: String) -> String:
	return str(parts.get(part, {}).get("blurb", ""))


## Part names, optionally only one category's, sorted.
func part_names(category := "") -> PackedStringArray:
	var out := PackedStringArray()
	for p: String in parts:
		if category == "" or parts[p].get("category") == category:
			out.append(p)
	out.sort()
	return out


## Every category present, sorted.
func categories() -> PackedStringArray:
	var seen := {}
	for p: String in parts:
		seen[str(parts[p].get("category", ""))] = true
	var out := PackedStringArray(seen.keys())
	out.sort()
	return out

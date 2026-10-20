class_name PartCondition
extends RefCounted
## The state a bought part comes in. Cheaper parts are worse parts: Quality and Trades can
## read `wear_of` to make a used or damaged part harder to fit well.

const NEW := "new"
const REFURBISHED := "refurbished"
const USED := "used"
const DAMAGED := "damaged"
## Best first.
const ALL: PackedStringArray = [NEW, REFURBISHED, USED, DAMAGED]

const _PRICE := {NEW: 1.0, REFURBISHED: 0.78, USED: 0.58, DAMAGED: 0.3}
const _WEAR := {NEW: 0.0, REFURBISHED: 0.1, USED: 0.3, DAMAGED: 0.65}
const _LABEL := {NEW: "NEW", REFURBISHED: "REFURB", USED: "USED", DAMAGED: "DAMAGED"}


static func is_valid(condition: String) -> bool:
	return _PRICE.has(condition)


## Share of the new price a part in this condition sells for.
static func price_factor(condition: String) -> float:
	return float(_PRICE.get(condition, 1.0))


## 0 (as new) to 1 (scrap): how worn the part is when it arrives.
static func wear_of(condition: String) -> float:
	return float(_WEAR.get(condition, 0.0))


static func label(condition: String) -> String:
	return str(_LABEL.get(condition, condition.to_upper()))


## 0 for new, higher for worse.
static func rank(condition: String) -> int:
	return maxi(0, ALL.find(condition))

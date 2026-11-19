class_name DesignPower
extends RefCounted
## How a ship's power sources behave, as data to tune (beenster, 19 Nov: can a contract's power
## demand be met by solar panels? Yes, as a real choice):
## - Solar burns no fuel and is quiet (SOLAR_SIGNATURE_SHARE of the usual heat per kW), but what
##   it delivers depends on the sunlight where the ship works (SUN by region, from the contract).
## - Batteries and capacitor banks store power (STORE_HOURS of their rating, kWh): they carry a
##   solar ship through shadow (SHADOW_HOURS) and are not generators.
## - Generators and reactors burn fuel (BURN, m3 a kWh): with the tanks they give the ship's
##   endurance, days without refuelling (DesignTotals.endurance_days()).
## Parts are keyed by their base type id (a variant "solar_panel:5H" is "solar_panel").

## What each power part is: "solar", "store" or "fuelled". Anything else that makes power is
## "fuelled" at DEFAULT_BURN.
const KIND: Dictionary = {
	"solar_panel": "solar",
	"battery_bank": "store",
	"capacitor_bank": "store",
}

## Hours of its rated output a store holds, so its capacity is power x hours, kWh.
const STORE_HOURS: Dictionary = {"battery_bank": 8.0, "capacitor_bank": 0.5}

## Fuel burned per kWh made, m3. Reactors burn their own core slowly; generators drink.
const BURN: Dictionary = {
	"generator": 0.0004,
	"gas_generator": 0.0005,
	"hydrogen_generator": 0.0003,
	"fission_pile": 0.00002,
	"reactor_small": 0.00002,
	"reactor_core": 0.00002,
}
const DEFAULT_BURN := 0.0004

## Parts that count as a reactor aboard (a "no reactor" clause).
const REACTORS: PackedStringArray = ["fission_pile", "reactor_small", "reactor_core"]

## Share of full sunlight by working region (an order's "region"; none = "inner").
const SUN: Dictionary = {"inner": 1.0, "mid": 0.6, "outer": 0.25, "deep": 0.02}
const DEFAULT_REGION := "inner"
## Region names to show.
const REGION_NAMES: Dictionary = {"inner": "Inner system", "mid": "Mid system", "outer": "Outer system",
		"deep": "Deep space"}

## Hours in shadow (behind a planet, docked in a shadowed bay) a solar ship must ride out on its
## stores, by region.
const SHADOW_HOURS: Dictionary = {"inner": 1.0, "mid": 1.5, "outer": 2.5, "deep": 2.5}

## Solar's share of the signature a kW of power usually adds (SIGNATURE_PER_KW).
const SOLAR_SIGNATURE_SHARE := 0.05

## Endurance never reads more than this, days (stores, air and crew run out long before).
const ENDURANCE_CAP := 365.0

## Folding arrays (moving-parts and 3D models threads): their share of the hull they take when
## stowed. Empty until those parts land.
const STOWED_SHARE: Dictionary = {}


static func base_id(type_id: String) -> String:
	return type_id.get_slice(":", 0)


## What a part is, for power: "solar", "store", "fuelled" or "" (makes none).
static func kind_of(type_id: String, power: float) -> String:
	var b := base_id(type_id)
	if KIND.has(b):
		return str(KIND[b])
	return "fuelled" if power > 0.0 else ""


static func burn_of(type_id: String) -> float:
	return float(BURN.get(base_id(type_id), DEFAULT_BURN))


static func sun(region: String) -> float:
	return float(SUN.get(region, SUN[DEFAULT_REGION]))


static func shadow_hours(region: String) -> float:
	return float(SHADOW_HOURS.get(region, SHADOW_HOURS[DEFAULT_REGION]))


## The working region of a design: its ship order's "region", else full sun.
static func region_of(d: DesignRecord) -> String:
	var r := str(d.order.get("region", DEFAULT_REGION)) if d.order is Dictionary else DEFAULT_REGION
	return r if SUN.has(r) else DEFAULT_REGION

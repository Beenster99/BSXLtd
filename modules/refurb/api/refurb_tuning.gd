class_name RefurbTuning
extends Resource
## The refurb shop's numbers (beenster tunes these in the inspector: modules/refurb/internal/
## data/refurb_tuning.tres). Times are seconds of yard time, money is credits, condition 0..1.

@export var version := 2

@export_group("Shop")
## Light-line cradles (one refurbishing bot each) for parts up to light_max long.
@export var cradles := 4
## The longest a part may be (m) for the light line; longer parts go to the heavy stand, under
## the crane, and the biggest the annex takes (its door and stand).
@export var light_max := 3.2
@export var heavy_max := 10.5
## Bots that only work the heavy stand (RF-2H), and the most bots on one heavy part at once
## (idle light-line bots join in).
@export var heavy_crew := 2
@export var team_max := 4
## Seconds a team takes to cut up a scrapped heavy part for the skip, at a bot's normal pace.
@export var cut_seconds := 14.0
## Slots on the second-hand intake rack and on the refurbished rack.
@export var intake_slots := 6
@export var out_slots := 6

@export_group("Stages")
## Seconds each stage takes for a size 1 part in middling condition, at a bot's normal pace:
## inspect (scan for cracks and worn parts), strip (covers off, worn parts out), clean (grit
## blast the grime and corrosion off), rebuild (new seals, bearings and wiring, welded repairs),
## test (bench test under power).
@export var stage_seconds: PackedFloat32Array = PackedFloat32Array([8.0, 14.0, 16.0, 22.0, 9.0])
## Each size class up takes this much longer (x per class).
@export var per_class := 1.22
## A worn part takes longer: the time is times (wear_base + wear_extra x wear), wear = 1 - condition.
@export var wear_base := 0.6
@export var wear_extra := 0.9

@export_group("Outcome")
## Condition a rebuilt part reaches (0..1) and the condition it must test at to be certified.
@export var rebuilt_condition := 0.97
@export var pass_at := 0.95
## Chance the bench test fails first time, times the wear it came in with (it goes back for
## another rebuild, half as long).
@export var retest_chance := 0.35
## Chance inspection finds a cracked casing and scraps it: times wear squared.
@export var scrap_chance := 0.6
## What a scrapped part is worth back (fraction of what it cost second-hand).
@export var scrap_return := 0.2
## The grade a certified part leaves as (DesignGrades: "S" Standard).
@export var certified_grade := "S"

@export_group("Cost")
## What refurbishing costs (seals, bearings, grit, power): the certified part's new price times
## (cost_base + cost_wear x wear).
@export var cost_base := 0.12
@export var cost_wear := 0.3

@export_group("Bots")
## Flying speed (m/s), and each bot's own pace, picked between these (never in unison).
@export var fly_speed := 2.6
@export var pace_min := 0.85
@export var pace_max := 1.18
## Charge used per second of work, gained per second on its charger rack; a bot goes back to
## charge (and stays till full) when under recharge_at, and tops up there whenever idle.
@export var drain := 0.0035
@export var recharge := 0.06
@export var recharge_at := 0.3
## Seconds a bot works one spot before moving round the part.
@export var spot_seconds := 3.5

@export_group("Crane and cart")
## The overhead crane: travel (m/s, along the runway and the bridge), hoist (m/s) and the
## seconds it takes to sling or unsling a load.
@export var crane_speed := 2.0
@export var hoist_speed := 1.1
@export var crane_hold := 1.4
## The goods-in cart that brings second-hand parts through from the stores hall: speed (m/s),
## seconds to load it at goods in, the speed its rollers push a light part onto the intake
## (m/s), and how many light parts it takes a trip.
@export var cart_speed := 3.0
@export var cart_load := 2.5
@export var cart_unload_speed := 1.2
@export var cart_carry := 3

@export_group("Stand-in dealer")
## Until the parts market sells second-hand parts, a used-parts dealer's lots arrive at goods
## in: the first after this many seconds, then one every gap (min, max) while little waits.
@export var dealer_first := 3.0
@export var dealer_gap := Vector2(35.0, 65.0)
## The condition its lots come in at (min, max), the biggest part it brings (m, longest side),
## and the chance a lot is a big one for the heavy stand.
@export var dealer_condition := Vector2(0.25, 0.8)
@export var dealer_max_size := 10.5
@export var dealer_heavy_chance := 0.3

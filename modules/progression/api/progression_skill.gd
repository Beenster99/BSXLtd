class_name ProgressionSkill
extends Resource
## A trade skill (internal/data/skills/<id>.tres). XP comes from completed joints in `trade`,
## scaled by joint quality; levels and perks follow from the XP.

@export var version := 1
@export var id: StringName = &""
@export var display_name := ""
## Trades trade id whose joints train this skill ("bolting").
@export var trade: StringName = &""
## XP for a joint of quality 1.0.
@export var xp_per_joint := 10
## Total XP needed for each level: [100, 250] means level 1 at 100 XP, level 2 at 250.
@export var xp_per_level: PackedInt32Array = PackedInt32Array()
@export var perks: Array[ProgressionPerk] = []


func level_for(xp: int) -> int:
	var level := 0
	for need in xp_per_level:
		if xp < need:
			break
		level += 1
	return level

class_name DesignMatrix
extends RefCounted
## The size x class capability matrix (beenster, 20 Nov): every major component in each size it
## comes in (its 3D size class, 1 to 8) and each class (its grade of capability: R Reclaimed,
## S Standard, L Lightweight, H Hardened, Q Quiet, P Precision; DesignGrades), with what it does
## at that size and class. Bigger is not always better: different makes pack their output very
## differently (a small plasma drive out-pushes a big ion thruster; a compact fusion cell
## out-powers a bigger generator), so the matrix also gives output per m3 and per tonne.
##
## A variant is named "<size><class>", "2P" = size 2, Precision, as on the palette and the part
## card (DesignGrades.label). For power, `supports()` lists everything one power unit can run
## (each consumer drawing no more than it makes), and `supported_by()` the other way: what Help
## lights up when a player clicks a cell. Read-only data from the catalogue; no UI here.

## The groups of major components, the figure each is judged on and its unit. `field` is the
## DesignPartType number; `categories` the palette groups whose parts belong.
const GROUPS: Array = [
	{"id": "power", "name": "Power units", "field": "power", "unit": "kW", "categories": ["power"]},
	{"id": "propulsion", "name": "Engines and thrusters", "field": "thrust", "unit": "kN", "categories": ["propulsion"]},
	{"id": "jump", "name": "Jump drives", "field": "jump", "unit": "ly / 100 t", "categories": ["jump"]},
	{"id": "defence", "name": "Shields and armour", "field": "defence", "unit": "defence", "categories": ["defence"]},
	{"id": "weapons", "name": "Weapons", "field": "attack", "unit": "dmg/s", "categories": ["weapons"]},
	{"id": "sensors", "name": "Sensors", "field": "sensor", "unit": "km", "categories": ["sensors"]},
]
## What Help calls the two axes.
const SIZE_NAME := "Size"
const CLASS_NAME := "Class"


static func group(id: String) -> Dictionary:
	for g: Dictionary in GROUPS:
		if g.id == id:
			return g
	return {}


## The base types in a group that come in sizes and do the group's job (a radiator is on the
## power palette but makes no power: it is left out), sorted by name.
static func types(cat: DesignCatalog, group_id: String) -> Array[DesignPartType]:
	var g := group(group_id)
	var out: Array[DesignPartType] = []
	if g.is_empty():
		return out
	for c: String in g.categories:
		for pt in cat.parts_in(c):
			if pt.size_class > 0 and float(pt.get(str(g.field))) > 0.0:
				out.append(pt)
	out.sort_custom(func(a, b): return a.display_name < b.display_name)
	return out


## The group a part belongs to by what it does ("" for none): the first group whose figure it has.
static func group_of(pt: DesignPartType) -> String:
	if pt == null:
		return ""
	for g: Dictionary in GROUPS:
		if (g.categories as Array).has(pt.category) and float(pt.get(str(g.field))) > 0.0:
			return str(g.id)
	return ""


## One variant as a matrix cell: its id, label, figure (in the group's unit), what it draws and
## weighs, its size and the figure per m3 and per tonne. Empty when it doesn't exist.
static func cell(cat: DesignCatalog, base: DesignPartType, size: int, grade: String, group_id: String) -> Dictionary:
	var pt := cat.part(DesignGrades.variant_id(base, size, grade))
	if pt == null:
		return {}
	var g := group(group_id)
	var figure := float(pt.get(str(g.field))) if not g.is_empty() else 0.0
	var vol := maxf(pt.size.x * pt.size.y * pt.size.z, 0.001)
	return {"id": pt.id, "base_id": base.id, "name": pt.display_name, "size": pt.size_class, "grade": pt.grade,
		"label": DesignGrades.label(pt), "figure": figure, "per_m3": figure / vol,
		"per_t": figure / maxf(pt.mass / 1000.0, 0.001), "draw_kw": draw_kw(pt), "make_kw": make_kw(pt),
		"mass": pt.mass, "cost": pt.cost, "dims": pt.size, "volume": vol, "lead_days": pt.lead_days}


## The whole matrix for a group: one row per type, its sizes, and a cell per size and class:
## [{base_id, name, sizes: [lo..hi], cells: {size: {grade: cell}}}].
static func rows(cat: DesignCatalog, group_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for base in types(cat, group_id):
		var span := DesignGrades.sizes(base)
		var sizes: Array[int] = []
		var cells := {}
		for s in range(span[0], span[1] + 1):
			sizes.append(s)
			var by_grade := {}
			for g in (DesignGrades.GRADE_ORDER if base.graded else PackedStringArray([DesignGrades.DEFAULT_GRADE])):
				var c := cell(cat, base, s, g, group_id)
				if not c.is_empty():
					by_grade[g] = c
			cells[s] = by_grade
		out.append({"base_id": base.id, "name": base.display_name, "sizes": sizes, "cells": cells})
	return out


## kW a part makes (0 for a consumer).
static func make_kw(pt: DesignPartType) -> float:
	return maxf(pt.power, 0.0)


## kW a part draws running (0 for a source), and with its motors moving on top.
static func draw_kw(pt: DesignPartType) -> float:
	return maxf(-pt.power, 0.0)


## Every variant (any group, or just `group_id`'s) that `source_id` alone can run: its draw is
## no more than the source makes. Largest draw first. Empty for anything that makes no power.
static func supports(cat: DesignCatalog, source_id: String, group_id: String = "") -> Array[String]:
	var src := cat.part(source_id)
	var out: Array[String] = []
	if src == null or make_kw(src) <= 0.0:
		return out
	var made := make_kw(src)
	var found: Array[Dictionary] = []
	for g: Dictionary in GROUPS:
		if group_id != "" and g.id != group_id:
			continue
		if g.id == "power":
			continue
		for row in rows(cat, str(g.id)):
			for s in row.cells:
				for gr in row.cells[s]:
					var c: Dictionary = row.cells[s][gr]
					if float(c.draw_kw) > 0.0 and float(c.draw_kw) <= made:
						found.append(c)
	found.sort_custom(func(a, b): return float(a.draw_kw) > float(b.draw_kw) or (float(a.draw_kw) == float(b.draw_kw) and str(a.id) < str(b.id)))
	for c in found:
		out.append(str(c.id))
	return out


## Every power unit variant that alone can run `consumer_id`, smallest output first.
static func supported_by(cat: DesignCatalog, consumer_id: String) -> Array[String]:
	var pt := cat.part(consumer_id)
	var out: Array[String] = []
	if pt == null or draw_kw(pt) <= 0.0:
		return out
	var need := draw_kw(pt)
	var found: Array[Dictionary] = []
	for row in rows(cat, "power"):
		for s in row.cells:
			for gr in row.cells[s]:
				var c: Dictionary = row.cells[s][gr]
				if float(c.make_kw) >= need:
					found.append(c)
	found.sort_custom(func(a, b): return float(a.make_kw) < float(b.make_kw) or (float(a.make_kw) == float(b.make_kw) and str(a.id) < str(b.id)))
	for c in found:
		out.append(str(c.id))
	return out


## Pairs where a smaller variant out-does a bigger one of another type in the same group, at
## Standard class: [{small: cell, big: cell}], the biggest gap first. Help shows a few as
## "bigger is not always better".
static func small_beats_big(cat: DesignCatalog, group_id: String, limit: int = 5) -> Array[Dictionary]:
	var std: Array[Dictionary] = []
	for row in rows(cat, group_id):
		for s in row.cells:
			if row.cells[s].has(DesignGrades.DEFAULT_GRADE):
				std.append(row.cells[s][DesignGrades.DEFAULT_GRADE])
	var out: Array[Dictionary] = []
	for a in std:
		for b in std:
			if a.base_id != b.base_id and float(a.volume) < float(b.volume) * 0.6 and float(a.figure) > float(b.figure):
				out.append({"small": a, "big": b, "gap": float(b.volume) / float(a.volume)})
	out.sort_custom(func(x, y): return float(x.gap) > float(y.gap))
	return out.slice(0, limit)

extends RefCounted
## The design console's layout as this player left it (beenster, 20 Nov: "I should be able to
## stretch and move sections of the interface"): where the dividers are, which side the tools
## are on, the 3D view above or below the data, and the text size. Kept on this machine only
## (user://), so each player has their own.

const PATH := "user://design_console.cfg"
const SECTION := "layout"
## Text sizes offered: label -> scale.
const TEXT_SIZES: Array = [["Normal", 1.0], ["Compact", 0.85], ["Dense", 0.72], ["Tiny", 0.6]]
## Each panel: its dock ("left" or "right"), place in it, share of its height, folded, hidden.
const PANELS := {
	"selection": {"title": "SELECTION AND INFO", "dock": "left", "order": 0, "ratio": 1.0, "collapsed": false, "hidden": false},
	"tools": {"title": "TOOLS, DOORS, WALLS, WIRES", "dock": "left", "order": 1, "ratio": 0.7, "collapsed": false, "hidden": false},
	"rooms": {"title": "ROOMS", "dock": "left", "order": 2, "ratio": 0.45, "collapsed": false, "hidden": false},
	"components": {"title": "COMPONENTS", "dock": "left", "order": 3, "ratio": 2.2, "collapsed": false, "hidden": false},
	"modules": {"title": "MODULES", "dock": "left", "order": 4, "ratio": 0.6, "collapsed": true, "hidden": false},
	"holo": {"title": "3D VIEW", "dock": "right", "order": 0, "ratio": 1.0, "collapsed": false, "hidden": false},
	"views": {"title": "SIDE AND END VIEW", "dock": "right", "order": 1, "ratio": 0.7, "collapsed": false, "hidden": false},
	"data": {"title": "DESIGN DATA", "dock": "right", "order": 2, "ratio": 1.5, "collapsed": false, "hidden": false},
	"contract": {"title": "CONTRACT", "dock": "right", "order": 3, "ratio": 0.9, "collapsed": true, "hidden": false},
	"hull": {"title": "HULL DESIGN", "dock": "right", "order": 4, "ratio": 0.8, "collapsed": true, "hidden": false},
}
## text: scale; left, right: the dividers' offsets, px; panels: as PANELS.
const DEFAULTS := {"text": 1.0, "left": 0, "right": 0, "panels": {}}

static var path := PATH


static func load_layout() -> Dictionary:
	var out := DEFAULTS.duplicate(true)
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK:
		for k: String in DEFAULTS:
			out[k] = cfg.get_value(SECTION, k, DEFAULTS[k])
	out.panels = merged_panels(out.panels if out.panels is Dictionary else {})
	return out


## The default layout (WINDOW > RESET LAYOUT).
static func defaults() -> Dictionary:
	var out := DEFAULTS.duplicate(true)
	out.panels = merged_panels({})
	return out


## Every panel's state: what was saved, over the defaults (a panel added later gets its own).
static func merged_panels(saved: Dictionary) -> Dictionary:
	var out := {}
	for id: String in PANELS:
		var p: Dictionary = (PANELS[id] as Dictionary).duplicate()
		var s: Variant = saved.get(id)
		if s is Dictionary:
			for k: String in ["dock", "order", "ratio", "collapsed", "hidden"]:
				if (s as Dictionary).has(k):
					p[k] = s[k]
		if str(p.dock) != "left" and str(p.dock) != "right":
			p.dock = PANELS[id].dock
		out[id] = p
	return out


static func save_layout(l: Dictionary) -> void:
	var cfg := ConfigFile.new()
	for k: String in DEFAULTS:
		cfg.set_value(SECTION, k, l.get(k, DEFAULTS[k]))
	cfg.save(path)

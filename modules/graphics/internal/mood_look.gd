extends RefCounted
## The yard's mood (flag "graphics.mood", beenster's 0.3.23 playtest: "too bright in the yard,
## both in the day and at night"). A working shipyard under a hazy sky: by day the exposure
## and the sky's fill come down so white walls stop glaring, and at night the fill is lower
## and every night lamp (a light with meta "night_energy", which its owner rescales by the
## hour) dimmed, so the floodlights light the work, not the whole yard like day. The sun and
## the planet-light stay as AlienSky sets them (UI's tests read them).
## Runs after AlienSky sets each hour (and after SkyLook), on top of what it set.

## By day: the ambient fill's share of what AlienSky set, and the exposure.
const DAY_AMBIENT := 0.6
const DAY_EXPOSURE := 0.6
## At full night: the ambient fill's share (on top of SkyLook's).
const NIGHT_AMBIENT := 0.8
## Night lamps: their energy's share.
const NIGHT_LAMPS := 0.6

## Meta on a night lamp: its owner's full energy, to put back; on a
## WorldEnvironment, that its exposure is the mood's.
const META := "gfx_mood"
const NIGHT_META := "night_energy"


## After AlienSky has set an hour (daylight 0 night .. 1 day).
static func sky(s: Node, daylight: float) -> void:
	var dark := 1.0 - smoothstep(0.0, 0.3, daylight)
	var env := s.get("environment") as Environment
	if env:
		env.ambient_light_energy *= lerpf(DAY_AMBIENT, NIGHT_AMBIENT, dark)
	var we := s.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we:
		exposure(we, daylight)


## The exposure for the hour, as the camera attributes' multiplier (Core's Graphics owns the
## environment's exposure, from the player's brightness, and the auto exposure next to it).
static func exposure(we: WorldEnvironment, daylight: float) -> void:
	var cam := we.camera_attributes
	if cam == null:
		cam = CameraAttributesPractical.new()   # Core's Graphics only makes one for eye adaptation
		we.camera_attributes = cam
	var dark := 1.0 - smoothstep(0.0, 0.3, daylight)
	cam.exposure_multiplier = lerpf(DAY_EXPOSURE, 1.0, dark)
	we.set_meta(META, true)


## Puts the exposure back.
static func unexpose(we: WorldEnvironment) -> void:
	if not we.has_meta(META):
		return
	if we.camera_attributes:
		we.camera_attributes.exposure_multiplier = 1.0
	we.remove_meta(META)


## Is this a lamp that only burns at night (its owner keeps its full energy in meta)?
static func is_night_lamp(l: Node) -> bool:
	return l is Light3D and l.has_meta(NIGHT_META)


## Dims a night lamp once; returns whether it changed.
static func lamp(l: Light3D) -> bool:
	if l.has_meta(META) or not l.has_meta(NIGHT_META):
		return false
	var full := float(l.get_meta(NIGHT_META))
	l.set_meta(META, full)
	l.set_meta(NIGHT_META, full * NIGHT_LAMPS)
	l.light_energy *= NIGHT_LAMPS
	return true


## Puts a night lamp back as its owner made it.
static func unlamp(l: Light3D) -> void:
	if not l.has_meta(META):
		return
	var full := float(l.get_meta(META))
	var now := float(l.get_meta(NIGHT_META))
	if now > 0.0:
		l.light_energy *= full / now
	l.set_meta(NIGHT_META, full)
	l.remove_meta(META)


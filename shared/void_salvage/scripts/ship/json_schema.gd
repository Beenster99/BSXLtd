class_name JsonSchema
extends RefCounted
## Checks a parsed JSON value against a JSON Schema (the subset the ship file's schema,
## data/ship_format/vsship-1.schema.json, uses): type, const, enum, properties, required,
## additionalProperties, maxProperties, items, minItems, maxItems, minimum, maximum, pattern,
## minLength, anyOf and
## local $refs ("#/$defs/<name>"). Returns what is wrong, each with its path; empty = valid.


static func validate(value: Variant, schema: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	_check(value, schema, schema, "$", errors)
	return errors


## Loads a schema file (JSON).
static func load_schema(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func _check(v: Variant, s: Dictionary, root: Dictionary, path: String, errors: PackedStringArray) -> void:
	if s.has("$ref"):
		var ref := String(s["$ref"])
		var target: Variant = root
		for part in ref.trim_prefix("#/").split("/"):
			target = (target as Dictionary).get(part) if target is Dictionary else null
		if not target is Dictionary:
			errors.append("%s: unknown $ref %s" % [path, ref])
			return
		_check(v, target, root, path, errors)
	if s.has("type") and not _type_ok(v, s["type"]):
		errors.append("%s: wants %s, has %s" % [path, s["type"], type_string(typeof(v))])
		return
	if s.has("const") and not _same(v, s["const"]):
		errors.append("%s: wants %s" % [path, JSON.stringify(s["const"])])
	if s.has("enum"):
		var found := false
		for e: Variant in s["enum"]:
			found = found or _same(v, e)
		if not found:
			errors.append("%s: %s is not one of the names it may be" % [path, JSON.stringify(v)])
	if s.has("anyOf"):
		var ok := false
		for option: Dictionary in s["anyOf"]:
			var sub := PackedStringArray()
			_check(v, option, root, path, sub)
			if sub.is_empty():
				ok = true
				break
		if not ok:
			errors.append("%s: matches none of its forms" % path)
	if v is float or v is int:
		if s.has("minimum") and float(v) < float(s["minimum"]):
			errors.append("%s: %s is under %s" % [path, v, s["minimum"]])
		if s.has("maximum") and float(v) > float(s["maximum"]):
			errors.append("%s: %s is over %s" % [path, v, s["maximum"]])
	if v is String and s.has("pattern") and not RegEx.create_from_string(s["pattern"]).search(v):
		errors.append("%s: \"%s\" does not match %s" % [path, v, s["pattern"]])
	if v is String and s.has("minLength") and (v as String).length() < int(s["minLength"]):
		errors.append("%s: \"%s\" is shorter than %s" % [path, v, s["minLength"]])
	if v is Array:
		var a: Array = v
		if s.has("minItems") and a.size() < int(s["minItems"]):
			errors.append("%s: %d items, wants at least %d" % [path, a.size(), s["minItems"]])
		if s.has("maxItems") and a.size() > int(s["maxItems"]):
			errors.append("%s: %d items, wants at most %d" % [path, a.size(), s["maxItems"]])
		if s.has("items"):
			for i in a.size():
				_check(a[i], s["items"], root, "%s[%d]" % [path, i], errors)
	if v is Dictionary:
		var d: Dictionary = v
		if s.has("maxProperties") and d.size() > int(s["maxProperties"]):
			errors.append("%s: %d keys, wants at most %d" % [path, d.size(), s["maxProperties"]])
		for key: String in s.get("required", []):
			if not d.has(key):
				errors.append("%s: missing \"%s\"" % [path, key])
		var props: Dictionary = s.get("properties", {})
		for key: Variant in d:
			if props.has(key):
				_check(d[key], props[key], root, "%s.%s" % [path, key], errors)
			elif s.get("additionalProperties") is Dictionary:
				_check(d[key], s["additionalProperties"], root, "%s.%s" % [path, key], errors)


static func _type_ok(v: Variant, t: Variant) -> bool:
	if t is Array:
		for one: Variant in t:
			if _type_ok(v, one):
				return true
		return false
	match String(t):
		"object":
			return v is Dictionary
		"array":
			return v is Array
		"string":
			return v is String
		"boolean":
			return v is bool
		"null":
			return v == null
		"number":
			return v is float or v is int
		"integer":
			return v is int or (v is float and float(v) == floorf(v))
	return false


static func _same(a: Variant, b: Variant) -> bool:
	if (a is float or a is int) and (b is float or b is int):
		return is_equal_approx(float(a), float(b))
	return typeof(a) == typeof(b) and a == b

extends ModuleTest
## The signature pad (beenster, 21 Nov): SIGN waits for ink, the strokes pack small, the host
## cleans what a player sends.


func run_tests() -> void:
	var pad := ContractSignaturePad.make("Sign here", 14)
	add_child(pad)
	await frames(1)
	var sign := pad.find_child("Sign", true, false) as Button
	check(sign != null and sign.disabled, "SIGN waits until something is written")
	pad.add_stroke(PackedVector2Array([Vector2(0.1, 0.7), Vector2(0.2, 0.5), Vector2(0.3, 0.7)]))
	check(sign.disabled, "three points are not a signature")
	pad.add_stroke(PackedVector2Array([Vector2(0.4, 0.6), Vector2(0.5, 0.4), Vector2(0.6, 0.6), Vector2(1.0, 0.0)]))
	check(not sign.disabled, "a scribble can be signed")
	var out: Array = []
	pad.signed.connect(func(sig: Array) -> void: out.append(sig))
	sign.pressed.emit()
	var got: Array = out[0] if not out.is_empty() else []
	check(got.size() == 2 and got[0] == [26, 178, 51, 128, 77, 178] and (got[1] as Array).slice(6) == [255, 0],
			"SIGN hands over the strokes as 0..255 pairs (%s)" % str(got))
	check(ContractSignaturePad.clean("x") == [] and ContractSignaturePad.clean([[1, 2, 3], [999, -4]]) == [[1, 2], [255, 0]],
			"the host keeps only whole points within the pad")
	var big: Array = []
	for i in 100:
		var s: Array = []
		for j in 100:
			s.append(j)
		big.append(s)
	var cleaned := ContractSignaturePad.clean(big)
	var n := 0
	for s: Array in cleaned:
		n += s.size()
	check(cleaned.size() <= ContractSignaturePad.MAX_STROKES and n <= ContractSignaturePad.MAX_POINTS * 2, "and clips a flood of ink")
	var v := ContractSignaturePad.view(got, Vector2(200, 50))
	add_child(v)
	await frames(1)
	check(v.custom_minimum_size == Vector2(200, 50), "a kept signature draws back")
	v.queue_free()
	pad.queue_free()

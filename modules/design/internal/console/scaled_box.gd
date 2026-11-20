extends Container
## Shows its one child smaller (or bigger) by `factor`: the child is laid out at size / factor
## and drawn scaled, so its text and buttons shrink together and clicks still land (beenster,
## 20 Nov: "an even smaller font option ... it would look real techy").

var factor := 1.0:
	set(v):
		factor = clampf(v, 0.4, 2.0)
		update_minimum_size()
		queue_sort()


func _init(f := 1.0) -> void:
	factor = f
	clip_contents = true


func _get_minimum_size() -> Vector2:
	var m := Vector2.ZERO
	for c in get_children():
		if c is Control and (c as Control).visible:
			m = m.max((c as Control).get_combined_minimum_size() * factor)
	return m


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		for c in get_children():
			if c is Control:
				var ctl := c as Control
				fit_child_in_rect(ctl, Rect2(Vector2.ZERO, size / factor))
				ctl.scale = Vector2(factor, factor)

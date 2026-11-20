extends ModuleTest
## The yard's deep-space sky in high definition (20 Nov): it has its shader with the detail
## knob, the detail follows the player's Model detail setting (Low standard, Medium high, High
## and Ultra full), and changing the setting changes the sky.
##   tools/run_tests.sh yard

const SpaceSky := preload("res://modules/yard/internal/space_sky.gd")


func run_tests() -> void:
	var was: Variant = GraphicsOptions.get_value("detail")
	var sky := SpaceSky.new()
	add_child(sky)
	await frames(1)
	check(sky.sky_material != null and sky.sky_material.shader != null, "the sky has its shader")
	check(sky.environment.sky.sky_material == sky.sky_material, "the environment draws that sky")
	var names := []
	for u: Dictionary in sky.sky_material.shader.get_shader_uniform_list():
		names.append(u.name)
	check(names.has("detail"), "the shader has a detail knob")
	var want := [0, 1, 2, 2]
	for level in 4:
		GraphicsOptions.set_value("detail", level)
		sky.apply_detail()
		check(int(sky.sky_material.get_shader_parameter("detail")) == want[level],
				"Model detail %d gives sky detail %d" % [level, want[level]])
	GraphicsOptions.set_value("detail", 0)
	var graphics := get_node_or_null("/root/Graphics")
	if graphics != null:
		graphics.emit_signal("changed")
		check(int(sky.sky_material.get_shader_parameter("detail")) == 0, "a settings change reaches the sky")
	GraphicsOptions.set_value("detail", was)
	sky.queue_free()

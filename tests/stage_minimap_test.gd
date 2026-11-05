extends SceneTree

const Minimap = preload("res://scripts/ui/expedition/stage_minimap.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func _run() -> void:
	var bounds := Rect2(-100.0, -50.0, 200.0, 100.0)
	var canvas := Vector2(216.0, 216.0)
	var top_left: Vector2 = Minimap.map_point(bounds, bounds.position, canvas)
	var bottom_right: Vector2 = Minimap.map_point(bounds, bounds.end, canvas)
	check(top_left.is_equal_approx(Vector2(10.0, 59.0)) and bottom_right.is_equal_approx(Vector2(206.0, 157.0)), "full rectangular bounds fit with margins")
	var x_step: Vector2 = Minimap.map_point(bounds, Vector2(10, 0), canvas) - Minimap.map_point(bounds, Vector2.ZERO, canvas)
	var y_step: Vector2 = Minimap.map_point(bounds, Vector2(0, 10), canvas) - Minimap.map_point(bounds, Vector2.ZERO, canvas)
	check(is_equal_approx(x_step.length(), y_step.length()), "equal world distances have equal map scale")
	var larger: Vector2 = Minimap.map_point(bounds, bounds.end, Vector2(300, 300))
	check(larger.x <= 290.0 and larger.y <= 290.0, "resized square retains margin without cropping")
	var degenerate: Vector2 = Minimap.map_point(Rect2(4, 5, 0, 0), Vector2(4, 5), canvas)
	check(degenerate.is_equal_approx(canvas / 2.0) and degenerate.is_finite(), "point bounds remain finite and centered")
	var line_end: Vector2 = Minimap.map_point(Rect2(0, 0, 0, 10), Vector2(0, 10), canvas)
	check(line_end.is_finite() and line_end.y <= 206.0, "line bounds remain finite and fitted")

	var minimap = Minimap.new()
	root.add_child(minimap)
	var surfaces: Array[PackedVector2Array] = [PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN])]
	var obstacles: Array[PackedVector2Array] = [PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN])]
	minimap.configure_map(bounds, surfaces, obstacles)
	var enemies := PackedVector2Array([Vector2(1, 2)])
	for heading in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
		minimap.update_markers(Vector2.ZERO, heading, enemies)
		check(minimap._markers.heading.is_equal_approx(heading), "cardinal heading is preserved in map coordinates")
	minimap.update_markers(Vector2.ZERO, Vector2.ZERO, enemies)
	check(minimap._markers.heading == Vector2.LEFT, "zero heading retains last direction")
	enemies.clear()
	surfaces[0].clear()
	obstacles[0].clear()
	check(minimap._markers.enemies.size() == 1 and minimap._background.surfaces[0].size() == 3 and minimap._background.obstacles[0].size() == 3, "presentation owns copies of caller data")
	minimap.configure_map(Rect2(), [], [])
	check(minimap._markers.enemies.is_empty() and not minimap._markers.has_player, "new map clears old markers")
	var terrain := {"vertices":PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.DOWN]),"colors":PackedColorArray([Color.GREEN,Color.GREEN,Color.BROWN])}
	minimap.configure_map(bounds,[],[],terrain)
	var mesh: ArrayMesh = minimap._background.terrain_mesh
	check(mesh != null and mesh.surface_get_array_len(0) == 3,"terrain is installed as one vertex-colored mesh")
	minimap.update_markers(Vector2.ZERO,Vector2.RIGHT,PackedVector2Array())
	minimap.update_obstacles([PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.DOWN])])
	check(minimap._background.terrain_mesh == mesh and minimap._background.obstacles.size() == 1,"markers and temporary obstacles reuse the static terrain mesh")
	minimap.configure_map(Rect2(),[],[])
	check(minimap._background.terrain_mesh == null,"changing stage clears the previous terrain resource")
	check(minimap.mouse_filter == Control.MOUSE_FILTER_STOP and minimap._background.mouse_filter == Control.MOUSE_FILTER_STOP and minimap._markers.mouse_filter == Control.MOUSE_FILTER_STOP, "panel and map consume pointer input")
	check(minimap._background.custom_minimum_size == canvas, "map has 216 logical unit minimum square")
	var steps: Array[int] = []
	var resets: Array[bool] = []
	minimap.zoom_requested.connect(func(step: int) -> void: steps.append(step))
	minimap.zoom_reset_requested.connect(func() -> void: resets.append(true))
	minimap._zoom_out.pressed.emit()
	minimap._zoom_in.pressed.emit()
	minimap._zoom_reset.pressed.emit()
	check(steps == [-1, 1] and resets.size() == 1, "buttons request camera zoom and reset")
	minimap.set_camera_zoom(1.25)
	check(minimap._zoom_reset.text == "125%", "camera zoom is presented as percentage")
	minimap.set_zoom_enabled(false)
	check(minimap._zoom_out.disabled and minimap._zoom_in.disabled and minimap._zoom_reset.disabled, "modal disables all zoom buttons")
	minimap.set_zoom_enabled(true)
	check(not minimap._zoom_out.disabled and not minimap._zoom_in.disabled and not minimap._zoom_reset.disabled, "zoom controls can be enabled again")
	minimap.free()
	print("Stage minimap: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

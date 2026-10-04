extends SceneTree
## Bitmap presentation contracts only; frames never authorize a combat action.

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var animation := CharacterAnimation.new()
	animation.configure(&"sentinel")
	_check(animation.actor_kind == &"sentinel" and animation.atlas != null and animation.atlas.get_size() == Vector2(256, 512), "Sentinel owns a full 32-frame atlas")
	if animation.atlas == null:
		quit(1)
		return
	var bitmap := animation.atlas.get_image()
	for index: int in range(32):
		var region := Rect2i(Vector2i(index % 4 * 64, index / 4 * 64), Vector2i(64, 64))
		var frame := bitmap.get_region(region)
		var bounds := frame.get_used_rect()
		_check(bounds.has_area() and bounds.position.x > 0 and bounds.end.x < 64 and bounds.end.y <= 59 and frame.get_pixel(0, 0).a == 0, "pose%d alpha gutters and cell containment" % index)
		var clear_edges := true
		for edge: int in range(64):
			clear_edges = clear_edges and frame.get_pixel(edge, 0).a == 0.0 and frame.get_pixel(edge, 63).a == 0.0 and frame.get_pixel(0, edge).a == 0.0 and frame.get_pixel(63, edge).a == 0.0
		_check(clear_edges, "pose%d every cell border transparent" % index)
		_check(animation.source_region(index) == Rect2(region) and is_zero_approx(animation.destination_rect(index).position.y + bounds.end.y - 1), "pose%d integer sampling and opaque baseline at feet" % index)
		if index < 28:
			var boots: Array[int] = []
			for y: int in range(bounds.end.y - 6, bounds.end.y):
				for x: int in range(64):
					var pixel := frame.get_pixel(x, y)
					if pixel.a > 0.5 and pixel.r > 0.14 and pixel.r > pixel.b * 1.2:
						boots.append(x)
			boots.sort()
			_check(not boots.is_empty() and absf(boots[boots.size() / 2] - CharacterAnimation.PIVOT.x) <= 5, "pose%d boot anchor centered on logical feet" % index)
		else:
			_check(bounds.size.x > bounds.size.y, "pose%d corpse silhouette lies horizontally" % index)
	for index: int in range(3):
		_check(bitmap.get_region(Rect2i(animation.source_region(4 + index))).get_data() != bitmap.get_region(Rect2i(animation.source_region(5 + index))).get_data(), "distinct front walking steps")
		_check(bitmap.get_region(Rect2i(animation.source_region(12 + index))).get_data() != bitmap.get_region(Rect2i(animation.source_region(13 + index))).get_data(), "distinct rear walking steps")
	var corpse := animation.death_copy()
	_check(corpse.atlas == animation.atlas and corpse.destination_rect(29) == animation.destination_rect(29), "death copy preserves exact grounding")
	var archer := CharacterAnimation.new()
	archer.configure(&"archer")
	_check(archer.actor_kind == &"archer" and archer.atlas != animation.atlas, "origin Archer still uses its unchanged atlas")
	if "--sentinel-preview" in OS.get_cmdline_user_args():
		await _render_preview(animation)
	print("Sentinel G7 animation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _render_preview(animation: CharacterAnimation) -> void:
	if DisplayServer.get_name() == "headless":
		_check(false, "native atlas preview requires a real renderer")
		return
	root.size = Vector2i(800, 650)
	root.content_scale_size = Vector2i(800, 650)
	var floor_view := AtlasFloor.new()
	root.add_child(floor_view)
	for index: int in range(32):
		for side: int in range(2):
			var pose := AtlasPose.new()
			pose.animation = animation
			pose.frame = index
			pose.position = Vector2(55 + index % 4 * 95 + side * 400, 76 + index / 4 * 78)
			floor_view.add_child(pose)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var capture := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/verification"))
	_check(capture.save_png("res://.godot/verification/sentinel_atlas_native.png") == OK, "real renderer capture on light and dark floors")
	var light_pixel := capture.get_pixel(24, 40)
	var dark_pixel := capture.get_pixel(424, 40)
	_check(absf(light_pixel.r - AtlasFloor.LIGHT.r) < 0.01 and absf(light_pixel.g - AtlasFloor.LIGHT.g) < 0.01 and absf(dark_pixel.r - AtlasFloor.DARK.r) < 0.01 and absf(dark_pixel.g - AtlasFloor.DARK.g) < 0.01, "transparent sprite corners reveal both floors, not RGB white boxes")

class AtlasFloor extends Node2D:
	const LIGHT := Color(0.8, 0.83, 0.75)
	const DARK := Color(0.11, 0.15, 0.15)
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 400, 650), LIGHT)
		draw_rect(Rect2(400, 0, 400, 650), DARK)

class AtlasPose extends Node2D:
	var animation: CharacterAnimation
	var frame := 0
	func _draw() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		draw_texture_rect_region(animation.atlas, animation.destination_rect(frame), animation.source_region(frame))

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

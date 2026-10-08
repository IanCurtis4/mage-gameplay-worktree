extends SceneTree
## Mechanical import of the generated 4x8 sheet. Keeps the source untouched.
## Godot --headless --path <project> --script res://tools/prepare_hunter_atlas.gd
const SOURCE := "res://assets/art/animation_sources/hunter_source.png"
const OUTPUT := "res://assets/art/animations/hunter.png"

func _initialize() -> void:
	var source := Image.load_from_file(SOURCE)
	if source == null or source.is_empty():
		push_error("Missing generated Hunter source")
		quit(1)
		return
	var cell := Vector2i(source.get_width() / 4, source.get_height() / 8)
	var poses: Array[Image] = []
	var scale_factor := 1.0
	for index: int in range(32):
		var frame := source.get_region(Rect2i(Vector2i(index % 4, index / 4) * cell, cell))
		_clean_alpha_dust(frame)
		var bounds := frame.get_used_rect()
		if not bounds.has_area():
			push_error("Empty Hunter source cell %d" % index)
			quit(1)
			return
		var pose := frame.get_region(bounds)
		poses.append(pose)
		scale_factor = minf(scale_factor, minf(56.0 / bounds.size.x, 54.0 / bounds.size.y))
	var atlas := Image.create_empty(256, 512, false, Image.FORMAT_RGBA8)
	for index: int in range(32):
		var pose := poses[index]
		pose.resize(maxi(1, roundi(pose.get_width() * scale_factor)), maxi(1, roundi(pose.get_height() * scale_factor)), Image.INTERPOLATE_NEAREST)
		var foot_x := roundi(_foot_x(pose, index < 28))
		var offset := Vector2i(clampi(32 - foot_x, 2, 62 - pose.get_width()), 59 - pose.get_height())
		atlas.blit_rect(pose, Rect2i(Vector2i.ZERO, pose.get_size()), Vector2i(index % 4, index / 4) * Vector2i(64, 64) + offset)
	var result := atlas.save_png(OUTPUT)
	print("Hunter normalized atlas: ", error_string(result), " scale=", scale_factor)
	quit(0 if result == OK else 1)

func _foot_x(pose: Image, upright: bool) -> float:
	if not upright:
		return pose.get_width() * 0.5
	var boot_x: Array[int] = []
	for y: int in range(maxi(0, pose.get_height() - 6), pose.get_height()):
		for x: int in range(pose.get_width()):
			var pixel := pose.get_pixel(x, y)
			if pixel.a > 0.5 and pixel.r > 0.14 and pixel.r > pixel.b * 1.2:
				boot_x.append(x)
	if boot_x.is_empty():
		return pose.get_width() * 0.5
	boot_x.sort()
	return float(boot_x[boot_x.size() / 2])

func _clean_alpha_dust(frame: Image) -> void:
	# Drop antialias dust and tiny disconnected source specks, not body details.
	var visited := PackedByteArray()
	var clusters: Array = []
	var primary: Array[Vector2i] = []
	visited.resize(frame.get_width() * frame.get_height())
	for y: int in range(frame.get_height()):
		for x: int in range(frame.get_width()):
			var start := Vector2i(x, y)
			var flat := y * frame.get_width() + x
			if visited[flat] != 0:
				continue
			visited[flat] = 1
			if frame.get_pixel(x, y).a < 0.5:
				frame.set_pixel(x, y, Color.TRANSPARENT)
				continue
			var cluster: Array[Vector2i] = [start]
			var cursor := 0
			while cursor < cluster.size():
				var point := cluster[cursor]
				cursor += 1
				for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var next := point + step
					if next.x < 0 or next.y < 0 or next.x >= frame.get_width() or next.y >= frame.get_height():
						continue
					var next_flat := next.y * frame.get_width() + next.x
					if visited[next_flat] != 0:
						continue
					visited[next_flat] = 1
					if frame.get_pixelv(next).a >= 0.5:
						cluster.append(next)
					else:
						frame.set_pixelv(next, Color.TRANSPARENT)
			clusters.append(cluster)
			if cluster.size() > primary.size():
				primary = cluster
	var primary_bounds := Rect2i(primary[0], Vector2i.ONE)
	for point: Vector2i in primary:
		primary_bounds = primary_bounds.expand(point)
	for cluster: Array[Vector2i] in clusters:
		var nearby := false
		for point: Vector2i in cluster:
			if primary_bounds.grow(8).has_point(point):
				nearby = true
				break
		if cluster.size() < 60 or not nearby:
			for point: Vector2i in cluster:
				frame.set_pixelv(point, Color.TRANSPARENT)

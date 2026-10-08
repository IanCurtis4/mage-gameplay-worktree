class_name HunterGroundArt
extends RefCounted
## Pure Hunter-only drawing recipes. No clocks, collision, targets or callbacks.

const INK := Color("263028")
const WOOD := Color("8c6744")
const ROPE := Color("d1b780")
const BONE := Color("ece1b4")
const MOSS := Color("647949")
const FROST := Color("a6e2db")
const RESIN := Color("45462b")

static func trap_recipe(skill_id: StringName, armed: bool, progress: float, elapsed: float, radius: float) -> Array[Dictionary]:
	var commands: Array[Dictionary] = []
	if skill_id not in HunterMath.NEW_TRAP_IDS or not is_finite(radius) or radius <= 0.0 or not is_finite(progress) or not is_finite(elapsed):
		return commands
	var phase := maxf(0.0, elapsed)
	var preparation := clampf(progress, 0.0, 1.0)
	var accent := FROST if skill_id == &"hunter_freezing_trap" else ROPE
	_circle(commands, Vector2.ZERO, radius, Color(MOSS, 0.06 if armed else 0.03))
	if armed:
		_arc(commands, Vector2.ZERO, radius, 0.0, TAU, Color(INK, 0.58), 3.0)
		_arc(commands, Vector2.ZERO, radius, 0.0, TAU, Color(ROPE, 0.53), 1.0)
	else:
		# Open rope segments and winding progress distinguish unarmed mechanisms.
		for index: int in range(8):
			var angle := TAU * float(index) / 8.0
			_arc(commands, Vector2.ZERO, radius, angle, angle + 0.38, Color(ROPE, 0.57), 1.5)
		if preparation > 0.0:
			_arc(commands, Vector2.ZERO, radius - 3.0, -PI / 2.0, -PI / 2.0 + TAU * preparation, BONE, 2.0)
	for side: float in [-1.0, 1.0]:
		var x := side * 17.0
		_line(commands, Vector2(x, -9), Vector2(x, 10), INK, 7.0)
		_line(commands, Vector2(x, -9), Vector2(x, 10), WOOD, 4.0)
		for y: float in [-6.0, 7.0]:
			_line(commands, Vector2(x - 4, y), Vector2(x + 4, y + 1), ROPE, 2.0)
	_line(commands, Vector2(-17, 9), Vector2(17, 9), INK, 5.0)
	_line(commands, Vector2(-17, 9), Vector2(17, 9), WOOD, 2.5)
	match skill_id:
		&"hunter_freezing_trap":
			for side: float in [-1.0, 1.0]:
				var spread := 11.0 if armed else 5.0 + preparation * 3.0
				_line(commands, Vector2(side * 4, 4), Vector2(side * spread, -8), INK, 5.0)
				_line(commands, Vector2(side * 4, 4), Vector2(side * spread, -8), accent, 2.5)
			var height := 16.0 if armed else 8.0 + preparation * 5.0
			_polygon(commands, PackedVector2Array([Vector2(-6, 4), Vector2(-4, -height + 3), Vector2(1, -height), Vector2(7, -5), Vector2(4, 5)]), INK)
			_polygon(commands, PackedVector2Array([Vector2(-3, 2), Vector2(-2, -height + 4), Vector2(1, -height + 2), Vector2(4, -5), Vector2(2, 3)]), FROST)
			_line(commands, Vector2(0, -height + 5), Vector2(0, 1), BONE, 1.0)
		&"hunter_tar_trap":
			_polygon(commands, PackedVector2Array([Vector2(-11, -9), Vector2(11, -9), Vector2(13, 4), Vector2(8, 10), Vector2(-8, 10), Vector2(-13, 4)]), INK)
			_polygon(commands, PackedVector2Array([Vector2(-8, -7), Vector2(8, -7), Vector2(10, 3), Vector2(6, 7), Vector2(-6, 7), Vector2(-10, 3)]), WOOD)
			_line(commands, Vector2(-10, 2), Vector2(10, 2), ROPE, 2.0)
			_circle(commands, Vector2(0, -6), 8.0, RESIN if armed else MOSS)
			_arc(commands, Vector2(0, -6), 8.0, PI, TAU, BONE, 2.0)
			if armed:
				_line(commands, Vector2(-4, -7), Vector2(2, -8), Color(ROPE, 0.55 + 0.15 * sin(phase * 2.0)), 1.5)
			else:
				_line(commands, Vector2(-9, -6), Vector2(9, -6), WOOD, 4.0)
		&"hunter_thorn_trap":
			var spread := 22.0 if armed else 12.0 + preparation * 6.0
			for index: int in range(5):
				var axis := Vector2.from_angle(-PI + float(index) * PI / 4.0)
				var normal := axis.orthogonal()
				var tip := axis * spread
				_polygon(commands, PackedVector2Array([axis * 7 + normal * 4, tip, axis * 7 - normal * 4]), INK)
				_polygon(commands, PackedVector2Array([axis * 9 + normal * 2, tip - axis * 3, axis * 9 - normal * 2]), BONE)
			for index: int in range(3):
				_arc(commands, Vector2(float(index - 1) * 5.0, 3), 4.0, PI * 0.25, PI * 1.75, ROPE, 1.5)
	if armed:
		_circle(commands, Vector2(0, 11), 2.0, Color(accent, 0.6 + 0.15 * sin(phase * 2.0)))
	else:
		_line(commands, Vector2(-8, 13), Vector2(8 - preparation * 12, 13), ROPE, 2.0)
	return commands

static func tar_recipe(radius: float, elapsed: float) -> Array[Dictionary]:
	var commands: Array[Dictionary] = []
	if not is_finite(radius) or radius <= 0.0 or not is_finite(elapsed):
		return commands
	_circle(commands, Vector2.ZERO, radius, Color("292d20", 0.29))
	# Contrasting strokes on actual radius; decorations remain inside it.
	_arc(commands, Vector2.ZERO, radius, 0.0, TAU, Color(INK, 0.90), 5.0)
	_arc(commands, Vector2.ZERO, radius, 0.0, TAU, Color(ROPE, 0.88), 1.5)
	for index: int in range(7):
		var point := Vector2.from_angle(TAU * float(index) / 7.0) * radius * 0.58
		var bubble := 6.0 + 1.5 * sin(maxf(0.0, elapsed) * 1.8 + float(index))
		_circle(commands, point, bubble, Color(RESIN, 0.42))
		_arc(commands, point, bubble, PI * 1.1, PI * 1.65, Color(ROPE, 0.45), 1.5)
	for index: int in range(5):
		var point := Vector2.from_angle(TAU * float(index) / 5.0 + 0.4) * radius * 0.81
		_line(commands, point - Vector2(4, 1), point + Vector2(3, 1), Color(MOSS, 0.73), 2.0)
	return commands

static func draw_recipe(canvas: CanvasItem, commands: Array[Dictionary]) -> void:
	for command: Dictionary in commands:
		match command["kind"]:
			&"circle": canvas.draw_circle(command["center"], command["radius"], command["color"])
			&"arc": canvas.draw_arc(command["center"], command["radius"], command["start"], command["end"], 64, command["color"], command["width"], true)
			&"line": canvas.draw_line(command["from"], command["to"], command["color"], command["width"], true)
			&"polygon": canvas.draw_colored_polygon(command["points"], command["color"])

static func _circle(commands: Array[Dictionary], center: Vector2, radius: float, color: Color) -> void:
	commands.append({"kind": &"circle", "center": center, "radius": radius, "color": color})

static func _arc(commands: Array[Dictionary], center: Vector2, radius: float, start: float, end: float, color: Color, width: float) -> void:
	commands.append({"kind": &"arc", "center": center, "radius": radius, "start": start, "end": end, "color": color, "width": width})

static func _line(commands: Array[Dictionary], first: Vector2, last: Vector2, color: Color, width: float) -> void:
	commands.append({"kind": &"line", "from": first, "to": last, "color": color, "width": width})

static func _polygon(commands: Array[Dictionary], points: PackedVector2Array, color: Color) -> void:
	commands.append({"kind": &"polygon", "points": points, "color": color})

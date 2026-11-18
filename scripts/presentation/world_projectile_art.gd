class_name WorldProjectileArt
extends RefCounted
## E08 P6-A2: silhouettes of the logical flights drawn by the spatial view. Presentation
## only: `spec()` reads a projectile node and returns plain data, `draw()` paints it on a
## CanvasItem. Position, collider and flight data are never written. The shapes keep the
## identity of the legacy 2D drawers (MageProjectile / SentinelProjectile /
## GeometerTraceProjectile / ArrowProjectile); each gets a dark halo so it reads on light ground.
const Recipes = preload("res://scripts/presentation/feedback_recipe_catalog.gd")

## element -> [core, glow]. Same palette family as the feedback layer.
const PALETTE := {
	&"physical": [Color("f6dfad"), Color("d29a4a")],
	&"fire": [Color("ffac68"), Color("ff7a2e")],
	&"ice": [Color("a9e9ff"), Color("6fb8e8")],
	&"lightning": [Color("ebe29b"), Color("f4d35e")],
	&"arcane": [Color("d8b4ff"), Color("9a6cf0")],
	&"spirit": [Color("b8f0e8"), Color("7dd6c8")],
	&"nature": [Color("b4e68c"), Color("5fa84a")],
	&"geometry": [Color("ebe29b"), Color("c9b45a")],
	&"blood": [Color("ff7b86"), Color("b02a42")],
	# E10a C1.8 (D5, C5 palette): light in ivory and gold; shadow in magenta over blue-black.
	&"light": [Color("fff3d0"), Color("e9bd4f")],
	&"shadow": [Color("d16ad8"), Color("26294f")],
}
## E10a C1.8: turquoise accent of the shadow effects (the "eye").
const SHADOW_ACCENT := Color("4fd6c4")
const HALO := Color(0.04, 0.05, 0.09, 0.5)

## Shapes: orb, spear, bolt, arrow, sentinel_*, trace.
static func spec(node: Object) -> Dictionary:
	var request: DamageRequest = node.get("request")
	var skill: StringName = request.skill_id if request != null else &""
	var variant: StringName = &"mage" if node is MageProjectile else (&"archer" if node is PlayerProjectile and skill == &"basic_attack" else &"")
	var recipe := Recipes.recipe(skill, variant)
	var element: StringName = recipe.element
	var shape := &"orb"
	var radius: float = float(node.get("projectile_radius")) if node.get("projectile_radius") != null else 6.0
	var tint: Variant = node.get("color")
	var core: Color = PALETTE[element][0]
	if node is MageProjectile and tint is Color: core = tint
	if node is GeometerTraceProjectile:
		var trace_element: StringName = (node as GeometerTraceProjectile).element
		shape = &"trace"; element = trace_element if trace_element in [&"fire", &"ice", &"lightning"] else &"lightning"
		core = PALETTE[element][0]
	elif node is ArrowProjectile:
		shape = &"arrow"
		if skill == &"enemy_arrow": element = &"physical"
	elif node is SentinelProjectile and String(skill).begins_with("sentinel_"):
		shape = StringName("sentinel_" + String(skill).trim_prefix("sentinel_"))
	elif skill in [&"lightning", &"electric_discharge"]:
		shape = &"bolt"
	elif skill in [&"fire_spear", &"ice_spear"]:
		shape = &"spear"
	elif skill in [&"double_shot", &"piercing_arrow", &"slowing_arrow", &"hunter_covering_shot"] or variant == &"archer":
		shape = &"arrow"
	return {"shape":shape, "element":element, "core":core, "glow":PALETTE[element][1], "radius":radius, "hostile":skill == &"enemy_arrow", "skill":skill}

## Paints `data` with the head at `position` pointing at `angle` (screen radians).
## `phase` is any monotonically increasing value tied to the flight (distance travelled).
static func draw(canvas: CanvasItem, data: Dictionary, position: Vector2, angle: float, phase: float) -> void:
	var core: Color = data.core
	var glow: Color = data.glow
	canvas.draw_set_transform(position, angle, Vector2.ONE)
	match data.shape:
		&"orb": _orb(canvas, data, core, glow, phase)
		&"spear": _spear(canvas, core, glow)
		&"bolt": _bolt(canvas, core, glow, phase)
		&"arrow": _arrow(canvas, data)
		&"trace": _trace(canvas, data, core)
		_: _sentinel(canvas, StringName(data.shape))
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func _orb(canvas: CanvasItem, data: Dictionary, core: Color, glow: Color, phase: float) -> void:
	var r: float = maxf(4.0, float(data.radius))
	var pulse := 1.0 + 0.08 * sin(phase * 0.35)
	# Soft tail: three fading segments, tapering toward the orb.
	for i: int in 3:
		var t := float(i) / 3.0
		canvas.draw_line(Vector2(-r * (3.2 - t * 1.6), 0), Vector2(-r * (1.6 - t * 0.2), 0), Color(HALO, 0.35 * (1.0 - t)), 6.0 - t * 2.0, true)
		canvas.draw_line(Vector2(-r * (3.0 - t * 1.5), 0), Vector2(-r * (1.6 - t * 0.2), 0), Color(glow, 0.5 * (1.0 - t * 0.6)), 4.0 - t * 1.6, true)
	canvas.draw_circle(Vector2.ZERO, r * pulse + 3.5, HALO)
	canvas.draw_circle(Vector2.ZERO, r * pulse + 2.0, Color(glow, 0.3))
	canvas.draw_circle(Vector2.ZERO, r * pulse, core)
	canvas.draw_circle(Vector2(-1, -1), r * 0.42, core.lightened(0.7))
	if data.element == &"fire":
		for k: int in 3:
			var wobble := sin(phase * 0.5 + float(k) * 2.1)
			canvas.draw_circle(Vector2(-r * (1.2 + 0.7 * k), wobble * 2.5), maxf(1.0, 2.4 - 0.6 * k), Color(glow, 0.7))

static func _spear(canvas: CanvasItem, core: Color, glow: Color) -> void:
	var outer := PackedVector2Array([Vector2(-24, 0), Vector2(-10, -6), Vector2(8, -6), Vector2(20, 0), Vector2(8, 6), Vector2(-10, 6)])
	canvas.draw_colored_polygon(_grow(outer, 2.2), HALO)
	canvas.draw_colored_polygon(outer, Color(glow, 0.28))
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-19, -3), Vector2(5, -4), Vector2(16, 0), Vector2(5, 4), Vector2(-19, 3)]), core)
	canvas.draw_line(Vector2(-13, 0), Vector2(9, 0), core.lightened(0.65), 2.0, true)

static func _bolt(canvas: CanvasItem, core: Color, glow: Color, phase: float) -> void:
	var j := 1.5 * sin(phase * 0.9)
	var bolt := PackedVector2Array([Vector2(-18, -5 + j), Vector2(-8, 2), Vector2(-2, -5 - j), Vector2(5, 3), Vector2(16, 0)])
	canvas.draw_polyline(bolt, HALO, 9.0, true)
	canvas.draw_polyline(bolt, Color(glow, 0.3), 7.0, true)
	canvas.draw_polyline(bolt, core, 3.0, true)
	canvas.draw_polyline(bolt, Color(1, 1, 1, 0.9), 1.0, true)

static func _arrow(canvas: CanvasItem, data: Dictionary) -> void:
	var shaft := Color("f6dfad")
	var head := Color("d29a4a")
	if data.hostile: shaft = Color("e9b9a6"); head = Color("c25a45")
	elif data.element == &"nature": shaft = Color("cfe8a8"); head = Color("5fa84a")
	canvas.draw_line(Vector2(-13, 0), Vector2(12, 0), HALO, 5.0, true)
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(14, 0), Vector2(4, -6.5), Vector2(4, 6.5)]), HALO)
	canvas.draw_line(Vector2(-13, 0), Vector2(12, 0), shaft, 3.0, true)
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(12, 0), Vector2(5, -5), Vector2(5, 5)]), head)
	canvas.draw_line(Vector2(-13, 0), Vector2(-17, -3), shaft, 1.5, true)
	canvas.draw_line(Vector2(-13, 0), Vector2(-17, 3), shaft, 1.5, true)

static func _trace(canvas: CanvasItem, data: Dictionary, tint: Color) -> void:
	canvas.draw_line(Vector2(-14, 0), Vector2(10, 0), HALO, 4.5, true)
	canvas.draw_line(Vector2(-14, 0), Vector2(10, 0), tint, 2.0, true)
	if data.element == &"fire":
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(12, 0), Vector2(-4, -5), Vector2(0, 0), Vector2(-4, 5)]), tint)
	elif data.element == &"ice":
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(13, 0), Vector2(5, -5), Vector2(0, 0), Vector2(5, 5)]), tint)
	else:
		var zig := PackedVector2Array([Vector2(-12, -3), Vector2(-3, 3), Vector2(1, -3), Vector2(12, 0)])
		canvas.draw_polyline(zig, HALO, 4.5, true)
		canvas.draw_polyline(zig, tint, 2.0, true)

static func _sentinel(canvas: CanvasItem, shape: StringName) -> void:
	match shape:
		&"sentinel_headshot":
			_line(canvas, Vector2(-24, 0), Vector2(14, 0), Color("d7f0de"), 2.0)
			canvas.draw_line(Vector2(-9, 0), Vector2(14, 0), Color.WHITE, 1.0, true)
			canvas.draw_polyline(PackedVector2Array([Vector2(5, -3), Vector2(14, 0), Vector2(5, 3)]), Color("d7f0de"), 2.0, true)
		&"sentinel_piercing_shot":
			_line(canvas, Vector2(-32, 0), Vector2(14, 0), Color("a6e3ee"), 2.0)
			canvas.draw_line(Vector2(-17, -3), Vector2(6, -3), Color("69a6af"), 1.0, true)
			canvas.draw_line(Vector2(-17, 3), Vector2(6, 3), Color("69a6af"), 1.0, true)
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(16, 0), Vector2(7, -5), Vector2(10, 0), Vector2(7, 5)]), Color.WHITE)
		&"sentinel_net_shot":
			canvas.draw_arc(Vector2.ZERO, 9.5, 0.0, TAU, 16, HALO, 3.5, true)
			canvas.draw_arc(Vector2.ZERO, 8.0, 0.0, TAU, 16, Color("bddfd1"), 1.5, true)
			canvas.draw_line(Vector2(-6, -6), Vector2(6, 6), Color.WHITE, 1.0, true)
			canvas.draw_line(Vector2(-6, 6), Vector2(6, -6), Color.WHITE, 1.0, true)
		&"sentinel_explosive_shot":
			_line(canvas, Vector2(-20, 0), Vector2(11, 0), Color("ffbf69"), 2.0)
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(13, 0), Vector2(6, -6), Vector2(3, 0), Vector2(6, 6)]), Color("ffda96"))
		&"sentinel_concussion_shot":
			_line(canvas, Vector2(-17, 0), Vector2(7, 0), Color("d7f0de"), 2.0)
			canvas.draw_circle(Vector2(10, 0), 6.5, HALO)
			canvas.draw_circle(Vector2(10, 0), 5.0, Color("eedb9f"))
			canvas.draw_arc(Vector2(10, 0), 8.0, -PI * 0.45, PI * 0.45, 12, Color("d7f0de"), 1.5, true)
		_:
			canvas.draw_circle(Vector2.ZERO, 8.0, HALO)
			canvas.draw_circle(Vector2.ZERO, 5.0, Color("d7f0de"))

static func _line(canvas: CanvasItem, a: Vector2, b: Vector2, color: Color, width: float) -> void:
	canvas.draw_line(a, b, HALO, width + 2.5, true)
	canvas.draw_line(a, b, color, width, true)

static func _grow(polygon: PackedVector2Array, amount: float) -> PackedVector2Array:
	var center := Vector2.ZERO
	for p: Vector2 in polygon: center += p
	center /= float(polygon.size())
	var result := PackedVector2Array()
	for p: Vector2 in polygon: result.append(p + (p - center).normalized() * amount)
	return result

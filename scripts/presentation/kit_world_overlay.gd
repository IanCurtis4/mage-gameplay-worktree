class_name KitWorldOverlay
extends Node2D
## E12 H3: disposable world overlay for the kit HUD state (ragrpg_kit_hud_v1). Two
## instances are used by H4: mode &"ground" (zones on the floor, below the actors) and mode
## &"overhead" (target marks, above the actors). Presentation only, outside any snapshot.
## World zones are projected point by point with the shared expedition projection; flat
## zones use arena coordinates. The DTO is not trusted: a malformed zone or mark is
## dropped, and a target id missing from `actors` is ignored.

const ProjectionMath = preload("res://scripts/world/expedition_projection.gd")

const MODE_GROUND := &"ground"
const MODE_OVERHEAD := &"overhead"
const CIRCLE_SEGMENTS := 48
const CONE_SEGMENTS := 24
const PIP_RADIUS := 3.5
const PIP_STEP := 9.0
const MARK_GAP := 9.0
const MARK_STACK := 12.0

var mode: StringName = MODE_GROUND:
	set(value):
		mode = value
		queue_redraw()
var _state: Dictionary = {}
var _actors: Dictionary = {}
## Number of times _draw drew something (tests and captures).
var draw_count := 0

## `dto` is a ragrpg_kit_hud_v1 dictionary ({} clears); `actors` maps target_id -> CombatActor.
func set_state(dto: Variant, actors: Variant = {}) -> void:
	_state = {}
	if typeof(dto) == TYPE_DICTIONARY and HudPalette.is_clean_state(dto): _state = dto
	_actors = actors if typeof(actors) == TYPE_DICTIONARY else {}
	queue_redraw()

func _process(_delta: float) -> void:
	# Marks follow moving actors; only the overhead mode needs a redraw per frame.
	if mode == MODE_OVERHEAD and not _state.is_empty(): queue_redraw()

## What the overlay draws in its mode (also used by tests): zones for ground, marks for
## overhead. Each zone: {"role", "polygon", "closed_outline", "color", "ratio", "shape", "space"}.
## Each mark: {"target_id", "key", "kind", "value", "max", "position", "color"}.
func plan() -> Array[Dictionary]:
	if _state.is_empty(): return [] as Array[Dictionary]
	return zone_plan(_state) if mode == MODE_GROUND else mark_plan(_state, _actors, self)

static func zone_plan(state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if typeof(state.get("zones")) != TYPE_ARRAY: return result
	for entry: Variant in state["zones"]:
		var zone := _zone(entry)
		if zone.is_empty(): return [] as Array[Dictionary] # a malformed zone drops the whole state
		result.append(zone)
	return result

static func _vec3(value: Variant) -> Variant:
	if typeof(value) != TYPE_VECTOR3: return null
	var v: Vector3 = value
	return v if is_finite(v.x) and is_finite(v.y) and is_finite(v.z) else null

static func _zone(entry: Variant) -> Dictionary:
	if typeof(entry) != TYPE_DICTIONARY: return {}
	var data: Dictionary = entry
	var space: Variant = data.get("space")
	if typeof(space) != TYPE_STRING_NAME or (space != &"world" and space != &"flat"): return {}
	var shape: Variant = data.get("shape")
	if typeof(shape) != TYPE_STRING_NAME or (shape != &"circle" and shape != &"cone" and shape != &"wide_circle"): return {}
	var center: Variant = _vec3(data.get("center"))
	if center == null or not HudPalette.is_number(data.get("radius")) or float(data["radius"]) <= 0.0: return {}
	var radius := float(data["radius"])
	if data.has("element") and not HudPalette.is_known_element(data["element"]): return {}
	var ratio := 1.0
	if data.has("remaining") or data.has("total"):
		if not HudPalette.is_number(data.get("remaining")) or not HudPalette.is_number(data.get("total")): return {}
		var total := float(data["total"])
		var remaining := float(data["remaining"])
		if total <= 0.0 or remaining < 0.0 or remaining > total: return {}
		ratio = remaining / total
	var is_world: bool = space == &"world"
	var angle_from := 0.0
	var angle_to := TAU
	var points := PackedVector2Array()
	var segments := CIRCLE_SEGMENTS
	if shape == &"cone":
		var facing: Variant = _vec3(data.get("facing"))
		if facing == null or not HudPalette.is_number(data.get("half_angle")): return {}
		var half := float(data["half_angle"])
		var direction := Vector2(facing.x, facing.z) if is_world else Vector2(facing.x, facing.y)
		if half <= 0.0 or half > PI or direction.length_squared() <= 0.000001: return {}
		var heading := direction.angle()
		angle_from = heading - half
		angle_to = heading + half
		segments = CONE_SEGMENTS
		points.append(_ground_point(center, Vector2.ZERO, is_world))
	for step: int in segments + (1 if shape == &"cone" else 0):
		var t := float(step) / float(segments)
		if shape != &"cone" and step == segments: break
		var angle := lerpf(angle_from, angle_to, t)
		points.append(_ground_point(center, Vector2(cos(angle), sin(angle)) * radius, is_world))
	return {
		"role": data.get("role", &""),
		"space": space,
		"shape": shape,
		"polygon": points,
		"color": HudPalette.element_color(data.get("element", &"none")),
		"ratio": ratio,
	}

## Local drawing point of `center + offset` on the ground: projected for the world,
## arena coordinates (x, y_canvas) for the flat arena.
static func _ground_point(center: Vector3, offset: Vector2, is_world: bool) -> Vector2:
	if is_world: return ProjectionMath.project(Vector3(center.x + offset.x, center.y, center.z + offset.y))
	return Vector2(center.x + offset.x, center.y + offset.y)

static func mark_plan(state: Dictionary, actors: Dictionary, reference: Node2D = null) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if typeof(state.get("target_marks")) != TYPE_ARRAY: return result
	var stack: Dictionary = {}
	for entry: Variant in state["target_marks"]:
		var mark := _mark(entry)
		if mark.is_empty(): return [] as Array[Dictionary] # a malformed mark drops the whole state
		var actor: Variant = actors.get(mark["target_id"])
		if actor == null or typeof(actor) != TYPE_OBJECT or not is_instance_valid(actor) or not actor is CombatActor: continue
		var level: int = stack.get(mark["target_id"], 0)
		stack[mark["target_id"]] = level + 1
		var anchor: Vector2 = actor.global_position if reference == null else reference.to_local(actor.global_position)
		mark["position"] = anchor + Vector2(0.0, actor.overhead_bar_y() - MARK_GAP - MARK_STACK * level)
		result.append(mark)
	return result

static func _mark(entry: Variant) -> Dictionary:
	if typeof(entry) != TYPE_DICTIONARY: return {}
	var data: Dictionary = entry
	if typeof(data.get("target_id")) != TYPE_INT or typeof(data.get("key")) != TYPE_STRING_NAME: return {}
	if typeof(data.get("kind")) != TYPE_STRING_NAME: return {}
	if data.has("element") and not HudPalette.is_known_element(data["element"]): return {}
	var kind: StringName = data["kind"]
	var mark := {"target_id": data["target_id"], "key": data["key"], "kind": kind, "color": HudPalette.element_color(data.get("element", &"none")), "value": 0, "max": 0}
	if kind == &"badge": return mark
	if kind != &"pips": return {}
	if typeof(data.get("value")) != TYPE_INT or typeof(data.get("max")) != TYPE_INT: return {}
	var value: int = data["value"]
	var maximum: int = data["max"]
	if maximum < 1 or value < 0 or value > maximum: return {}
	mark["value"] = value
	mark["max"] = maximum
	return mark

func _draw() -> void:
	var items := plan()
	if items.is_empty(): return
	draw_count += 1
	if mode == MODE_GROUND:
		for zone: Dictionary in items:
			var color: Color = zone["color"]
			var fade := lerpf(0.55, 1.0, float(zone["ratio"]))
			var polygon: PackedVector2Array = zone["polygon"]
			draw_colored_polygon(polygon, Color(color, 0.16 * fade))
			var outline := polygon.duplicate()
			outline.append(polygon[0])
			draw_polyline(outline, Color(color, 0.85 * fade), 2.0, true)
		return
	for mark: Dictionary in items:
		_draw_mark(mark)

func _draw_mark(mark: Dictionary) -> void:
	var color: Color = mark["color"]
	var center: Vector2 = mark["position"]
	if mark["kind"] == &"badge":
		var diamond := PackedVector2Array([center + Vector2(0, -5), center + Vector2(5, 0), center + Vector2(0, 5), center + Vector2(-5, 0)])
		draw_colored_polygon(diamond, color)
		draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), HudPalette.PIP_OUTLINE, 1.0, true)
		return
	var count: int = mark["max"]
	for index: int in count:
		var point := center + Vector2((float(index) - (count - 1) * 0.5) * PIP_STEP, 0.0)
		draw_circle(point, PIP_RADIUS, color if index < int(mark["value"]) else HudPalette.PIP_EMPTY)
		draw_arc(point, PIP_RADIUS, 0.0, TAU, 12, HudPalette.PIP_OUTLINE, 1.0, true)

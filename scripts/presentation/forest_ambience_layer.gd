extends Node2D
## E08 P5 A2: procedural forest ambience (presentation only, code-drawn).
## A few drifting leaves and pollen motes, soft dappled light shafts and a very
## light ground mist, in screen space. It is a disposable child of the expedition
## view, which the snapshot registry already treats as presentation, so nothing
## here is saved: it is rebuilt by `install` whenever the view is attached.
## Ordering: absolute z 4050 sits above every world sprite (<= 4000) and below the
## view's indicator/effect node (4090), and far below the HUD canvas layers, so
## danger, target and area indicators are never covered.
## Cost model: fixed state of STATE_CAP records, analytic motion from elapsed time
## (no per-frame allocations, no cumulative drift), frozen when the tree is paused.
const NODE_NAME := "ForestAmbience"
const BIOME := "forest"
const Z_INDEX := 4050
const INDICATOR_Z := 4090
const LEAVES := 10
const MOTES := 20
const MIST := 5
const SHAFTS := 4
const STATE_CAP := 48
const MAX_STEP := 0.1
## The motion is slow, so the canvas item redraws at 30 Hz instead of every frame.
const REDRAW_INTERVAL := 1.0 / 30.0
# Per-particle record: x, y (0..1 of the screen), phase, speed, size, alpha.
const FIELDS := 6
const MAX_ALPHA := 0.5
const LEAF_COLORS: Array[Color] = [Color(0.62, 0.76, 0.34), Color(0.88, 0.76, 0.34), Color(0.76, 0.5, 0.26)]
const MOTE_COLOR := Color(1.0, 0.95, 0.7)
const MIST_COLOR := Color(0.82, 0.93, 0.88)
const SHAFT_COLOR := Color(1.0, 0.96, 0.74)

static var _soft: GradientTexture2D

var layer_seed := 0
var elapsed := 0.0
var _since_draw := 0.0
var _state := PackedFloat32Array()
var _shaft_points := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _last_camera := Transform2D()
var _have_camera := false

## Deterministic seed for a stage: run seed text plus stage id.
static func stage_seed(seed_text: String, stage_id: String) -> int:
	return (seed_text + "|" + stage_id).hash() & 0x7FFFFFFF

static func particle_count() -> int:
	return LEAVES + MOTES + MIST + SHAFTS

## Idempotent hook: keeps exactly one layer under `host` for the forest biome and
## none for any other biome. Returns the layer or null.
static func install(host: Node, biome: String, seed_value: int) -> Node2D:
	if not is_instance_valid(host): return null
	var existing := host.get_node_or_null(NODE_NAME) as Node2D
	if biome != BIOME:
		if existing != null:
			host.remove_child(existing); existing.queue_free()
		return null
	if existing != null:
		if int(existing.get("layer_seed")) == seed_value: return existing
		host.remove_child(existing); existing.queue_free()
	var layer: Node2D = (load("res://scripts/presentation/forest_ambience_layer.gd") as Script).new()
	layer.set("layer_seed", seed_value)
	host.add_child(layer)
	return layer

func _init() -> void:
	name = NODE_NAME
	z_as_relative = false
	z_index = Z_INDEX
	process_mode = Node.PROCESS_MODE_PAUSABLE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func _ready() -> void:
	_build_state()
	_follow_camera()
	queue_redraw()

static func _soft_texture() -> GradientTexture2D:
	if _soft == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
		_soft = GradientTexture2D.new()
		_soft.gradient = gradient
		_soft.fill = GradientTexture2D.FILL_RADIAL
		_soft.fill_from = Vector2(0.5, 0.5)
		_soft.fill_to = Vector2(1.0, 0.5)
		_soft.width = 96
		_soft.height = 96
	return _soft

func _build_state() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = layer_seed
	_state.resize(STATE_CAP * FIELDS)
	var total := particle_count()
	for index: int in total:
		var base := index * FIELDS
		_state[base] = rng.randf()
		_state[base + 1] = rng.randf()
		_state[base + 2] = rng.randf() * TAU
		_state[base + 3] = rng.randf_range(0.6, 1.0)
		_state[base + 4] = rng.randf()
		_state[base + 5] = rng.randf()

## Fingerprint of the generated state, for determinism checks.
func state_signature() -> int:
	return _state.to_byte_array().hex_encode().hash()

func state_size() -> int:
	return _state.size()

func _process(delta: float) -> void:
	advance(delta)

## Advances the animation clock; called every unpaused frame.
func advance(delta: float) -> void:
	var step := minf(maxf(delta, 0.0), MAX_STEP)
	elapsed += step
	_since_draw += step
	_follow_camera()
	if _since_draw >= REDRAW_INTERVAL or delta == 0.0:
		_since_draw = 0.0
		queue_redraw()

# Local space is screen pixels centered on the screen centre: the node rides the
# camera, so zoom and UI scale never resize or displace the effect.
func _follow_camera() -> void:
	var viewport := get_viewport()
	if viewport == null: return
	var camera := viewport.get_camera_2d()
	if camera == null: return
	var center := camera.get_screen_center_position()
	var inverse_zoom := Vector2(1.0 / maxf(camera.zoom.x, 0.01), 1.0 / maxf(camera.zoom.y, 0.01))
	var target := Transform2D(0.0, inverse_zoom, 0.0, center)
	if _have_camera and target == _last_camera: return
	_last_camera = target; _have_camera = true
	global_transform = target

func _wrap01(value: float) -> float:
	return value - floorf(value)

## P7-C4 batching: the whole layer is three triangle-array commands (shafts, mist with the soft texture,
## then motes and leaves) instead of ~40 separate primitives. The formulas and draw order are unchanged;
## circles are the same 64-segment fans that `draw_circle` builds, with the same vertex colours.
const DRAW_BATCHES := 3
const CIRCLE_SEGMENTS := 64
const CIRCLE_VERTS := CIRCLE_SEGMENTS + 1
const DOTS := LEAVES + MOTES

static var _unit_circle := PackedVector2Array()
static var _circle_indices := PackedInt32Array()

## Batched commands issued by the last `_draw` (the cost test pins this value).
var last_batch_count := 0
var _centers := PackedVector2Array()
var _shaft_verts := PackedVector2Array()
var _shaft_cols := PackedColorArray()
var _shaft_idx := PackedInt32Array()
var _mist_verts := PackedVector2Array()
var _mist_cols := PackedColorArray()
var _mist_uvs := PackedVector2Array()
var _mist_idx := PackedInt32Array()
var _dot_verts := PackedVector2Array()
var _dot_cols := PackedColorArray()

static func _ensure_tables() -> void:
	if not _unit_circle.is_empty(): return
	_unit_circle.resize(CIRCLE_VERTS)
	_unit_circle[0] = Vector2.ZERO
	for i: int in CIRCLE_SEGMENTS:
		_unit_circle[1 + i] = Vector2.from_angle(TAU * float(i) / float(CIRCLE_SEGMENTS))
	_circle_indices.resize(DOTS * CIRCLE_SEGMENTS * 3)
	for j: int in DOTS:
		for i: int in CIRCLE_SEGMENTS:
			var o := (j * CIRCLE_SEGMENTS + i) * 3
			var b := j * CIRCLE_VERTS
			_circle_indices[o] = b; _circle_indices[o + 1] = b + 1 + i; _circle_indices[o + 2] = b + 1 + (i + 1) % CIRCLE_SEGMENTS

func _ensure_buffers() -> void:
	if not _dot_verts.is_empty(): return
	_ensure_tables()
	_centers.resize(LEAVES + MOTES + MIST)
	_shaft_verts.resize(SHAFTS * 6); _shaft_cols.resize(SHAFTS * 6)
	_mist_verts.resize(MIST * 4); _mist_cols.resize(MIST * 4); _mist_uvs.resize(MIST * 4); _mist_idx.resize(MIST * 6)
	for k: int in MIST:
		var u := k * 4
		_mist_uvs[u] = Vector2(0, 0); _mist_uvs[u + 1] = Vector2(1, 0); _mist_uvs[u + 2] = Vector2(1, 1); _mist_uvs[u + 3] = Vector2(0, 1)
		var o := k * 6
		_mist_idx[o] = u; _mist_idx[o + 1] = u + 1; _mist_idx[o + 2] = u + 2; _mist_idx[o + 3] = u; _mist_idx[o + 4] = u + 2; _mist_idx[o + 5] = u + 3
	_dot_verts.resize(DOTS * CIRCLE_VERTS); _dot_cols.resize(DOTS * CIRCLE_VERTS)

## Centres (screen-centred pixels) of leaves, motes and mist, in that order, as of the last draw.
func particle_centers() -> PackedVector2Array:
	return _centers

func _put_dot(slot: int, center: Vector2, rotation_value: float, scale_value: Vector2, radius: float, color: Color) -> void:
	var basis_x := Vector2.from_angle(rotation_value) * scale_value.x * radius
	var basis_y := Vector2.from_angle(rotation_value + PI * 0.5) * scale_value.y * radius
	var base := slot * CIRCLE_VERTS
	for i: int in CIRCLE_VERTS:
		var u := _unit_circle[i]
		_dot_verts[base + i] = center + basis_x * u.x + basis_y * u.y
		_dot_cols[base + i] = color

func _draw() -> void:
	last_batch_count = 0
	if _state.size() < particle_count() * FIELDS: return
	var size := get_viewport_rect().size
	if size.x < 8.0 or size.y < 8.0: return
	_ensure_buffers()
	var half := size * 0.5
	var t := elapsed
	# Light shafts first (furthest back inside the layer), then mist, motes, leaves.
	var shaft_start := LEAVES + MOTES + MIST
	_shaft_idx.clear()
	for k: int in SHAFTS:
		var base := (shaft_start + k) * FIELDS
		var pulse := 0.55 + 0.45 * sin(t * 0.18 * _state[base + 3] + _state[base + 2])
		var alpha := 0.14 * pulse
		var top_x := (_wrap01(_state[base] + t * 0.004 * (_state[base + 3] - 0.8)) * 1.3 - 0.15) * size.x
		var width := (0.07 + 0.07 * _state[base + 4]) * size.x
		var slant := size.y * 0.55
		var drop := size.y * (0.7 + 0.25 * _state[base + 5])
		var color := SHAFT_COLOR
		var clear := Color(color.r, color.g, color.b, 0.0)
		var lit := Color(color.r, color.g, color.b, alpha)
		_shaft_points[0] = Vector2(top_x - width - half.x, -half.y)
		_shaft_points[1] = Vector2(top_x - half.x, -half.y)
		_shaft_points[2] = Vector2(top_x + width - half.x, -half.y)
		_shaft_points[3] = Vector2(top_x + width + slant - half.x, drop - half.y)
		_shaft_points[4] = Vector2(top_x + slant - half.x, drop - half.y)
		_shaft_points[5] = Vector2(top_x - width + slant - half.x, drop - half.y)
		var v := k * 6
		for i: int in 6:
			_shaft_verts[v + i] = _shaft_points[i]
			_shaft_cols[v + i] = clear
		_shaft_cols[v + 1] = lit
		# Same triangulation `draw_polygon` would use.
		for index: int in Geometry2D.triangulate_polygon(_shaft_points):
			_shaft_idx.append(v + index)
	if not _shaft_idx.is_empty():
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _shaft_idx, _shaft_verts, _shaft_cols)
		last_batch_count += 1
	var mist_start := LEAVES + MOTES
	for k: int in MIST:
		var base := (mist_start + k) * FIELDS
		var drift := _wrap01(_state[base] + t * 0.006 * _state[base + 3])
		var x := (drift * 1.6 - 0.3) * size.x - half.x
		var y := (0.55 + 0.4 * _state[base + 1]) * size.y - half.y
		var radius_x := size.x * (0.22 + 0.12 * _state[base + 4])
		var radius_y := size.y * (0.09 + 0.05 * _state[base + 5])
		var breathe := 0.8 + 0.2 * sin(t * 0.25 + _state[base + 2])
		var tint := Color(MIST_COLOR.r, MIST_COLOR.g, MIST_COLOR.b, 0.1 * breathe)
		_centers[LEAVES + MOTES + k] = Vector2(x, y)
		var v := k * 4
		_mist_verts[v] = Vector2(x - radius_x, y - radius_y); _mist_verts[v + 1] = Vector2(x + radius_x, y - radius_y)
		_mist_verts[v + 2] = Vector2(x + radius_x, y + radius_y); _mist_verts[v + 3] = Vector2(x - radius_x, y + radius_y)
		_mist_cols[v] = tint; _mist_cols[v + 1] = tint; _mist_cols[v + 2] = tint; _mist_cols[v + 3] = tint
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _mist_idx, _mist_verts, _mist_cols, _mist_uvs, PackedInt32Array(), PackedFloat32Array(), _soft_texture().get_rid())
	last_batch_count += 1
	for k: int in MOTES:
		var base := (LEAVES + k) * FIELDS
		var speed := _state[base + 3]
		var x := _wrap01(_state[base] + t * 0.004 * speed + 0.015 * sin(t * 0.5 * speed + _state[base + 2])) * size.x - half.x
		var y := _wrap01(_state[base + 1] - t * 0.006 * speed) * size.y - half.y
		var twinkle := 0.5 + 0.5 * sin(t * (0.8 + speed) + _state[base + 2])
		var radius := 1.3 + 1.6 * _state[base + 4]
		_centers[LEAVES + k] = Vector2(x, y)
		_put_dot(k, Vector2(x, y), 0.0, Vector2.ONE, radius, Color(MOTE_COLOR.r, MOTE_COLOR.g, MOTE_COLOR.b, MAX_ALPHA * 0.75 * (0.3 + 0.7 * twinkle) * (0.5 + 0.5 * _state[base + 5])))
	for k: int in LEAVES:
		var base := k * FIELDS
		var speed := _state[base + 3]
		var sway := sin(t * 0.7 * speed + _state[base + 2])
		var x := _wrap01(_state[base] + t * 0.012 * speed + 0.03 * sway) * size.x - half.x
		var y := _wrap01(_state[base + 1] + t * 0.022 * speed) * size.y - half.y
		var spin := t * 0.9 * speed + _state[base + 2]
		var radius := 4.0 + 2.6 * _state[base + 4]
		var tint: Color = LEAF_COLORS[k % LEAF_COLORS.size()]
		_centers[k] = Vector2(x, y)
		_put_dot(MOTES + k, Vector2(x, y), spin, Vector2(1.0, 0.5 + 0.2 * sin(spin * 1.7)), radius, Color(tint.r, tint.g, tint.b, MAX_ALPHA * (0.6 + 0.4 * _state[base + 5])))
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _circle_indices, _dot_verts, _dot_cols)
	last_batch_count += 1

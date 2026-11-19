extends Node2D
## E10a T16 (A15) — persistent drawn node of the Cultista figures: the Geometria Impossível
## figure and the Revelação eye, drawn for their whole duration (4–7 s), not only at the
## `effect_start` burst. Presentation only: it reads the kit state, never writes it, joins no
## snapshot group (the kit's `snapshot_compact_blocker` is what keeps the exact format) and
## frees itself the moment its source stops matching: the figure ended, a new figure
## replaced it (serial), the player died or left, or the kit object is no longer the
## player's (a snapshot restore). The kit also releases it explicitly at the end of the
## figure and on death. This script never names a class_name (E10a T1 note about 4.7.2).

const ProjectionMath = preload("res://scripts/world/expedition_projection.gd")

var kind: StringName = &""
var serial := 0
## The runtime kit object that owns the figure (RefCounted, read only).
var kit: RefCounted
var world := false
## Number of times _draw drew something (tests and captures).
var draw_count := 0
var _owner: WeakRef
var _state: Dictionary = {}

func setup(runtime: RefCounted, player: Node, figure_kind: StringName, figure_serial: int) -> void:
	kit = runtime
	_owner = weakref(player)
	kind = figure_kind
	serial = figure_serial
	var motion: Variant = player.get(&"world_motion")
	world = motion != null and bool(motion.call(&"is_current_world"))
	top_level = true
	z_as_relative = false
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_state = kit.call(&"figure_state", kind)
	_place()

## True while the kit still wants this exact figure.
func is_source_current() -> bool:
	var player := _owner.get_ref() as Node if _owner != null else null
	if player == null or not is_instance_valid(player) or player.get(&"kit") != kit: return false
	if not bool(player.call(&"is_alive")): return false
	_state = kit.call(&"figure_state", kind)
	return bool(_state.get("active", false)) and int(_state.get("serial", -1)) == serial

## Detaches and frees the node now (idempotent).
func release() -> void:
	if get_parent() != null: get_parent().remove_child(self)
	if not is_queued_for_deletion(): queue_free()

func _process(_delta: float) -> void:
	if not is_source_current():
		release()
		return
	_place()
	queue_redraw()

func _place() -> void:
	if _state.is_empty(): return
	if kind == &"geometry":
		var center: Vector3 = _state.get("center", Vector3.ZERO)
		position = ProjectionMath.project(center) if world else Vector2(center.x, center.z)
		z_index = clampi(floori(center.y * 4.0) + 1, -4000, 4000) if world else -1
	else:
		var player := _owner.get_ref() as Node2D if _owner != null else null
		if player != null and is_instance_valid(player): position = player.global_position
		z_index = 4001 if world else 5

func _draw() -> void:
	if kit == null or _state.is_empty(): return
	draw_count += 1
	kit.call(&"draw_persistent", kind, self, _state, world)

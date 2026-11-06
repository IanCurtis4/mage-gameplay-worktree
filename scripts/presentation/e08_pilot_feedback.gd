extends Control
## Cosmetic pulses on confirmed anchors only; gameplay indicators remain authoritative.
const ProjectionMath = preload("res://scripts/world/expedition_projection.gd")
const CAP := 48
const LIFETIME := 0.38
const KINDS := [&"cast_start", &"cast_cancel", &"projectile_launch", &"impact", &"area_start", &"area_end", &"teleport", &"death", &"revive"]
var bridge: PresentationEventBridge
var host: WeakRef
var pulses: Array[Dictionary] = []

func _init() -> void:
	name = "E08PilotFeedback"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS

func configure(source: PresentationEventBridge, controller: Node) -> void:
	if bridge == source: return
	dispose()
	bridge = source
	host = weakref(controller)
	bridge.event_confirmed.connect(_event)
	bridge.world_advanced.connect(_advance)

func _active() -> bool:
	var controller: Node = host.get_ref() if host != null else null
	return is_instance_valid(controller) and controller.is_inside_tree() and controller.process_mode != Node.PROCESS_MODE_DISABLED and not controller.get("snapshot_passive") and not get_tree().paused

func _event(event: Dictionary) -> void:
	if event.kind in [&"stage_enter", &"stage_exit"]:
		pulses.clear(); queue_redraw(); return
	if event.kind not in KINDS or not _active(): return
	var controller: Node2D = host.get_ref() as Node2D
	var payload: Dictionary = event.payload
	var local: Vector2
	if payload.get("position_unavailable", false):
		if not payload.has("legacy_position_2d"): return
		local = controller.to_local(payload.legacy_position_2d)
	else:
		var view: ExpeditionGeometryView = controller.get("expedition_view")
		if not is_instance_valid(view): return
		if not view.point_visible(event.position): return
		local = controller.to_local(view.to_global(ProjectionMath.project(event.position)))
	if pulses.size() >= CAP: pulses.pop_front()
	pulses.append({"position":local, "kind":event.kind, "age":0.0})
	queue_redraw()

func _advance(delta: float) -> void:
	if not _active(): return
	for i: int in range(pulses.size()-1, -1, -1):
		pulses[i].age += delta
		if pulses[i].age >= LIFETIME: pulses.remove_at(i)
	queue_redraw()

func _process(_delta: float) -> void:
	var controller: Node = host.get_ref() if host != null else null
	if not is_instance_valid(controller) or controller.process_mode == Node.PROCESS_MODE_DISABLED or bool(controller.get("snapshot_passive")):
		if not pulses.is_empty(): pulses.clear(); queue_redraw()

func _draw() -> void:
	for pulse: Dictionary in pulses:
		var t: float = clampf(pulse.age / LIFETIME, 0.0, 1.0)
		var tint := Color("ffbb6b")
		if pulse.kind in [&"teleport", &"revive"]: tint = Color("a7e8ff")
		elif pulse.kind in [&"cast_cancel", &"death", &"area_end"]: tint = Color("b8a9cf")
		var p: Vector2 = pulse.position + Vector2(0, -16)
		var radius := 5.0 + 10.0*t
		draw_arc(p, radius, 0, TAU, 24, Color(tint, (1.0-t)*0.65), 1.5, true)
		for side: float in [-1.0, 1.0]:
			draw_line(p + Vector2(side*(radius+3), 0), p + Vector2(side*(radius+7), 0), Color(tint, (1.0-t)*0.8), 1.5, true)

func dispose() -> void:
	if is_instance_valid(bridge):
		if bridge.event_confirmed.is_connected(_event): bridge.event_confirmed.disconnect(_event)
		if bridge.world_advanced.is_connected(_advance): bridge.world_advanced.disconnect(_advance)
	bridge = null; host = null; pulses.clear()
	queue_redraw()

func _exit_tree() -> void: dispose()

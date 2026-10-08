class_name HunterPresentation
extends Node2D
## Read-only presentation of the committed Hunter cycle. No resolver or timer
## in this node can create/consume an opening, damage, concealment or movement.

const EVENT_CAP := 16
const TRAIL_CAP := 6
const EVENT_DURATION := 0.36
const TRAIL_DURATION := 0.24
var player_owner: PlayerActor
var events: Array[Dictionary] = []
var trails: Array[Dictionary] = []
var visual_time := 0.0
var _last_foot := Vector2.ZERO

func configure(owner: PlayerActor) -> void:
	player_owner = owner
	_last_foot = owner.global_position
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = 3

func clear() -> void:
	events.clear()
	trails.clear()
	visual_time = 0.0
	if is_instance_valid(player_owner):
		_last_foot = player_owner.global_position
	queue_redraw()

func _available() -> bool:
	return is_instance_valid(player_owner) and player_owner.is_hunter() and player_owner.is_alive() and not (is_inside_tree() and get_tree().paused)

func notify_consumed(point: Vector2) -> void:
	_add_event(point, &"consume", 20.0)

func notify_trap(point: Vector2, skill: StringName, radius: float) -> void:
	if skill in HunterMath.NEW_TRAP_IDS:
		_add_event(point, skill, radius)

func _add_event(point: Vector2, kind: StringName, radius: float) -> void:
	if not _available() or not point.is_finite() or not is_finite(radius) or radius <= 0.0 or events.size() >= EVENT_CAP:
		return
	events.append({"point": point, "kind": kind, "radius": radius, "remaining": EVENT_DURATION})
	queue_redraw()

func _process(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0 or (is_inside_tree() and get_tree().paused):
		return
	if not _available():
		clear()
		return
	visual_time += delta
	for collection: Array[Dictionary] in [events, trails]:
		for index: int in range(collection.size() - 1, -1, -1):
			collection[index]["remaining"] = maxf(0.0, float(collection[index]["remaining"]) - delta)
			if float(collection[index]["remaining"]) <= 0.0:
				collection.remove_at(index)
	if player_owner.hunter_state.step_remaining > 0.0:
		if _last_foot.distance_to(player_owner.global_position) >= 10.0:
			if trails.size() >= TRAIL_CAP:
				trails.pop_front()
			trails.append({"point": player_owner.global_position, "remaining": TRAIL_DURATION})
			_last_foot = player_owner.global_position
	else:
		_last_foot = player_owner.global_position
	queue_redraw()

func _collect_markers() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not is_instance_valid(player_owner) or not player_owner.is_alive():
		return result
	# Snapshot IDs only. Never retain a target node, damage request or ledger.
	var ids: Array = player_owner.hunter_state._openings.keys()
	var mark_id := player_owner.hunter_state.marked_target_id
	if mark_id > 0 and mark_id not in ids:
		ids.append(mark_id)
	for id: int in ids:
		var target := instance_from_id(id) as CombatActor
		if not is_instance_valid(target) or not target.is_alive() or target.is_queued_for_deletion():
			continue
		result.append({"point": target.global_position + Vector2(0, -52.0 * target.sprite_visual_scale - 15.0), "marked": player_owner.hunter_state.is_marked(id), "open": not player_owner.hunter_state.opening(id).is_empty()})
	return result

func _stroke(from: Vector2, to: Vector2, color: Color, width: float = 2.0) -> void:
	draw_line(from, to, Color("18221a", color.a), width + 2.0, true)
	draw_line(from, to, color, width, true)

func _draw() -> void:
	if not is_instance_valid(player_owner) or not player_owner.is_alive():
		return
	for marker: Dictionary in _collect_markers():
		var point := to_local(marker["point"])
		if bool(marker["marked"]):
			# Solid small diamond is priority; the separate broken notches mean open.
			var diamond := PackedVector2Array([point + Vector2(0, -6), point + Vector2(5, 0), point + Vector2(0, 6), point + Vector2(-5, 0), point + Vector2(0, -6)])
			draw_polyline(diamond, Color("18221a"), 5.0, true)
			draw_polyline(diamond, Color("e3b96b"), 2.0, true)
		if bool(marker["open"]):
			for side: float in [-1.0, 1.0]:
				_stroke(point + Vector2(side * 8, -9), point + Vector2(side * 12, -9), Color("eee2bd"))
				_stroke(point + Vector2(side * 12, -9), point + Vector2(side * 12, 8), Color("eee2bd"))
				_stroke(point + Vector2(side * 12, 8), point + Vector2(side * 8, 8), Color("eee2bd"))
	for event: Dictionary in events:
		var phase := 1.0 - float(event["remaining"]) / EVENT_DURATION
		var point := to_local(event["point"])
		var kind: StringName = event["kind"]
		var color := Color("e8d8a3", 1.0 - phase)
		if kind == &"consume":
			point += Vector2(0, -28)
			for index: int in 4:
				var axis := Vector2.from_angle(PI * 0.25 + PI * 0.5 * index)
				_stroke(point + axis * lerpf(2, 11, phase), point + axis * lerpf(9, 19, phase), color, 2.5)
		else:
			var distance := float(event["radius"]) * lerpf(0.22, 0.8, phase)
			if kind == &"hunter_freezing_trap":
				color = Color("c2e7df", 1.0 - phase)
			for index: int in 6:
				var axis := Vector2.from_angle(TAU * index / 6.0)
				var tip := point + axis * distance
				_stroke(tip - axis * 9, tip, color)
				if kind == &"hunter_thorn_trap":
					_stroke(tip, tip + axis.rotated(0.5) * -6, color)
	for trail: Dictionary in trails:
		var point := to_local(trail["point"])
		var color := Color("c6d9a3", float(trail["remaining"]) / TRAIL_DURATION * 0.7)
		_stroke(point + Vector2(-5, 2), point + Vector2(-1, -2), color, 1.5)
		_stroke(point + Vector2(1, 3), point + Vector2(5, -1), color, 1.5)

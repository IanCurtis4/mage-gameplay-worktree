class_name GeometerCasting
extends Node2D
## G1 orchestration and underlay. Field damage/transformations belong to G4/G5.

signal hit(request: DamageRequest, target: CombatActor)
signal feedback(message: String)
signal construction_closed(result: Dictionary)

var player: PlayerActor
var targets: Array[CombatActor] = []
var construction := GeometerConstructionState.new()
var preview_command: GeometerCastCommand
var preview_valid := false

func configure(caster: PlayerActor) -> void:
	player = caster
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = -1
	player.geometer_cast_ready.connect(launch)

func alive_positions() -> Dictionary[int, Vector2]:
	var positions: Dictionary[int, Vector2] = {}
	for actor: CombatActor in targets:
		if is_instance_valid(actor) and actor.is_alive():
			positions[actor.get_instance_id()] = actor.global_position
	return positions

func capture(skill: StringName, point: Vector2, force_ground: bool = false) -> GeometerCastCommand:
	var command := GeometerCastCommand.new()
	command.skill_id = skill
	command.element = construction.grammar.selected_element
	command.point = point
	var enemy := BattleTargeting.pick(point, targets, null, false) if not force_ground else null
	command.actor_id = enemy.get_instance_id() if enemy != null else 0
	return command

func check(command: GeometerCastCommand) -> Dictionary:
	construction.refresh(alive_positions(), player.navigation)
	return player.geometer_shot_check(command, construction, targets)

func begin(command: GeometerCastCommand) -> bool:
	var result := check(command)
	if not result["ok"]:
		feedback.emit(result["reason"])
		return false
	if player.skill_cast_time(command.skill_id) > 0.0:
		return player.begin_geometer_cast(command, construction, targets)
	launch(command)
	return true

func launch(command: GeometerCastCommand) -> void:
	construction.refresh(alive_positions(), player.navigation)
	var result := player.commit_geometer_shot(command, construction, targets)
	if not result["ok"]:
		feedback.emit(result["reason"])
		return
	var projectile := GeometerTraceProjectile.new()
	add_child(projectile)
	projectile.z_index = 2
	projectile.configure_trace(result, command, player.global_position, player.navigation)
	projectile.delivered.connect(_on_delivered.bind(projectile))
	projectile.add_to_group("player_projectiles")
	queue_redraw()

func _on_delivered(ticket: int, success: bool, point: Vector2, victim: CombatActor, projectile: GeometerTraceProjectile) -> void:
	# Validate ticket before damage: clear/timeout cannot leave a damaging late shot.
	if not construction.grammar.pending_snapshot().any(func(item: Dictionary) -> bool: return int(item["ticket"]) == ticket and not bool(item["resolved"])) or not player.is_alive():
		return
	if success and is_instance_valid(victim) and victim.is_alive() and projectile.request.magic_damage > 0.0:
		projectile.request.target_id = victim.get_instance_id()
		hit.emit(projectile.request, victim)
	for result: Dictionary in construction.resolve_shot(ticket, success, point, alive_positions(), player.navigation):
		_report_delivery(result)
	_retire_invalid_flights()
	queue_redraw()

func _report_delivery(result: Dictionary) -> void:
	if not result["ok"]:
		feedback.emit(result["reason"])
	elif result.get("formation", false):
		construction_closed.emit(result)

func advance(delta: float) -> void:
	if not is_instance_valid(player) or not player.is_alive() or (is_inside_tree() and get_tree().paused):
		return
	for result: Dictionary in construction.advance(delta, alive_positions(), player.navigation):
		_report_delivery(result)
	_retire_invalid_flights()
	queue_redraw()

func _retire_invalid_flights() -> void:
	var active_tickets: Array[int] = []
	for pending: Dictionary in construction.grammar.pending_snapshot():
		if not bool(pending["resolved"]):
			active_tickets.append(int(pending["ticket"]))
	for child: Node in get_children():
		if child is GeometerTraceProjectile and child.ticket not in active_tickets:
			child.queue_free()

func select(element: StringName) -> bool:
	if not is_instance_valid(player) or not player.is_geometer() or not player.is_alive() or (is_inside_tree() and get_tree().paused):
		return false
	return construction.grammar.select_element(element)

func clear_construction() -> void:
	player.cancel_active_cast()
	construction.clear()
	preview_command = null
	for child: Node in get_children():
		if child is GeometerTraceProjectile:
			child.queue_free()
	queue_redraw()

func outline_segments() -> Array[PackedVector2Array]:
	var points := construction.positions()
	var segments: Array[PackedVector2Array] = []
	if points.size() < 2:
		return segments
	for index: int in range(3 if points.size() == 3 else 1):
		var next := (index + 1) % points.size()
		if points[index].is_finite() and points[next].is_finite():
			segments.append(PackedVector2Array([points[index], points[next]]))
	return segments

func _draw() -> void:
	var points := construction.positions()
	var tint := Color("b5dce8", 0.6)
	for segment: PackedVector2Array in outline_segments():
		if construction.suspended or construction.shape == GeometerConstructionState.Shape.PREPARATION:
			draw_dashed_line(to_local(segment[0]), to_local(segment[1]), tint, 1.5, 8.0)
		else:
			draw_line(to_local(segment[0]), to_local(segment[1]), tint, 1.5)
	for index: int in range(points.size()):
		if points[index].is_finite():
			_draw_vertex(to_local(points[index]), construction.vertices[index].element, construction.vertices[index].actor_id > 0)
			draw_string(ThemeDB.fallback_font, to_local(points[index]) + Vector2(14, 4), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, tint)
	if preview_command != null:
		var point := preview_command.point
		for actor: CombatActor in targets:
			if is_instance_valid(actor) and actor.is_alive() and actor.get_instance_id() == preview_command.actor_id:
				point = actor.global_position
		if point.is_finite():
			var preview_tint := Color("87e0cf") if preview_valid else Color("ff8b8b")
			draw_arc(to_local(point), 15.0, 0.0, TAU, 24, preview_tint, 1.5)
			if not points.is_empty() and points[-1].is_finite():
				draw_dashed_line(to_local(points[-1]), to_local(point), preview_tint, 1.0, 7.0)
			if points.size() == 2 and points[0].is_finite():
				draw_dashed_line(to_local(point), to_local(points[0]), preview_tint, 1.0, 7.0)

func _draw_vertex(point: Vector2, element: StringName, mobile: bool) -> void:
	var tint := Color("ffac68") if element == &"fire" else (Color("a9e9ff") if element == &"ice" else Color("ebe29b"))
	var glyph := PackedVector2Array([point + Vector2(0, -8), point + Vector2(7, 6), point + Vector2(-7, 6), point + Vector2(0, -8)])
	if element == &"ice":
		glyph = PackedVector2Array([point + Vector2(0, -8), point + Vector2(7, 0), point + Vector2(0, 8), point + Vector2(-7, 0), point + Vector2(0, -8)])
	elif element == &"lightning":
		glyph = PackedVector2Array([point + Vector2(5, -8), point + Vector2(-4, 0), point + Vector2(4, 0), point + Vector2(-5, 8)])
	draw_polyline(glyph, tint, 2.0)
	if mobile:
		draw_arc(point, 12.0, 0.0, TAU, 20, tint, 1.0)

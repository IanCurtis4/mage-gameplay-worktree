class_name FireWall
extends Node2D
## Four visual pillars share one overlap source, so refreshing burn never creates
## four independent tick streams on the same actor.

const PILLAR_COUNT := 4
const PILLAR_SPACING := 54.0
const PILLAR_RADIUS := 22.0
const DURATION := 5.0
const BURN_DURATION := 3.0

var source_id: int
var burn_damage := 0.0
var targets: Array[CombatActor] = []
var remaining := DURATION
var pillar_offsets := PackedVector2Array()
var _previous_positions: Dictionary[int, Vector2] = {}

func configure(caster: CombatActor, facing: Vector2, damage_per_tick: float, potential_targets: Array[CombatActor]) -> void:
	source_id = caster.get_instance_id()
	burn_damage = damage_per_tick
	targets = potential_targets.duplicate()
	global_position = caster.global_position + facing.normalized() * ClassCatalog.skill_definition(&"fire_wall").range
	var wall_axis := facing.normalized().orthogonal()
	for index: int in range(PILLAR_COUNT):
		pillar_offsets.append(wall_axis * ((float(index) - 1.5) * PILLAR_SPACING))
	for actor: CombatActor in targets:
		if actor != null and is_instance_valid(actor):
			_previous_positions[actor.get_instance_id()] = actor.global_position
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _process(delta: float) -> void:
	remaining = maxf(0.0, remaining - delta)
	for actor: CombatActor in targets:
		if actor == null or not is_instance_valid(actor) or not actor.is_alive():
			continue
		var actor_id := actor.get_instance_id()
		var previous: Vector2 = _previous_positions.get(actor_id, actor.global_position)
		for offset: Vector2 in pillar_offsets:
			if _distance_to_segment(global_position + offset, previous, actor.global_position) <= actor.collision_radius + PILLAR_RADIUS:
				actor.apply_burn(source_id, burn_damage, BURN_DURATION)
				break
		_previous_positions[actor_id] = actor.global_position
	if remaining <= 0.0:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var alpha := minf(1.0, remaining * 2.0)
	for index: int in range(pillar_offsets.size()):
		var offset := pillar_offsets[index]
		var flicker := sin((DURATION - remaining) * 13.0 + index * 1.8) * 4.0
		draw_circle(offset, PILLAR_RADIUS, Color(1.0, 0.24, 0.08, 0.16 * alpha))
		draw_arc(offset, PILLAR_RADIUS, 0.0, TAU, 24, Color(1.0, 0.50, 0.16, 0.9 * alpha), 3.0, true)
		var flame := PackedVector2Array([Vector2(-13, 4), Vector2(-17, -10), Vector2(-9, -27), Vector2(-5, -17), Vector2(2, -43 - flicker), Vector2(9, -24), Vector2(14, -10), Vector2(12, 4)])
		for vertex: int in range(flame.size()):
			flame[vertex] += offset
		draw_colored_polygon(flame, Color(1.0, 0.32, 0.08, 0.9 * alpha))
		draw_colored_polygon(PackedVector2Array([offset + Vector2(-7, 3), offset + Vector2(-4, -13), offset + Vector2(3, -25 - flicker), offset + Vector2(8, 3)]), Color(1.0, 0.83, 0.27, alpha))

func _distance_to_segment(point: Vector2, from: Vector2, to: Vector2) -> float:
	var segment := to - from
	if segment.length_squared() <= 0.0001:
		return point.distance_to(from)
	var fraction := clampf((point - from).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return point.distance_to(from + segment * fraction)

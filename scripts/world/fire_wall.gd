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

func configure(caster: CombatActor, facing: Vector2, damage_per_tick: float, potential_targets: Array[CombatActor]) -> void:
	source_id = caster.get_instance_id()
	burn_damage = damage_per_tick
	targets = potential_targets.duplicate()
	global_position = caster.global_position + facing.normalized() * ClassCatalog.skill_definition(&"fire_wall").range
	var wall_axis := facing.normalized().orthogonal()
	for index: int in range(PILLAR_COUNT):
		pillar_offsets.append(wall_axis * ((float(index) - 1.5) * PILLAR_SPACING))
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _process(delta: float) -> void:
	remaining = maxf(0.0, remaining - delta)
	for actor: CombatActor in targets:
		if actor == null or not is_instance_valid(actor) or not actor.is_alive():
			continue
		for offset: Vector2 in pillar_offsets:
			if actor.global_position.distance_to(global_position + offset) <= actor.collision_radius + PILLAR_RADIUS:
				actor.apply_burn(source_id, burn_damage, BURN_DURATION)
				break
	if remaining <= 0.0:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var alpha := minf(1.0, remaining * 2.0)
	for offset: Vector2 in pillar_offsets:
		draw_circle(offset, PILLAR_RADIUS, Color(1.0, 0.24, 0.08, 0.16 * alpha))
		draw_arc(offset, PILLAR_RADIUS, 0.0, TAU, 24, Color(1.0, 0.50, 0.16, 0.9 * alpha), 3.0, true)
		draw_line(offset + Vector2(0, 12), offset + Vector2(0, -22), Color(1.0, 0.32, 0.08, 0.8 * alpha), 7.0, true)

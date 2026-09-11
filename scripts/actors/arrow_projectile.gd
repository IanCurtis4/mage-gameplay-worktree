class_name ArrowProjectile
extends Node2D

signal hit(request: DamageRequest, target: CombatActor)

var request: DamageRequest
var target: CombatActor
var speed := 430.0

func configure(damage_request: DamageRequest, target_actor: CombatActor) -> void:
	request = damage_request
	target = target_actor
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target) or not target.is_alive():
		queue_free()
		return
	var destination := target.global_position + Vector2(0, -18)
	global_position = global_position.move_toward(destination, speed * delta)
	rotation = global_position.angle_to_point(destination)
	if global_position.distance_to(destination) <= 12.0:
		hit.emit(request, target)
		queue_free()

func _draw() -> void:
	draw_line(Vector2(-13, 0), Vector2(12, 0), Color("f6dfad"), 3.0)
	draw_colored_polygon(PackedVector2Array([Vector2(12, 0), Vector2(5, -5), Vector2(5, 5)]), Color("d29a4a"))

class_name EquipmentHeadVisual
extends Node2D
## Cosmetic read-only overlay. Shares the actor's exact atlas frame/pivot/flip.
var actor: PlayerActor
func configure(owner_actor: PlayerActor) -> void:
	actor = owner_actor
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
func _process(_delta: float) -> void:
	queue_redraw()
func is_equipped() -> bool:
	if not is_instance_valid(actor) or not actor.is_alive() or actor.run_state == null or actor.run_state.build_snapshot == null: return false
	var snapshot := actor.run_state.build_snapshot
	var id: Variant = snapshot.equipped.get(&"head")
	return id != null and snapshot.equipment_instances.has(id) and snapshot.equipment_instances[id].definition_id == &"pilot_head"
func _draw() -> void:
	if not is_equipped() or actor.character_animation == null: return
	var animation := actor.character_animation
	var frame := animation.state.frame_index()
	var rect := animation.destination_rect(frame)
	# Frame-specific head positions in source-cell coordinates, including attack lean.
	var anchor := Vector2(33, 18)
	if frame % 4 == 1 and frame in [8, 9, 10, 11, 20, 21, 22, 23]: anchor += Vector2(2, 2)
	if frame >= 24: anchor += Vector2(1, 3)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(-actor.sprite_visual_scale if animation.state.flip_h else actor.sprite_visual_scale, actor.sprite_visual_scale))
	var point := rect.position + anchor
	var dome := PackedVector2Array([point + Vector2(-13, 6), point + Vector2(-12, -6), point + Vector2(-5, -12), point + Vector2(6, -11), point + Vector2(13, -4), point + Vector2(12, 8)])
	draw_colored_polygon(dome, Color("637783"))
	draw_colored_polygon(PackedVector2Array([point + Vector2(-11, -5), point + Vector2(-5, -10), point + Vector2(1, -10), point + Vector2(1, 0), point + Vector2(-11, 0)]), Color("8699a0"))
	draw_line(point + Vector2(7, -7), point + Vector2(10, -3), Color("a9b7b9"), 1)
	var line := dome.duplicate()
	line.append(dome[0])
	draw_polyline(line, Color("253440"), 2)
	if animation.state.back_view:
		draw_line(point + Vector2(-4, -9), point + Vector2(-4, 7), Color("a8bbc4"), 2)
	else:
		draw_line(point + Vector2(-10, 1), point + Vector2(12, 1), Color("d0d9db"), 3)
		draw_line(point + Vector2(-8, 4), point + Vector2(11, 4), Color("27313a"), 2)
		draw_line(point + Vector2(2, -1), point + Vector2(2, 8), Color("a8bbc4"), 2)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

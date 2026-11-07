class_name EquipmentHeadVisual
extends Node2D
## Compatibility marker for existing hosts/snapshot omission.
## Drawing lives in CharacterAnimation for both world actors and inventory portraits.
var actor: PlayerActor
func configure(owner_actor: PlayerActor) -> void:
	actor = owner_actor
	set_process(false)
func is_equipped() -> bool:
	if not is_instance_valid(actor) or not actor.is_alive() or actor.run_state == null or actor.run_state.build_snapshot == null: return false
	var snapshot := actor.run_state.build_snapshot
	var id: Variant = snapshot.equipped.get(&"head")
	return id != null and snapshot.equipment_instances.has(id) and snapshot.equipment_instances[id].definition_id == &"pilot_head"

static func legacy_pose(frame: int, back: bool) -> Dictionary:
	var anchor := Vector2(33,18)
	if frame%4==1 and frame in [8,9,10,11,20,21,22,23]: anchor+=Vector2(2,2)
	if frame>=24: anchor+=Vector2(1,3)
	return {"point":anchor,"angle":0.0,"depth":1,"flip":false,"visible":frame<28,"view":1 if back else 0}

static func draw_resolved(canvas: CanvasItem, descriptor: Dictionary, tint: Color, scale: float, depth: int) -> void:
	var head: Dictionary = descriptor.get("head",{})
	if head.is_empty() or not head.visible or head.depth!=depth: return
	var point: Vector2 = descriptor.origin+Vector2(head.point)
	var view: int = head.view
	var side := view>=2
	var mirror := -1.0 if bool(head.flip) != (view==3) else 1.0
	var body := Transform2D(0.0,Vector2(-scale if descriptor.flip else scale,scale),0.0,Vector2.ZERO)
	canvas.draw_set_transform_matrix(body*Transform2D(float(head.angle),Vector2(mirror,1.0),0.0,point))
	var dome := PackedVector2Array([Vector2(-13,6),Vector2(-12,-6),Vector2(-5,-12),Vector2(6,-11),Vector2(13,-4),Vector2(12,8)])
	if side: dome=PackedVector2Array([Vector2(-9,7),Vector2(-10,-5),Vector2(-5,-12),Vector2(5,-11),Vector2(11,-4),Vector2(10,8)])
	canvas.draw_colored_polygon(dome,Color("637783")*tint)
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-11,-5),Vector2(-5,-10),Vector2(1,-10),Vector2(1,0),Vector2(-11,0)]),Color("8699a0")*tint)
	var line := dome.duplicate(); line.append(dome[0]); canvas.draw_polyline(line,Color("253440")*tint,2)
	if view==1:
		canvas.draw_line(Vector2(-4,-9),Vector2(-4,7),Color("a8bbc4")*tint,2)
	elif side:
		canvas.draw_line(Vector2(3,-1),Vector2(11,0),Color("d0d9db")*tint,3)
		canvas.draw_line(Vector2(5,3),Vector2(11,4),Color("27313a")*tint,2)
		canvas.draw_line(Vector2(11,-1),Vector2(10,8),Color("a8bbc4")*tint,2)
	else:
		canvas.draw_line(Vector2(-10,1),Vector2(12,1),Color("d0d9db")*tint,3)
		canvas.draw_line(Vector2(-8,4),Vector2(11,4),Color("27313a")*tint,2)
		canvas.draw_line(Vector2(2,-1),Vector2(2,8),Color("a8bbc4")*tint,2)
	canvas.draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)

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
	return id != null and snapshot.equipment_instances.has(id) and EquipmentArtCatalog.has_head(snapshot.equipment_instances[id].definition_id)

static func legacy_pose(frame: int, back: bool) -> Dictionary:
	var anchor := Vector2(33,18)
	if frame%4==1 and frame in [8,9,10,11,20,21,22,23]: anchor+=Vector2(2,2)
	if frame>=24: anchor+=Vector2(1,3)
	return {"point":anchor,"angle":0.0,"depth":1,"flip":false,"visible":frame<28,"view":1 if back else 0}

static func resolved_transform(descriptor: Dictionary,scale: float) -> Transform2D:
	var head: Dictionary=descriptor.head
	var point: Vector2=descriptor.origin+Vector2(head.point)
	var body := Transform2D(0.0,Vector2(-scale if descriptor.flip else scale,scale),0.0,Vector2.ZERO)
	return body*Transform2D(float(head.angle),Vector2(-1.0 if head.flip else 1.0,1.0),0.0,point)

static func draw_resolved(canvas: CanvasItem, descriptor: Dictionary, tint: Color, scale: float, depth: int) -> void:
	var head: Dictionary=descriptor.get("head",{})
	if head.is_empty() or not head.visible or head.depth!=depth:return
	var texture := EquipmentArtCatalog.head_texture(StringName(head.get("key",&"")))
	if texture==null:return
	# Four authored source views; no implicit west mirror.
	canvas.draw_set_transform_matrix(resolved_transform(descriptor,scale))
	canvas.draw_texture_rect_region(texture,Rect2(-EquipmentArtCatalog.HEAD_ANCHOR,EquipmentArtCatalog.HEAD_CELL),Rect2(int(head.view)*96,0,96,96),tint,false,true)
	canvas.draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)

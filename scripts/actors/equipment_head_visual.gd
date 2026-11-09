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

static var fit_enabled := true  ## evidence switch: false reproduces the legacy anchor placement

## P7-C6 head-fit table (tools/prepare_e08_head_fit.py): per class/frame measured head
## (centre x, top row, width) of the atlas actually drawn with a head piece, and per piece/view
## painted bounds. Unknown class/piece: the legacy anchor placement is used unchanged.
static func fit_data() -> Dictionary:
	return EquipmentHeadFitData.DATA

static func kind_of(descriptor: Dictionary) -> StringName:
	var atlas: Texture2D = descriptor.get("atlas")
	if atlas==null: return &""
	var parts := atlas.resource_path.split("/")
	var at := parts.find("directional")
	return StringName(parts[at+1]) if at>=0 and at+1<parts.size()-1 else &""

## Crown seat: returns {} (legacy) or {origin, angle, scale(Vector2), seat(Vector2 in piece px), head_width}.
## Head top-centre and width come from the measured body frame, so the piece follows idle bob, walk,
## action, hurt recoil and (via the authored point/angle plus the upright offset) the fall/corpse frames.
static func fit(descriptor: Dictionary) -> Dictionary:
	var head: Dictionary=descriptor.get("head",{})
	var data := fit_data()
	if not fit_enabled or head.is_empty() or data.is_empty() or int(descriptor.get("version",1))!=2: return {}
	var kind := kind_of(descriptor)
	var cls: Dictionary=data.classes.get(String(kind),{})
	var piece: Dictionary=data.pieces.get(String(head.get("key",&"")),{})
	if cls.is_empty() or piece.is_empty(): return {}
	var frame := int(descriptor.frame)
	var row: Array=cls.frames[frame]
	var view: Dictionary=piece.views[int(head.view)]
	var top_centre := Vector2(float(row[0]),float(row[1]))
	var angle := float(head.angle)
	if frame%16>=14:
		var offset: Array=cls.rotated_offset[frame/16]
		top_centre=Vector2(head.point)+Vector2(float(offset[0]),float(offset[1])).rotated(angle)
	var width := float(row[2])
	var horizontal := float(piece.width_k)*width/float(view.w)
	var scale := Vector2(horizontal,horizontal*float(piece.vk))
	var seat := Vector2(float(view.cx),float(view.y0))
	var origin := top_centre+Vector2(0.0,float(piece.drop)*width)
	if frame%16>=14:
		# Fall/corpse: the larger piece must not sink below the ground the body rests on. Lift it by
		# the excess of its painted bounds (descriptor.origin.y + local y must stay <= 0.05).
		var lowest := -INF
		for corner: Vector2 in [Vector2(view.bx0,view.by0),Vector2(view.bx1,view.by0),Vector2(view.bx0,view.by1),Vector2(view.bx1,view.by1)]:
			lowest=maxf(lowest,(origin+((corner-seat)*scale).rotated(angle)).y)
		origin.y-=maxf(0.0,lowest+float(descriptor.origin.y)-0.04)
	return {"origin":origin,"angle":angle,"scale":scale,"seat":seat,"head_width":width}

static func resolved_transform(descriptor: Dictionary,scale: float) -> Transform2D:
	var head: Dictionary=descriptor.head
	var body := Transform2D(0.0,Vector2(-scale if descriptor.flip else scale,scale),0.0,Vector2.ZERO)
	var placed := fit(descriptor)
	if not placed.is_empty():
		var size: Vector2=placed.scale
		return body*Transform2D(float(placed.angle),Vector2(-size.x if head.flip else size.x,size.y),0.0,descriptor.origin+Vector2(placed.origin))
	var point: Vector2=descriptor.origin+Vector2(head.point)
	return body*Transform2D(float(head.angle),Vector2(-1.0 if head.flip else 1.0,1.0),0.0,point)

static func draw_resolved(canvas: CanvasItem, descriptor: Dictionary, tint: Color, scale: float, depth: int) -> void:
	var head: Dictionary=descriptor.get("head",{})
	if head.is_empty() or not head.visible or head.depth!=depth:return
	var texture := EquipmentArtCatalog.head_texture(StringName(head.get("key",&"")))
	if texture==null:return
	# Four authored source views; no implicit west mirror.
	canvas.draw_set_transform_matrix(resolved_transform(descriptor,scale))
	var placed := fit(descriptor)
	var anchor: Vector2=placed.seat if not placed.is_empty() else EquipmentArtCatalog.HEAD_ANCHOR
	canvas.draw_texture_rect_region(texture,Rect2(-anchor,EquipmentArtCatalog.HEAD_CELL),Rect2(int(head.view)*96,0,96,96),tint,false,true)
	canvas.draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)

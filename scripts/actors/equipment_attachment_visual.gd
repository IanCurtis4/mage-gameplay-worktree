class_name EquipmentAttachmentVisual
extends RefCounted
## Grip-based pixel equipment, calibrated per body frame. Cosmetic geometry only.

const CELL := Vector2(64, 64)
const SUPPORTED: Array[StringName] = [&"sword", &"axe", &"staff", &"bow", &"shield", &"prismatic_focus", &"wooden_beads"]
static var _texture_cache: Dictionary = {}

static func describe(snapshot: BuildSnapshot, catalog: BuildEffectCatalog) -> Dictionary:
	var result := {"main_hand": &"", "off_hand": &"", "arms": &"", "head": &""}
	if snapshot == null or catalog == null:
		return result
	for slot: StringName in [&"main_hand", &"off_hand", &"arms", &"head"]:
		var instance_id: Variant = snapshot.equipped.get(slot)
		if instance_id == null or not snapshot.equipment_instances.has(instance_id):
			continue
		var instance: EquipmentInstance = snapshot.equipment_instances[instance_id]
		var definition := catalog.get_definition(&"equipment", instance.definition_id) as EquipmentDefinition
		if definition == null:
			continue
		if slot == &"head":
			result[slot] = &"pilot_head" if definition.id == &"pilot_head" else &""
			continue
		var key := definition.visual_key
		if key.is_empty():
			key = _fallback_key(slot, definition, snapshot.base_class_id)
		result[slot] = key if key in SUPPORTED else &""
	return result

const RIG = preload("res://scripts/actors/equipment_hand_rig.gd")
const PROFILES := {
	&"sword": {"size":Vector2(16,32),"grip":Vector2(8,25),"angle":0.20},
	&"axe": {"size":Vector2(20,32),"grip":Vector2(10,25),"angle":0.22},
	&"staff": {"size":Vector2(16,40),"grip":Vector2(7,30),"angle":0.30},
	&"bow": {"size":Vector2(20,34),"grip":Vector2(14,17),"angle":0.65},
	&"shield": {"size":Vector2(20,26),"grip":Vector2(10,13),"angle":0.0},
	&"prismatic_focus": {"size":Vector2(14,20),"grip":Vector2(7,16),"angle":-0.10},
	&"wooden_beads": {"size":Vector2(12,12),"grip":Vector2(6,5),"angle":0.0},
}
static var _bounds_cache: Dictionary = {}

static func placement(kind: StringName,state: CombatAnimationState,key: StringName,slot: StringName,body_origin: Vector2) -> Dictionary:
	if key not in PROFILES: return {}
	var pose: Dictionary = RIG.pose(kind,state.frame_index())
	if pose.is_empty():return {}
	var hand: Vector2 = pose["off"] if slot==&"off_hand" else pose["main"]
	if slot==&"arms":hand+=Vector2(-2,0)
	var point := body_origin+hand
	var angle: float = PROFILES[key]["angle"]
	if key==&"bow" and kind==&"sentinel":angle=0.45
	if key==&"bow" and (kind==&"hunter" or state.hurt_remaining>0.0):angle=1.05
	var phase := state.frame_index()%4
	var attack := state.frame_index() in range(8,12) or state.frame_index() in range(20,24)
	if attack:
		if key in [&"sword",&"axe"]:angle=[-0.35,-0.85,0.75,0.22][phase]
		elif key==&"bow":angle=[0.08,0.05,0.12,0.14][phase]
		elif key==&"staff":angle=[0.10,0.26,0.28,0.12][phase]
	var depth := 0 if pose["back"] and hand.x<32 or (attack and phase==1 and key in [&"sword",&"axe"]) else 1
	if key==&"bow" and state.hurt_remaining>0.0:
		# The recoil arm carries the bow behind the body, keeping the face clear.
		depth=0
	if state.dead:
		depth=0
		angle=PI*0.5 if key!=&"wooden_beads" else 0.0
		if state.frame_index()%2==1:
			# The actual bottom pixel rests on the same ground as the corpse.
			point.y=-_rotated_bottom(key,angle)
	var finger: Rect2 = pose["off_fingers"] if slot==&"off_hand" else pose["main_fingers"]
	return {"point":point,"angle":angle,"depth":depth,"grip":PROFILES[key]["grip"],"size":PROFILES[key]["size"],"finger_rect":finger,"slot":slot,"key":key}

static func piece_transform(placement_data: Dictionary,scale: float,flip: bool) -> Transform2D:
	var sign_x := -1.0 if flip else 1.0
	var p: Vector2 = placement_data["point"]
	return Transform2D(float(placement_data["angle"])*sign_x,Vector2(scale*sign_x,scale),0.0,Vector2(p.x*sign_x,p.y)*scale)

static func draw_on(canvas: CanvasItem,state: CombatAnimationState,visual: Dictionary,tint: Color,scale: float,kind: StringName=&"swordsman",body_origin: Vector2=Vector2(-32,-58),depth: int=1) -> void:
	if canvas==null or state==null:return
	for slot: StringName in [&"main_hand",&"off_hand",&"arms"]:
		var key := StringName(visual.get(String(slot),&""))
		var placed := placement(kind,state,key,slot,body_origin)
		if placed.is_empty() or placed["depth"]!=depth:continue
		_draw_piece(canvas,state,placed,tint,scale)
		if key==&"bow" and not state.dead and state.action_remaining>0.0 and state.action!=&"dash":
			_draw_bow_arrow(canvas,state,placed,tint,scale)
	canvas.draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)

static func draw_fingers(canvas: CanvasItem,state: CombatAnimationState,visual: Dictionary,tint: Color,scale: float,kind: StringName,atlas: Texture2D,body_origin: Vector2) -> void:
	if state.dead or atlas==null:return
	for slot: StringName in [&"main_hand",&"off_hand"]:
		var placed := placement(kind,state,StringName(visual.get(String(slot),&"")),slot,body_origin)
		if placed.is_empty():continue
		var finger: Rect2 = placed["finger_rect"]
		var cell := Vector2(state.frame_index()%4*64,(state.frame_index()>>2)*64)
		canvas.draw_set_transform(Vector2.ZERO,0.0,Vector2(-scale if state.flip_h else scale,scale))
		canvas.draw_texture_rect_region(atlas,Rect2(body_origin+finger.position,finger.size),Rect2(cell+finger.position,finger.size),tint)
	canvas.draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)

static func _texture(key: StringName) -> Texture2D:
	var texture := _texture_cache.get(key) as Texture2D
	if texture==null:
		texture=load("res://assets/art/equipment/%s.svg" % key) as Texture2D
		if texture!=null:_texture_cache[key]=texture
	return texture

static func _rotated_bottom(key: StringName,angle: float) -> float:
	if not _bounds_cache.has(key):
		var texture := _texture(key)
		_bounds_cache[key]=texture.get_image().get_used_rect() if texture!=null else Rect2i(Vector2i.ZERO,Vector2i(PROFILES[key]["size"]))
	var bounds: Rect2i = _bounds_cache[key]
	var grip: Vector2 = PROFILES[key]["grip"]
	var bottom := -INF
	for corner: Vector2 in [Vector2(bounds.position),Vector2(bounds.end-Vector2i.ONE),Vector2(bounds.position.x,bounds.end.y-1),Vector2(bounds.end.x-1,bounds.position.y)]:bottom=maxf(bottom,(corner-grip).rotated(angle).y)
	return bottom

static func _draw_piece(canvas: CanvasItem,state: CombatAnimationState,placed: Dictionary,tint: Color,scale: float) -> void:
	var texture := _texture(placed["key"])
	if texture==null:return
	var transform := piece_transform(placed,scale,state.flip_h)
	canvas.draw_set_transform_matrix(transform)
	canvas.draw_texture(texture,-Vector2(placed["grip"]),tint)

static func _draw_bow_arrow(canvas: CanvasItem,state: CombatAnimationState,placed: Dictionary,tint: Color,scale: float) -> void:
	if state.action_duration<=0.0 or 1.0-state.action_remaining/state.action_duration>=0.75:return
	canvas.draw_set_transform_matrix(piece_transform(placed,scale,state.flip_h))
	var from := Vector2(-11,0);var to := Vector2(20,0)
	canvas.draw_line(from,to,Color(0.32,0.22,0.16,tint.a),1.0,false)
	canvas.draw_line(from+Vector2(0,-1),to-Vector2(3,1),Color(0.84,0.69,0.43,tint.a),1.0,false)
	canvas.draw_colored_polygon(PackedVector2Array([to+Vector2(0,-2),to+Vector2(5,0),to+Vector2(0,2)]),Color(0.78,0.85,0.85,tint.a))
	canvas.draw_line(from,from+Vector2(-3,-2),Color(0.79,0.72,0.56,tint.a),1.0,false)

static func _fallback_key(slot: StringName, definition: EquipmentDefinition, base_class: StringName) -> StringName:
	if slot == &"arms":
		return &""
	if definition.item_kind == &"shield":
		return &"shield"
	if definition.item_kind == &"focus":
		return &"prismatic_focus"
	if definition.item_kind == &"jewelry":
		return &"wooden_beads" if slot == &"off_hand" else &""
	if definition.item_kind != &"weapon":
		return &""
	var id := String(definition.id).to_lower()
	if id.contains("axe") or id.contains("machado"):
		return &"axe"
	if id.contains("bow") or id.contains("arco"):
		return &"bow"
	if id.contains("staff") or id.contains("cajado") or base_class == &"mage":
		return &"staff"
	if base_class in [&"archer", &"hunter"]:
		return &"bow"
	return &"sword"


## Resolved exactly once with the body frame. Legacy placement API stays intact.
static func resolve_equipment(kind: StringName, state: CombatAnimationState, visual: Dictionary, origin: Vector2, frame: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot: StringName in [&"main_hand",&"off_hand",&"arms"]:
		var key := StringName(visual.get(slot,&""))
		if key not in PROFILES: continue
		var placed: Dictionary
		if frame.is_empty():
			placed=placement(kind,state,key,slot,origin)
			if not placed.is_empty(): placed["flip"]=false
		else:
			var pose: Dictionary = frame.slots[String(slot)]
			var hand := Vector2(pose.point[0],pose.point[1])
			var fingers: Array = pose.fingers
			placed={"point":origin+hand,"angle":pose.get("angle_overrides",{}).get(String(key),float(PROFILES[key].angle)+float(pose.angle)),"depth":pose.get("depth_overrides",{}).get(String(key),int(pose.depth)),"flip":pose.flip,"grip":PROFILES[key].grip,"size":PROFILES[key].size,"finger_rect":Rect2(fingers[0],fingers[1],fingers[2],fingers[3]),"slot":slot,"key":key}
			if state.dead:
				# The corpse releases equipment onto the same local ground as V1.
				# Local mirroring changes the rotated support, never the X anchor.
				var support := _rotated_bottom(key,-float(placed.angle) if bool(placed.flip) else float(placed.angle))
				var grounded: Vector2=placed.point
				if state.pose_index()==15 or grounded.y+support>0.0:
					grounded.y=-support
					placed.point=grounded
		if not placed.is_empty(): result.append(placed)
	return result

static func resolved_transform(placed: Dictionary, scale: float, body_flip: bool) -> Transform2D:
	var body := Transform2D(0.0,Vector2(-scale if body_flip else scale,scale),0.0,Vector2.ZERO)
	return body*Transform2D(float(placed.angle),Vector2(-1.0 if placed.get("flip",false) else 1.0,1.0),0.0,Vector2(placed.point))

static func draw_resolved(canvas: CanvasItem, descriptor: Dictionary, tint: Color, scale: float, depth: int) -> void:
	for placed: Dictionary in descriptor.equipment:
		if placed.depth!=depth: continue
		var texture := _texture(placed.key)
		if texture==null: continue
		canvas.draw_set_transform_matrix(resolved_transform(placed,scale,descriptor.flip))
		canvas.draw_texture(texture,-Vector2(placed.grip),tint)
		if placed.key==&"bow" and descriptor.arrow_visible:
			# Same cosmetic arrow as V1, using the resolved hand transform.
			var from := Vector2(-11,0); var to := Vector2(20,0)
			canvas.draw_line(from,to,Color(0.32,0.22,0.16,tint.a),1,false)
			canvas.draw_line(from+Vector2(0,-1),to-Vector2(3,1),Color(0.84,0.69,0.43,tint.a),1,false)
			canvas.draw_colored_polygon(PackedVector2Array([to+Vector2(0,-2),to+Vector2(5,0),to+Vector2(0,2)]),Color(0.78,0.85,0.85,tint.a))
			canvas.draw_line(from,from+Vector2(-3,-2),Color(0.79,0.72,0.56,tint.a),1,false)
	canvas.draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)

static func draw_resolved_fingers(canvas: CanvasItem, descriptor: Dictionary, tint: Color, scale: float) -> void:
	if descriptor.dead: return
	for placed: Dictionary in descriptor.equipment:
		if placed.slot not in [&"main_hand",&"off_hand"]: continue
		var crop: Rect2 = placed.finger_rect
		canvas.draw_set_transform(Vector2.ZERO,0.0,Vector2(-scale if descriptor.flip else scale,scale))
		canvas.draw_texture_rect_region(descriptor.atlas,Rect2(descriptor.origin+crop.position,crop.size),Rect2(descriptor.region.position+crop.position,crop.size),tint)
	canvas.draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)

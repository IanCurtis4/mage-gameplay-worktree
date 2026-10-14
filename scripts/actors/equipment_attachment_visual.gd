class_name EquipmentAttachmentVisual
extends RefCounted
## Small, read-only SVG equipment overlays. No combat geometry is exposed here.

const CELL := Vector2(64, 64)
const SUPPORTED: Array[StringName] = [&"sword", &"axe", &"staff", &"bow", &"shield", &"prismatic_focus", &"wooden_beads"]
static var _texture_cache: Dictionary = {}

static func describe(snapshot: BuildSnapshot, catalog: BuildEffectCatalog) -> Dictionary:
	var result := {"main_hand": &"", "off_hand": &"", "arms": &""}
	if snapshot == null or catalog == null:
		return result
	for slot: StringName in [&"main_hand", &"off_hand", &"arms"]:
		var instance_id: Variant = snapshot.equipped.get(slot)
		if instance_id == null or not snapshot.equipment_instances.has(instance_id):
			continue
		var instance: EquipmentInstance = snapshot.equipment_instances[instance_id]
		var definition := catalog.get_definition(&"equipment", instance.definition_id) as EquipmentDefinition
		if definition == null:
			continue
		var key := definition.visual_key
		if key.is_empty():
			key = _fallback_key(slot, definition, snapshot.base_class_id)
		result[slot] = key if key in SUPPORTED else &""
	return result

static func draw_on(canvas: CanvasItem, state: CombatAnimationState, visual: Dictionary, tint: Color, scale: float) -> void:
	if canvas == null or state == null:
		return
	var frame := state.frame_index()
	var action_frame := frame % 4
	var back := state.back_view
	var hand_y := -22.0 if back else -24.0
	var hand_x := 18.0 if back else 14.0
	var action_lift := -2.0 if state.action_remaining > 0.0 and action_frame >= 2 else 0.0
	var base := Vector2(hand_x, hand_y + action_lift)
	var main_key := StringName(visual.get("main_hand", &""))
	var off_key := StringName(visual.get("off_hand", &""))
	var arms_key := StringName(visual.get("arms", &""))
	if state.dead:
		# Lay the equipment beside the collapsed sprite instead of leaving it at
		# the standing hand anchor. These are visual overlays only.
		var grounded_scale := scale * 0.65
		if not main_key.is_empty():
			_draw_piece(canvas, main_key, Vector2(22.0, 2.0), PI * 0.5, Vector2(12, 22), tint, grounded_scale, state.flip_h)
		if not off_key.is_empty():
			_draw_piece(canvas, off_key, Vector2(-22.0, 2.0), PI * 0.5, Vector2(12, 18), tint, grounded_scale, state.flip_h)
		if not arms_key.is_empty():
			_draw_piece(canvas, arms_key, Vector2(0.0, 1.0), 0.0, Vector2(10, 10), tint, grounded_scale, state.flip_h)
		return
	var rotation := _weapon_rotation(state, action_frame)
	if not main_key.is_empty():
		_draw_piece(canvas, main_key, base, rotation, Vector2(18, 30), tint, scale, state.flip_h)
	if not off_key.is_empty():
		var off_point := Vector2(-19.0 if back else -13.0, hand_y + (1.0 if action_frame % 2 == 1 else 0.0))
		_draw_piece(canvas, off_key, off_point, -rotation * 0.45, Vector2(18, 22), tint, scale, state.flip_h)
	if not arms_key.is_empty():
		_draw_piece(canvas, arms_key, Vector2(8.0, -18.0), 0.0, Vector2(12, 12), tint, scale, state.flip_h)

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

static func _weapon_rotation(state: CombatAnimationState, frame: int) -> float:
	var angle := -0.20 if state.facing.y < -0.25 else 0.20
	if state.facing.x < -0.1:
		angle = -angle
	if state.action_remaining > 0.0:
		angle += [-0.45, -0.18, 0.28, 0.48][frame]
	return angle

static func _draw_piece(canvas: CanvasItem, key: StringName, anchor: Vector2, rotation: float, size: Vector2, tint: Color, scale: float, flip: bool) -> void:
	if key not in SUPPORTED:
		return
	var texture := _texture_cache.get(key) as Texture2D
	if texture == null:
		texture = load("res://assets/art/equipment/%s.svg" % key) as Texture2D
		if texture == null:
			return
		_texture_cache[key] = texture
	var point := Vector2(-anchor.x if flip else anchor.x, anchor.y)
	canvas.draw_set_transform(point * scale, rotation, Vector2(-scale if flip else scale, scale))
	canvas.draw_texture_rect(texture, Rect2(-size * 0.5, size), false, tint)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

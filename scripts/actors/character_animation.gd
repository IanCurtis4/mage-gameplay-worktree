class_name CharacterAnimation
extends RefCounted
## Shared atlas + per-actor visual state. All gameplay lives in the owner.

const CELL := Vector2(64, 64)
const PIVOT := Vector2(32, 58)
const WEAPONLESS_KINDS: Array[StringName] = [&"swordsman", &"archer", &"berserker", &"defender", &"elementalist", &"hunter", &"mage", &"sentinel", &"spiritualist", &"geometer"]
static var _atlas_cache: Dictionary = {}
static var _weaponless_atlas_cache: Dictionary = {}
const ATTACHMENT_VISUAL_SCRIPT = preload("res://scripts/actors/equipment_attachment_visual.gd")
var state := CombatAnimationState.new()
var atlas: Texture2D
var actor_kind: StringName = &"swordsman"
var _equipment_visual: Dictionary = {}
var equipment_visual: Dictionary:
	get:
		return _equipment_visual
	set(value):
		set_equipment_visual(value)
var _last_position := Vector2.ZERO
var _observed_position := false
var _ground_offsets := PackedFloat32Array()
var _base_atlas: Texture2D
var _base_ground_offsets := PackedFloat32Array()

func configure(kind: StringName) -> void:
	actor_kind = kind
	if actor_kind not in [&"swordsman", &"mage", &"warrior", &"archer", &"defender", &"berserker", &"elementalist", &"spiritualist", &"geometer", &"sentinel", &"hunter", &"gel", &"beast_master", &"animal_companion"]:
		actor_kind = &"swordsman"
	var cached: Dictionary = _atlas_cache.get(actor_kind, {})
	if cached.is_empty():
		atlas = load("res://assets/art/animations/%s.png" % actor_kind) as Texture2D
		var offsets := _measure_ground_offsets(atlas)
		_atlas_cache[actor_kind] = {"atlas": atlas, "ground_offsets": offsets}
		_base_atlas = atlas
		_base_ground_offsets = offsets
	else:
		atlas = cached["atlas"]
		_base_atlas = atlas
		_base_ground_offsets = cached["ground_offsets"]
	_select_atlas_for_visual()
	state = CombatAnimationState.new()
	_observed_position = false

func set_equipment_visual(value: Dictionary) -> void:
	_equipment_visual = value.duplicate(true)
	_select_atlas_for_visual()

func _select_atlas_for_visual() -> void:
	var has_player_contract := equipment_visual.has("main_hand") or equipment_visual.has("off_hand") or equipment_visual.has("arms")
	if not has_player_contract or actor_kind not in WEAPONLESS_KINDS:
		atlas = _base_atlas if _base_atlas != null else atlas
		_ground_offsets = _base_ground_offsets
		return
	var cached: Dictionary = _weaponless_atlas_cache.get(actor_kind, {})
	if cached.is_empty():
		var path := "res://assets/art/animations/%s_weaponless.png" % actor_kind
		var texture := load(path) as Texture2D if ResourceLoader.exists(path) else null
		cached = {"atlas": texture, "ground_offsets": _measure_ground_offsets(texture)}
		_weaponless_atlas_cache[actor_kind] = cached
	if cached["atlas"] != null:
		atlas = cached["atlas"]
		_ground_offsets = cached["ground_offsets"]
	else:
		atlas = _base_atlas
		_ground_offsets = _base_ground_offsets

static func _measure_ground_offsets(texture: Texture2D) -> PackedFloat32Array:
	var offsets := PackedFloat32Array()
	if texture == null:
		return offsets
	var bitmap := texture.get_image()
	for index: int in range(32):
		var bounds := bitmap.get_region(Rect2i(Vector2i(index % 4 * 64, index / 4 * 64), Vector2i(64, 64))).get_used_rect()
		# Last opaque pixel rests on the ground rather than above the contact shadow.
		offsets.append(PIVOT.y - float(bounds.end.y - 1))
	return offsets

func observe(position: Vector2, delta: float) -> void:
	var displacement := position - _last_position if _observed_position else Vector2.ZERO
	_last_position = position
	_observed_position = true
	state.advance(delta, displacement)

func play(action: StringName, direction: Vector2 = Vector2.ZERO, duration: float = 0.25) -> void:
	state.trigger(action, direction, duration)

## Every state used by the atlas and equipment drawers, independent of the
## continuous presentation clock. Equal keys produce identical draw commands.
func draw_key() -> Array:
	return [state.frame_index(),state.flip_h,state.dead,state.hurt_remaining > 0.0,
		state.action_remaining > 0.0,state.action,
		state.action_duration > 0.0 and 1.0-state.action_remaining/state.action_duration < 0.75,
		atlas,_equipment_visual.duplicate()]

func draw_on(canvas: CanvasItem, tint: Color = Color.WHITE, visual_scale: float = 1.0) -> void:
	if atlas == null:
		return
	var frame := state.frame_index()
	var region := source_region(frame)
	var body_origin := destination_rect(frame).position
	ATTACHMENT_VISUAL_SCRIPT.draw_on(canvas,state,equipment_visual,tint,visual_scale,actor_kind,body_origin,0)
	# draw_set_transform replaces the prior transform, so compose flip and scale here.
	# The zero translation keeps the sprite pivot anchored at the actor's feet.
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2(-visual_scale if state.flip_h else visual_scale, visual_scale))
	canvas.draw_texture_rect_region(atlas, destination_rect(frame), region, tint)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	ATTACHMENT_VISUAL_SCRIPT.draw_on(canvas,state,equipment_visual,tint,visual_scale,actor_kind,body_origin,1)
	ATTACHMENT_VISUAL_SCRIPT.draw_fingers(canvas,state,equipment_visual,tint,visual_scale,actor_kind,atlas,body_origin)

func source_region(frame: int) -> Rect2:
	# Integer cell coordinates are explicit; no fractional atlas-row sampling.
	var cell_index := Vector2i(frame % 4, frame >> 2)
	return Rect2(Vector2(cell_index) * CELL, CELL)

func destination_rect(frame: int) -> Rect2:
	var ground_offset := _ground_offsets[frame] if frame >= 0 and frame < _ground_offsets.size() else 0.0
	return Rect2(-PIVOT + Vector2(0, ground_offset), CELL)

func death_copy() -> CharacterAnimation:
	var result := CharacterAnimation.new()
	result.actor_kind = actor_kind
	result._base_atlas = _base_atlas
	result._base_ground_offsets = _base_ground_offsets
	result.equipment_visual = equipment_visual.duplicate(true)
	result.state.face(state.facing)
	result.state.trigger(&"death")
	return result

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
	var directional := DirectionalAnimationSet.default_path(actor_kind)
	if FileAccess.file_exists(directional):
		var applied := set_directional_manifest(directional)
		if not applied.ok: push_warning("Directional animation rejected: "+str(applied.get("detail","")))

## Atomic producer API; no new actor fields or persisted graph kinds.
func set_directional_manifest(path: String) -> Dictionary:
	var loaded := DirectionalAnimationSet.load_manifest(path)
	if not loaded.ok: return loaded
	var bundle: DirectionalAnimationSet = loaded.bundle
	if bundle.actor_kind()!=actor_kind: return {"ok":false,"error_code":&"directional_kind_mismatch"}
	_base_atlas=bundle.body(false)
	_base_ground_offsets=bundle.ground_offsets()
	_select_atlas_for_visual()
	return {"ok":true}

## Per-instance catalog body for unequipped enemy kinds. Player/equipment
## contracts require their dedicated weaponless body and are explicitly refused.
## Only existing atlas fields change; the current animation state stays alive.
func set_body_atlas(texture: Texture2D) -> bool:
	if texture == null or actor_kind in WEAPONLESS_KINDS or not _equipment_visual.is_empty(): return false
	var path := texture.resource_path
	if not path.begins_with("res://") or path.contains("::") or not ResourceLoader.exists(path, "Texture2D"): return false
	if texture.get_size() != Vector2(256, 512): return false
	var bitmap := texture.get_image()
	if bitmap == null or bitmap.is_empty(): return false
	var offsets := _measure_ground_offsets(texture)
	_base_atlas = texture
	_base_ground_offsets = offsets
	atlas = texture
	_ground_offsets = offsets
	return true

func set_equipment_visual(value: Dictionary) -> void:
	_equipment_visual = value.duplicate(true)
	_select_atlas_for_visual()

func _select_atlas_for_visual() -> void:
	var has_player_contract := equipment_visual.has("main_hand") or equipment_visual.has("off_hand") or equipment_visual.has("arms") or equipment_visual.has("head")
	var bundle := DirectionalAnimationSet.for_texture(_base_atlas)
	if bundle!=null and bundle.actor_kind()==actor_kind:
		atlas=bundle.body(has_player_contract)
		_ground_offsets=bundle.ground_offsets()
		return
	# A missing/invalid V2 unit after cold restore falls back as a whole.
	if _base_atlas!=null and _base_atlas.get_size()==DirectionalAnimationSet.SIZE:
		_base_atlas=load("res://assets/art/animations/%s.png" % actor_kind) as Texture2D
		_base_ground_offsets=_measure_ground_offsets(_base_atlas)
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
func _active_bundle() -> DirectionalAnimationSet:
	var bundle := DirectionalAnimationSet.for_texture(atlas)
	if bundle!=null and bundle.actor_kind()!=actor_kind: bundle=null
	if bundle==null and atlas!=null and atlas.get_size()==DirectionalAnimationSet.SIZE:
		push_warning("Directional animation unit unavailable; restoring complete legacy presentation for "+String(actor_kind))
		_select_atlas_for_visual()
	return bundle

## One selector is shared by descriptors, draw caching and bare-body drawing.
func _frame_for_view(view: int) -> int:
	return state.frame_index() if view<0 else view*16+state.pose_index()

func draw_key() -> Array:
	var bundle := _active_bundle()
	var frame := _frame_for_view(state.direction_index() if bundle!=null else -1)
	return [frame,false if bundle!=null else state.flip_h,state.dead,state.hurt_remaining>0.0,
		state.action_remaining>0.0,state.action,
		state.action_duration>0.0 and 1.0-state.action_remaining/state.action_duration<0.75,
		atlas,_equipment_visual.duplicate()]

## Single frame/transform authority for body, hands, fingers, helmet and death.
## Callers get detached geometry; editing it cannot alter the immutable catalog.
func render_descriptor() -> Dictionary:
	var bundle := _active_bundle()
	var direction := state.direction_index() if bundle!=null else (1 if state.back_view else 0)
	var frame := _frame_for_view(direction if bundle!=null else -1)
	var destination := destination_rect(frame)
	var raw: Dictionary = bundle.frame(frame) if bundle!=null and not equipment_visual.is_empty() else {}
	var head := {}
	if equipment_visual.get("head",&"")==&"pilot_head":
		if bundle==null:
			head=EquipmentHeadVisual.legacy_pose(frame,state.back_view)
		else:
			head=raw.head.duplicate(true)
			head.point=Vector2(head.point[0],head.point[1])
			head.view=direction
	return {"version":2 if bundle!=null else 1,"frame":frame,"direction":direction,
		"atlas":atlas,"region":source_region(frame),"rect":destination,"origin":destination.position,
		"flip":false if bundle!=null else state.flip_h,"dead":state.dead,"head":head,
		"equipment":ATTACHMENT_VISUAL_SCRIPT.resolve_equipment(actor_kind,state,equipment_visual,destination.position,raw),
		"arrow_visible":not state.dead and state.action_remaining>0.0 and state.action!=&"dash" and state.action_duration>0.0 and 1.0-state.action_remaining/state.action_duration<0.75}

func draw_on(canvas: CanvasItem, tint: Color = Color.WHITE, visual_scale: float = 1.0) -> void:
	if atlas==null or canvas==null: return
	# Unadorned enemies have no attachment/head/finger commands. Do not allocate
	# a rig descriptor (or clone a V2 frame) merely to draw this one body quad.
	if equipment_visual.is_empty():
		var bundle := _active_bundle()
		var frame := _frame_for_view(state.direction_index() if bundle!=null else -1)
		canvas.draw_set_transform(Vector2.ZERO,0.0,Vector2(-visual_scale if bundle==null and state.flip_h else visual_scale,visual_scale))
		canvas.draw_texture_rect_region(atlas,destination_rect(frame),source_region(frame),tint)
		canvas.draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)
		return
	var descriptor := render_descriptor()
	ATTACHMENT_VISUAL_SCRIPT.draw_resolved(canvas,descriptor,tint,visual_scale,0)
	EquipmentHeadVisual.draw_resolved(canvas,descriptor,tint,visual_scale,0)
	canvas.draw_set_transform(Vector2.ZERO,0.0,Vector2(-visual_scale if descriptor.flip else visual_scale,visual_scale))
	canvas.draw_texture_rect_region(descriptor.atlas,descriptor.rect,descriptor.region,tint)
	canvas.draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)
	ATTACHMENT_VISUAL_SCRIPT.draw_resolved(canvas,descriptor,tint,visual_scale,1)
	ATTACHMENT_VISUAL_SCRIPT.draw_resolved_fingers(canvas,descriptor,tint,visual_scale)
	EquipmentHeadVisual.draw_resolved(canvas,descriptor,tint,visual_scale,1)

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
	# Preserve the exact selected orientation; normalizing an already unit
	# vector again can round its components during a death copy.
	result.state.facing = state.facing
	result.state.back_view = state.back_view
	result.state.flip_h = state.flip_h
	result.state.trigger(&"death")
	return result

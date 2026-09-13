class_name CharacterAnimation
extends RefCounted
## Shared atlas + per-actor visual state. All gameplay lives in the owner.

const CELL := Vector2(64, 64)
const PIVOT := Vector2(32, 58)
var state := CombatAnimationState.new()
var atlas: Texture2D
var actor_kind: StringName = &"swordsman"
var _last_position := Vector2.ZERO
var _observed_position := false

func configure(kind: StringName) -> void:
	actor_kind = kind
	if actor_kind not in [&"swordsman", &"mage", &"warrior", &"archer"]:
		actor_kind = &"swordsman"
	atlas = load("res://assets/art/animations/%s.png" % actor_kind) as Texture2D
	state = CombatAnimationState.new()
	_observed_position = false

func observe(position: Vector2, delta: float) -> void:
	var displacement := position - _last_position if _observed_position else Vector2.ZERO
	_last_position = position
	_observed_position = true
	state.advance(delta, displacement)

func play(action: StringName, direction: Vector2 = Vector2.ZERO, duration: float = 0.25) -> void:
	state.trigger(action, direction, duration)

func draw_on(canvas: CanvasItem, tint: Color = Color.WHITE) -> void:
	if atlas == null:
		return
	var frame := state.frame_index()
	var region := Rect2(Vector2(frame % 4, frame / 4) * CELL, CELL)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1.0 if state.flip_h else 1.0, 1.0))
	canvas.draw_texture_rect_region(atlas, Rect2(-PIVOT, CELL), region, tint)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func death_copy() -> CharacterAnimation:
	var result := CharacterAnimation.new()
	result.actor_kind = actor_kind
	result.atlas = atlas
	result.state.face(state.facing)
	result.state.trigger(&"death")
	return result

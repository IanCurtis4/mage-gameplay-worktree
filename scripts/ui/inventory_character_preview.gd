class_name InventoryCharacterPreview
extends Control
## Read-only portrait. The animation and attachment share the in-world renderer.

var _animation: CharacterAnimation
var _identity: StringName = &""
var _sprite: Node2D

func _ready() -> void:
	_sprite = Node2D.new()
	_sprite.draw.connect(_draw_actor)
	add_child(_sprite)
	resized.connect(_place_sprite)
	_place_sprite()

func _place_sprite() -> void:
	if _sprite != null:
		_sprite.position = Vector2(size.x * 0.5, size.y * 0.78)
		_sprite.queue_redraw()

func configure(identity_id: StringName, equipment_visual: Dictionary) -> void:
	if _animation == null or _identity != identity_id:
		_identity = identity_id
		_animation = CharacterAnimation.new()
		_animation.configure(identity_id)
	_animation.set("equipment_visual", equipment_visual.duplicate(true))
	queue_redraw()
	if _sprite != null: _sprite.queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("101b27"))

func _draw_actor() -> void:
	if _animation != null:
		_animation.draw_on(_sprite, Color.WHITE, 2.4)

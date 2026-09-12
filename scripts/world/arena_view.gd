class_name ArenaView
extends Node2D

var bounds := Rect2()
var obstacles: Array[Rect2] = []
var _ground: ColorRect

func configure(arena_bounds: Rect2, arena_obstacles: Array[Rect2]) -> void:
	bounds = arena_bounds
	obstacles = arena_obstacles.duplicate()
	if _ground == null:
		_ground = ColorRect.new()
		_ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ground_material := ShaderMaterial.new()
		ground_material.shader = preload("res://scripts/world/pilot_ground.gdshader")
		ground_material.set_shader_parameter("grass_texture", preload("res://assets/art/pilot/grass.png"))
		ground_material.set_shader_parameter("dirt_texture", preload("res://assets/art/pilot/dirt.png"))
		ground_material.set_shader_parameter("stone_texture", preload("res://assets/art/pilot/stone.png"))
		_ground.material = ground_material
		add_child(_ground)
	_ground.position = bounds.position
	_ground.size = bounds.size
	(_ground.material as ShaderMaterial).set_shader_parameter("ground_size", bounds.size)
	queue_redraw()

func _draw() -> void:
	draw_rect(bounds.grow(36.0), Color("233d36"), true)
	draw_rect(bounds.grow(4.0), Color("7b8c65"), false, 4.0)

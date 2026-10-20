class_name RewardPickup
extends Node2D

var ticket_id := ""
var _time := 0.0
var world_area: WorldEffectArea

func bind_world_area(world: WorldGeometry, anchor: ExpeditionWorldPoint, traversal: Dictionary, revision: int) -> Dictionary:
	if world_area != null: return {"ok":false,"error_code":&"already_bound"}
	var area := WorldEffectArea.new()
	var checked := area.configure(world,anchor,traversal,&"ground_connected",revision)
	if checked["ok"]: world_area = area
	return checked

func can_collect_world(actor: CombatActor, maximum_range: float) -> bool:
	if world_area == null or not is_instance_valid(actor) or not actor.is_alive() or (is_inside_tree() and get_tree().paused): return false
	var checked := world_area.query(actor,maximum_range)
	return checked["ok"] and checked["data"]["hit"]


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	var lift := sin(_time * 3.0) * 5.0
	var center := Vector2(0, -22 + lift)
	draw_circle(Vector2.ZERO, 30.0, Color(0.85, 0.69, 0.28, 0.13))
	draw_colored_polygon(PackedVector2Array([center + Vector2(0, -17), center + Vector2(13, 0), center + Vector2(0, 17), center + Vector2(-13, 0)]), Color("e9c67b"))
	draw_polyline(PackedVector2Array([center + Vector2(0, -17), center + Vector2(13, 0), center + Vector2(0, 17), center + Vector2(-13, 0), center + Vector2(0, -17)]), Color("fff2bd"), 3.0)

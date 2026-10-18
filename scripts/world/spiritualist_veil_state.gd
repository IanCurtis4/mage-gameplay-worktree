class_name SpiritualistVeilState
extends RefCounted
## One finite ground zone; membership and debuff ownership stay in the controller.

const RADIUS := 110.0

var active := false
var center := Vector2.INF
var remaining := 0.0
var world_area: WorldEffectArea

func start_world(world: WorldGeometry, anchor: ExpeditionWorldPoint, profile: Dictionary, duration: float, revision: int) -> Dictionary:
	if not is_finite(duration) or duration <= 0.0: return {"ok":false,"error_code":&"invalid_duration"}
	var area := WorldEffectArea.new()
	var result := area.configure(world,anchor,profile,&"ground_connected",revision)
	if not result["ok"]: return result
	start(Vector2.ZERO,duration)
	world_area = area
	return result

func contains_actor(actor: CombatActor) -> bool:
	if not active or not is_instance_valid(actor): return false
	if world_area != null:
		var result := world_area.query(actor,RADIUS)
		return result["ok"] and result["data"]["hit"]
	return actor.world_motion == null and contains(actor.global_position)


func start(point: Vector2, duration: float) -> void:
	clear()
	if not point.is_finite() or not is_finite(duration) or duration <= 0.0:
		return
	active = true
	center = point
	remaining = duration

func advance(delta: float) -> bool:
	if not active or delta <= 0.0:
		return false
	remaining = maxf(0.0, remaining - delta)
	if remaining <= 0.0:
		clear()
		return true
	return false

func contains(point: Vector2) -> bool:
	return active and point.is_finite() and center.distance_to(point) <= RADIUS

func clear() -> void:
	world_area = null
	active = false
	center = Vector2.INF
	remaining = 0.0

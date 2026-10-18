class_name SpiritualistProcessionState
extends RefCounted
## Finite three-apparition schedule. No combat actor or companion is spawned.

const COUNT := 3
const DEPARTURE_STEP := 0.20
const FLIGHT_TIME := 0.22

var active := false
var source := Vector2.ZERO
var target_id := 0
var elapsed := 0.0
var departures_issued := 0
var impacts_issued := 0
var captured_request: DamageRequest
var world_action: WorldLockedAction
var world_failure: StringName = &""

func start_world(caster: CombatActor, target: CombatActor, request: DamageRequest, maximum_range: float, revision: int) -> Dictionary:
	if request == null: return {"ok":false,"error_code":&"invalid_request"}
	var guard := WorldLockedAction.new()
	var result := guard.configure(caster,target,maximum_range,false,revision)
	if not result["ok"]: return result
	start(Vector2.ZERO,target,request)
	world_action = guard
	return result


func start(caster_origin: Vector2, target: CombatActor, request: DamageRequest) -> void:
	cancel()
	if target == null or request == null:
		return
	active = true
	source = caster_origin
	target_id = target.get_instance_id()
	captured_request = request.copy()

func advance(delta: float) -> Array[Dictionary]:
	var due: Array[Dictionary] = []
	if not active: return due
	if world_action != null:
		if world_action.paused(): return due
		var valid := world_action.validate()
		if not valid["ok"]:
			var reason: StringName = valid["error_code"]
			cancel()
			world_failure = reason
			return due
	if not active or delta < 0.0:
		return due
	elapsed += delta
	while true:
		var next_departure := float(departures_issued) * DEPARTURE_STEP if departures_issued < COUNT else INF
		var next_impact := float(impacts_issued) * DEPARTURE_STEP + FLIGHT_TIME if impacts_issued < COUNT else INF
		var next_time := minf(next_departure, next_impact)
		if next_time > elapsed + 0.0001:
			break
		if next_departure < next_impact:
			due.append({"kind": &"departure", "index": departures_issued})
			departures_issued += 1
		else:
			var request := captured_request.scheduled_tick()
			request.is_secondary = impacts_issued > 0
			due.append({"kind": &"impact", "index": impacts_issued, "request": request})
			impacts_issued += 1
	return due

func all_impacts_issued() -> bool:
	return impacts_issued == COUNT

func cancel() -> void:
	world_action = null
	world_failure = &""
	active = false
	source = Vector2.ZERO
	target_id = 0
	elapsed = 0.0
	departures_issued = 0
	impacts_issued = 0
	captured_request = null

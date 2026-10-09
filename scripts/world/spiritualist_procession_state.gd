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
	active = false
	source = Vector2.ZERO
	target_id = 0
	elapsed = 0.0
	departures_issued = 0
	impacts_issued = 0
	captured_request = null

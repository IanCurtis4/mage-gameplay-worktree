class_name SpiritualistDrainState
extends RefCounted
## One finite channel per player. The controller validates each due impact.

const TICK_INTERVAL := 0.5
const TICK_COUNT := 4

var active := false
var target_id := 0
var origin := Vector2.ZERO
var elapsed := 0.0
var ticks_issued := 0
var ticks_resolved := 0
var healed_total := 0.0
var captured_request: DamageRequest
var world_action: WorldLockedAction
var world_failure: StringName = &""

func start_world(caster: CombatActor, target: CombatActor, request: DamageRequest, maximum_range: float, revision: int) -> Dictionary:
	if request == null: return {"ok":false,"error_code":&"invalid_request"}
	var guard := WorldLockedAction.new()
	var result := guard.configure(caster,target,maximum_range,true,revision)
	if not result["ok"]: return result
	start(target,Vector2.ZERO,request)
	world_action = guard
	return result

var _inscription_claimed := false

func start(target: CombatActor, caster_origin: Vector2, request: DamageRequest) -> void:
	cancel()
	if target == null or request == null:
		return
	active = true
	target_id = target.get_instance_id()
	origin = caster_origin
	captured_request = request.copy()

func advance(delta: float) -> Array[DamageRequest]:
	var due: Array[DamageRequest] = []
	if not active: return due
	if world_action != null:
		if world_action.paused(): return due
		var valid := world_action.validate()
		if not valid["ok"]:
			var reason: StringName = valid["error_code"]
			cancel()
			world_failure = reason
			return due
	if not active or delta <= 0.0:
		return due
	elapsed = minf(float(TICK_COUNT) * TICK_INTERVAL, elapsed + delta)
	while ticks_issued < TICK_COUNT and elapsed + 0.0001 >= float(ticks_issued + 1) * TICK_INTERVAL:
		var request := captured_request.scheduled_tick()
		request.is_secondary = ticks_issued > 0
		due.append(request)
		ticks_issued += 1
	return due

func resolve_tick() -> bool:
	if not active or ticks_resolved >= ticks_issued:
		return false
	ticks_resolved += 1
	if ticks_resolved == TICK_COUNT:
		active = false
		return true
	return false

func claim_completion_inscription(request: DamageRequest) -> float:
	if _inscription_claimed or ticks_resolved != TICK_COUNT or request == null or captured_request == null or request.emission_id != captured_request.emission_id:
		return 0.0
	_inscription_claimed = true # Before damage callbacks can cancel/restart/reenter.
	if not bool(request.effect_snapshot.get("kit_policies", {}).get(&"drain_inscription", false)): return 0.0
	var power := float(request.effect_snapshot.get("drain_echo_power", 0.0))
	return power if is_finite(power) and power > 0.0 else 0.0

func cancel() -> void:
	world_action = null
	world_failure = &""
	active = false
	target_id = 0
	elapsed = 0.0
	ticks_issued = 0
	ticks_resolved = 0
	healed_total = 0.0
	captured_request = null
	_inscription_claimed = false

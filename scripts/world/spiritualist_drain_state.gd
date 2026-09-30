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
	if not active or delta <= 0.0:
		return due
	elapsed = minf(float(TICK_COUNT) * TICK_INTERVAL, elapsed + delta)
	while ticks_issued < TICK_COUNT and elapsed + 0.0001 >= float(ticks_issued + 1) * TICK_INTERVAL:
		var request := captured_request.copy()
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

func cancel() -> void:
	active = false
	target_id = 0
	elapsed = 0.0
	ticks_issued = 0
	ticks_resolved = 0
	healed_total = 0.0
	captured_request = null

class_name GeometerInteractionLedger
extends RefCounted
## Shared claims for one construction, retained across edits and wall -> triangle.
## Only effect consumers claim actual victims/projectiles; detection is not a proc.

enum Component { TRANSPORT, FIRE_EXIT, LIGHTNING_FOUNDATION, LIGHTNING_RULE }
const VICTIM_INTERVAL := 2.0
const INTERCEPTION_INTERVAL := 2.0
const TIME_EPSILON := 0.000001

var construction_id := 0
var elapsed := 0.0
var _victim_ready: Dictionary[int, float] = {}
var _projectile_components: Dictionary[int, int] = {}
var _interception_ready := 0.0

func sync(identity: int) -> void:
	if identity == construction_id:
		return
	construction_id = maxi(0, identity)
	elapsed = 0.0
	_victim_ready.clear()
	_projectile_components.clear()
	_interception_ready = 0.0

func advance(delta: float) -> void:
	if construction_id > 0 and is_finite(delta) and delta > 0.0:
		elapsed += delta

func claim_victim(actor_id: int) -> bool:
	if construction_id <= 0 or actor_id <= 0 or elapsed + TIME_EPSILON < _victim_ready.get(actor_id, 0.0):
		return false
	_victim_ready[actor_id] = elapsed + VICTIM_INTERVAL
	return true

func claim_owned_projectile(projectile_id: int, component: Component, request: DamageRequest, owner_id: int) -> bool:
	if construction_id <= 0 or projectile_id <= 0 or owner_id <= 0 or request == null or request.source_id != owner_id or request.is_secondary or GeometerCastCommand.is_trace_skill(request.skill_id) or component < Component.TRANSPORT or component > Component.LIGHTNING_RULE:
		return false
	var mask := 1 << int(component)
	var current: int = _projectile_components.get(projectile_id, 0)
	if current & mask:
		return false
	_projectile_components[projectile_id] = current | mask
	return true

func projectile_claimed(projectile_id: int, component: Component) -> bool:
	return (_projectile_components.get(projectile_id, 0) & (1 << int(component))) != 0

func claim_interception_refund(has_capacity: bool) -> bool:
	if construction_id <= 0 or not has_capacity or elapsed + TIME_EPSILON < _interception_ready:
		return false
	_interception_ready = elapsed + INTERCEPTION_INTERVAL
	return true

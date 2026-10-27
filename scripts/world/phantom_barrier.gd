class_name PhantomBarrier
extends Node2D
## Traversable strip: absorbs a finite number of enemy arrows and debuffs crossing enemies.

const HALF_LENGTH := 120.0
const HALF_WIDTH := 10.0
const DURATION := 5.0
const TARGET_INTERVAL := 0.75
const SLOW_FRACTION := 0.30
const SLOW_DURATION := 2.0
const WEAKEN_FRACTION := 0.20
const WEAKEN_DURATION := 2.5

var targets: Array[CombatActor] = []
var remaining := DURATION
var remaining_capacity := 0
var normal := Vector2.RIGHT
var axis := Vector2.DOWN
var _previous_positions: Dictionary[int, Vector2] = {}
var _inside: Dictionary[int, bool] = {}
var _cooldowns: Dictionary[int, float] = {}
var world_volume: WorldEffectVolume
var _world_previous: Dictionary[int, ExpeditionWorldPoint] = {}

func bind_world_volume(world: WorldGeometry, anchor: ExpeditionWorldPoint, profile: Dictionary, volume: AABB, revision: int) -> Dictionary:
	if world_volume != null: return {"ok":false,"error_code":&"already_bound"}
	var shape := WorldEffectVolume.new()
	var checked := shape.configure(world,anchor,profile,volume,revision)
	if not checked["ok"]: return checked
	world_volume = shape
	_inside.clear()
	for candidate: Variant in targets:
		if not is_instance_valid(candidate): continue
		var actor := candidate as CombatActor
		if actor.world_motion == null or actor.world_motion.geometry != world: continue
		_world_previous[actor.get_instance_id()] = actor.world_point()
		_inside[actor.get_instance_id()] = shape.actor_fraction(actor.world_point(),actor.world_point(),actor) >= 0.0
	return checked

func world_interception_fraction(from: Vector3, to: Vector3, collider: Dictionary, world: WorldGeometry) -> float:
	if not is_active() or world_volume == null or world_volume.geometry != world: return -1.0
	return world_volume.fraction(from,to,collider)

func _advance_world_crossings() -> void:
	for candidate: Variant in targets:
		if not is_instance_valid(candidate): continue
		var actor := candidate as CombatActor
		var id := actor.get_instance_id()
		if not actor.is_alive() or actor.world_motion == null or actor.world_motion.geometry != world_volume.geometry: _world_previous.erase(id); _inside.erase(id); continue
		var current := actor.world_point()
		var previous: ExpeditionWorldPoint = _world_previous.get(id,current)
		var inside := world_volume.actor_fraction(current,current,actor) >= 0.0
		if not _inside.get(id,inside) and previous.position.distance_squared_to(current.position) > WorldGeometry.EPS and world_volume.actor_fraction(previous,current,actor) >= 0.0 and float(_cooldowns.get(id,0.0)) <= 0.0:
			var source := StringName("phantom_barrier_%d" % get_instance_id())
			actor.apply_slow(SLOW_FRACTION,SLOW_DURATION,source)
			actor.apply_weaken(WEAKEN_FRACTION,WEAKEN_DURATION,source)
			_cooldowns[id] = TARGET_INTERVAL
		_inside[id] = inside
		_world_previous[id] = current


var _world_advancing := false
var world_field: WorldGroundField
func bind_world_field(field: WorldGroundField) -> Dictionary:
	if world_field != null: return WorldSkillCast.failure(&"already_bound")
	if field == null or not field.is_current(): return WorldSkillCast.failure(&"world_reconfigured")
	world_field = field
	world_field.track(self,targets)
	_inside.clear()
	for actor: CombatActor in world_field.actors(): _inside[actor.get_instance_id()] = world_field.contains(actor)
	world_volume = field.volume
	return {"ok":true,"error_code":&""}
func _on_world_field_motion(segments: Array[Dictionary], actor: WeakRef) -> void: world_field.queue_motion(segments,actor)
func _exit_tree() -> void:
	if world_field != null: world_field.close()

func configure(caster: CombatActor, facing: Vector2, potential_targets: Array[CombatActor], placement_range: float, capacity: int) -> void:
	assert(caster != null and is_finite(placement_range) and placement_range >= 0.0 and capacity > 0)
	targets = potential_targets.duplicate()
	normal = facing.normalized() if not facing.is_zero_approx() else Vector2.RIGHT
	axis = normal.orthogonal()
	global_position = caster.global_position + normal * placement_range
	rotation = normal.angle()
	remaining = DURATION
	remaining_capacity = capacity
	_previous_positions.clear()
	_inside.clear()
	_cooldowns.clear()
	for actor: CombatActor in targets:
		if actor != null and is_instance_valid(actor) and actor.is_alive():
			var actor_id := actor.get_instance_id()
			_previous_positions[actor_id] = actor.global_position
			_inside[actor_id] = _within_band(actor.global_position, actor.collision_radius)
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _ready() -> void:
	add_to_group("phantom_barriers")

func is_active() -> bool:
	return remaining > 0.0 and remaining_capacity > 0 and not is_queued_for_deletion()

func absorb_projectile() -> bool:
	if not is_active():
		return false
	remaining_capacity -= 1
	queue_redraw()
	if remaining_capacity <= 0:
		queue_free()
	return true

func interception_fraction(from: Vector2, to: Vector2, radius: float) -> float:
	if world_volume != null: return -1.0
	if not is_active():
		return -1.0
	return _entry_fraction(from, to, radius)

func _process(delta: float) -> void:
	if _world_advancing: return
	if is_queued_for_deletion() or not is_finite(delta) or delta < 0: return
	if is_inside_tree() and get_tree().paused:
		return
	if not is_active():
		return
	remaining = maxf(0.0, remaining - delta)
	if remaining <= 0.0:
		queue_free()
		return
	for actor_id: int in _cooldowns.keys():
		_cooldowns[actor_id] = maxf(0.0, _cooldowns[actor_id] - delta)
	if world_field != null:
		if not world_field.is_current(): queue_free(); return
		_world_advancing = true
		_advance_world_field()
		_world_advancing = false
		return
	if world_volume != null:
		_advance_world_crossings()
		return
	for actor: CombatActor in targets:
		if actor == null or not is_instance_valid(actor):
			continue
		var actor_id := actor.get_instance_id()
		if not actor.is_alive():
			_previous_positions.erase(actor_id)
			_inside.erase(actor_id)
			_cooldowns.erase(actor_id)
			continue
		var current := actor.global_position
		var previous: Vector2 = _previous_positions.get(actor_id, current)
		var inside_now := _within_band(current, actor.collision_radius)
		if not _inside.get(actor_id, inside_now) and current.distance_squared_to(previous) > 0.0001 and _entry_fraction(previous, current, actor.collision_radius) >= 0.0 and _cooldowns.get(actor_id, 0.0) <= 0.0:
			var source := StringName("phantom_barrier_%d" % get_instance_id())
			actor.apply_slow(SLOW_FRACTION, SLOW_DURATION, source)
			actor.apply_weaken(WEAKEN_FRACTION, WEAKEN_DURATION, source)
			_cooldowns[actor_id] = TARGET_INTERVAL
		_inside[actor_id] = inside_now
		_previous_positions[actor_id] = current
	queue_redraw()

func _advance_world_field() -> void:
	for candidate: Variant in world_field.actors():
		if not is_instance_valid(candidate) or candidate.is_queued_for_deletion(): continue
		var actor := candidate as CombatActor
		if is_queued_for_deletion(): return
		var id := actor.get_instance_id()
		for segment: Dictionary in world_field.take_motion(actor):
			var start_inside := world_field.contains_point(actor,segment["from"])
			if not start_inside and world_field.crossed(actor,segment) and float(_cooldowns.get(id,0.0)) <= 0:
				_cooldowns[id] = TARGET_INTERVAL # Claim before any callback/reentry.
				var source := StringName("phantom_barrier_%d" % get_instance_id())
				actor.apply_slow(SLOW_FRACTION,SLOW_DURATION,source)
				if is_instance_valid(actor): actor.apply_weaken(WEAKEN_FRACTION,WEAKEN_DURATION,source)
			if not is_instance_valid(actor) or not actor.is_alive() or is_queued_for_deletion(): break
		if is_instance_valid(actor) and actor.is_alive(): _inside[id] = world_field.contains(actor)

func _within_band(point: Vector2, radius: float) -> bool:
	var offset := point - global_position
	return absf(offset.dot(normal)) <= HALF_WIDTH + radius and absf(offset.dot(axis)) <= HALF_LENGTH + radius

func _entry_fraction(from: Vector2, to: Vector2, radius: float) -> float:
	var from_offset := from - global_position
	var to_offset := to - global_position
	var start := Vector2(from_offset.dot(normal), from_offset.dot(axis))
	var finish := Vector2(to_offset.dot(normal), to_offset.dot(axis))
	var entry := 0.0
	var exit := 1.0
	for coordinate: int in 2:
		var start_value := start.x if coordinate == 0 else start.y
		var change := (finish.x - start.x) if coordinate == 0 else (finish.y - start.y)
		var half_extent := (HALF_WIDTH if coordinate == 0 else HALF_LENGTH) + maxf(0.0, radius)
		if absf(change) <= 0.000001:
			if absf(start_value) > half_extent:
				return -1.0
			continue
		var first := (-half_extent - start_value) / change
		var second := (half_extent - start_value) / change
		entry = maxf(entry, minf(first, second))
		exit = minf(exit, maxf(first, second))
		if entry > exit:
			return -1.0
	return entry if entry <= 1.0 and exit >= 0.0 else -1.0

func _draw() -> void:
	if world_field != null: return # Shared WorldFieldView draws the committed world shape.
	var alpha := minf(1.0, remaining * 2.0)
	var charge_fraction := float(remaining_capacity) / 6.0
	draw_rect(Rect2(-HALF_WIDTH, -HALF_LENGTH, HALF_WIDTH * 2.0, HALF_LENGTH * 2.0), Color(0.59, 0.37, 0.85, 0.13 * alpha))
	draw_line(Vector2(0, -HALF_LENGTH), Vector2(0, HALF_LENGTH), Color(0.81, 0.65, 1.0, (0.45 + charge_fraction * 0.35) * alpha), 4.0, true)
	for index: int in 7:
		var y := -HALF_LENGTH + 20.0 + float(index) * 36.0
		draw_circle(Vector2(0, y), 4.0, Color(0.91, 0.81, 1.0, 0.65 * alpha))

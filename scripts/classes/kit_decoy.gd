class_name KitDecoy
extends CombatActor
## E10a C1.6 — decoy primitive: a temporary actor with HP and no AI that enemies may
## target (EnemyActor.set_target_override) and the player may not (it never joins
## RunController.enemies). It has an owner, a point, HP, a deadline and a drawer that
## the owning system registers. While one exists the compact cut is ineligible (the
## node joins `player_effects`). API: docs/epics/e10a/t1_base_seam_api.md.

signal decoy_removed(decoy: KitDecoy, reason: StringName)

const GROUP := &"kit_decoys"
const DEFAULT_RADIUS := 18.0

## Entity ID of the owning player (snapshot rebinds it).
var owner_id := 0
## Seconds left on the gameplay clock (pause-frozen).
var remaining := 0.0
## Drawer registered by the system (presentation only, never persisted as a Callable).
var drawer_id: StringName = &""
## System that created the decoy (free text ID, for queries such as one per owner).
var source_id_tag: StringName = &""
## Empty while alive; why the decoy left (&"expired", &"destroyed", &"removed").
var removal_reason: StringName = &""

## drawer_id -> Callable(canvas: CanvasItem, decoy: KitDecoy, t: float). Process-local;
## a missing drawer falls back to the default circle.
static var _drawers: Dictionary = {}

static func register_drawer(id: StringName, drawer: Callable) -> bool:
	if id.is_empty() or not drawer.is_valid(): return false
	_drawers[id] = drawer
	return true

static func unregister_drawer(id: StringName) -> void:
	_drawers.erase(id)

## Creates a decoy under `host` (the RunController) at `point`: a Vector2 on the flat
## arena, or an ExpeditionWorldPoint in the expedition world (the owner must be bound).
## Returns {"ok", "error_code", "decoy"}. Errors: invalid_owner, invalid_payload,
## spatial_binding_required, and the world position errors of WorldActorMotion.
static func spawn(host: Node, owner: PlayerActor, point: Variant, hp: float, duration: float, drawer: StringName, source_tag: StringName = &"") -> Dictionary:
	if host == null or not is_instance_valid(owner) or not owner.is_alive(): return {"ok": false, "error_code": &"invalid_owner", "decoy": null}
	if not is_finite(hp) or hp <= 0.0 or not is_finite(duration) or duration <= 0.0: return {"ok": false, "error_code": &"invalid_payload", "decoy": null}
	var decoy := KitDecoy.new()
	decoy.name = "KitDecoy"
	decoy.owner_id = owner.get_instance_id()
	decoy.remaining = duration
	decoy.drawer_id = drawer
	decoy.source_id_tag = source_tag
	var stats := StatCalculator.calculate({&"str": 1, &"agi": 1, &"vit": 1, &"int": 1, &"dex": 1, &"luk": 1})
	decoy.setup("Isca", Color("c7b8ff"), stats, DEFAULT_RADIUS)
	decoy.health.max_hp = hp
	decoy.health.current_hp = hp
	decoy.process_mode = Node.PROCESS_MODE_PAUSABLE
	if point is ExpeditionWorldPoint:
		if owner.world_motion == null or not owner.world_motion.is_current_world():
			decoy.free()
			return {"ok": false, "error_code": &"spatial_binding_required", "decoy": null}
		var bound := decoy.bind_world_geometry(owner.world_motion.geometry, point, owner.world_motion.profile(), "decoy_%d" % decoy.get_instance_id())
		if not bound["ok"]:
			decoy.free()
			return {"ok": false, "error_code": bound.get("error_code", &"invalid_position"), "decoy": null}
	elif point is Vector2:
		decoy.global_position = point
	else:
		decoy.free()
		return {"ok": false, "error_code": &"invalid_payload", "decoy": null}
	decoy.actor_died.connect(decoy._on_decoy_died)
	decoy.add_to_group(GROUP)
	decoy.add_to_group("player_effects")
	host.add_child(decoy)
	return {"ok": true, "error_code": &"", "decoy": decoy}

## Live decoys under `host`, optionally of one owner and source tag, by instance ID.
static func decoys_of(host: Node, owner_id_filter: int = 0, source_tag: StringName = &"") -> Array[KitDecoy]:
	var result: Array[KitDecoy] = []
	if host == null: return result
	for node: Node in host.get_children():
		var decoy := node as KitDecoy
		if decoy == null or not decoy.is_active(): continue
		if owner_id_filter != 0 and decoy.owner_id != owner_id_filter: continue
		if not source_tag.is_empty() and decoy.source_id_tag != source_tag: continue
		result.append(decoy)
	result.sort_custom(func(a: KitDecoy, b: KitDecoy) -> bool: return a.get_instance_id() < b.get_instance_id())
	return result

func is_active() -> bool:
	return removal_reason.is_empty() and is_alive() and not is_queued_for_deletion()

## Removes the decoy now (idempotent).
func remove(reason: StringName = &"removed") -> void:
	if not removal_reason.is_empty(): return
	removal_reason = reason
	remove_from_group(GROUP)
	decoy_removed.emit(self, reason)
	queue_free()

func _process(delta: float) -> void:
	if is_inside_tree() and get_tree().paused: return
	super._process(delta)
	if not is_active() or not is_finite(delta) or delta <= 0.0: return
	remaining = maxf(0.0, remaining - delta)
	queue_redraw()
	if remaining <= 0.0: remove(&"expired")

func _on_decoy_died(_actor: CombatActor) -> void:
	remove(&"destroyed")

func _draw() -> void:
	var drawer: Callable = _drawers.get(drawer_id, Callable())
	if drawer.is_valid():
		drawer.call(self, self, remaining)
		return
	draw_circle(Vector2(0, -18), collision_radius, Color(0.78, 0.72, 1.0, 0.55))
	draw_arc(Vector2(0, -18), collision_radius + 4.0, 0.0, TAU, 24, Color(0.95, 0.9, 1.0, 0.9), 2.0, true)

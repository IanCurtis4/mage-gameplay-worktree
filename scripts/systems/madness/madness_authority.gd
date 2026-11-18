class_name MadnessAuthority
extends RefCounted
## E10a T4 (C2) — family authority of Loucura, Delírio, Desorientação, Êxtase, Ídolo and
## contágio (Cultista family: base Acólito, Cultista, later Flagelante, Oráculo,
## Observador, Arauto da Peste, Aberração, Lunático and Abissal). Numbers and rules:
## docs/epics/e10a/t4_contract.md; API for T5/T7: docs/epics/e10a/t4_madness_api.md.
##
## One authority per player, kept by the module that creates it in a field named
## `madness` (the Acólito base module for its family); other modules find it with
## of(player). Per-enemy state lives in the enemy's ActorMarks (owner = the player's
## instance ID) and follows the enemy restoration (A4). The authority keeps only player
## state and IDs: no Node, Callable or actor reference.
##
## A7: this script never names its own class_name (it recognises itself by path).

const SCRIPT_PATH := "res://scripts/systems/madness/madness_authority.gd"

var owner_id := 0
## Kit-prefixed ID of the Ecstasy stat source (e.g. cultist_ecstasy).
var stat_source_id: StringName = &"madness_ecstasy"
var delirium_duration := MadnessRules.DELIRIUM_DURATION
var ecstasy := MadnessEcstasy.new()
## MATK fraction currently published to the owner's breakdown (0 when none).
var ecstasy_published := 0.0
## Serial of state entries (Delirium, Disorientation) and of threshold arrivals.
var entry_serial := 0
var arrival_serial := 0
## Idol of this owner: options of the live decoy, its serial and pulse clock.
var idol_serial := 0
var idol_ticks := 0
var idol_tick_remaining := 0.0
var idol_tick := MadnessRules.IDOL_TICK
var idol_radius := MadnessRules.IDOL_RADIUS
var idol_madness := MadnessRules.IDOL_MADNESS
## kit_time of the last tick: two modules may forward on_tick, one tick counts.
var last_tick_stamp := -1.0
var gained_total := 0.0
## Accepted event keys (bounded, oldest first). Madness and Ecstasy share the ring.
var _claimed: Dictionary = {}
var _claim_order: Array[String] = []

## The authority of `player`: the `madness` field of its first attached module that
## holds one (origin first). Null when none. Cast it with `as` at the call site.
static func of(player: PlayerActor) -> RefCounted:
	if not is_instance_valid(player): return null
	for module: ClassKit in player.kit_modules():
		var held: Variant = module.get(&"madness")
		if held is RefCounted and (held as RefCounted).get_script() != null and ((held as RefCounted).get_script() as Script).resource_path == SCRIPT_PATH: return held
	return null

## Called once from the owning module's on_attach. Options: stat_source_id
## (StringName), delirium_duration (2..8 s), ecstasy (per-charge values),
## ecstasy_enabled (bool).
func configure(player: PlayerActor, options: Dictionary = {}) -> Dictionary:
	owner_id = player.get_instance_id() if is_instance_valid(player) else 0
	for key: Variant in options:
		if String(key) not in ["stat_source_id", "delirium_duration", "ecstasy", "ecstasy_enabled"]: return MadnessRules.failure(&"invalid_options", String(key))
	if options.has("stat_source_id"):
		var source := StringName(options["stat_source_id"])
		if source.is_empty(): return MadnessRules.failure(&"invalid_options", "stat_source_id")
		stat_source_id = source
	if options.has("delirium_duration"):
		var seconds := float(options["delirium_duration"])
		if not MadnessRules.delirium_duration_valid(seconds): return MadnessRules.failure(&"invalid_options", "delirium_duration")
		delirium_duration = seconds
	if options.has("ecstasy"):
		var checked := ecstasy.configure(options["ecstasy"])
		if not checked["ok"]: return checked
	if options.has("ecstasy_enabled"): ecstasy.enabled = bool(options["ecstasy_enabled"])
	KitDecoy.register_drawer(MadnessRules.IDOL_DRAWER, MadnessHelpers.draw_idol)
	return {"ok": true, "error_code": &"", "detail": ""}

## The Ecstasy passive (T7) turns the charges on. Off: no gain and identity helpers.
func set_ecstasy_enabled(player: PlayerActor, value: bool) -> void:
	ecstasy.enabled = value
	sync_stats(player)

# --- Madness -------------------------------------------------------------------------

## Adds Madness to `enemy` once per event (EffectProcLedger identity or explicit key,
## joined with the enemy's stable key). At the threshold the enemy enters Delirium
## (non-boss) or Disorientation (boss) and the Madness returns to 0. A direct gain on a
## contagion-marked enemy is copied once to its neighbours; `copy` gains never spread.
## Returns {"ok", "error_code", "added", "entered"} (entered: &"", &"delirium",
## &"disoriented" or &"pending").
func add(enemy: CombatActor, amount: float, event: Variant, owner: PlayerActor, copy: bool = false, actors: Array = []) -> Dictionary:
	if not is_instance_valid(owner) or not owner.is_alive(): return _refused(&"invalid_owner")
	_bind_owner(owner)
	if not MadnessHelpers.is_enemy(enemy) or not MadnessHelpers.is_live(enemy): return _refused(&"invalid_target")
	if not is_finite(amount) or amount <= 0.0 or amount > MadnessRules.THRESHOLD: return _refused(&"invalid_amount")
	var identity := MadnessHelpers.event_identity(event)
	if identity.is_empty(): return _refused(&"missing_event")
	var key := "madness@%s:%s" % [identity, MadnessHelpers.enemy_key(enemy)]
	if _claimed.has(key): return _refused(&"duplicate_event")
	_remember(key)
	if enemy.marks.has_mark(MadnessRules.MARK_DELIRIUM) or enemy.marks.has_mark(MadnessRules.MARK_DISORIENTED): return _refused(&"already_maddened")
	if enemy.marks.has_mark(MadnessRules.MARK_IMMUNE): return _refused(&"immune")
	var current := madness_of(enemy)
	var updated := minf(MadnessRules.THRESHOLD, current + amount)
	var added := updated - current
	gained_total += added
	enemy.marks.set_mark(MadnessRules.MARK_MADNESS, owner_id, updated)
	enemy.marks.set_mark(MadnessRules.MARK_HOLD, owner_id, int(enemy.marks.value(MadnessRules.MARK_HOLD, 0)), MadnessRules.HOLD_SECONDS)
	var enemies := MadnessHelpers.enemies_of(owner, actors)
	var entered: StringName = &""
	if updated >= MadnessRules.THRESHOLD - 0.0001: entered = _reach_threshold(enemy, owner, enemies)
	var contagion: Variant = enemy.marks.value(MadnessRules.MARK_CONTAGION) if enemy.marks.owner_of(MadnessRules.MARK_CONTAGION) == owner_id else null
	if not copy and contagion is Dictionary:
		var spread: Dictionary = contagion
		# The copy is a fraction of what the marked enemy actually received (after the threshold clamp).
		for neighbour: CombatActor in MadnessHelpers.neighbours(enemy, enemies, float(spread.get("radius", MadnessRules.CONTAGION_RADIUS))):
			var share := minf(MadnessRules.THRESHOLD, added * float(spread.get("fraction", MadnessRules.CONTAGION_FRACTION)))
			if share > 0.0: add(neighbour, share, identity + ":copy", owner, true, enemies)
		var pulse := float(spread.get("pulse", MadnessRules.CONTAGION_PULSE))
		if entered == MadnessRules.STATE_DELIRIUM and pulse > 0.0:
			for neighbour: CombatActor in MadnessHelpers.neighbours(enemy, enemies, float(spread.get("radius", MadnessRules.CONTAGION_RADIUS))):
				add(neighbour, pulse, identity + ":pulse", owner, true, enemies)
	return {"ok": true, "error_code": &"", "added": added, "entered": entered}

## Madness accumulated on `enemy` (0 when none).
static func madness_of(enemy: CombatActor) -> float:
	return float(enemy.marks.value(MadnessRules.MARK_MADNESS, 0.0)) if is_instance_valid(enemy) else 0.0

## True while the enemy is in Delirium or Disorientation (optionally of one owner).
static func is_maddened(enemy: CombatActor, owner_filter: int = 0) -> bool:
	if not is_instance_valid(enemy): return false
	for key: StringName in [MadnessRules.MARK_DELIRIUM, MadnessRules.MARK_DISORIENTED]:
		if enemy.marks.has_mark(key) and (owner_filter == 0 or enemy.marks.owner_of(key) == owner_filter): return true
	return false

static func state_of(enemy: CombatActor) -> StringName:
	if not is_instance_valid(enemy): return MadnessRules.STATE_NONE
	if enemy.marks.has_mark(MadnessRules.MARK_DELIRIUM): return MadnessRules.STATE_DELIRIUM
	if enemy.marks.has_mark(MadnessRules.MARK_DISORIENTED): return MadnessRules.STATE_DISORIENTED
	if enemy.marks.has_mark(MadnessRules.MARK_IMMUNE): return MadnessRules.STATE_IMMUNE
	if madness_of(enemy) >= MadnessRules.THRESHOLD - 0.0001: return MadnessRules.STATE_PENDING
	return MadnessRules.STATE_NONE

func _reach_threshold(enemy: CombatActor, owner: PlayerActor, enemies: Array) -> StringName:
	if MadnessHelpers.is_boss(enemy):
		_enter_disorientation(enemy as EnemyActor, owner, MadnessRules.DISORIENT_DEFAULTS)
		return MadnessRules.STATE_DISORIENTED
	if delirium_count(owner, enemies) >= MadnessRules.DELIRIUM_CAP:
		_mark_pending(enemy)
		return MadnessRules.STATE_PENDING
	_enter_delirium(enemy as EnemyActor, owner, enemies)
	return MadnessRules.STATE_DELIRIUM

## Waiting for a Delirium slot: the Madness stays at the threshold (the hold mark keeps
## the arrival order in its value and is renewed every tick).
func _mark_pending(enemy: CombatActor) -> void:
	var arrival := int(enemy.marks.value(MadnessRules.MARK_HOLD, 0))
	if arrival <= 0:
		arrival_serial += 1
		arrival = arrival_serial
	enemy.marks.set_mark(MadnessRules.MARK_MADNESS, owner_id, MadnessRules.THRESHOLD)
	enemy.marks.set_mark(MadnessRules.MARK_HOLD, owner_id, arrival, MadnessRules.HOLD_SECONDS)

# --- Delirium ------------------------------------------------------------------------

## Delirious enemies of `owner` (cap 3, D4).
func delirium_count(owner: PlayerActor, actors: Array = []) -> int:
	var count := 0
	for candidate: Variant in MadnessHelpers.enemies_of(owner, actors):
		var enemy := candidate as CombatActor
		if MadnessHelpers.is_live(enemy) and enemy.marks.has_mark(MadnessRules.MARK_DELIRIUM) and enemy.marks.owner_of(MadnessRules.MARK_DELIRIUM) == owner_id: count += 1
	return count

func _enter_delirium(enemy: EnemyActor, owner: PlayerActor, enemies: Array) -> void:
	enemy.marks.remove(MadnessRules.MARK_MADNESS)
	enemy.marks.remove(MadnessRules.MARK_HOLD)
	enemy.marks.set_mark(MadnessRules.MARK_DELIRIUM, owner_id, 1, delirium_duration)
	_gain_ecstasy(owner, enemy)
	_retarget_delirious(enemy, enemies)

## Points a delirious enemy at the nearest live non-boss enemy, for what is left of
## the Delirium. Without a target it holds still and never attacks the player (combat
## hold, decision A8); it looks again every tick. A refused hold ends the Delirium.
func _retarget_delirious(enemy: EnemyActor, enemies: Array) -> void:
	var left := enemy.marks.remaining(MadnessRules.MARK_DELIRIUM)
	if left <= 0.0: return
	var target := MadnessHelpers.nearest_non_boss(enemy, enemies)
	if target != null and enemy.set_target_override(target, owner_id, left, MadnessRules.DELIRIUM_REASON)["ok"]:
		if _held_by_delirium(enemy): enemy.clear_combat_hold()
		return
	if enemy.target_override_reason() == MadnessRules.DELIRIUM_REASON: enemy.clear_target_override()
	if enemy.set_combat_hold(owner_id, left, MadnessRules.DELIRIUM_REASON)["ok"]: return
	_end_delirium(enemy)

func _held_by_delirium(enemy: EnemyActor) -> bool:
	return enemy.has_combat_hold() and StringName(enemy.marks.value(EnemyActor.COMBAT_HOLD_MARK, &"")) == MadnessRules.DELIRIUM_REASON and enemy.marks.owner_of(EnemyActor.COMBAT_HOLD_MARK) == owner_id

func _end_delirium(enemy: EnemyActor) -> void:
	enemy.marks.remove(MadnessRules.MARK_DELIRIUM)
	if enemy.target_override_reason() == MadnessRules.DELIRIUM_REASON: enemy.clear_target_override()
	if _held_by_delirium(enemy): enemy.clear_combat_hold()

# --- Boss Disorientation ---------------------------------------------------------------

## Disorientation of a boss by a kit (Revelation, T7): once per event; refused under
## immunity unless options.bypass_immunity. Options: MadnessRules.DISORIENT_DEFAULTS.
func disorient(boss: CombatActor, event: Variant, owner: PlayerActor, options: Dictionary = {}) -> Dictionary:
	if not is_instance_valid(owner) or not owner.is_alive(): return _refused(&"invalid_owner")
	_bind_owner(owner)
	if not MadnessHelpers.is_enemy(boss) or not MadnessHelpers.is_live(boss) or not MadnessHelpers.is_boss(boss): return _refused(&"invalid_target")
	var checked := MadnessRules.validate("disorient", options)
	if not checked["ok"]: return checked
	var identity := MadnessHelpers.event_identity(event)
	if identity.is_empty(): return _refused(&"missing_event")
	var key := "disorient@%s:%s" % [identity, MadnessHelpers.enemy_key(boss)]
	if _claimed.has(key): return _refused(&"duplicate_event")
	_remember(key)
	var settings: Dictionary = checked["options"]
	if not bool(settings["bypass_immunity"]):
		if boss.marks.has_mark(MadnessRules.MARK_DISORIENTED): return _refused(&"already_maddened")
		if boss.marks.has_mark(MadnessRules.MARK_IMMUNE): return _refused(&"immune")
	_enter_disorientation(boss as EnemyActor, owner, settings)
	return {"ok": true, "error_code": &"", "added": 0.0, "entered": MadnessRules.STATE_DISORIENTED}

func _enter_disorientation(boss: EnemyActor, owner: PlayerActor, settings: Dictionary) -> void:
	var duration := float(settings["duration"])
	boss.marks.remove(MadnessRules.MARK_MADNESS)
	boss.marks.remove(MadnessRules.MARK_HOLD)
	boss.marks.set_mark(MadnessRules.MARK_DISORIENTED, owner_id, 1, duration)
	boss.marks.set_mark(MadnessRules.MARK_IMMUNE, owner_id, 1, duration + float(settings["immunity"]))
	if float(settings["damage_taken"]) > 1.0: boss.add_received_damage_source(MadnessRules.DISORIENT_SOURCE, float(settings["damage_taken"]), duration)
	if float(settings["accuracy"]) > 0.0: boss.add_accuracy_source(MadnessRules.DISORIENT_SOURCE, float(settings["accuracy"]), duration)
	if float(settings["minion_chance"]) > 0.0: boss.register_commit_deflection(MadnessRules.DISORIENT_SOURCE, owner_id, float(settings["minion_chance"]), float(settings["minion_radius"]), duration)
	_gain_ecstasy(owner, boss)

# --- Ecstasy -------------------------------------------------------------------------

func _gain_ecstasy(owner: PlayerActor, enemy: CombatActor) -> void:
	entry_serial += 1
	var key := "ecstasy@enter:%s:%d" % [MadnessHelpers.enemy_key(enemy), entry_serial]
	if _claimed.has(key): return
	_remember(key)
	if ecstasy.gain() > 0: sync_stats(owner)

## Forward of ClassKit.temporary_stat_sources (only from the module that enables the
## Ecstasy): pure read of the published MATK bonus.
func temporary_stat_sources(_player: PlayerActor = null) -> Array[Dictionary]:
	var sources: Array[Dictionary] = []
	if ecstasy_published > 0.0: sources.append({"source_id": stat_source_id, "label": "Êxtase", "increased": {&"magic_attack": ecstasy_published}})
	return sources

## Forward of ClassKit.skill_cost: base * (1 - cost_per_charge * charges). Pure.
func skill_cost(base_cost: float) -> float:
	return ecstasy.skill_cost(base_cost)

## Forward of ClassKit.before_hit_mitigation: the onus from 3 charges as a T1.1
## damage_multiplier. Never cancels; secondary hits are not scaled.
func before_hit(_player: PlayerActor, hit: Dictionary) -> Dictionary:
	var request := hit.get("request") as DamageRequest
	if request == null or request.is_secondary: return {}
	var multiplier := ecstasy.damage_taken_multiplier()
	return {"damage_multiplier": multiplier} if multiplier > 1.0 else {}

## Publishes the MATK bonus when it changes (refresh_kit_stats: no heal, no reset).
func sync_stats(player: PlayerActor) -> void:
	var wanted := ecstasy.matk_bonus() if is_instance_valid(player) and player.is_alive() else 0.0
	if is_equal_approx(wanted, ecstasy_published): return
	ecstasy_published = wanted
	if is_instance_valid(player): player.refresh_kit_stats()

# --- Idol ----------------------------------------------------------------------------

## Places the Idol (a KitDecoy of the T1): one per owner, the previous one is removed.
## Options: MadnessRules.IDOL_DEFAULTS. `point` is a Vector2 (flat) or an
## ExpeditionWorldPoint (world). `host` defaults to the owner's parent (RunController).
func place_idol(player: PlayerActor, point: Variant, options: Dictionary = {}, host: Node = null) -> Dictionary:
	if not is_instance_valid(player) or not player.is_alive(): return MadnessRules.failure(&"invalid_owner")
	_bind_owner(player)
	var checked := MadnessRules.validate("idol", options)
	if not checked["ok"]: return checked
	var settings: Dictionary = checked["options"]
	var parent := host if host != null else player.get_parent()
	if parent == null: return MadnessRules.failure(&"invalid_host")
	for previous: CombatActor in idols(player): previous.call(&"remove", &"replaced")
	KitDecoy.register_drawer(MadnessRules.IDOL_DRAWER, MadnessHelpers.draw_idol)
	var spawned := KitDecoy.spawn(parent, player, point, player.health.max_hp * float(settings["hp_fraction"]), float(settings["duration"]), MadnessRules.IDOL_DRAWER, MadnessRules.IDOL_TAG)
	if not spawned["ok"]: return spawned
	(spawned["decoy"] as CombatActor).actor_name = "Ídolo Impossível"
	idol_serial += 1
	idol_ticks = 0
	idol_tick = float(settings["tick"])
	idol_tick_remaining = idol_tick
	idol_radius = float(settings["radius"])
	idol_madness = float(settings["madness"])
	_idol_gaze(player, spawned["decoy"], MadnessHelpers.enemies_of(player), false)
	return spawned

## Live Idols of this owner (0 or 1), under the owner's parent or the owner itself.
func idols(player: PlayerActor) -> Array[CombatActor]:
	var result: Array[CombatActor] = []
	if not is_instance_valid(player) or owner_id == 0: return result
	for host: Node in [player.get_parent(), player]:
		if host == null: continue
		for decoy: CombatActor in KitDecoy.decoys_of(host, owner_id, MadnessRules.IDOL_TAG):
			if decoy not in result: result.append(decoy)
	return result

func idol(player: PlayerActor) -> CombatActor:
	var found := idols(player)
	return found[0] if not found.is_empty() else null

func remove_idol(player: PlayerActor, reason: StringName = &"removed") -> bool:
	var found := idols(player)
	for decoy: CombatActor in found: decoy.call(&"remove", reason)
	return not found.is_empty()

## One gaze of the Idol: non-boss enemies in reach without Delirium or another
## override target it; with `with_madness`, every enemy in reach (boss included) gains
## the tick Madness once per tick event.
func _idol_gaze(player: PlayerActor, decoy: CombatActor, enemies: Array, with_madness: bool) -> void:
	var left := float(decoy.get(&"remaining"))
	var key := "idol:%d:%d" % [idol_serial, idol_ticks]
	var listed := enemies.duplicate()
	listed.sort_custom(func(a: Variant, b: Variant) -> bool: return MadnessHelpers.enemy_key(a as CombatActor) < MadnessHelpers.enemy_key(b as CombatActor))
	for candidate: Variant in listed:
		var enemy := candidate as CombatActor
		if not MadnessHelpers.is_enemy(enemy) or not MadnessHelpers.is_live(enemy) or MadnessHelpers.distance(decoy, enemy) > idol_radius: continue
		var hostile := enemy as EnemyActor
		if not MadnessHelpers.is_boss(enemy) and not enemy.marks.has_mark(MadnessRules.MARK_DELIRIUM) and left > 0.0:
			var reason := hostile.target_override_reason()
			if reason.is_empty() or (reason == MadnessRules.IDOL_REASON and hostile.combat_target() != decoy): hostile.set_target_override(decoy, owner_id, left, MadnessRules.IDOL_REASON)
		if with_madness and MadnessHelpers.is_live(enemy): add(enemy, idol_madness, key, player, false, enemies)

# --- Contagion -----------------------------------------------------------------------

## Marks `enemy` for contagion (Delírio Compartilhado): its direct Madness gains are
## copied once to its neighbours, and its Delirium pulses them once. Options:
## MadnessRules.CONTAGION_DEFAULTS.
func mark_contagion(player: PlayerActor, enemy: CombatActor, options: Dictionary = {}) -> Dictionary:
	if not is_instance_valid(player) or not player.is_alive(): return MadnessRules.failure(&"invalid_owner")
	_bind_owner(player)
	if not MadnessHelpers.is_enemy(enemy) or not MadnessHelpers.is_live(enemy): return MadnessRules.failure(&"invalid_target")
	var checked := MadnessRules.validate("contagion", options)
	if not checked["ok"]: return checked
	var settings: Dictionary = checked["options"]
	if not enemy.marks.set_mark(MadnessRules.MARK_CONTAGION, owner_id, {"fraction": settings["fraction"], "radius": settings["radius"], "pulse": settings["pulse"]}, float(settings["duration"])): return MadnessRules.failure(&"mark_refused")
	return {"ok": true, "error_code": &"", "detail": ""}

# --- Gameplay clock (forward of ClassKit.on_tick: never in pause, never dead) --------------

func tick(player: PlayerActor, delta: float, actors: Array = []) -> void:
	if not is_instance_valid(player) or not player.is_alive() or delta <= 0.0 or not is_finite(delta): return
	if is_equal_approx(player.kit_time, last_tick_stamp): return
	last_tick_stamp = player.kit_time
	_bind_owner(player)
	var enemies := MadnessHelpers.enemies_of(player, actors)
	var listed := enemies.duplicate()
	listed.sort_custom(func(a: Variant, b: Variant) -> bool: return MadnessHelpers.enemy_key(a as CombatActor) < MadnessHelpers.enemy_key(b as CombatActor))
	var pending: Array[CombatActor] = []
	for candidate: Variant in listed:
		var enemy := candidate as CombatActor
		if not MadnessHelpers.is_enemy(enemy) or not MadnessHelpers.is_live(enemy): continue
		var hostile := enemy as EnemyActor
		var marks := enemy.marks
		if marks.has_mark(MadnessRules.MARK_DELIRIUM) and marks.owner_of(MadnessRules.MARK_DELIRIUM) == owner_id:
			if hostile.target_override_reason() != MadnessRules.DELIRIUM_REASON: _retarget_delirious(hostile, enemies)
			continue
		if hostile.target_override_reason() == MadnessRules.DELIRIUM_REASON and hostile.target_override_owner_id() == owner_id: hostile.clear_target_override()
		if _held_by_delirium(hostile): hostile.clear_combat_hold()
		if marks.has_mark(MadnessRules.MARK_MADNESS) and marks.owner_of(MadnessRules.MARK_MADNESS) == owner_id:
			if madness_of(enemy) >= MadnessRules.THRESHOLD - 0.0001 and not MadnessHelpers.is_boss(enemy):
				_mark_pending(enemy)
				pending.append(enemy)
			elif not marks.has_mark(MadnessRules.MARK_HOLD):
				var left := madness_of(enemy) - MadnessRules.DECAY_PER_SECOND * delta
				if left <= 0.0: marks.remove(MadnessRules.MARK_MADNESS)
				else: marks.update_value(MadnessRules.MARK_MADNESS, left)
	pending.sort_custom(func(a: CombatActor, b: CombatActor) -> bool:
		var order_a := int(a.marks.value(MadnessRules.MARK_HOLD, 0))
		var order_b := int(b.marks.value(MadnessRules.MARK_HOLD, 0))
		return order_a < order_b if order_a != order_b else MadnessHelpers.enemy_key(a) < MadnessHelpers.enemy_key(b))
	var count := delirium_count(player, enemies)
	for enemy: CombatActor in pending:
		if count >= MadnessRules.DELIRIUM_CAP: break
		_enter_delirium(enemy as EnemyActor, player, enemies)
		count = delirium_count(player, enemies)
	var current := idol(player)
	if current != null:
		idol_tick_remaining -= delta
		while idol_tick_remaining <= 0.0 and is_instance_valid(current) and current.call(&"is_active"):
			idol_ticks += 1
			_idol_gaze(player, current, enemies, true)
			idol_tick_remaining += idol_tick
	if ecstasy.tick(delta): sync_stats(player)

# --- Lifecycle and snapshot ------------------------------------------------------------

## Forward of ClassKit.on_death: the Idol leaves and the Ecstasy empties.
func on_death(player: PlayerActor) -> void:
	remove_idol(player, &"owner_died")
	ecstasy.reset()
	if ecstasy_published > 0.0:
		ecstasy_published = 0.0
		if is_instance_valid(player): player.refresh_kit_stats()

## Forward of ClassKit.on_build_changed: no recharge, no reset.
func on_build_changed(player: PlayerActor) -> void:
	sync_stats(player)

## Forward of ClassKit.snapshot_compact_blocker (A4: an active Idol forces the exact format).
func compact_blocker(player: PlayerActor) -> String:
	return "madness_idol" if idol(player) != null else ""

# --- HUD reading (pure) --------------------------------------------------------------

static func describe_enemy(enemy: CombatActor) -> Dictionary:
	if not is_instance_valid(enemy): return {}
	var state := state_of(enemy)
	var remaining := 0.0
	if state == MadnessRules.STATE_DELIRIUM: remaining = enemy.marks.remaining(MadnessRules.MARK_DELIRIUM)
	elif state == MadnessRules.STATE_DISORIENTED: remaining = enemy.marks.remaining(MadnessRules.MARK_DISORIENTED)
	elif state == MadnessRules.STATE_IMMUNE: remaining = enemy.marks.remaining(MadnessRules.MARK_IMMUNE)
	return {"id": enemy.get_instance_id(), "madness": madness_of(enemy), "threshold": MadnessRules.THRESHOLD, "state": state, "remaining": remaining, "boss": MadnessHelpers.is_boss(enemy), "contagion": enemy.marks.has_mark(MadnessRules.MARK_CONTAGION)}

## Pure reading for the HUD (T12): Ecstasy, Idol, Delirium count and one line per enemy
## that carries Madness or a Madness state.
func describe(player: PlayerActor = null, actors: Array = []) -> Dictionary:
	var lines: Array[Dictionary] = []
	var delirious := 0
	var idol_line := {}
	if is_instance_valid(player):
		for candidate: Variant in MadnessHelpers.enemies_of(player, actors):
			var enemy := candidate as CombatActor
			if not MadnessHelpers.is_enemy(enemy) or not MadnessHelpers.is_live(enemy): continue
			var line := describe_enemy(enemy)
			if line["state"] == MadnessRules.STATE_DELIRIUM: delirious += 1
			if float(line["madness"]) > 0.0 or line["state"] != MadnessRules.STATE_NONE or bool(line["contagion"]): lines.append(line)
		var current := idol(player)
		if current != null: idol_line = {"hp": current.health.current_hp, "max_hp": current.health.max_hp, "remaining": float(current.get(&"remaining"))}
	return {"ecstasy": ecstasy.charges, "ecstasy_cap": MadnessRules.ECSTASY_CAP, "ecstasy_enabled": ecstasy.enabled, "onus": ecstasy.has_onus(), "damage_taken": ecstasy.damage_taken_multiplier(), "idol": idol_line, "delirium_count": delirious, "delirium_cap": MadnessRules.DELIRIUM_CAP, "enemies": lines}

func has_claimed(key: String) -> bool:
	return _claimed.has(key)

func _refused(code: StringName) -> Dictionary:
	return {"ok": false, "error_code": code, "added": 0.0, "entered": &""}

func _remember(key: String) -> void:
	_claimed[key] = true
	_claim_order.append(key)
	while _claim_order.size() > MadnessRules.EVENT_MEMORY:
		_claimed.erase(_claim_order.pop_front())

func _bind_owner(player: PlayerActor) -> void:
	if owner_id == 0 and is_instance_valid(player): owner_id = player.get_instance_id()

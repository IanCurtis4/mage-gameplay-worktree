class_name FlankAuthority
extends RefCounted
## E09 T6 (C3) — family authority of the Assassin, kept by a kit (K3 Duelista, K4
## Lâmina Arcana) in one of its own fields: own concealment and its opening strike,
## the parry window, one victim per owner with its Sentence (0..5 in ActorMarks),
## the execution through DamageRequest and the single kill callback.
## Contract: docs/epics/e09/t6_contract.md. API for kits: docs/epics/e09/t6_delivery.md.
##
## Only the T1 seam is used (ActorMarks, gameplay facing override, kit_break_sight,
## kit_make_request/kit_emit_hit, the kit concealment source). The authority never
## stores a Node, the player, or an enemy instance ID with an entity role: the victim
## is the actor whose mark carries this owner and `victim_serial`, so the exact
## snapshot keeps it with the enemy and the compact cut stays eligible (A5).

# --- Own concealment --------------------------------------------------------------
var concealment_remaining := 0.0
## Entered and not yet revealed or expired. While the seam reveal window runs it is
## armed but not effective (PlayerActor.kit_concealed() stays false).
var concealment_armed := false
## Gameplay seconds effectively hidden in the current concealment.
var hidden_seconds := 0.0
## Window after a reveal by attack in which the first marked request opens from concealment.
var opening_remaining := 0.0
var opening_hidden_seconds := 0.0
var openings_total := 0

# --- Parry window -------------------------------------------------------------------
var parry_remaining := 0.0
## Parries left in the window; FlankRules.UNLIMITED_CHARGES for the whole duration.
var parry_charges := 0
var parried_total := 0

# --- Victim and Sentence --------------------------------------------------------------
var victim_serial := 0
## Instance ID cache of the current victim. Omitted from the snapshot: rebuilt from
## the mark after a restore, so the owner never references an enemy by entity.
var _victim_hint := 0
var gained_total := 0
## Accepted Sentence event keys (bounded, oldest first). Text keys, never entity IDs.
var _claimed: Dictionary = {}
var _claim_order: Array[String] = []

# --- Execution and kills -----------------------------------------------------------------
var spend_key := ""
var spend_amount := 0
var executions_total := 0
var lethal_total := 0
var execution_kills := 0
var _killed: Dictionary = {}
var _kill_order: Array[String] = []

# --- Clock -------------------------------------------------------------------------------

## Gameplay clock; call from ClassKit.on_tick (never runs in pause or while dead).
func tick(player: PlayerActor, delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0: return
	if concealment_armed:
		if is_instance_valid(player) and player.kit_concealed(): hidden_seconds += delta
		concealment_remaining = maxf(0.0, concealment_remaining - delta)
		if concealment_remaining <= 0.0: end_concealment() # expiry: no opening strike
	if opening_remaining > 0.0:
		opening_remaining = maxf(0.0, opening_remaining - delta)
		if opening_remaining <= 0.0: opening_hidden_seconds = 0.0
	if parry_remaining > 0.0:
		parry_remaining = maxf(0.0, parry_remaining - delta)
		if parry_remaining <= 0.0: parry_charges = 0

# --- Own concealment -------------------------------------------------------------------

## Enters (or renews, keeping the longer deadline) the kit concealment.
func enter_concealment(player: PlayerActor, duration: float = -1.0) -> bool:
	if not is_instance_valid(player) or not player.is_alive(): return false
	var value := FlankRules.CONCEALMENT_DURATION if duration < 0.0 else clampf(duration, FlankRules.CONCEALMENT_RANGE.x, FlankRules.CONCEALMENT_RANGE.y)
	if not is_finite(value): return false
	if not concealment_armed: hidden_seconds = 0.0
	concealment_armed = true
	concealment_remaining = maxf(concealment_remaining, value)
	opening_remaining = 0.0
	opening_hidden_seconds = 0.0
	return true

## ClassKit.concealment_active: the kit concealment source of the seam.
func concealment_active() -> bool:
	return concealment_armed and concealment_remaining > 0.0

func end_concealment() -> void:
	concealment_armed = false
	concealment_remaining = 0.0
	hidden_seconds = 0.0

## ClassKit.on_reveal: an offensive action revealed the owner. Opens the opening window.
func on_reveal(_player: PlayerActor, _duration: float) -> void:
	if not concealment_armed: return
	opening_remaining = FlankRules.OPENING_WINDOW
	opening_hidden_seconds = hidden_seconds
	end_concealment()

func opening_ready() -> bool:
	return opening_remaining > 0.0

# --- Outgoing requests --------------------------------------------------------------------

## Marks an outgoing kit request at commit: side seen from the target, opening strike
## from concealment. Attacking reveals (seam reveal) or cancels an armed concealment.
## Mutates and returns `request`; call it for every kit request (skills and basic attack).
func mark_request(player: PlayerActor, request: DamageRequest, target: CombatActor = null) -> DamageRequest:
	if request == null or not is_instance_valid(player): return request
	if player.kit_concealed(): player.reveal_from_offense()
	elif concealment_armed: end_concealment()
	var victim: CombatActor = target
	if not is_instance_valid(victim): victim = instance_from_id(request.target_id) as CombatActor
	var side: Dictionary = {"side": FlankRules.FRONT, "cos": 1.0}
	if is_instance_valid(victim): side = FlankRules.side_between(victim, player)
	var from_concealment := opening_remaining > 0.0
	var hidden := opening_hidden_seconds if from_concealment else 0.0
	if from_concealment:
		opening_remaining = 0.0
		opening_hidden_seconds = 0.0
		openings_total += 1
	request.effect_snapshot[FlankRules.SNAPSHOT_KEY] = {"side": side["side"], "cos": float(side["cos"]), "from_concealment": from_concealment, "hidden_seconds": hidden, "execution": false, "lethal": false, "charges": 0}
	return request

# --- Turn and sight -------------------------------------------------------------------

## Forced turn: the enemy looks away from the owner, who ends up exactly behind it.
func turn_away(player: PlayerActor, enemy: CombatActor, duration: float = -1.0) -> bool:
	if not is_instance_valid(player) or not is_instance_valid(enemy) or not enemy.is_alive() or enemy == player: return false
	var away := FlankRules.ground_position(enemy) - FlankRules.ground_position(player)
	away.y = 0.0
	if away.length() < FlankRules.OVERLAP_EPSILON: away = player.gameplay_ground_facing()
	return turn(enemy, away, duration)

## Generic forced turn to a ground direction (gameplay facing override of T1).
func turn(enemy: CombatActor, ground_direction: Vector3, duration: float = -1.0) -> bool:
	if not is_instance_valid(enemy) or not enemy.is_alive(): return false
	var direction := Vector3(ground_direction.x, 0.0, ground_direction.z)
	if not direction.is_finite() or direction.is_zero_approx(): return false
	var value := FlankRules.control_duration(duration, FlankRules.TURN_DURATION, FlankRules.TURN_RANGE, enemy)
	return enemy.override_gameplay_ground_facing(direction.normalized(), value, FlankRules.TURN_OWNER)

## The enemy loses sight of the owner (ThreatService.break_sight through the seam).
func break_sight(player: PlayerActor, enemy: CombatActor, duration: float = -1.0) -> Dictionary:
	if not is_instance_valid(player) or not is_instance_valid(enemy): return {"ok": false, "error_code": &"invalid_target"}
	return player.kit_break_sight(enemy, FlankRules.control_duration(duration, FlankRules.SIGHT_BREAK_DURATION, FlankRules.SIGHT_BREAK_RANGE, enemy))

## Turn plus sight break: the opening created by a parry (Duelista) or a feint.
func expose(player: PlayerActor, enemy: CombatActor, turn_duration: float = -1.0, sight_duration: float = -1.0) -> Dictionary:
	return {"turned": turn_away(player, enemy, turn_duration), "sight": break_sight(player, enemy, sight_duration)}

# --- Parry window -------------------------------------------------------------------------

func open_parry(player: PlayerActor, duration: float = -1.0, charges: int = 1) -> bool:
	if not is_instance_valid(player) or not player.is_alive(): return false
	if charges == 0 or charges < FlankRules.UNLIMITED_CHARGES: return false
	var value := FlankRules.PARRY_WINDOW if duration < 0.0 else clampf(duration, FlankRules.PARRY_RANGE.x, FlankRules.PARRY_RANGE.y)
	if not is_finite(value): return false
	parry_remaining = value
	parry_charges = charges
	return true

## Unlimited parries for a longer span (Duelo); the duration is the kit's.
func open_parry_mode(player: PlayerActor, duration: float) -> bool:
	if not is_instance_valid(player) or not player.is_alive() or not is_finite(duration) or duration <= 0.0: return false
	parry_remaining = duration
	parry_charges = FlankRules.UNLIMITED_CHARGES
	return true

func parry_open() -> bool:
	return parry_remaining > 0.0 and parry_charges != 0

func close_parry() -> void:
	parry_remaining = 0.0
	parry_charges = 0

## ClassKit.before_hit_mitigation helper: a frontal melee hit inside the window is
## parried. On success the kit returns {"cancel": true, "reason": result["reason"]}.
func try_parry(player: PlayerActor, hit: Dictionary, expose_attacker: bool = true) -> Dictionary:
	if not parry_open(): return {"parried": false, "reason": &"no_window"}
	if StringName(hit.get("kind", &"")) != &"melee": return {"parried": false, "reason": &"not_melee"}
	var attacker := hit.get("source") as CombatActor
	if not is_instance_valid(attacker) or not is_instance_valid(player): return {"parried": false, "reason": &"no_attacker"}
	var side := FlankRules.side_between(player, attacker)
	if side["side"] != FlankRules.FRONT: return {"parried": false, "reason": &"not_front", "side": side["side"]}
	if parry_charges > 0:
		parry_charges -= 1
		if parry_charges == 0: parry_remaining = 0.0
	parried_total += 1
	var result := {"parried": true, "reason": &"flank_parry", "attacker_id": attacker.get_instance_id()}
	if expose_attacker: result["exposed"] = expose(player, attacker)
	return result

# --- Victim ---------------------------------------------------------------------------------

## Marks the owner's single victim; the previous victim loses its mark.
func mark_victim(player: PlayerActor, actor: CombatActor) -> Dictionary:
	if not is_instance_valid(player) or not player.is_alive(): return {"ok": false, "error_code": &"invalid_owner"}
	if not is_instance_valid(actor) or not actor.is_alive() or actor == player: return {"ok": false, "error_code": &"invalid_target"}
	var current := victim(player)
	if current == actor: return {"ok": true, "error_code": &"", "changed": false}
	if current != null: current.marks.remove(FlankRules.VICTIM_MARK)
	victim_serial += 1
	if not actor.marks.set_mark(FlankRules.VICTIM_MARK, player.get_instance_id(), {"sentence": 0, "serial": victim_serial, "see_through": true}):
		_victim_hint = 0
		return {"ok": false, "error_code": &"mark_refused"}
	_victim_hint = actor.get_instance_id()
	return {"ok": true, "error_code": &"", "changed": true}

## Current living victim of the owner, or null.
func victim(player: PlayerActor) -> CombatActor:
	if victim_serial <= 0 or not is_instance_valid(player): return null
	var hinted: CombatActor = null
	if _victim_hint != 0: hinted = instance_from_id(_victim_hint) as CombatActor
	if _is_victim(player, hinted, true): return hinted
	_victim_hint = 0
	for actor: CombatActor in _candidates(player):
		if _is_victim(player, actor, true):
			_victim_hint = actor.get_instance_id()
			return actor
	return null

func is_victim(player: PlayerActor, actor: CombatActor) -> bool:
	return _is_victim(player, actor, true)

func clear_victim(player: PlayerActor) -> void:
	var current := victim(player)
	if current != null: current.marks.remove(FlankRules.VICTIM_MARK)
	_victim_hint = 0

## Sentence on `actor` (default: the current victim); 0 when it is not this owner's victim.
func sentence(player: PlayerActor, actor: CombatActor = null) -> int:
	var target := actor if actor != null else victim(player)
	if not _is_victim(player, target, true): return 0
	return int(FlankRules.victim_mark(target).get("sentence", 0))

# --- Sentence gain --------------------------------------------------------------------------

## ClassKit.on_damage_dealt helper. The kit chooses which sources count with `counted`
## ({&"back": bool, &"concealment": bool, &"direct": bool}; missing keys count). Per
## hit the largest enabled source applies (sources do not add up). Returns charges added.
func record_hit(player: PlayerActor, result: Dictionary, counted: Dictionary = {}) -> int:
	if not bool(result.get("landed", false)) or int(result.get("damage", 0)) <= 0 or bool(result.get("secondary", false)): return 0
	var flags := FlankRules.result_flags(result)
	if bool(flags.get("execution", false)): return 0
	var target := instance_from_id(int(result.get("target_id", 0))) as CombatActor
	if not _is_victim(player, target, true): return 0
	var amount := 0
	if bool(counted.get(FlankRules.SOURCE_DIRECT, true)): amount = int(FlankRules.SENTENCE_GAIN[FlankRules.SOURCE_DIRECT])
	if bool(counted.get(FlankRules.SOURCE_BACK, true)) and flags.get("side", &"") == FlankRules.BACK:
		amount = maxi(amount, int(FlankRules.SENTENCE_GAIN[FlankRules.SOURCE_BACK]))
	if bool(counted.get(FlankRules.SOURCE_CONCEALMENT, true)) and bool(flags.get("from_concealment", false)):
		amount = maxi(amount, int(FlankRules.SENTENCE_GAIN[FlankRules.SOURCE_CONCEALMENT]))
	var key := event_key(result)
	if amount <= 0 or key.is_empty(): return 0
	return _apply_gain(player, target, "hit@" + key, amount)

## Kit event worth a fixed source (normally &"combo": parry, three elements, toxins),
## deduplicated by its explicit key. Returns charges added.
func gain(player: PlayerActor, actor: CombatActor, source: StringName, key: String) -> int:
	var amount := int(FlankRules.SENTENCE_GAIN.get(source, 0))
	if amount <= 0 or key.is_empty() or not _is_victim(player, actor, true): return 0
	return _apply_gain(player, actor, "%s@%s" % [source, key], amount)

func has_claimed(key: String) -> bool:
	return _claimed.has(key)

## Ledger identity of one damage application (root_event_id, event_id, target), or the
## target's application_sequence when the hit had no causal context. "" means no key.
static func event_key(result: Dictionary) -> String:
	var target := int(result.get("target_id", 0))
	var context := result.get("context") as CombatEventContext
	if context != null and not context.root_event_id.is_empty() and context.event_id > 0:
		return "%s#%d:%d" % [context.root_event_id, context.event_id, target]
	var sequence := int(result.get("application_sequence", 0))
	return "seq:%d:%d" % [target, sequence] if sequence > 0 and target != 0 else ""

func _apply_gain(player: PlayerActor, actor: CombatActor, key: String, amount: int) -> int:
	if _claimed.has(key): return 0
	_remember(_claimed, _claim_order, key, FlankRules.EVENT_MEMORY)
	var current := sentence(player, actor)
	var added := clampi(amount, 0, maxi(0, FlankRules.SENTENCE_CAP - current))
	if added > 0:
		_set_sentence(actor, current + added)
		gained_total += added
	return added

func _set_sentence(actor: CombatActor, value: int) -> void:
	var mark := FlankRules.victim_mark(actor).duplicate()
	mark["sentence"] = clampi(value, 0, FlankRules.SENTENCE_CAP)
	actor.marks.update_value(FlankRules.VICTIM_MARK, mark)

# --- Execution ------------------------------------------------------------------------------

## Execution strike on `actor` (call from resolve_cast). Spends every charge of the
## victim once per commit; damage scales with the charges; full charges under the
## category threshold is certain death, through a DamageRequest marked as execution.
## Bosses never get certain death (A4). Options: "per_charge", "can_crit", "emit"
## (default true: kit_emit_hit), "accuracy_mode" (non-lethal only; default GEOMETRY).
func execute(player: PlayerActor, actor: CombatActor, skill_id: StringName, physical: float, magic: float, options: Dictionary = {}) -> Dictionary:
	if not is_instance_valid(player) or not player.is_alive(): return {"ok": false, "error_code": &"invalid_owner"}
	if not is_instance_valid(actor) or not actor.is_alive() or actor == player or actor.health == null: return {"ok": false, "error_code": &"invalid_target"}
	if not is_finite(physical) or not is_finite(magic) or physical < 0.0 or magic < 0.0: return {"ok": false, "error_code": &"invalid_payload"}
	var commit := "%s@%.5f" % [String(skill_id), player.kit_time]
	if commit == spend_key: return {"ok": false, "error_code": &"already_executed"}
	var per_charge := clampf(float(options.get("per_charge", FlankRules.EXECUTION_PER_CHARGE)), FlankRules.EXECUTION_PER_CHARGE_RANGE.x, FlankRules.EXECUTION_PER_CHARGE_RANGE.y)
	var charges := sentence(player, actor)
	var category := FlankRules.category_of(actor)
	var threshold := FlankRules.execution_threshold(category)
	var hp_fraction := actor.health.current_hp / maxf(1.0, actor.health.max_hp)
	var immune := actor.has_method(&"returning_immune") and bool(actor.call(&"returning_immune"))
	var lethal := charges >= FlankRules.SENTENCE_CAP and threshold >= 0.0 and hp_fraction <= threshold + 1.0e-6 and not immune
	var multiplier := 1.0 + per_charge * float(charges)
	var accuracy: DamageRequest.AccuracyMode = DamageRequest.AccuracyMode.GEOMETRY
	if not lethal and options.get("accuracy_mode") == DamageRequest.AccuracyMode.CONTESTED: accuracy = DamageRequest.AccuracyMode.CONTESTED
	var request := player.kit_make_request(actor, skill_id, physical * multiplier, magic * multiplier, accuracy, bool(options.get("can_crit", true)) and not lethal)
	mark_request(player, request, actor)
	if lethal and not _raise_to_lethal(request, actor): lethal = false
	var flags: Dictionary = request.effect_snapshot[FlankRules.SNAPSHOT_KEY]
	flags["execution"] = true
	flags["lethal"] = lethal
	flags["charges"] = charges
	flags["category"] = category
	if charges > 0: _set_sentence(actor, 0)
	spend_key = commit
	spend_amount = charges
	executions_total += 1
	if lethal: lethal_total += 1
	if bool(options.get("emit", true)): player.kit_emit_hit(request, actor)
	return {"ok": true, "error_code": &"", "request": request, "charges": charges, "lethal": lethal, "category": category, "threshold": threshold, "hp_fraction": hp_fraction, "multiplier": multiplier}

## Raises the amounts until CombatMath itself (target defenses, no crit) deals at least
## HP + shield. Debuffs only lower defenses and raise damage taken, so the probe is a floor.
func _raise_to_lethal(request: DamageRequest, actor: CombatActor) -> bool:
	var state := actor.health
	var needed := state.current_hp + state.shield_hp
	if request.physical_damage + request.magic_damage <= 0.0: request.physical_damage = 1.0
	for _step: int in FlankRules.LETHAL_PROBE_STEPS:
		var probe := CombatMath.resolve(request, state.physical_defense, state.magic_defense, state.flee_rating, state.crit_resistance, 0.0, 1.0)
		var dealt := float(probe["damage"])
		if bool(probe["landed"]) and dealt >= needed: return true
		var factor := maxf(1.5, needed / maxf(1.0, dealt) * 1.05)
		request.physical_damage *= factor
		request.magic_damage *= factor
	return false

# --- Kill and death ------------------------------------------------------------------------

## ClassKit.on_kill_confirmed helper. "first" is true once per victim (the seam already
## calls once; a retry returns first = false). The kit acts only on first == true.
func on_kill_confirmed(player: PlayerActor, result: Dictionary) -> Dictionary:
	var target := int(result.get("target_id", 0))
	var out := {"kill": target != 0, "first": false, "execution": false, "victim": false}
	if target == 0: return out
	var key := "k:%d" % target
	if _killed.has(key): return out
	_remember(_killed, _kill_order, key, FlankRules.KILL_MEMORY)
	out["first"] = true
	out["execution"] = bool(FlankRules.result_flags(result).get("execution", false))
	var actor := instance_from_id(target) as CombatActor
	out["victim"] = target == _victim_hint or _is_victim(player, actor, false)
	if out["victim"]: _victim_hint = 0
	if out["execution"]: execution_kills += 1
	return out

## ClassKit.on_death helper: concealment, opening, parry and the victim end.
func on_death(player: PlayerActor) -> void:
	end_concealment()
	opening_remaining = 0.0
	opening_hidden_seconds = 0.0
	close_parry()
	clear_victim(player)

# --- Behind the victim (Lâmina Arcana) --------------------------------------------------

## Point behind `actor` (opposite its gameplay facing), validated by the world geometry
## (or the flat navigation) and classified as back. Tries 0°, +30° and -30°.
func back_point(player: PlayerActor, actor: CombatActor, gap: float = -1.0) -> Dictionary:
	if not is_instance_valid(player) or not is_instance_valid(actor) or not actor.is_alive() or actor == player: return {"ok": false, "error_code": &"invalid_target"}
	var spacing := FlankRules.BACK_GAP if gap < 0.0 else clampf(gap, FlankRules.BACK_GAP_RANGE.x, FlankRules.BACK_GAP_RANGE.y)
	var facing := actor.gameplay_ground_facing()
	facing.y = 0.0
	if not facing.is_finite() or facing.is_zero_approx(): return {"ok": false, "error_code": &"invalid_facing"}
	facing = facing.normalized()
	var target_ground := FlankRules.ground_position(actor)
	var world := player.world_motion != null
	if world and (actor.world_motion == null or not player.world_motion.is_current_world() or not actor.world_motion.is_current_world() or actor.world_motion.geometry != player.world_motion.geometry):
		return {"ok": false, "error_code": &"incompatible_target"}
	var bodies := actor.collision_radius + player.collision_radius
	if world: bodies = float(actor.world_motion.profile()["radius"]) + float(player.world_motion.profile()["radius"])
	var reach := bodies + spacing
	for angle: float in FlankRules.BACK_ANGLES_DEG:
		var heading := (-facing).rotated(Vector3.UP, deg_to_rad(angle))
		if world:
			var geometry := player.world_motion.geometry
			var traced := geometry.trace_ground(actor.world_point(), heading, reach, player.world_motion.profile(), geometry.geometry_revision)
			if not traced.get("ok", false): continue
			var data: Dictionary = traced["data"]["destination"]
			var point := ExpeditionWorldPoint.create(String(data["stage_id"]), String(data["surface_id"]), data["position"])
			var offset := Vector2(point.position.x - target_ground.x, point.position.z - target_ground.z)
			if offset.length() + 0.001 < bodies: continue
			if not geometry.position_query(point, player.world_motion.profile(), geometry.geometry_revision).get("ok", false): continue
			if FlankRules.classify(target_ground, facing, point.position)["side"] != FlankRules.BACK: continue
			return {"ok": true, "error_code": &"", "world_point": point, "ground": point.position, "angle": angle}
		else:
			var flat := actor.global_position + Vector2(heading.x, heading.z) * reach
			if player.navigation == null or not player.navigation.is_walkable(flat) or not player.navigation.is_segment_clear(actor.global_position, flat, 0.0): continue
			var ground := Vector3(flat.x, 0.0, flat.y)
			if FlankRules.classify(target_ground, facing, ground)["side"] != FlankRules.BACK: continue
			return {"ok": true, "error_code": &"", "position": flat, "ground": ground, "angle": angle}
	return {"ok": false, "error_code": &"back_point_blocked"}

## Moves the owner behind `actor` (WorldActorMotion.teleport: teleport_legal and range;
## flat arena: walkable point) and faces it. Call from resolve_cast; the strike that
## follows is classified by mark_request as usual.
func teleport_behind(player: PlayerActor, actor: CombatActor, maximum_range: float, gap: float = -1.0) -> Dictionary:
	if not is_finite(maximum_range) or maximum_range <= 0.0: return {"ok": false, "error_code": &"invalid_range"}
	var point := back_point(player, actor, gap)
	if not point["ok"]: return point
	if player.world_motion != null:
		var moved := player.world_motion.teleport(point["world_point"], maximum_range, player.world_motion.geometry.geometry_revision)
		if not moved.get("ok", false): return {"ok": false, "error_code": moved.get("error_code", &"illegal_teleport")}
	else:
		if player.global_position.distance_to(point["position"]) > maximum_range + 0.001: return {"ok": false, "error_code": &"out_of_range"}
		player.global_position = point["position"]
		player.velocity = Vector2.ZERO
	var toward := FlankRules.ground_position(actor) - FlankRules.ground_position(player)
	toward.y = 0.0
	if not toward.is_zero_approx(): player.override_gameplay_ground_facing(toward.normalized(), 0.25, &"flank_teleport")
	return {"ok": true, "error_code": &"", "side": FlankRules.side_between(actor, player)["side"], "angle": point["angle"]}

# --- Internals -------------------------------------------------------------------------------

func _is_victim(player: PlayerActor, actor: CombatActor, require_alive: bool) -> bool:
	if victim_serial <= 0 or not is_instance_valid(player) or not is_instance_valid(actor) or actor == player: return false
	if require_alive and not actor.is_alive(): return false
	if actor.marks.owner_of(FlankRules.VICTIM_MARK) != player.get_instance_id(): return false
	return int(FlankRules.victim_mark(actor).get("serial", -1)) == victim_serial

func _candidates(player: PlayerActor) -> Array[CombatActor]:
	var result: Array[CombatActor] = []
	var parents: Array[Node] = [player]
	if player.get_parent() != null: parents.append(player.get_parent())
	for parent: Node in parents:
		for child: Node in parent.get_children():
			if child is CombatActor and child != player and not result.has(child): result.append(child)
	return result

static func _remember(memory: Dictionary, order: Array[String], key: String, limit: int) -> void:
	memory[key] = true
	order.append(key)
	while order.size() > limit: memory.erase(order.pop_front())

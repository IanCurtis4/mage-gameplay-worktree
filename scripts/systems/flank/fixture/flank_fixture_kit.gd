extends "res://scripts/classes/fixture/fixture_kit.gd"
## E09 T6 fixture kit: the T1 fixture kit plus a FlankAuthority, forwarding the seam
## hooks exactly as K3/K4 are expected to (docs/epics/e09/t6_delivery.md).
## Never listed in ClassKitRegistry.MODULES; tests install it with install_fixture().
## Fixture skills (T1 fixture slots): slot 0 enters the own concealment, slot 2
## (single target) is the execution. The basic attack is marked by the authority.

var flank := FlankAuthority.new()
## Sources the kit counts for the Sentence (missing keys count).
var counted: Dictionary = {}
var parry_enabled := true
var kill_callbacks := 0
var execution_callbacks := 0
var last_execution: Dictionary = {}
var last_parry: Dictionary = {}

func _slot(index: int) -> StringName:
	return ClassKitRegistry.SKILL_IDS[fixture_id][index]

func on_tick(player: PlayerActor, delta: float) -> void:
	super(player, delta)
	flank.tick(player, delta)

func resolve_cast(player: PlayerActor, cast: Dictionary) -> bool:
	var skill := StringName(cast["skill_id"])
	if skill == _slot(0):
		calls.append("resolved:" + String(skill))
		return flank.enter_concealment(player)
	if skill == _slot(2):
		calls.append("resolved:" + String(skill))
		var target := cast.get("target") as CombatActor
		var executed := flank.execute(player, target, skill, player.stat_breakdown.value(&"melee_attack"), 0.0)
		last_execution = {"ok": executed["ok"], "error_code": executed["error_code"], "charges": executed.get("charges", 0), "lethal": executed.get("lethal", false), "category": executed.get("category", &"")}
		return bool(executed["ok"])
	return super(player, cast)

func compose_basic_attack(player: PlayerActor, target: CombatActor, request: DamageRequest) -> DamageRequest:
	return flank.mark_request(player, super(player, target, request), target)

func before_hit_mitigation(player: PlayerActor, hit: Dictionary) -> Dictionary:
	var decision := super(player, hit)
	if bool(decision.get("cancel", false)) or not parry_enabled: return decision
	var parry := flank.try_parry(player, hit)
	last_parry = {"parried": parry["parried"], "reason": parry["reason"]}
	if bool(parry["parried"]): return {"cancel": true, "reason": parry["reason"]}
	return {}

func on_damage_dealt(player: PlayerActor, result: Dictionary) -> void:
	super(player, result)
	flank.record_hit(player, result, counted)

func on_kill_confirmed(player: PlayerActor, result: Dictionary) -> void:
	super(player, result)
	var kill := flank.on_kill_confirmed(player, result)
	if not bool(kill["first"]): return
	kill_callbacks += 1
	if bool(kill["execution"]):
		execution_callbacks += 1
		flank.enter_concealment(player) # "Se matar, volta à ocultação."

func on_death(player: PlayerActor) -> void:
	super(player)
	flank.on_death(player)

func concealment_active(_player: PlayerActor) -> bool:
	return flank.concealment_active()

func on_reveal(player: PlayerActor, duration: float) -> void:
	super(player, duration)
	flank.on_reveal(player, duration)

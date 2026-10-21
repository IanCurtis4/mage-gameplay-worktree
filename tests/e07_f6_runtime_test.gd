extends "res://tests/fixtures/e07/f5/suite.gd"
func _run() -> void:
	var f := make("f6_runtime")
	if not enter(f)["ok"]: dispose(f); finish_test(); return
	var host: RunController = f["controller"]
	var actor: EnemyActor = host.campaign_runtime.actors["entry_field"]
	var boss: EnemyActor = host.campaign_runtime.actors["entry_boss"]
	var rng := RandomNumberGenerator.new(); rng.seed = 42
	var request := DamageRequest.new(); request.source_id = host.player.get_instance_id(); request.target_id = actor.get_instance_id()
	request.magic_damage = 1.0; request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY; request.can_crit = false
	var result := actor.apply_damage(request, rng)
	check(float(result.get("actual_damage", 0.0)) > 0.0 and actor.threat.amounts["player"] == result["actual_damage"], "real HealthState damage drives ledger once")
	var amount: float = actor.threat.amounts["player"]
	actor.observe_threat_damage(result)
	check(actor.threat.amounts["player"] == amount, "callback replay cannot generate another unit")
	boss.threat.engage()
	host.player.health._hp_deficit = 8.0
	var boss_before: float = boss.threat.amounts["player"]
	check(host.player.health.heal(1000.0) == 8.0, "canonical heal clips overheal")
	check(actor.threat.amounts["player"] == amount + 2.0 and boss.threat.amounts["player"] == boss_before + 2.0, "real heal signal divides only the effective eight among two enemies")
	host.combat_participation.observe({}, 2.0)
	var grace := host.combat_participation.remaining
	host._on_player_healed(8.0, host.player.health.heal_sequence)
	check(actor.threat.amounts["player"] == amount + 2.0 and host.combat_participation.remaining == grace, "heal callback replay changes neither threat nor combat grace")
	host._on_enemy_damage_resolved(result)
	check(host.combat_participation.remaining == grace, "damage callback replay cannot renew combat grace")
	check(host.player.health.heal(1000.0) == 0.0 and host.player.health.heal_sequence == 1, "overheal emits no event")
	check(host.encounter_active, "real damage/healing blocks immediate out-of-combat consumers")
	host.player.health._hp_deficit = 4.0
	check(not host.player.regenerate_hp(1.0, host.encounter_active, false) and host.player.health.hp_deficit() == 4.0, "HP regeneration uses the same combat authority")
	check(not host.run_state.open_offer(host.encounter_active, rng)["ok"], "offer consumes participation authority")
	check(actor.apply_taunt(2.0) and actor.threat.forced_id == "player" and actor.taunt_remaining == 2.0, "existing taunt adapter fixes ledger target")
	actor.threat.advance(2.0)
	check(actor.threat.forced_id.is_empty(), "existing duration expires without new skill")
	var hp := actor.health.current_hp
	actor._begin_return()
	check(not actor.threat.engaged and actor.health.current_hp == hp and actor.threat.amounts["player"] == amount + 2.0, "real leash removes link without healing/reset")
	boss._begin_return()
	host.combat_participation.observe({}, 5.0)
	check(not host.encounter_active and host.run_state.open_offer(host.encounter_active, rng)["ok"], "five-second exit releases offer on uncleared stage")
	actor.engagement_mode = &"idle"
	check(actor.observe_threat_damage(result).get("already_applied", false) and actor.engagement_mode == &"idle" and not actor.threat.engaged, "old damage replay cannot restart engagement after leash")
	host._on_provoke_requested(actor, 2.0)
	check(host.encounter_active and actor.threat.forced_id == "player", "successful taunt blocks out-of-combat consumers in the same tick")
	actor._begin_return(); host.combat_participation.observe({}, 5.0)
	host.player.health._hp_deficit = 1.0; host.player.health.heal(1.0)
	var outside_sequence := host.player.health.heal_sequence
	actor.threat.engage("player")
	var outside_amount: float = actor.threat.amounts["player"]
	host._on_player_healed(1.0, outside_sequence)
	check(actor.threat.amounts["player"] == outside_amount and not host.combat_participation.active(), "replay of out-of-combat healing cannot acquire new recipients later")
	# Two actual source actors exercise target adapter, independently of multiplayer.
	var source := PlayerActor.new(); source.configure(host.navigation, RunState.new(&"mage")); host.add_child(source)
	source.set_process(false)
	check(actor.register_threat_actor("fixture_pet", "player", "local_party", source)["ok"], "fixture pet identity records owner separately")
	var point := actor.world_point()
	check(source.bind_world_geometry(actor.world_motion.geometry, point, host.player.world_motion.profile(), "f6_source")["ok"], "synthetic source shares canonical geometry")
	actor.threat.eligibility("player", true, true); actor.threat.eligibility("fixture_pet", true, true)
	actor.threat.observe("fixture_pet_hit", &"damage", "fixture_pet", 100.0)
	check(actor.threat.current_id == "fixture_pet" and actor.threat.amounts["player"] == amount + 2.0, "second source wins without duplicate owner credit")
	actor._mob_cast = {"captured_target": "old"}
	actor._advance_threat(0.0)
	check(actor.player == source and actor._mob_cast.is_empty(), "real target binding cancels prepared cast without redirecting it")
	actor.engagement_mode = &"engaged"
	actor._refresh_player_acquisition()
	var emitted: Array = []
	actor.attack_requested.connect(func(hit: DamageRequest, target: CombatActor, _ranged: bool) -> void: emitted.append([hit.target_id, target]))
	actor.attack_cooldown = 0.0; actor._try_attack(false)
	check(not emitted.is_empty() and emitted[0][0] == source.get_instance_id() and emitted[0][1] == source, "actual enemy attack uses the selected source")
	actor.threat.eligibility("fixture_pet", false, false)
	check(actor.threat.current_id == "player", "source death selects surviving participant")
	# Solid-floor/hidden eligibility is checked against WorldGeometry; no ledger reset.
	actor._advance_threat(0.0)
	check(actor.threat.amounts["fixture_pet"] == 100.0, "source visibility checks preserve accumulated credit")
	dispose(f); finish_test()

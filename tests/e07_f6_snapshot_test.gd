extends "res://tests/fixtures/e07/f5/suite.gd"
func _run() -> void:
	var f := make("f6_snapshot")
	if not enter(f)["ok"]: dispose(f); finish_test(); return
	var host: RunController = f["controller"]
	var actor: EnemyActor = host.campaign_runtime.actors["entry_field"]
	actor.threat.observe("precut_dot", &"damage", "player", 17.0)
	check(actor.apply_taunt(4.0), "taunt before durable cut")
	actor.threat.advance(0.75)
	host.player.health._hp_deficit = 9.0; host.player.health.heal(3.0)
	var pet := PlayerActor.new(); pet.configure(host.navigation, host.run_state); host.add_child(pet); pet.set_process(false)
	check(pet.bind_world_geometry(actor.world_motion.geometry, actor.world_point(), host.player.world_motion.profile(), "snapshot_pet")["ok"], "synthetic pet uses canonical world before cut")
	check(actor.register_threat_actor("fixture_pet", "player", "local_party", pet)["ok"], "second stable source has explicit owner")
	var damage := DamageRequest.new(); damage.source_id = pet.get_instance_id(); damage.target_id = actor.get_instance_id(); damage.magic_damage = 1.0; damage.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY; damage.can_crit = false
	var resolved := actor.apply_damage(damage, host.rng)
	check(float(resolved.get("actual_damage", 0.0)) > 0.0 and actor.threat.amounts["fixture_pet"] == resolved["actual_damage"], "second real source damage is attributed before snapshot")
	host.combat_participation.hostile_damage(); host.combat_participation.observe({}, 1.25)
	var expected := actor.threat.view()
	var hp := host.player.health.current_hp
	var result: Dictionary = f["service"].checkpoint(host, f["barrier"], "f5_expedition", &"f5_fixture_phase", "f6_suspend", f["facade"].current_profile().revision, true)
	check(result["ok"], "ledger/fixation/claims persist with world and profile: " + str(result.get("error_code")))
	if not result["ok"]: dispose(f); finish_test(); return
	var reopened := ProfileFacade.new(f["store"])
	check(reopened.open_profile()["ok"], "fresh canonical reader")
	f["facade"] = reopened; f["service"] = ExpeditionService.new(reopened)
	result = f["service"].resume("f5_expedition", host.run_state.character_id, "f6_resume", reopened.current_profile().revision)
	check(result["ok"], "fresh process-equivalent durable resume: " + str(result.get("error_code")))
	if not result["ok"]: dispose(f); finish_test(); return
	adopt(f, result); host = f["controller"]; actor = host.campaign_runtime.actors["entry_field"]
	check(actor.threat.view().entries == expected.entries, "exact detached amounts and owner identities restored")
	check(actor.threat.forced_remaining == 3.25 and actor.threat.current_id == "player", "no offline advancement or taunt reset")
	check(actor.threat_actors["player"] == host.player and actor.player == host.player, "source/target refs bind reconstructed actor")
	check(actor.threat_actors["fixture_pet"] != pet and actor.threat_actors["fixture_pet"].world_motion.geometry == actor.world_motion.geometry and actor.threat.participants["fixture_pet"]["owner"] == "player", "multiple source references and shared geometry are reconstructed")
	check(host.player.health.current_hp == hp and host.player.health.heal_sequence == 1, "health and effective heal receipt sequence preserved")
	check(host.combat_participation.remaining == 3.75, "combat grace exact across suspension")
	var before: float = actor.threat.amounts["player"]
	check(actor.threat.observe("precut_dot", &"damage", "player", 17.0).get("already_applied", false) and actor.threat.amounts["player"] == before, "DoT replay remains claimed after restart")
	host._on_player_healed(3.0, 1)
	check(actor.threat.amounts["player"] == before and host.combat_participation.remaining == 3.75, "healing replay preserves both threat and combat grace after restart")
	actor.threat.advance(3.0); check(actor.threat.forced_remaining == 0.25, "next simulation step continues existing fixation")
	actor.threat.amounts["player"] = -1.0
	var rejected := SnapshotRegistry.new().capture(host, f["barrier"])
	check(not rejected["ok"], "malformed negative ledger cannot enter checkpoint")
	actor.threat.amounts["player"] = before
	check(SnapshotRegistry.new().capture(host, f["barrier"])["ok"], "failed capture leaves healthy graph retryable")
	dispose(f); finish_test()

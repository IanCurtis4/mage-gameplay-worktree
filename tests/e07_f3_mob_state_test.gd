extends "res://tests/e07_f3_continuation_test.gd"
var mode := ""
func _run() -> void:
	for value: String in ["pending","consumed","dead","dead_pending"]:
		mode = value; selected_skill = StringName("mob_"+value)
		await _case(&"swordsman",&"",1.0/30.0)
	var output := FileAccess.open("res://.godot/verification/e07_f3_mob_state.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(measurements,"  ",true)); output.close()
	print("E07 F3 mob state: %d checks, %d failures; scenarios=%d" % [checks,failures,measurements.size()])
	quit(1 if failures else 0)
func _prepare(c: RunController,_evolution: StringName) -> void:
	for enemy: CombatActor in c.enemies: enemy.free()
	c.enemies.clear()
	var loaded := BuildContentLoader.load_catalog(true,true)
	check(loaded["ok"] and c.run_state.set_effect_catalog(loaded["catalog"])["ok"],"real complete mob/effect catalog is stable")
	check(c.reward_service.configure_mob_loot(EquipmentLootProfiles.production(c.run_state.effect_catalog()))["ok"],"actual loot resolver uses existing production recipe")
	var world := c.player.world_motion.geometry
	var profile := c.player.world_motion.profile()
	c.encounter_index = 4
	var born := c.spawn_world_enemy({"species":&"test_beast_master","category":&"rare"},SpatialFixture.point("root",Vector3(700,0,1000)),profile,world.geometry_revision,4,profile)
	check(born["ok"],"real finite Master is born on support")
	if not born["ok"]: return
	var master: EnemyActor = born["data"]["actor"]
	var other := c.spawn_world_enemy({"species":&"test_gel","category":&"normal"},SpatialFixture.point("root",Vector3(850,0,1500)),profile,world.geometry_revision,4)
	check(other["ok"],"another required mob keeps the encounter active after Master death")
	master.health.max_hp = 100000; master.health.current_hp = 100000
	if other["ok"]: other["data"]["actor"].health.max_hp = 100000; other["data"]["actor"].health.current_hp = 100000
	master.engagement_mode = &"engaged"
	master._request_companion_once(); master._request_companion_once()
	check(master.summon_used and c._world_pending_companions.size() == 1,"finite summon is claimed once and queued before a deferred callback")
	if mode in ["consumed","dead"]:
		c._advance_world_companion_requests()
		check(c.enemies.size() == 3 and c._world_pending_companions.is_empty(),"one actual animal consumes the pending intent")
	if mode in ["dead","dead_pending"]:
		var request := DamageRequest.new()
		request.source_id = c.player.get_instance_id(); request.target_id = master.get_instance_id(); request.skill_id = &"fixture_master_death"
		request.magic_damage = 1000000; request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY; request.can_crit = false
		master.apply_damage(request,c.rng)
		check(c.enemies.size() == 1 and c.reward_service._queue.size() == 1,"Master death removes its animal and freezes exactly one mob ticket")
	if mode in ["pending","dead_pending"]: paused = true
	_disable(c)

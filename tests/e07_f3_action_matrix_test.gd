extends "res://tests/e07_f3_continuation_test.gd"
func _run() -> void:
	var cases: Array[Array] = [
		[&"mage",&"",&"soul_impact"], [ &"mage",&"",&"fire_wall"],
		[&"mage",&"",&"lightning_wall"], [ &"mage",&"",&"ice_wall"],
		[&"mage",&"",&"phantom_barrier"], [ &"archer",&"",&"snare_trap"],
		[&"archer",&"",&"explosive_trap"], [ &"archer",&"",&"foliage_shelter"],
		[&"archer",&"hunter",&"hunter_tar_trap"], [ &"archer",&"hunter",&"hunter_thorn_trap"],
		[&"archer",&"hunter",&"hunter_tar_field_fixture"],
		[&"archer",&"hunter",&"hunter_total_cover"], [ &"archer",&"sentinel",&"sentinel_net_shot"],
		[&"archer",&"sentinel",&"sentinel_explosive_shot"],
		[&"mage",&"spiritualist",&"spiritualist_procession"],
		[&"mage",&"spiritualist",&"spiritualist_spectral_veil"],
		[&"mage",&"spiritualist",&"spiritualist_echo_curse"],
		[&"swordsman",&"",&"enemy_arrow_fixture"],
		[&"mage",&"mg_ar",&"geometer_figure"],
	]
	for row: Array in cases:
		selected_skill = row[2]
		await _case(row[0],row[1],1.0/30.0)
	cut_during_preparation = true; selected_skill = &"fire_spear"
	await _case(&"mage",&"",1.0/60.0)
	selected_skill = &"geometer_trace_preparation"
	await _case(&"mage",&"mg_ar",1.0/60.0)
	var output := FileAccess.open("res://.godot/verification/e07_f3_action_matrix.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(measurements,"  ",true)); output.close()
	print("E07 F3 action matrix: %d checks, %d failures; scenarios=%d" % [checks,failures,measurements.size()])
	quit(1 if failures else 0)
func _prepare(c: RunController,evolution: StringName) -> void:
	var scenario := selected_skill
	if scenario == &"hunter_tar_field_fixture": selected_skill = &"hunter_tar_trap"
	super._prepare(c,evolution)
	selected_skill = scenario
	if scenario == &"hunter_tar_field_fixture":
		_step_effects(c,1)
		check(is_instance_valid(c.hunter_tar_field) and c.hunter_tar_field.active,"actual trap produces an active Tar field before the cut")
	if selected_skill != &"geometer_figure": return
	_step_effects(c,1)
	for point: Vector3 in [Vector3(300,0,550),Vector3(350,0,500)]:
		var skill: StringName = &"geometer_triangulation" if point.x == 350 else &"geometer_trace"
		c.player.mage_cooldowns[skill] = 0
		var trace := c.geometer_casting.begin_world_trace(skill,SpatialFixture.point("root",point),null,c.player.world_motion.geometry.geometry_revision)
		check(trace["ok"],"additional real trace forms retained triangle")
		if c.player.has_active_cast(): c.player._advance_world_cast(10)
		_step_effects(c,1)
	check(c.geometer_casting.construction.has_active_figure(),"actual figure exists before capture")

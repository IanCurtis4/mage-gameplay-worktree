extends SceneTree
## Native end-to-end UI evidence with isolated profile and unchanged production loot.
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var directory := "res://.godot/verification/e06_reward_feedback/native"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	for size: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		var viewport := SubViewport.new()
		viewport.size=size
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var profile_path := ProjectSettings.globalize_path(directory+"/profile_%d_%d" % [size.x,Time.get_ticks_usec()])
		var facade := ProfileFacade.new(ProfileStore.new(profile_path,ProfileCatalog.pilot()), ProfileRewardResolver.pilot_progression())
		assert(facade.create_character("create",0,"Observadora",&"swordsman")["ok"])
		var started := facade.start_run("start",facade.current_profile().revision)
		assert(started["ok"])
		RunController.pending_run_state=started["run_state"]
		RunController.pending_run_facade=facade
		RunController.pending_gameplay_extension=true
		RunController.pending_training_mode=false
		var c := RunController.new()
		viewport.add_child(c)
		c.set_process(false)
		c.player.set_process(false)
		for enemy: CombatActor in c.enemies:enemy.set_process(false)
		# Find a reproducible legal production outcome with both gear and card.
		# Pure resolver search changes neither tables nor the real service RNG.
		var chosen := -1
		for seed_value: int in range(1,1001):
			var random := RandomNumberGenerator.new()
			random.seed=seed_value
			var items := 0
			var cards := 0
			for enemy: EnemyActor in c.enemies:
				if enemy.is_summoned:continue
				var values: Array[float]=[]
				for roll: int in 5:values.append(random.randf())
				var resolved := c.reward_service._loot_resolver.roll(enemy.occurrence,values)
				assert(resolved["ok"])
				items+=resolved["equipment_drops"].size()
				cards+=int(not StringName(resolved["card_id"]).is_empty())
			if items>0 and cards>0:
				chosen=seed_value
				break
		assert(chosen>=0)
		c.rng.seed=chosen
		for enemy: EnemyActor in c.enemies.duplicate():
			if enemy.is_summoned or not is_instance_valid(enemy):continue
			enemy.health.current_hp=0.0
			c._on_enemy_died(enemy)
		assert(c.reward != null and not c.encounter_active)
		assert(c.acquisition_journal.entries().is_empty())
		var collected := c._collect_reward()
		if not collected["ok"]:
			print("NATIVE_COLLECTION_FAILURE ",JSON.stringify(collected))
			quit(1)
			return
		await _capture(viewport,directory,"encounter_%d" % size.x)
		c.reward_feedback.hide_history()
		await _capture(viewport,directory,"recent_%d" % size.x)
		c._open_augment_menu()
		var offer := c.run_state.current_offer.duplicate()
		assert(not offer.is_empty())
		c._confirm_augment(offer[0].id)
		var total := c.acquisition_journal.totals()
		assert(total["equipment"]>0 and total["cards"]>0 and total["augments"]==1 and total["base_xp"]>0 and total["job_xp"]>0)
		c._show_result(false)
		await _capture(viewport,directory,"result_%d" % size.x)
		c.reward_feedback.open_history(0)
		await _capture(viewport,directory,"run_%d" % size.x)
		print("REWARD_FEEDBACK_NATIVE ",JSON.stringify({"viewport":[size.x,size.y],"production_seed":chosen,"totals":total,"history_rect":str(c.reward_feedback.history_panel.get_global_rect()),"recent_rect":str(c.reward_feedback.recent_panel.get_global_rect())}))
		viewport.queue_free()
		paused=false
		await process_frame
	print("REWARD_FEEDBACK_NATIVE_OK")
	quit(0)
func _capture(viewport: SubViewport,directory: String,name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().save_png(directory+"/"+name+".png")==OK)

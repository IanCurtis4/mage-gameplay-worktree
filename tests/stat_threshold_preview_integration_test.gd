extends SceneTree
## Read-only projections, individualized affordability and real consumer agreement.

const PROFILE_ID := "123e4567-e89b-42d3-a456-426614174309"
var checks := 0
var failures := 0
var directory: String

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	directory = ProjectSettings.globalize_path("res://.godot/verification/stat_preview_%d_%d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()])
	var unopened := ProfileFacade.new(ProfileStore.new(directory.path_join("unopened")))
	_check(not unopened.attribute_purchase_preview("unknown", &"str")["ok"] and not DirAccess.dir_exists_absolute(directory.path_join("unopened")), "preview never opens or writes an unavailable profile")
	var mage := CharacterState.new(IdentityIds.character_id(PROFILE_ID, 1), "Marcos", &"mage")
	mage.base_xp_total = 225 # Base3: 26 currency points.
	mage.attribute_allocations[&"int"] = 6 # 9 ->15 costs16.
	mage.attribute_allocations[&"str"] = 4 # 2 ->6 costs8. Remaining2.
	var facade := _facade("mage", mage)
	var id := mage.character_id
	var before_bytes := FileAccess.get_file_as_bytes(directory.path_join("mage/profile.json"))
	var before_revision := facade.current_profile().revision
	var strength := facade.attribute_purchase_preview(id, &"str")
	var intelligence := facade.attribute_purchase_preview(id, &"int")
	_check(strength["can_purchase"] and strength["cost"] == 2 and strength["available"] == 2, "cheap secondary is affordable at its permanent cost")
	_check(not intelligence["can_purchase"] and intelligence["cost"] == 3 and intelligence["blocking_reason"] == &"insufficient_points" and intelligence["after"] != null, "expensive primary still exposes gains but cannot spend another attribute's price")
	_check(intelligence["next_milestones"] == [18, 20, 21], "preview reports unique next effective INT milestones")
	var boosted := facade.attribute_purchase_preview(id, &"str", 1, [{"source_id": &"preview:buff", "primary_flat": {&"str": 4.5}}])
	_check(boosted["cost"] == 2 and is_equal_approx(boosted["effective"], 10.5) and boosted["next_milestones"] == [20], "buffs and fractions affect gains and milestones, not permanent prices")
	_check(facade.current_profile().revision == before_revision and FileAccess.get_file_as_bytes(directory.path_join("mage/profile.json")) == before_bytes, "repeated projections leave disk and revision unchanged")
	var scene := load("res://scenes/character_menu.tscn") as PackedScene
	var menu := scene.instantiate() as CharacterMenu
	menu.set_profile_facade(facade)
	root.add_child(menu)
	await process_frame
	menu._select_roster_index(0)
	menu.menu_tabs.current_tab = 0
	_check(not menu.attribute_increment_buttons[&"str"].disabled and menu.attribute_increment_buttons[&"int"].disabled, "menu disables each purchase using its own cost")
	_check(menu.attribute_increment_buttons[&"str"].text.contains("2 pontos") and menu.attribute_increment_buttons[&"int"].text.contains("3 pontos"), "costs are visible without hovering")
	_check(menu.attribute_preview_labels[&"int"].text.contains("Próximo marco: 18") and menu.attribute_preview_labels[&"int"].text.contains("→") and menu.attribute_preview_labels[&"int"].text.contains("Saldo insuficiente"), "visible row explains threshold, projected gain and insufficient funds")
	_check(menu.attribute_preview_labels[&"int"].text.contains("0.964 → 0.963"), "small cast gains remain visible instead of rounding both sides to the same number")
	if DisplayServer.get_name() != "headless":
		var ancestor: Node = menu.progression_panel.get_parent()
		while not ancestor is ScrollContainer:
			ancestor = ancestor.get_parent()
		var attributes_scroll := ancestor as ScrollContainer
		for extent: Vector2i in [Vector2i(1280,720), Vector2i(1920,1080)]:
			root.size = extent
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			_check(menu.get_global_rect().encloses(menu.start_run_button.get_global_rect()), "start action remains inside rendered viewport")
			root.get_texture().get_image().save_png("res://.godot/verification/stat_attributes_%dx%d.png" % [extent.x,extent.y])
			attributes_scroll.ensure_control_visible(menu.attribute_increment_buttons[&"luk"].get_parent() as Control)
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			_check(attributes_scroll.get_global_rect().encloses(menu.attribute_increment_buttons[&"luk"].get_global_rect()), "last attribute remains reachable by scrolling")
			_check(attributes_scroll.get_global_rect().encloses(menu.attribute_preview_labels[&"luk"].get_global_rect()), "last attribute details remain readable by scrolling")
			root.get_texture().get_image().save_png("res://.godot/verification/stat_attributes_%dx%d_bottom.png" % [extent.x,extent.y])
			attributes_scroll.scroll_vertical = 0
	var bought := menu._allocate_attribute(&"str")
	var actual := facade.build_preview(id)
	_check(bought["ok"] and bought["spent"] == 2 and _same_values(strength["after"], actual["stat_breakdown"]), "real menu transaction matches read-only projection exactly")
	_check(menu.attribute_increment_buttons[&"str"].disabled and menu.attribute_increment_buttons[&"int"].disabled, "zero remaining funds disable every purchase after refresh")
	menu.queue_free()
	await process_frame
	var reloaded := ProfileFacade.new(ProfileStore.new(directory.path_join("mage")))
	_check(reloaded.open_profile()["ok"] and _same_values(actual["stat_breakdown"], reloaded.build_preview(id)["stat_breakdown"]), "reload reproduces purchased stats without stored balances")
	var started := reloaded.start_run("preview-run", reloaded.current_profile().revision)
	_check(started["ok"] and _same_values(actual["stat_breakdown"], started["run_state"].build_snapshot.stat_breakdown()), "run snapshot matches purchased and reloaded stats")
	_check(reloaded.attribute_purchase_preview(id, &"vit")["blocking_reason"] == &"run_active", "projection cannot authorize menu purchases in an active run")
	_test_actor_threshold_crossing(started["run_state"])
	_test_allocation_passive_and_cap()
	print("Stat threshold preview integration: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(1 if failures else 0)

func _test_allocation_passive_and_cap() -> void:
	var character := CharacterState.new(IdentityIds.character_id(PROFILE_ID,1), "Sede", &"swordsman")
	character.base_xp_total = ProgressionRules.MAX_BASE_XP
	character.job_xp_total = ProgressionRules.MAX_JOB_XP
	character.evolution_id = &"berserker"
	character.purchased_skill_ranks = {&"slash":3, &"blood_thirst":1}
	character.attribute_allocations[&"str"] = 52
	var facade := _facade("passive",character)
	var vit := facade.attribute_purchase_preview(character.character_id, &"vit")
	_check(vit["after"].value(&"melee_attack") > vit["before"].value(&"melee_attack"), "VIT projection recalculates allocation-dependent Blood Thirst")
	var result := facade.allocate_attributes("passive-buy",facade.current_profile().revision,character.character_id,{&"vit":1})
	_check(result["ok"] and _same_values(vit["after"],facade.build_preview(character.character_id)["stat_breakdown"]), "passive projection equals committed canonical build")
	var capped := facade.attribute_purchase_preview(character.character_id,&"str")
	_check(not capped["can_purchase"] and capped["cost"] == -1 and capped["after"] == null and capped["blocking_reason"] == &"attribute_cap_reached", "permanent cap exposes no fictitious purchase")
	facade._read_only = true
	_check(facade.attribute_purchase_preview(character.character_id,&"vit")["blocking_reason"] == &"profile_read_only", "read-only state overrides affordable projection")

func _test_actor_threshold_crossing(state: RunState) -> void:
	var actor := PlayerActor.new()
	root.add_child(actor)
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0,0,600,300),[],20.0)
	actor.configure(navigation,state)
	actor.set_process(false)
	var baseline := actor.stat_breakdown
	actor.health.current_hp -= 25.0
	actor.current_sp -= 17.0
	actor.attack_cooldown = 0.75
	actor.mage_cooldowns[&"fireball"] = 1.25
	var sources: Array[Dictionary] = [{"source_id":&"buff:thresholds", "primary_flat":{&"vit":5.0,&"int":3.0,&"dex":3.0}}]
	var crossed := state.build_snapshot.stat_breakdown(sources)
	actor._apply_derived_stats(crossed)
	_check(crossed.value(&"max_hp") > baseline.value(&"max_hp") and crossed.value(&"max_sp") > baseline.value(&"max_sp") and crossed.value(&"hit_rating") > baseline.value(&"hit_rating"), "runtime buff crosses HP SP and HIT milestones")
	_check(is_equal_approx(actor.health.max_hp-actor.health.current_hp,25.0) and is_equal_approx(actor.max_sp-actor.current_sp,17.0), "threshold recalculation preserves missing HP and SP")
	actor._apply_derived_stats(baseline)
	_check(is_equal_approx(actor.health.max_hp-actor.health.current_hp,25.0) and is_equal_approx(actor.max_sp-actor.current_sp,17.0) and actor.attack_cooldown == 0.75 and actor.mage_cooldowns[&"fireball"] == 1.25, "removing buff preserves deficits and cooldowns")
	actor.queue_free()

func _facade(label: String, character: CharacterState) -> ProfileFacade:
	var profile := ProfileState.new(PROFILE_ID)
	profile.characters.append(character)
	profile.selected_character_id = character.character_id
	profile.next_character_counter = 2
	var store := ProfileStore.new(directory.path_join(label))
	_check(store.commit(profile)["ok"], "fixture committed only to isolated directory")
	var facade := ProfileFacade.new(store)
	_check(facade.open_profile()["ok"], "isolated facade opens")
	return facade

func _same_values(left: StatBreakdown, right: StatBreakdown) -> bool:
	for stat_id: StringName in StatCalculator.DERIVED_IDS:
		if not is_equal_approx(left.value(stat_id), right.value(stat_id)): return false
	for stat_id: StringName in IdentityIds.attribute_ids():
		if not is_equal_approx(left.primary_value(stat_id),right.primary_value(stat_id)): return false
	return true

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

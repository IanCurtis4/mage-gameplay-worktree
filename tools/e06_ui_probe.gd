extends SceneTree
## Native renderer inspection, isolated training/profile fixtures only.
const Publication = preload("res://tools/content/publication_bundle.gd")
const F = preload("res://tests/e06_tx_fixture.gd")
const OUTPUT := "res://.godot/verification/e06_ui/visual"
class FixedState extends CombatAnimationState:
	var chosen := 0
	func frame_index() -> int: return chosen
func _initialize() -> void:
	_run.call_deferred()
func _label(parent: Node, title: String, point: Vector2, size: int = 18) -> void:
	var label := Label.new()
	label.text = title
	label.position = point
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.save_png(OUTPUT.path_join(name + ".png")) != OK: push_error("capture failed"); quit(1)
	print("CAPTURE ", name, " pixels=", image.get_size(), " window=", root.size)
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var compiled := Publication.compile()
	if not compiled["ok"]: push_error(JSON.stringify(compiled)); quit(1); return
	var comparison := Publication.comparison("swordsman", 0, BuildContentLoader.pilot(), compiled["source_catalog"])
	if not comparison["ok"]: push_error(JSON.stringify(comparison)); quit(1); return
	var state := RunState.from_build("", comparison["snapshot"])
	state.set_effect_catalog(BuildContentLoader.pilot())
	RunController.pending_run_state = state
	RunController.pending_training_mode = true
	RunController.pending_run_facade = null
	var controller := RunController.new()
	root.add_child(controller)
	controller.set_process(false)
	controller.player.set_process(false)
	for actor: CombatActor in controller.enemies: actor.set_process(false)
	controller.encounter_active = false
	var profiles := ProfileCatalog.pilot()
	for id: StringName in profiles.equipment_ids():
		var already := false
		for instance: EquipmentInstance in controller.run_state.local_equipment_instances.values():
			if instance.definition_id == id: already = true
		if not already: controller.run_state.add_local_equipment(id, profiles.equipment_metadata(id))
	for index: int in 12: controller.run_state.card_inventory.grant(&"echo_card" if index % 2 == 0 else &"bulwark_card", controller.run_state.effect_catalog())
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = size
		await process_frame
		controller._open_inventory()
		controller.inventory_panel.slots.select(8)
		controller.inventory_panel.refresh_view()
		controller.inventory_panel.equipment_list.select(0)
		controller.inventory_panel.propose({"kind": &"unequip", "slot": &"head"})
		await _capture("inventory_%d" % size.x)
		controller.inventory_panel.dismiss()
	# Capture native offers with closed0/1/2/3 pools; do not publish fixtures.
	root.size = Vector2i(1280, 720)
	for count: int in 4:
		var source := BuildContentLoader.pilot()
		var pool := BuildEffectCatalog.new()
		pool.set_mob_catalog(source.mob_catalog())
		for definition: Resource in BuildContentLoader.definitions(&"set"): pool.register_set(definition)
		for origin: StringName in [&"equipment", &"card"]:
			for id: StringName in source.ids(origin): pool.register_definition(origin, source.get_definition(origin, id))
		for index: int in count:
			var definition := source.get_definition(&"augment", [&"vitality", &"keen_edge", &"battle_rhythm"][index]) as AugmentDefinition
			definition.display_name += " da Guarda da Arena demonstrativa"
			pool.register_definition(&"augment", definition)
		controller.run_state.set_effect_catalog(pool)
		controller.run_state.queue_choice()
		controller._open_augment_menu()
		await _capture("offers_%d" % count)
		if count > 0:
			var first: StringName = controller.run_state.current_offer[0].id
			controller._confirm_augment(first)
		controller.run_state.reset()
		controller.player.apply_run_modifiers(controller.run_state)
	controller.free()
	await process_frame
	# Each real policy offer uses its approved direction's learned preparations.
	var cases := [["spiritualist", 0, &"spiritualist_echo_fixed_origin"], ["spiritualist", 1, &"spiritualist_drain_inscription"], ["hunter", 0, &"hunter_marked_mechanism"], ["hunter", 1, &"hunter_covering_fan"], ["mg_ar", 0, &"geometer_ground_anchor"], ["mg_ar", 1, &"geometer_collapse_first_element"]]
	for entry: Array in cases:
		var source := BuildContentLoader.pilot()
		var build := Publication.comparison(entry[0], entry[1], source, compiled["source_catalog"])
		if not build["ok"]: push_error(JSON.stringify(build)); quit(1); return
		var policy_state := RunState.from_build("", build["snapshot"])
		var pool := BuildEffectCatalog.new()
		pool.set_mob_catalog(source.mob_catalog())
		for definition: Resource in BuildContentLoader.definitions(&"set"): pool.register_set(definition)
		for origin: StringName in [&"equipment", &"card"]:
			for id: StringName in source.ids(origin): pool.register_definition(origin, source.get_definition(origin, id))
		pool.register_definition(&"augment", source.get_definition(&"augment", entry[2]))
		policy_state.set_effect_catalog(pool)
		RunController.pending_run_state = policy_state
		RunController.pending_training_mode = true
		RunController.pending_run_facade = null
		var policy_controller := RunController.new()
		root.add_child(policy_controller)
		policy_controller.set_process(false)
		policy_controller.player.set_process(false)
		for actor: CombatActor in policy_controller.enemies: actor.set_process(false)
		policy_controller.encounter_active = false
		policy_state.queue_choice()
		policy_controller._open_augment_menu()
		if policy_state.current_offer.size() != 1:
			push_error("policy offer missing: " + String(entry[2])); quit(1); return
		var description := BuildPresentation.augment_progress(policy_controller, policy_state.current_offer[0])
		if not description.contains("transformação ativada"):
			push_error("policy preview missing: " + String(entry[2])); quit(1); return
		await _capture("policy_" + String(entry[2]))
		policy_controller._confirm_augment(entry[2])
		policy_controller.free()
		await process_frame
	var directory := ProjectSettings.globalize_path(OUTPUT.path_join("menu_profile"))
	var store := ProfileStore.new(directory)
	var facade := ProfileFacade.new(store)
	facade.create_character("visual-create", 0, "Guarda da Arena", &"swordsman")
	var profile := facade.current_profile()
	var catalog := ProfileCatalog.pilot()
	for id: StringName in catalog.equipment_ids(): F.own(profile, id, catalog)
	store.commit(profile)
	var menu := (load("res://scenes/character_menu.tscn") as PackedScene).instantiate() as CharacterMenu
	menu.set_profile_facade(ProfileFacade.new(store))
	root.add_child(menu)
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = size
		await process_frame
		for index: int in menu.menu_tabs.get_tab_count():
			if menu.menu_tabs.get_tab_title(index).to_lower().contains("equip"): menu.menu_tabs.current_tab = index
		await _capture("menu_%d" % size.x)
	menu.free()
	await process_frame
	root.size = Vector2i(1280, 720)
	var gallery := Node2D.new()
	root.add_child(gallery)
	for index: int in 2:
		var floor := ColorRect.new()
		floor.color = Color("192b31") if index == 0 else Color("cfcbc0")
		floor.position = Vector2(index * 640, 0)
		floor.size = Vector2(640, 720)
		gallery.add_child(floor)
	_label(gallery, "Elmo · frente / caminhada / ação / costas / dano · escuro e claro", Vector2(20, 12), 20)
	var kinds := [&"swordsman", &"mage", &"archer", &"defender", &"berserker", &"elementalist", &"spiritualist", &"geometer", &"sentinel", &"hunter"]
	for row: int in kinds.size():
		_label(gallery, String(kinds[row]), Vector2(12, 58 + row * 63), 14)
		for sample: int in 12:
			var actor := PlayerActor.new()
			actor.run_state = state
			actor.health = HealthState.new()
			actor.health.max_hp = 100
			actor.character_animation = CharacterAnimation.new()
			actor.character_animation.configure(kinds[row])
			var fixed := FixedState.new()
			fixed.chosen = [0, 4, 9, 16, 21, 24][sample % 6]
			fixed.back_view = sample % 6 in [3, 4]
			fixed.flip_h = sample % 2 == 1
			actor.character_animation.state = fixed
			actor.sprite_visual_scale = 1.0
			actor.position = Vector2(170 + (sample % 6) * 80 + (640 if sample >= 6 else 0), 109 + row * 63)
			gallery.add_child(actor)
			actor.set_process(false)
			var head := EquipmentHeadVisual.new()
			actor.add_child(head)
			head.configure(actor)
	await _capture("helm_poses")
	print("E06_UI_VISUAL_OK")
	quit(0)

extends SceneTree
const Publication = preload("res://tools/content/publication_bundle.gd")
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var catalog := BuildContentLoader.pilot()
	var compiled := Publication.compile()
	var blueprint := Publication.comparison("swordsman", 0, catalog, compiled["source_catalog"])
	assert(blueprint["ok"])
	var state := RunState.from_build("", blueprint["snapshot"])
	var meta := ProfileCatalog.pilot().equipment_metadata(&"arena_warden_mail")
	meta["power_ruleset_id"] = &"equipment_growth_v1"; meta["item_level"] = 30
	var added := state.add_local_equipment(&"arena_warden_mail", meta)
	assert(added["ok"])
	RunController.pending_run_state = state
	RunController.pending_run_facade = null
	RunController.pending_training_mode = true
	var controller := RunController.new()
	root.add_child(controller)
	controller.set_process(false); controller.player.set_process(false)
	for actor: CombatActor in controller.enemies: actor.set_process(false)
	controller.encounter_active = false
	root.size = Vector2i(1280, 720)
	controller._open_inventory()
	controller.inventory_panel.slots.select(4); controller.inventory_panel.refresh_view()
	var panel := controller.inventory_panel
	var tooltip := ""
	for index: int in panel.equipment_list.item_count:
		if panel.equipment_list.get_item_metadata(index) == added["instance_id"]:
			panel.equipment_list.select(index); panel.equipment_list.item_selected.emit(index)
			tooltip = panel.equipment_list.get_item_tooltip(index)
	if panel.confirm_button.disabled or not tooltip.contains("8.64"):
		push_error("native growth preview invalid: " + panel.status_label.text); quit(1); return
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://.godot/verification/e06_balance/native"
	DirAccess.make_dir_recursive_absolute(path)
	assert(root.get_texture().get_image().save_png(path.path_join("growth_inventory.png")) == OK)
	var key := InputEventKey.new(); key.keycode = KEY_ESCAPE; key.pressed = true
	controller._input(key)
	assert(not panel.visible and not paused)
	print("E06_BALANCE_NATIVE_OK growth8.64 preview canonical keyboardEsc")
	quit(0)

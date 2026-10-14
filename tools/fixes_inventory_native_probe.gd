extends SceneTree
## Native renderer evidence; explicit fixture profile, never the player's save.
var panel: RunInventoryPanel
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var large := "large" in OS.get_cmdline_user_args()
	var size := Vector2i(1920,1080) if large else Vector2i(1280,720)
	root.size = size
	var background := ColorRect.new()
	background.size = size
	background.color = Color("4f6e54")
	root.add_child(background)
	var hint := Label.new()
	hint.text = "Fixture gráfica isolada · janelas arrastáveis · coleção compartilhada"
	hint.position = Vector2(20,12)
	root.add_child(hint)
	var catalog := ProfileCatalog.pilot()
	var path := ProjectSettings.globalize_path("res://.godot/verification/e06_playtest_fixes/native_profile_%d" % Time.get_ticks_usec())
	var store := ProfileStore.new(path,catalog)
	var facade := ProfileFacade.new(store)
	assert(facade.create_character("create",0,"Candidata",&"swordsman")["ok"])
	var candidate := facade.current_profile()
	var character := candidate.characters[0]
	var loaded := BuildContentLoader.load_catalog(true)
	assert(loaded["ok"])
	var effects: BuildEffectCatalog = loaded["catalog"]
	for id: StringName in [&"class_set_swordsman_head",&"class_set_swordsman_torso",&"class_set_swordsman_feet",&"shared_sword",&"shared_shield"]:
		var definition := effects.get_definition(&"equipment",id) as EquipmentDefinition
		assert(definition != null)
		var metadata := definition.metadata()
		metadata["item_level"] = definition.min_item_level
		var added := candidate.add_equipment_instance(id,metadata)
		assert(added["ok"],str(added))
		character.equipped[definition.slot] = added["instance_id"]
	character.presets[character.selected_preset]["equipped"] = character.equipped.duplicate(true)
	for id: StringName in [&"bulwark_card",&"trail_card"]:
		assert(candidate.card_inventory.grant(id,effects,"native-fixture-"+String(id))["ok"])
	assert(store.commit(candidate)["ok"])
	facade = ProfileFacade.new(ProfileStore.new(path,catalog))
	assert(facade.open_profile()["ok"])
	panel = RunInventoryPanel.new()
	root.add_child(panel)
	panel.configure_profile(facade,character.character_id)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var suffix := "1920" if large else "1280"
	var image := root.get_texture().get_image()
	assert(image.save_png("res://.godot/verification/e06_playtest_fixes/inventory_equipment_%s.png" % suffix)==OK)
	panel.bag_tabs.current_tab = 3
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://.godot/verification/e06_playtest_fixes/inventory_cards_%s.png" % suffix)==OK)
	print("FIXES_INVENTORY_NATIVE ",JSON.stringify({"viewport":[size.x,size.y],"slots":panel.slot_buttons.size(),"tabs":panel.bag_tabs.get_tab_count(),"cards":panel.cards_list.item_count,"equipment_rect":str(panel.equipment_window.get_global_rect()),"bag_rect":str(panel.bag_window.get_global_rect())}))
	quit(0)

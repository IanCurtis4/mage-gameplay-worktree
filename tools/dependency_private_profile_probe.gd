extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size()==1)
	var directory := ProjectSettings.globalize_path("res://.godot/verification/dependency_private_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(directory)
	for file: String in [ProfileStore.PRIMARY_FILE,ProfileStore.BACKUP_FILE]:
		if FileAccess.file_exists(args[0].path_join(file)):
			assert(DirAccess.copy_absolute(args[0].path_join(file),directory.path_join(file))==OK)
	var before: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join(ProfileStore.PRIMARY_FILE)))
	var facade := ProfileFacade.new(ProfileStore.new(directory,ProfileCatalog.pilot()))
	var opened := facade.open_profile()
	assert(opened.get("ok",false),str(opened.get("error_code",&"")))
	var encoded := ProfileCodec.encode(facade.current_profile())
	assert(encoded["ok"])
	var after: Dictionary = JSON.parse_string(encoded["text"])
	assert(after["characters"].size()==before["characters"].size())
	for index: int in before["characters"].size():
		var original: Dictionary = before["characters"][index]
		var current: Dictionary = after["characters"][index]
		for key: String in ["character_id","base_class_id","evolution_id","base_xp_total","job_xp_total","granted_skill_ranks","attribute_allocations","equipped","presets","action_slots"]:
			assert(current[key]==original[key],key)
		for id: String in current["purchased_skill_ranks"]:
			assert(int(current["purchased_skill_ranks"][id])<=int(original["purchased_skill_ranks"].get(id,0)))
	for key: String in ["equipment_instances","card_inventory"]: assert(after[key]==before[key],key)
	var menu := (load("res://scenes/character_menu.tscn") as PackedScene).instantiate() as CharacterMenu
	menu.set_profile_facade(facade)
	root.add_child(menu)
	await process_frame
	assert(not menu._read_only and menu.roster_list.item_count==before["characters"].size())
	var created := false
	if before["characters"].size()<ProfileState.MAX_CHARACTERS:
		var result := facade.create_character("dependency-private-create",facade.current_profile().revision,"Teste isolado",&"swordsman")
		assert(result["ok"])
		created = true
	print("DEPENDENCY_PRIVATE_PROFILE_OK preserved_characters=",before["characters"].size()," create_new=",created," loot_preserved=true schema=",after["schema_version"]," catalog=",after["catalog_version"])
	quit(0)

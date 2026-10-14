extends SceneTree
## Copies a preserved private profile into an isolated fixture; never writes its source.
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 1)
	var source := args[0]
	var directory := ProjectSettings.globalize_path("res://.godot/verification/e06_profile_hotfix/private_probe_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(directory)
	for file: String in [ProfileStore.PRIMARY_FILE,ProfileStore.BACKUP_FILE]:
		assert(DirAccess.copy_absolute(source.path_join(file),directory.path_join(file))==OK)
	var before: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join(ProfileStore.PRIMARY_FILE)))
	var facade := ProfileFacade.new(ProfileStore.new(directory,ProfileCatalog.pilot()))
	var opened := facade.open_profile()
	print("PRIVATE_PROFILE_OPEN ",JSON.stringify({"ok":opened.get("ok",false),"error_code":opened.get("error_code",&""),"read_only":opened.get("read_only",false),"saved_characters":before["characters"].size()}))
	if not opened.get("ok",false): quit(1);return
	assert(facade.current_profile().characters.size()==before["characters"].size())
	var menu := (load("res://scenes/character_menu.tscn") as PackedScene).instantiate() as CharacterMenu
	menu.set_profile_facade(facade);root.add_child(menu)
	await process_frame
	assert(not menu._read_only and menu.roster_list.item_count==before["characters"].size() and not menu.create_button.disabled)
	menu.name_input.text = "Validação isolada"
	var result := menu.create_character(&"swordsman")
	assert(result["ok"],str(result))
	var after: Dictionary = JSON.parse_string(ProfileCodec.encode(facade.current_profile())["text"])
	for index: int in before["characters"].size(): assert(after["characters"][index] == before["characters"][index])
	for record: Dictionary in before["equipment_instances"]:
		var found := false
		for preserved: Dictionary in after["equipment_instances"]:
			if preserved["instance_id"]==record["instance_id"]: found = preserved==record
		assert(found)
	assert(after["characters"].size()==before["characters"].size()+1)
	print("PRIVATE_PROFILE_RECOVERY_OK original_characters_preserved=",before["characters"].size()," new_creation_ok=true schema=",after["schema_version"])
	quit(0)

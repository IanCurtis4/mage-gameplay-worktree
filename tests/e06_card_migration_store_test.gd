extends SceneTree
## Schema-4 durable migration must open the roster, preserve bytes and permit creation.
const F = preload("res://tests/e06_inventory_fixture.gd")
var checks := 0
var failures := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1;push_error(label)
func _write(directory: String,name: String,text: String) -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(directory.path_join(name),FileAccess.WRITE);file.store_string(text);file.close()
func _run() -> void:
	var base := ProjectSettings.globalize_path("res://.godot/verification/e06_profile_hotfix/store_%d" % Time.get_ticks_usec())
	var catalog := ProfileCatalog.pilot()
	var source := ProfileFacade.new(ProfileStore.new(base.path_join("source"),catalog))
	for index: int in 7: check(source.create_character("create-%d" % index,index,"Preservado %d" % index,&"swordsman")["ok"],"seven historical characters %d" % index)
	var raw: Dictionary = ProfileCodec.encode(source.current_profile(),catalog)["data"]
	raw.erase("card_inventory");raw["schema_version"]=4;raw["catalog_version"]=11
	var old := JSON.stringify(raw,"\t")
	var directory := base.path_join("real-migration")
	_write(directory,ProfileStore.PRIMARY_FILE,old)
	var previous := raw.duplicate(true);previous["revision"]-=1
	_write(directory,ProfileStore.BACKUP_FILE,JSON.stringify(previous))
	var facade := ProfileFacade.new(ProfileStore.new(directory,catalog))
	var opened := facade.open_profile()
	check(opened.get("ok",false) and opened.get("migrated",false),"durable schema4 migration opens facade")
	if not opened.get("ok",false): print(opened);_finish();return
	var after: Dictionary = ProfileCodec.encode(facade.current_profile(),catalog)["data"]
	for key: String in ["characters","equipment_instances","next_equipment_counter","next_character_counter","next_run_counter","selected_character_id","settings","lifetime_stats","legacy_loadouts","unresolved_legacy"]:check(after[key]==raw[key],"historical value preserved "+key)
	check(after["schema_version"]==6 and after["catalog_version"]==14 and after["revision"]==raw["revision"]+1,"only schema/catalog and one migration revision advance")
	check(facade.current_profile().card_inventory.describe()["owned"].is_empty(),"no discarded historical card reconstructed")
	check(FileAccess.get_file_as_string(directory.path_join(ProfileStore.BACKUP_FILE))==old,"exact original primary archived as backup")
	var before_reopen := FileAccess.get_file_as_string(directory.path_join(ProfileStore.PRIMARY_FILE))
	check(facade.open_profile()["ok"] and FileAccess.get_file_as_string(directory.path_join(ProfileStore.PRIMARY_FILE))==before_reopen,"reopen does not repeat migration or write")
	var menu := (load("res://scenes/character_menu.tscn") as PackedScene).instantiate() as CharacterMenu
	menu.set_profile_facade(facade);root.add_child(menu);await process_frame
	check(menu.roster_list.item_count==7 and not menu._read_only and not menu.create_button.disabled,"seven characters visible and creation enabled")
	menu.name_input.text="Oitavo personagem"
	check(menu.create_character(&"swordsman")["ok"] and facade.current_profile().characters.size()==8,"normal menu creates eighth character after migration")
	var current: Dictionary = ProfileCodec.encode(facade.current_profile(),catalog)["data"]
	for index: int in 7:check(current["characters"][index]==raw["characters"][index],"creation preserves original character %d" % index)
	menu.queue_free();await process_frame
	for stage: StringName in [&"write_pending",&"validate_pending",&"backup",&"replace"]:
		var target := base.path_join(String(stage));_write(target,ProfileStore.PRIMARY_FILE,old)
		var fault := F.FaultStore.new(target,catalog);fault.failure_stage=stage
		check(not fault.load_profile()["ok"] and FileAccess.get_file_as_string(target.path_join(ProfileStore.PRIMARY_FILE))==old,"failed migration keeps old primary "+String(stage))
		if stage!=&"write_pending":check(FileAccess.file_exists(target.path_join(ProfileStore.PENDING_FILE)) and not ProfileStore.new(target,catalog).load_profile()["ok"],"unconfirmed pending is preserved "+String(stage))
	var pending := base.path_join("pending");_write(pending,ProfileStore.PRIMARY_FILE,old);_write(pending,ProfileStore.PENDING_FILE,"user pending evidence")
	check(not ProfileStore.new(pending,catalog).load_profile()["ok"] and FileAccess.get_file_as_string(pending.path_join(ProfileStore.PENDING_FILE))=="user pending evidence","pending evidence blocks migration without removal")
	_finish()
func _finish() -> void:
	print("E06 durable card migration: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)

extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var start := Time.get_ticks_usec()
	var cold := BuildContentLoader.load_catalog_for_profile(ProfileCatalog.pilot())
	print("PERF cold_catalog_us=", Time.get_ticks_usec() - start, " ok=", cold["ok"])
	for iteration in range(3):
		start = Time.get_ticks_usec()
		var warm := BuildContentLoader.load_catalog_for_profile(ProfileCatalog.pilot())
		print("PERF warm_catalog_%d_us=" % iteration, Time.get_ticks_usec() - start, " ok=", warm["ok"])
	var profile_id := "123e4567-e89b-42d3-a456-426614174309"
	var character := CharacterState.new(IdentityIds.character_id(profile_id, 1), "Medição", &"mage")
	character.base_xp_total = 225
	var profile := ProfileState.new(profile_id)
	profile.characters.append(character)
	profile.selected_character_id = character.character_id
	profile.next_character_counter = 2
	var directory := ProjectSettings.globalize_path("res://.godot/verification/fixes_performance_fixture_%d" % Time.get_ticks_usec())
	var store := ProfileStore.new(directory)
	var committed := store.commit(profile)
	print("PERF fixture_commit_ok=", committed["ok"])
	var facade := ProfileFacade.new(store)
	var opened := facade.open_profile()
	print("PERF fixture_open_ok=", opened["ok"])
	if not opened["ok"]:
		quit(1)
		return
	for iteration in range(3):
		start = Time.get_ticks_usec()
		var count := 0
		for attribute_id: StringName in IdentityIds.attribute_ids():
			var preview := facade.attribute_purchase_preview(character.character_id, attribute_id)
			if preview["ok"]: count += 1
		print("PERF six_attribute_previews_%d_us=" % iteration, Time.get_ticks_usec() - start, " ok_count=", count)
	var build := facade.build_preview(character.character_id)
	print("PERF build_preview_ok=", build["ok"])
	if build["ok"]:
		for iteration in range(3):
			start = Time.get_ticks_usec()
			var state := RunState.from_build("perf_%d" % iteration, build["snapshot"])
			state.queue_choice()
			var rng := RandomNumberGenerator.new()
			rng.seed = 1777
			var offer := state.open_offer(false, rng)
			print("PERF run_init_offer_%d_us=" % iteration, Time.get_ticks_usec() - start, " ok=", offer["ok"])
	quit()


extends "res://tools/e10a_t16_effects_probe.gd"
## E10a T16 native evidence of the Acólito family flow (windowed, real renderer, 1280x720), on the candidate that
## already carries the T8 bodies (T10 captured it before they were integrated):
##   ui_creation_<state>       the creation tab (four bases) of a fresh profile, and the Acólito created and selected
##   ui_onboarding_<id>        the in-battle onboarding guide (expanded) over a real arena with the family body, for the
##                             Acólito base, the Sacerdote and the Cultista (production base and kits, real PlayerActor)
## Args: <output folder>. Run without --headless:
##   Godot --path . --script res://tools/e10a_t16_ui_probe.gd -- <folder>

func menu(label_text: String, character: CharacterState) -> CharacterMenu:
	var directory := ProjectSettings.globalize_path("res://.godot/verification/e10a_t16_ui/" + label_text)
	DirAccess.make_dir_recursive_absolute(directory)
	var catalog := ProfileCatalog.pilot()
	if character != null:
		var profile := ProfileState.new("123e4567-e89b-42d3-a456-426614174116")
		character.character_id = IdentityIds.character_id(profile.profile_id, profile.next_character_counter)
		profile.characters.append(character)
		profile.next_character_counter += 1
		profile.selected_character_id = character.character_id
		ProfileStore.new(directory, catalog).commit(profile)
	var node := (load("res://scenes/character_menu.tscn") as PackedScene).instantiate() as CharacterMenu
	node.set_profile_facade(ProfileFacade.new(ProfileStore.new(directory, catalog)))
	root.add_child(node)
	return node

func creation() -> void:
	var node := menu("fresh", null)
	await process_frame
	await process_frame
	check(node.create_buttons.size() == 4 and node.create_buttons[3].text == "Criar Acólito", "the creation tab lists four bases, the Acólito last")
	for scroll in node.find_children("*", "ScrollContainer", true, false): (scroll as ScrollContainer).scroll_vertical = 100000
	await process_frame
	await shot("ui_creation_fresh")
	node.queue_free()
	await process_frame
	var character := CharacterState.new("x", "Acólito de teste", &"acolyte")
	node = menu("created", character)
	await process_frame
	await process_frame
	await shot("ui_creation_acolyte_selected")
	node.queue_free()
	await process_frame

func onboarding(evolution: StringName, identity: StringName, title: String) -> void:
	var slots: Array[StringName] = [&"acolyte_punishing_light", &"acolyte_prayer", &"acolyte_votive_shield", &"acolyte_shadow_seal", &"acolyte_disturbing_whisper"]
	live_arena(evolution, slots, Vector2(220, 560))
	await process_frame
	var script := ClassKitRegistry.onboarding_script(identity)
	check(script != null, "onboarding script of " + String(identity))
	if script == null: return
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var guide: Control = script.new()
	guide.configure(player)
	layer.add_child(guide)
	await process_frame
	guide.toggle_button.pressed.emit()
	label(title + " · onboarding em combate com o corpo da família (T8)", Vector2(12, 6))
	await wait_seconds(0.3)
	await shot("ui_onboarding_" + String(identity))
	layer.queue_free()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	folder = args[0]
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1280, 720)
	await creation()
	await onboarding(&"", &"acolyte", "Acólito (base)")
	await onboarding(&"priest", &"priest", "Sacerdote")
	await onboarding(&"cultist", &"cultist", "Cultista")
	var file := FileAccess.open(folder.path_join("result_ui.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "captures": captures}, "  ") + "\n")
	file.close()
	print("E10a T16 ui: %d checks, %d captures, %d failures" % [checks, captures.size(), failures])
	quit(1 if failures > 0 else 0)

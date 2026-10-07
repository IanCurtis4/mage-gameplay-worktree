extends SceneTree
## Actual game/menu at native 1280x720, isolated legal profiles, no FPS claim.

const PROFILE_ID := "123e4567-e89b-42d3-a456-426614174275"
const CAPTURE_DIR := "res://.godot/verification/action_bar_game_native"
var checks := 0
var failures := 0
var captures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	for identity: Array in [[&"archer", &"sentinel"], [&"mage", &"mg_ar"], [&"mage", &"spiritualist"], [&"mage", &""]]:
		await _show_identity(identity[0], identity[1])
	print("Action bar game renderer: %d checks, %d captures, %d failures" % [checks, captures, failures])
	quit(1 if failures else 0)

func _show_identity(origin: StringName, evolution: StringName) -> void:
	var catalog := ProfileCatalog.pilot()
	var character := CharacterState.new(IdentityIds.character_id(PROFILE_ID, 1), "Prova visual", origin)
	character.evolution_id = evolution
	character.base_xp_total = ProgressionRules.MAX_BASE_XP
	character.job_xp_total = ProgressionRules.MAX_JOB_XP if not evolution.is_empty() else ProgressionRules.UNEVOLVED_MAX_JOB_XP
	for id: StringName in catalog.skill_ids_for_identity(origin, evolution):
		if int(catalog.effective_skill_ranks(origin, evolution, character.purchased_skill_ranks, character.granted_skill_ranks).get(id, 0)) == 0:
			_check(CharacterProgression.learn_skill(character, catalog, id)["ok"], "legal rank1 " + String(id))
	var summary := CharacterProgression.summary(character, catalog)
	var snapshot := BuildSnapshot.from_character(character, summary["base_level"], summary["job_level"], summary["effective_skill_ranks"], catalog.skill_ids_for_identity(origin, evolution), catalog)
	character.action_slots = ActionBarLayout.empty()
	var learned := snapshot.learned_skill_ids(ProfileCatalog.ACTIVE)
	for i: int in learned.size():
		character.action_slots[i] = learned[i]
	# Explicit final Alt slot demonstrates two-row layout with legal unique IDs.
	if not learned.is_empty():
		character.action_slots = ActionBarLayout.move(character.action_slots, learned.size() - 1, 23)
	snapshot.action_slots = character.action_slots.duplicate()
	RunController.pending_run_state = RunState.from_build("", snapshot)
	RunController.pending_training_mode = true
	var arena := (load("res://scenes/main.tscn") as PackedScene).instantiate() as RunController
	arena.control_preferences.path = ProjectSettings.globalize_path(CAPTURE_DIR + "/controls.cfg")
	root.add_child(arena)
	current_scene = arena
	arena.set_process(false)
	arena.player.set_process(false)
	arena.training_boss.set_process(false)
	arena.player.position = Vector2(850, 450)
	arena.training_boss.position = Vector2(1000, 550)
	for child: Node in arena.player.get_children():
		if child is Camera2D:
			child.position_smoothing_enabled = false
	arena._update_hud()
	await _frames(4)
	var bounds := Rect2(Vector2.ZERO, Vector2(1280, 720))
	_check(bounds.encloses(arena.battle_controls.skill_bar.get_global_rect()), "bar inside viewport " + String(evolution))
	_check(not arena.skill_label.visible and not arena.hud_panel.get_global_rect().intersects(arena.battle_controls.skill_bar.get_global_rect()), "HUD cannot overlap lower actions")
	for button: Button in arena.battle_controls.slot_buttons:
		_check(bounds.encloses(button.get_global_rect()), "slot fits")
	var label := String(evolution if not evolution.is_empty() else origin)
	await _capture(label + "_game")
	if evolution == &"sentinel":
		arena._toggle_settings(true)
		await _frames(4)
		_check(bounds.encloses(arena.battle_controls.settings_panel.get_global_rect()), "actual paused editor bounds")
		await _capture(label + "_settings")
		arena._toggle_settings(false)
	paused = false
	arena.free()
	current_scene = null
	await _frames(2)
	var directory := ProjectSettings.globalize_path(CAPTURE_DIR + "/" + label + "_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(directory)
	var profile := ProfileState.new(PROFILE_ID)
	profile.characters.append(character)
	profile.selected_character_id = character.character_id
	profile.next_character_counter = 2
	var store := ProfileStore.new(directory, catalog)
	_check(store.commit(profile)["ok"], "isolated legal profile committed")
	var menu := (load("res://scenes/character_menu.tscn") as PackedScene).instantiate() as CharacterMenu
	menu.action_preferences.path = ProjectSettings.globalize_path(CAPTURE_DIR + "/controls.cfg")
	menu.set_profile_facade(ProfileFacade.new(store))
	root.add_child(menu)
	menu.menu_tabs.current_tab = 1
	await _frames(4)
	_check(bounds.encloses(menu.menu_tabs.get_global_rect()), "skills page fits")
	_check(bounds.encloses(menu.start_run_button.get_global_rect()), "menu footer fits")
	var right_scroll := menu.action_editor.get_parent().get_parent().get_parent() as ScrollContainer
	_check(menu.action_editor.size.x <= right_scroll.size.x, "editor no horizontal clipping")
	await _capture(label + "_menu")
	menu.free()
	await _frames(2)

func _frames(count: int) -> void:
	for _i: int in count:
		await process_frame

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
	_check(root.get_texture().get_image().save_png(CAPTURE_DIR + "/" + label + ".png") == OK, "capture " + label)
	captures += 1

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

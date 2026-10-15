extends SceneTree
## Skill consultation is read-only in an active run and stays bounded at common viewports.

const F = preload("res://tests/e06_inventory_fixture.gd")

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var fixture := F.make(self, "skill_window", &"mage")
	var controller: RunController = fixture["controller"]
	await process_frame
	await _check_main_window(controller, Vector2i(1280, 720))
	await _check_main_window(controller, Vector2i(1920, 1080))
	await _check_pending_discard()
	var profile: ProfileState = fixture["facade"].current_profile()
	var character: CharacterState = profile.character_by_id(controller.run_state.build_snapshot.character_id)
	var xp_before := character.base_xp_total
	var ranks_before := character.purchased_skill_ranks.duplicate(true)
	var record_before := ProfileCodec.encode(profile, ProfileCatalog.pilot())
	controller.training_mode = true
	controller._open_skill_window()
	_check(controller.skill_window.visible and paused, "training opens the same read-only skills consultation")
	_check(not controller.skill_window.draft.editable and controller.skill_window.draft.facade == null and controller.skill_window.draft.sequence.is_empty(), "training consultation cannot stage persistent skill ranks")
	_check(character.base_xp_total == xp_before and character.purchased_skill_ranks == ranks_before, "opening and closing training consultation does not grant XP or ranks")
	controller.skill_window.dismiss()
	await process_frame
	_check(ProfileCodec.encode(profile, ProfileCatalog.pilot())["text"] == record_before["text"] and character.base_xp_total == xp_before and character.purchased_skill_ranks == ranks_before, "training consultation leaves profile XP and ranks byte-equivalent")
	var preview := SkillPresentation.run_preview(controller.run_state, controller.persistent_facade)
	var embedded := SkillWindow.new()
	embedded.set_embedded(true)
	embedded.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	embedded.configure_catalog(preview["skills"], preview["summary"], preview["base_class_id"])
	root.add_child(embedded)
	root.size = Vector2i(880, 640)
	embedded.size = Vector2(880, 640)
	await process_frame
	_check(Rect2(Vector2.ZERO, Vector2(880, 640)).encloses(embedded.get_global_rect()) and embedded.skill_panel.size.x > 0 and embedded.detail_panel.size.x > 0, "embedded skill window fits an 880 by 640 host")
	_check(embedded._scroll.get_v_scroll_bar().max_value > 0.0, "embedded catalog retains independent scrolling")
	embedded.queue_free()
	await process_frame
	controller.queue_free()
	await process_frame
	for file_name: String in DirAccess.get_files_at(String(fixture["directory"])):
		DirAccess.remove_absolute(String(fixture["directory"]).path_join(file_name))
	DirAccess.remove_absolute(String(fixture["directory"]))
	print("E06 skill window: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _check_main_window(controller: RunController, extent: Vector2i) -> void:
	root.size = extent
	await process_frame
	controller._open_skill_window()
	await process_frame
	var window: SkillWindow = controller.skill_window
	var viewport := Rect2(Vector2.ZERO, Vector2(extent))
	var run_ranks_before := controller.run_state.build_snapshot.skill_ranks.duplicate(true)
	_check(window.visible and paused, "open pauses the run and shows skills at %s" % extent)
	_check(viewport.encloses(window.get_global_rect()) and window.skill_panel.size.x > 0 and window.detail_panel.size.x > 0, "both panels fit the viewport at %s" % extent)
	_check(controller.battle_controls.action_editor.get_parent() == window.action_host and controller.battle_controls.action_editor.slots_grid.columns == 6, "real action editor moves into the consultation and uses six columns")
	_check(controller.battle_controls.action_editor.slots_grid.get_child_count() == 24, "action editor retains all 24 shortcut slots")
	_check(window.skill_entries.has(&"fire_spear") and window.skill_entries[&"fire_spear"]["option"]["rank"] == 1, "active run displays its actual learned rank")
	_check(window._jobs == [&""] and window._tabs.get_child_count() == 1, "job tabs show only the possessed base job when no evolution is owned")
	var fire: Dictionary = window.skill_entries[&"fire_spear"]
	fire["button"].pressed.emit()
	_check(window._details.text.contains("Investimento total") and fire["button"].tooltip_text.contains("R1/"), "selecting a skill shows canonical effect, investment, and its displayed rank")
	_check(fire["button"].get_child(0).size == Vector2(32, 32), "skill card icon uses the compact 32-pixel size")
	_check(window._rank_picker.visible and window._rank_picker.item_count == 2, "rank picker offers highest and confirmed R1 choices only")
	window._rank_picker.select(1)
	window._rank_picker.item_selected.emit(1)
	fire = window.skill_entries[&"fire_spear"]
	_check(fire["button"].drag_payload() == {"kind": "action_skill", "skill_id": &"fire_spear", "rank": 1, "source_index": -1}, "confirmed active drag payload carries its explicit rank and library source")
	var passive_drag := false
	for candidate: Variant in window.skill_entries.keys():
		var candidate_id := StringName(candidate)
		var candidate_def := ClassCatalog.skill_definition(candidate_id)
		if candidate_def != null and candidate_def.category == SkillDefinition.Category.PASSIVE:
			passive_drag = window.skill_entries[candidate]["button"].drag_payload() == null
			break
	_check(passive_drag, "passive skill cards never produce an action-bar drag payload")
	var light_theme := Theme.new()
	light_theme.set_color("font_color", "Label", Color("263b54"))
	var tooltip := (fire["button"] as Button)._make_custom_tooltip(fire["button"].tooltip_text) as Control
	tooltip.theme = light_theme
	var tooltip_scroll := tooltip.get_child(0) as ScrollContainer
	var tooltip_content := tooltip_scroll.get_child(0) as RichTextLabel
	var tooltip_foreground := tooltip_content.get_theme_color("default_color")
	var tooltip_luminance := 0.2126 * _linear_channel(tooltip_foreground.r) + 0.7152 * _linear_channel(tooltip_foreground.g) + 0.0722 * _linear_channel(tooltip_foreground.b)
	_check(tooltip_content.bbcode_enabled and tooltip_content.text.contains("[b]"), "skill tooltip renders emphasized details through RichTextLabel")
	_check(tooltip_luminance >= 0.8, "skill tooltip keeps readable light text under a light lobby theme")
	await process_frame
	_check(tooltip_scroll.custom_minimum_size.y <= 580.0 and tooltip_scroll.get_v_scroll_bar().max_value >= 0.0, "skill tooltip content stays inside a bounded scroll viewport")
	tooltip.free()
	var icon_categories_match := true
	for skill_id: Variant in window.skill_entries:
		var entry: Dictionary = window.skill_entries[skill_id]
		var definition := ClassCatalog.skill_definition(StringName(skill_id))
		var icon := entry["button"].get_child(0) as TextureRect
		var expected_category: StringName = ProfileCatalog.ACTIVE if definition != null and definition.category == SkillDefinition.Category.ACTIVE else ProfileCatalog.PASSIVE
		if definition == null or icon.texture != SkillPresentation.icon(StringName(skill_id)) or StringName(entry["option"]["metadata"]["category"]) != expected_category:
			icon_categories_match = false
	_check(icon_categories_match, "each skill icon and category matches its catalog metadata")
	var count := window.skill_entries.size()
	var view_switch := window.skill_panel.get_node("ViewSwitch") as Button
	if not window._tree:
		view_switch.pressed.emit()
		count = window.skill_entries.size()
	view_switch.pressed.emit()
	_check(not window._tree and window.skill_entries.size() == count, "list view preserves the same published skill choices")
	_check(window._scroll.get_v_scroll_bar().max_value > 0.0 and window._canvas.custom_minimum_size.y > window._scroll.size.y, "skill catalog scrolls independently when content exceeds its viewport")
	var close := window.detail_panel.get_node("Close") as Button
	close.pressed.emit()
	await process_frame
	_check(not window.visible and not paused and controller.battle_controls.action_editor.get_parent() != window.action_host and controller.battle_controls.action_editor.slots_grid.columns == 12, "close restores the action editor and resumes the run")
	controller._open_skill_window()
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	controller.get_viewport().push_input(escape)
	await process_frame
	_check(not window.visible and not paused, "viewport Escape closes the skill window before opening settings")
	var entry: Dictionary = window.skill_entries.get(&"fire_spear", {})
	_check(not entry.is_empty() and entry["plus"].disabled and not window.draft.editable, "run-local skill view remains read-only")
	_check(controller.run_state.build_snapshot.skill_ranks == run_ranks_before, "read-only view leaves the run snapshot ranks unchanged")

func _check_pending_discard() -> void:
	var directory := ProjectSettings.globalize_path("res://.godot/verification/e06_skill_window_editor")
	DirAccess.make_dir_recursive_absolute(directory)
	var catalog := ProfileCatalog.pilot()
	var facade := ProfileFacade.new(ProfileStore.new(directory, catalog), ProfileRewardResolver.pilot_progression())
	var created := facade.create_character("skill-window-character", 0, "Consulta", &"mage")
	_check(created["ok"], "isolated UI fixture creates a real catalog-backed mage")
	var character_id := String(created["character_id"])
	var granted := facade.grant_playtest_progression("skill-window-xp", facade.current_profile().revision, character_id, &"max_levels")
	_check(granted["ok"], "isolated UI fixture funds its canonical skill wallet")
	var window := SkillWindow.new()
	window.set_embedded(true)
	root.add_child(window)
	window.configure(facade, character_id, true)
	await process_frame
	var before := ProfileCodec.encode(facade.current_profile(), catalog)
	var plus: Button = window.skill_entries[&"fire_spear"]["plus"]
	_check(not plus.disabled, "funded persistent consultation exposes an enabled pending-rank control")
	plus.pressed.emit()
	_check(window.draft.sequence == [&"fire_spear"] and int(window.skill_entries[&"fire_spear"]["option"]["rank"]) == 1 and window.draft.preview["original_ranks"].get(&"fire_spear", 0) == 0 and facade.current_profile().character_by_id(character_id).purchased_skill_ranks.get(&"fire_spear", 0) == 0, "plus stages a preview while durable ranks remain unchanged")
	_check(window.skill_entries[&"fire_spear"]["button"].drag_payload() == null, "a pending, unconfirmed rank cannot be dragged into the action bar")
	(window.skill_panel.get_node("ViewSwitch") as Button).pressed.emit()
	window._undo.pressed.emit()
	var after := ProfileCodec.encode(facade.current_profile(), catalog)
	_check(window.draft.sequence.is_empty() and window.skill_entries[&"fire_spear"]["option"]["rank"] == 0 and before["text"] == after["text"], "discard removes pending edits without changing the profile")
	window.queue_free()
	await process_frame
	for file_name: String in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file_name))
	DirAccess.remove_absolute(directory)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _linear_channel(value: float) -> float:
	return value / 12.92 if value <= 0.04045 else pow((value + 0.055) / 1.055, 2.4)

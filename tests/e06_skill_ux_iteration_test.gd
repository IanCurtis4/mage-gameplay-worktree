extends SceneTree
## Focused UI checks for rank-aware skill assignment and its presentation contract.

const F = preload("res://tests/e06_inventory_fixture.gd")

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var fixture := F.make(self, "skill_ux_iteration", &"mage")
	var controller: RunController = fixture["controller"]
	controller._open_skill_window()
	await process_frame
	var window: SkillWindow = controller.skill_window
	var controls: BattleControls = controller.battle_controls
	var editor: ActionBarEditor = controls.action_editor
	_check(window.visible and paused, "skill consultation opens without leaving the run")
	_check(window._options.size() == window.skill_entries.size() and not window._options.is_empty(), "visible choices and cards share the available skill set")
	var jobs_match := window._jobs.size() >= 1 and window._jobs.has(&"")
	for option: Dictionary in window._options:
		var id := StringName(option["skill_id"])
		var definition := ClassCatalog.skill_definition(id)
		var job := StringName(option["metadata"].get("required_evolution_id", &""))
		if not option.get("available", false) or definition == null or not window._jobs.has(job): jobs_match = false
	_check(jobs_match, "job tabs contain only owned, available source and item skills")
	var all_icons_compact := true
	for id: Variant in window.skill_entries:
		var entry: Dictionary = window.skill_entries[id]
		var icon := (entry["button"] as Button).get_child(0) as TextureRect
		if icon.size != Vector2(32, 32) or icon.texture == null: all_icons_compact = false
	_check(all_icons_compact, "all available skill cards have a loaded 32-pixel icon")
	var skill_id: StringName = &"fire_spear"
	_check(window.skill_entries.has(skill_id), "fixture exposes the mage's confirmed active skill")
	if window.skill_entries.has(skill_id):
		window.skill_entries[skill_id]["button"].pressed.emit()
		var picker: OptionButton = window._rank_picker
		var rank_one_index := -1
		for index: int in picker.item_count:
			if picker.get_item_id(index) == 1: rank_one_index = index
		_check(picker.visible and rank_one_index >= 0, "rank picker offers explicit R1 when R1 is confirmed and supported")
		if rank_one_index >= 0:
			picker.select(rank_one_index)
			picker.item_selected.emit(rank_one_index)
			var refreshed: Dictionary = window.skill_entries[skill_id]
			_check(refreshed["button"].drag_payload() == {"kind": "action_skill", "skill_id": skill_id, "rank": 1, "source_index": -1}, "selected confirmed rank produces the canonical library drag payload")
			var payload := {"kind": "action_skill", "skill_id": skill_id, "rank": 1, "source_index": -1}
			var prior_slot: Variant = controls.action_slots[4]
			editor.slot_buttons[4]._drop_data(Vector2.ZERO, payload)
			var assigned := ActionBarLayout.skill_id(controls.action_slots[4]) == skill_id and ActionBarLayout.selected_rank(controls.action_slots[4]) == 1
			if not assigned:
				print("SKILL_DROP_DIAGNOSTIC ", {"learned": controls.learned_skills.has(skill_id), "battle_available_ranks": controls.available_ranks, "editor_available_ranks": editor.available_ranks, "payload": payload, "slot_before": prior_slot, "slot_after": controls.action_slots[4], "connections": editor.assignment_requested.get_connections().size(), "status": controller.status_label.text, "profile_revision": controller.persistent_facade.current_profile().revision, "snapshot_rank": controller.run_state.build_snapshot.skill_ranks.get(skill_id, 0)})
			_check(assigned, "drop routes explicit rank to the selected shortcut")
			editor.slot_buttons[5]._drop_data(Vector2.ZERO, {"kind": "action_skill", "skill_id": skill_id, "rank": 0, "source_index": -1})
			_check(ActionBarLayout.skill_id(controls.action_slots[5]) == skill_id and ActionBarLayout.selected_rank(controls.action_slots[5]) == 0, "same skill can occupy a second shortcut at highest rank")
			var before_forgery := controls.action_slots.duplicate(true)
			editor.slot_buttons[6]._drop_data(Vector2.ZERO, {"kind": "action_skill", "skill_id": skill_id, "rank": 2, "source_index": -1})
			_check(controls.action_slots == before_forgery, "payload cannot assign a rank above effective access")
			_check(ActionBarLayout.valid(controls.action_slots, controls.learned_skills, ItemSkillAdapters.IDS), "rank variants leave the full shortcut layout valid")
	var passive_drag_rejected := false
	for raw_id: Variant in window.skill_entries:
		var id := StringName(raw_id)
		var definition := ClassCatalog.skill_definition(id)
		if definition != null and definition.category == SkillDefinition.Category.PASSIVE:
			passive_drag_rejected = window.skill_entries[raw_id]["button"].drag_payload() == null
			break
	_check(passive_drag_rejected, "passive cards cannot create action-bar payloads")
	var tooltip := SkillTooltip.create("[b]Efeito[/b]\n" + "Detalhe de escala. ".repeat(300)) as SkillTooltip.BoundedTooltip
	root.add_child(tooltip)
	await process_frame
	var tooltip_bounds := tooltip.scrolling.custom_minimum_size.y <= 580.0 and tooltip.content.bbcode_enabled and tooltip.content.text.contains("[b]Efeito[/b]")
	_check(tooltip_bounds, "rich tooltip renders emphasis while limiting its scroll region")
	_check(tooltip.content.size.x <= 440.0 and tooltip.scrolling.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "long tooltip wraps within its bounded width")
	tooltip.queue_free()
	controller.queue_free()
	await process_frame
	for file_name: String in DirAccess.get_files_at(String(fixture["directory"])):
		DirAccess.remove_absolute(String(fixture["directory"]).path_join(file_name))
	DirAccess.remove_absolute(String(fixture["directory"]))
	print("E06 skill UX iteration: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

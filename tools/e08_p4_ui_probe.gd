extends SceneTree
## Current native UI proof, canonical admin fixture and isolated persisted profiles.
const IDENTITIES := [[&"swordsman", &""], [&"archer", &""], [&"mage", &""], [&"swordsman", &"berserker"], [&"swordsman", &"defender"], [&"archer", &"hunter"], [&"archer", &"sentinel"], [&"mage", &"elementalist"], [&"mage", &"spiritualist"], [&"mage", &"mg_ar"]]
const PROFILE_ID := "123e4567-e89b-42d3-a456-426614174289"
var folder := ""
var checks := 0
var failures: Array[String] = []
var records: Array[Dictionary] = []
var captures: Array[String] = []

func _initialize() -> void: _run.call_deferred()
func check(value: bool, label: String) -> bool:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)
	return value
func settle() -> void:
	for i: int in 5: await process_frame
func shot(label: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	var path := folder.path_join(label+".png")
	if check(root.get_texture().get_image().save_png(path) == OK, "capture "+label): captures.append(path.get_file())
func rect(control: Control) -> Rect2: return GuiMetrics.visual_rect(control)
func inside(control: Control) -> bool:
	return control != null and control.is_visible_in_tree() and control.size.x > 0 and control.size.y > 0 and Rect2(Vector2.ZERO,Vector2(root.size)).grow(1).encloses(rect(control))
func click(position: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var e := InputEventMouseButton.new(); e.position=position; e.global_position=position; e.button_index=button; e.pressed=true
	root.push_input(e,true)
	e=e.duplicate(); e.pressed=false; root.push_input(e,true)
	await settle()

func _run() -> void:
	if DisplayServer.get_name() == "headless": push_error("native renderer required"); quit(1); return
	folder=OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1280,720)
	GuiMetrics.scale=1.2
	for identity: Array in IDENTITIES:
		if not await identity_ui(identity[0],identity[1]): break
	var out := {"checks":checks,"failures":failures,"records":records,"captures":captures,"ui_scale":GuiMetrics.scale,"viewport":str(root.size),"renderer":RenderingServer.get_video_adapter_name(),"interaction":"current drag payload/drop handlers plus native right click and settings click; no physical drag claim"}
	var file := FileAccess.open(folder.path_join("result.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(out,"  ",true)); file.close()
	print("E08 P4 Sol UI: %d checks, %d identities, %d captures, %d failures" % [checks,records.size(),captures.size(),failures.size()])
	quit(1 if not failures.is_empty() else 0)

func identity_ui(origin: StringName, evolution: StringName) -> bool:
	var label := "geometer" if evolution==&"mg_ar" else String(origin if evolution.is_empty() else evolution)
	var catalog := ProfileCatalog.pilot()
	var character := CharacterState.new(IdentityIds.character_id(PROFILE_ID,1),"Prova "+label,origin)
	character.evolution_id=evolution
	character.base_xp_total=ProgressionRules.MAX_BASE_XP
	character.job_xp_total=ProgressionRules.UNEVOLVED_MAX_JOB_XP if evolution.is_empty() else ProgressionRules.MAX_JOB_XP
	character.action_slots=ActionBarLayout.empty()
	var profile := ProfileState.new(PROFILE_ID)
	profile.characters.append(character); profile.selected_character_id=character.character_id; profile.next_character_counter=2
	var loaded := BuildContentLoader.load_catalog(true)
	if not check(loaded.get("ok",false), "effects catalog loaded"): return false
	for card: StringName in [&"bulwark_card",&"trail_card"]:
		if not check(profile.card_inventory.grant(card,loaded.catalog,"p4-sol-"+String(card),character.character_id).get("ok",false), "owned fixture card "+String(card)): return false
	for slot_id: StringName in [&"head",&"main_hand"]:
		for definition_id: StringName in catalog.equipment_ids():
			if not catalog.equipment_is_allowed(definition_id,slot_id,origin,evolution): continue
			var added := profile.add_equipment_instance(definition_id,catalog.equipment_metadata(definition_id),character.character_id)
			if not check(added.get("ok",false), "owned fixture equipment "+String(slot_id)): return false
			character.equipped[slot_id]=StringName(added.instance_id)
			break
	character.presets[character.selected_preset]["equipped"]=character.equipped.duplicate(true)
	var store := ProfileStore.new(folder.path_join("profiles/"+label),catalog)
	if not check(store.commit(profile).get("ok",false), "valid fixture persisted "+label): return false
	var facade := ProfileFacade.new(store)
	if not check(facade.open_profile().get("ok",false),"fixture reopened "+label): return false
	# All-icons UI fixture uses the existing explicit admin command. This is not
	# a claim that every rank can be bought simultaneously with a normal wallet.
	var unlock := PlaytestProfileAdmin.grant(facade,"p4-sol-unlock",facade.current_profile().revision,character.character_id,&"unlock_skills")
	if not check(unlock.get("ok",false),"canonical admin fixture unlock "+label): return false
	character=facade.current_profile().character_by_id(character.character_id)
	var summary := CharacterProgression.summary(character,catalog)
	var snapshot := BuildSnapshot.from_character(character,summary.base_level,summary.job_level,summary.effective_skill_ranks,catalog.skill_ids_for_identity(origin,evolution),catalog)
	var learned := snapshot.learned_skill_ids(ProfileCatalog.ACTIVE)
	if not check(learned.size()>1 and learned.size()<=24,"active icon fixture fits "+label): return false
	var slots := ActionBarLayout.empty()
	for i: int in learned.size(): slots=ActionBarLayout.assign(slots,learned[i],i)
	slots=ActionBarLayout.move(slots,learned.size()-1,23)
	if not check(facade.update_action_slots("p4-sol-layout",facade.current_profile().revision,character.character_id,slots).get("ok",false),"canonical fixture layout "+label): return false
	var menu := CharacterMenu.new()
	menu.action_preferences.path=folder.path_join("controls.cfg")
	menu.set_profile_facade(facade); root.add_child(menu); current_scene=menu
	menu.menu_tabs.current_tab=1
	await settle()
	var editor := menu.action_editor
	check(editor.slot_buttons.size()==24 and editor.library.get_child_count()==0, "current editor and intentional empty compatibility handle "+label)
	check(inside(menu.skill_window.skill_panel) and inside(menu.skill_window.detail_panel), "actual skill panels inside viewport "+label)
	var action_scroll := menu.skill_window.detail_panel.get_node("ActionScroll") as ScrollContainer
	check(inside(action_scroll), "actual action scroll inside UI120 viewport "+label)
	for slot: Button in editor.slot_buttons:
		action_scroll.ensure_control_visible(slot); await settle()
		check(rect(action_scroll).grow(1).encloses(rect(slot)), "menu slot reachable by scroll "+label)
	# Current skill window provides the drag payload. No obsolete library traversal.
	var button: SkillWindow.SkillButton
	for entry_id: StringName in menu.skill_window.skill_entries:
		var candidate := menu.skill_window.skill_entries[entry_id]["button"] as SkillWindow.SkillButton
		if candidate.drag_allowed: button=candidate; break
	if not check(button != null, "current active drag source "+label): menu.free(); return false
	var dragged_id := button.skill_id
	var payload: Dictionary = button.drag_payload()
	var destination := editor.slot_buttons[22] as ActionBarSlot
	check(destination._can_drop_data(Vector2.ZERO,payload), "current slot accepts current skill payload "+label)
	destination._drop_data(Vector2.ZERO,payload)
	await settle()
	check(ActionBarLayout.skill_id(editor.action_slots[22])==dragged_id, "current assignment route "+label)
	var saved := facade.current_profile().character_by_id(character.character_id)
	check(ActionBarLayout.skill_id(saved.action_slots[22])==dragged_id, "assignment persisted "+label)
	var moved := {"kind":"action_skill","skill_id":dragged_id,"rank":0,"source_index":22}
	(editor.slot_buttons[21] as ActionBarSlot)._drop_data(Vector2.ZERO,moved)
	await settle()
	check(ActionBarLayout.skill_id(editor.action_slots[21])==dragged_id and editor.action_slots[22]==null, "current movement route "+label)
	action_scroll.ensure_control_visible(editor.slot_buttons[21]); await settle()
	await shot(label+"_menu_120")
	await click(rect(editor.slot_buttons[21]).get_center(),MOUSE_BUTTON_RIGHT)
	check(editor.action_slots[21]==null, "native right click removes "+label)
	var inventory := RunInventoryPanel.new()
	menu.add_child(inventory); inventory.configure_profile(facade,character.character_id)
	await settle()
	check(inventory.slot_buttons.size()==14 and inventory.bag_tabs.get_tab_count()==4, "inventory actual fourteen slots/four tabs "+label)
	check(inside(inventory.equipment_window) and inside(inventory.bag_window), "inventory windows inside UI120 viewport "+label)
	await shot(label+"_equipment_120")
	inventory.bag_tabs.current_tab=3
	await settle()
	check(inventory.equipment_list.item_count>0, "equipment icons populated "+label)
	check(inventory.cards_list.item_count==2, "two owned cards shown "+label)
	if label=="sentinel": await shot(label+"_cards_120")
	inventory.free()
	character=facade.current_profile().character_by_id(character.character_id)
	menu.free(); current_scene=null; await settle()
	summary=CharacterProgression.summary(character,catalog)
	snapshot=BuildSnapshot.from_character(character,summary.base_level,summary.job_level,summary.effective_skill_ranks,catalog.skill_ids_for_identity(origin,evolution),catalog)
	snapshot.action_slots=character.action_slots.duplicate()
	RunController.pending_run_state=RunState.from_build("",snapshot); RunController.pending_training_mode=true
	var host := (load("res://scenes/main.tscn") as PackedScene).instantiate() as RunController
	host.control_preferences.path=folder.path_join("controls.cfg")
	root.add_child(host); current_scene=host
	host.set_process(false); host.player.set_process(false); host.training_boss.set_process(false)
	await settle()
	GuiMetrics.set_scale(1.2,host.ui_root)
	host._update_hud()
	await settle()
	check(inside(host.battle_controls.skill_bar) and host.battle_controls.slot_buttons.size()==24, "actual game bar inside UI120 viewport "+label)
	for slot: Button in host.battle_controls.slot_buttons:
		check(inside(slot), "game slot inside "+label)
	check(not rect(host.hud_panel).intersects(rect(host.battle_controls.skill_bar)), "HUD/action bar separated "+label)
	await shot(label+"_game_120")
	if label=="sentinel":
		await click(rect(host.battle_controls.settings_button).get_center())
		check(paused and host.battle_controls.settings_overlay.visible and inside(host.battle_controls.settings_panel),"native settings click opens bounded modal")
		await shot(label+"_settings_120")
		var e := InputEventKey.new(); e.pressed=true; e.keycode=KEY_ESCAPE; e.physical_keycode=KEY_ESCAPE; root.push_input(e,true)
		await settle()
		check(not paused and not host.battle_controls.settings_overlay.visible,"native Escape closes settings")
	records.append({"identity":label,"active_icons":learned.size(),"purchased_ranks":character.purchased_skill_ranks,"admin_skills_unlocked":character.admin_skills_unlocked,"profile_character":character.character_id,"menu_scale":1.2,"game_scale":host.ui_root.scale.x})
	paused=false; host.free(); current_scene=null; await settle()
	return failures.is_empty()

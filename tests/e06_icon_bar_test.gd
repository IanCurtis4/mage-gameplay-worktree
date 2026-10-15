extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var controls := BattleControls.new()
	root.add_child(controls)
	var slots := ActionBarLayout.empty()
	slots = ActionBarLayout.assign(slots,&"fireball",0,1)
	slots = ActionBarLayout.assign(slots,&"fireball",12,3)
	slots = ActionBarLayout.assign(slots,&"dash",1)
	controls.set_skill_ranks({&"fireball":5,&"dash":2})
	controls.set_action_bar([&"fireball",&"dash"],slots,ControlPreferences.new())
	await process_frame
	var first := controls.slot_buttons[0] as ActionBarSlot
	var third := controls.slot_buttons[12] as ActionBarSlot
	_check(controls.slot_buttons.size() == 24 and controls.skill_bar.columns == 12, "all24bindings remain")
	_check(first.text.is_empty() and first.icon == null and first.combat_icon.texture == SkillPresentation.icon(&"fireball"), "full face replaces side-by-side native text/icon")
	_check(first.key_hint.text == "1" and first.rank_hint.text == "R1" and third.rank_hint.text == "R3", "key and selected rank remain readable overlays")
	first.key_hint.text = "Ctrl+Alt+Shift+Espaço"
	await process_frame
	_check(first.key_hint.size.x <= first.size.x and first.size.is_equal_approx(Vector2(60,60)), "long binding hint cannot widen or overflow the icon slot")
	first.key_hint.text = "1"
	_check(first.size.is_equal_approx(Vector2(60,60)) and first.combat_icon.size.is_equal_approx(Vector2(54,54)), "square slot contains almost-full icon")
	_check(first.combat_icon.mouse_filter == Control.MOUSE_FILTER_IGNORE and first.cooldown_hint.mouse_filter == Control.MOUSE_FILTER_IGNORE, "visual overlays cannot intercept clicks")
	controls.show_skill_state(&"fireball","BOLA DE FOGO R1\n18 SP · RECARGA 999s",true,1)
	_check(first.text.is_empty() and first.tooltip_text.contains("18 SP") and first.tooltip_text.contains("RECARGA 999s") and first.button_pressed and not third.button_pressed, "description/state stays in tooltip and active version remains distinct")
	controls.show_skill_cooldown(&"fireball",8.0)
	_check(first.cooldown_fraction == 0.0 and first.cooldown_hint.text == "8.0", "numeric canonical remaining starts graphic cycle")
	controls.show_skill_cooldown(&"fireball",6.0)
	_check(first.cooldown_fraction == .25 and third.cooldown_fraction == .25 and first.cooldown_hint.text == "6.0", "versions share cooldown and numeric source overrides descriptive text")
	_check(first.combat_icon.material != third.combat_icon.material, "slot materials do not share mutable uniforms")
	controls.show_skill_cooldown(&"fireball",6.0)
	_check(first.cooldown_fraction == .25, "unchanged remaining during pause never advances visual time")
	controls.set_action_bar([&"fireball",&"dash"],slots,controls.control_preferences)
	first = controls.slot_buttons[0] as ActionBarSlot
	_check(first.cooldown_fraction == .25 and first.cooldown_hint.text == "6.0", "bar rebuild preserves observed cooldown")
	controls.show_skill_cooldown(&"fireball",10.0)
	_check(first.cooldown_fraction == 0.0 and first.cooldown_hint.text == "10", "renewed/increased cooldown restarts sweep and uses subtle whole seconds")
	controls.show_skill_cooldown(&"fireball",.7)
	_check(first.cooldown_hint.text == "0.7", "subsecond remaining is legible")
	controls.show_skill_cooldown(&"fireball",0.0)
	_check(first.cooldown_fraction == 1.0 and first.cooldown_hint.text.is_empty(), "ready clears overlay immediately")
	controls.show_skill_cooldown(&"fireball",4.0)
	_check(first.cooldown_fraction == 0.0, "next cooldown starts new observation")
	controls.show_skill_cooldown(&"fireball",-1.0)
	_check(first.cooldown_hint.text.is_empty(), "negative expiry is clamped to ready")
	controls.show_skill_state(&"fireball","BOLA DE FOGO R1\n18 SP · SEM SP",false,1)
	_check(first.combat_blocked and first.blocked_hint.text == "!" and first.text.is_empty(), "resource block has discreet marker and full tooltip")
	controls.show_skill_state(&"fireball","BOLA DE FOGO R1\n18 SP · PRONTO",false,1)
	_check(not first.combat_blocked and first.blocked_hint.text.is_empty(), "resource recovery clears marker")
	var empty := controls.slot_buttons[23] as ActionBarSlot
	_check(empty.combat_icon.texture == null and empty.text.is_empty() and empty.cooldown_hint.text.is_empty(), "empty slot keeps key only")
	var editor := controls.action_editor.slot_buttons[0] as ActionBarSlot
	_check(editor.combat_icon == null and editor.icon != null and not editor.text.is_empty(), "paused editor keeps its authored presentation")
	var retained := ActionBarLayout.assign(ActionBarLayout.empty(),&"fire_spear",0,1)
	controls.set_action_bar([&"dash"],retained,controls.control_preferences)
	first = controls.slot_buttons[0] as ActionBarSlot
	_check(first.disabled and first.combat_blocked and first.tooltip_text.contains("indisponível"), "lost access retains disabled slot and tooltip")
	controls.free()
	await process_frame
	print("E06 icon bar: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
func _check(value: bool, text: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(text)

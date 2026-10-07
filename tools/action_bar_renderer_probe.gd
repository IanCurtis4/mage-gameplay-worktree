extends SceneTree
## Renderer proof for the actual paused editor, including native Viewport drag routing.

const ControlsScript := preload("res://scripts/ui/battle_controls.gd")
const CAPTURE_DIR := "res://.godot/verification/action_bar_native"
var checks := 0
var failures := 0
var casts := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var background := ColorRect.new()
	background.color = Color("253d3c")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var title := Label.new()
	title.text = "Barra de ações · verificação de apresentação (1280×720)"
	title.position = Vector2(30, 100)
	root.add_child(title)
	var controls := ControlsScript.new()
	root.add_child(controls)
	var learned: Array[StringName] = [&"sentinel_headshot", &"sentinel_observe", &"sentinel_piercing_shot", &"sentinel_net_shot", &"sentinel_explosive_shot", &"sentinel_concussion_shot", &"sentinel_absolute_focus", &"double_shot", &"piercing_arrow", &"arrow_rain", &"extended_aim", &"snare_trap", &"explosive_trap", &"slowing_arrow", &"foliage_shelter"]
	var slots := ActionBarLayout.empty()
	for i: int in learned.size():
		slots[i] = learned[i]
	controls.set_action_bar(learned, slots, ControlPreferences.new())
	controls.set_options(CastIntent.Mode.RELEASE, true)
	controls.skill_selected.connect(func(_id: StringName) -> void: casts += 1)
	for id: StringName in learned:
		controls.show_skill_state(id, "Skill aprendida · R5\n20 SP · PRONTO", false)
	await _frames(3)
	var bounds := Rect2(Vector2.ZERO, Vector2(1280, 720))
	_check(bounds.encloses(controls.skill_bar.get_global_rect()), "battle bar bounds")
	for button: Button in controls.slot_buttons:
		_check(controls.skill_bar.get_global_rect().encloses(button.get_global_rect()), "individual slot fits")
	await _capture("battle")
	controls.settings_overlay.show()
	paused = true
	await _frames(3)
	_check(bounds.encloses(controls.settings_panel.get_global_rect()), "paused editor bounds")
	await _capture("editor")
	var source := controls.action_editor.library.get_child(0) as Control
	var destination := controls.action_editor.slot_buttons[23] as Control
	var start := source.get_global_rect().get_center()
	var end := destination.get_global_rect().get_center()
	_motion(start)
	await _frames(2)
	_button(start, true)
	await _frames(2)
	_motion(start + Vector2(25, 0), true)
	await _frames(3)
	_check(root.gui_is_dragging(), "real viewport drag began from learned library")
	_motion(end, true)
	await _frames(3)
	await _capture("drag")
	_button(end, false)
	await _frames(3)
	_check(controls.action_slots[23] == &"sentinel_headshot" and controls.action_slots[0] == null, "real library drop moves unique skill")
	_check(casts == 0, "drag never cast a skill")
	_check(ActionBarLayout.valid(controls.action_slots, learned), "real drag preserves canonical layout")
	await _capture("after_drop")
	paused = false
	root.remove_child(controls)
	controls.queue_free()
	root.remove_child(background)
	background.queue_free()
	root.remove_child(title)
	title.queue_free()
	await _frames(2)
	print("Action bar native: %d checks, %d failures · 4 captures" % [checks, failures])
	quit(1 if failures else 0)

func _motion(point: Vector2, held: bool = false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = Vector2(25, 0)
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	Input.parse_input_event(event)

func _button(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(event)

func _frames(count: int) -> void:
	for _i: int in count:
		await process_frame

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
	root.get_texture().get_image().save_png(CAPTURE_DIR + "/" + label + ".png")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

extends SceneTree
## Native viewport input: close hit area, drag bounds and world click isolation.

var checks := 0
var failures := 0
var closes := 0
var world_clicks := 0
var _input_scale := Vector2.ONE

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var world := Button.new()
	world.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	world.pressed.connect(func() -> void: world_clicks += 1)
	root.add_child(world)
	var panel := RunInventoryPanel.new()
	panel.closed.connect(func() -> void: closes += 1)
	root.add_child(panel)
	for extent: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = extent
		await process_frame
		panel._layout_windows()
		panel.show()
		await process_frame
		panel._layout_windows()
		await process_frame
		_input_scale = Vector2(extent) / panel.get_viewport_rect().size
		var logical_extent: Vector2i = Vector2i(panel.get_viewport_rect().size)
		_check(_inside(panel.equipment_window.get_global_rect(), logical_extent) and _inside(panel.bag_window.get_global_rect(), logical_extent), "both windows fit %s" % extent)
		_check(panel.slot_buttons.size() == 14 and panel.bag_tabs.get_tab_count() == 4, "fourteen slots and four bag tabs")
		for close_button: Button in panel.close_buttons:
			_check(close_button.size.x >= 44 and close_button.size.y >= 44, "close hit rect is at least 44 pixels")
			for sample: Vector2 in _five_points(close_button.get_global_rect()):
				panel.show()
				await process_frame
				var previous := closes
				_click(sample)
				await process_frame
				_check(closes == previous + 1 and not panel.visible, "close responds at %s within %s" % [sample, extent])
		panel.show()
		await process_frame
		var previous_world := world_clicks
		_click(panel.equipment_window.get_global_rect().position + Vector2(8, 72))
		await process_frame
		_check(world_clicks == previous_world, "window intercepts world click")
		_click(Vector2(15, 15))
		await process_frame
		_check(world_clicks == previous_world + 1, "outside window passes to underlying control")
		var header: Control = panel.equipment_window.get_child(0).get_node("DragHeader")
		var origin := header.get_global_rect().position + Vector2(30, 22)
		_press(origin)
		_motion(origin + Vector2(4000, 4000))
		_release(origin + Vector2(4000, 4000))
		await process_frame
		_check(_inside(panel.equipment_window.get_global_rect(), logical_extent), "drag clamps to viewport")
		panel._layout_windows()
	panel.queue_free()
	world.queue_free()
	await process_frame
	print("E06 inventory window input: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _five_points(rect: Rect2) -> Array[Vector2]:
	return [rect.position + Vector2(4, 4), rect.position + Vector2(rect.size.x - 4, 4), rect.position + Vector2(4, rect.size.y - 4), rect.end - Vector2(4, 4), rect.get_center()]

func _inside(rect: Rect2, extent: Vector2i) -> bool:
	return rect.position.x >= 0 and rect.position.y >= 0 and rect.end.x <= extent.x + 1 and rect.end.y <= extent.y + 1

func _click(at: Vector2) -> void:
	_press(at)
	_release(at)

func _press(at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.pressed = true
	event.position = at * _input_scale
	event.global_position = event.position
	root.push_input(event)

func _release(at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	event.position = at * _input_scale
	event.global_position = event.position
	root.push_input(event)

func _motion(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at * _input_scale
	event.global_position = event.position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

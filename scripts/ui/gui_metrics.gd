class_name GuiMetrics
extends RefCounted
## Scale the interface only; world coordinates and camera remain untouched.
const SCALE := 0.85

static func configure_root(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	var update := resize_root.bind(control)
	if not control.get_viewport().size_changed.is_connected(update):
		control.get_viewport().size_changed.connect(update)
		var viewport := control.get_viewport()
		control.tree_exiting.connect(func() -> void:
			if viewport.size_changed.is_connected(update): viewport.size_changed.disconnect(update)
		)
	resize_root(control)

static func resize_root(control: Control) -> void:
	if not is_instance_valid(control): return
	control.scale = Vector2.ONE * SCALE
	control.position = Vector2.ZERO
	control.size = control.get_viewport_rect().size / SCALE

static func local_extent(control: Control) -> Vector2:
	var transform_scale := control.get_global_transform_with_canvas().get_scale().abs()
	return control.get_viewport_rect().size / transform_scale

static func visual_rect(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)

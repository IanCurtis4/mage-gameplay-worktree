extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	var elementalist := CharacterAnimation.new()
	elementalist.configure(&"elementalist")
	_check(elementalist.actor_kind == &"elementalist" and elementalist.atlas != null and elementalist.atlas.get_size() == Vector2(256, 512), "Elementalist resolves its own 32-frame atlas")
	if elementalist.atlas != null:
		var bitmap := elementalist.atlas.get_image()
		var frames_valid := true
		for index: int in range(32):
			var region := Rect2i(Vector2i(index % 4 * 64, index / 4 * 64), Vector2i(64, 64))
			var frame := bitmap.get_region(region)
			var bounds := frame.get_used_rect()
			frames_valid = frames_valid and bounds.has_area() and bounds.end.y <= 59 and frame.get_pixel(0, 0).a == 0.0
		_check(frames_valid, "Elementalist keeps alpha gutters and the 32,58 foot contract in every frame")
	var mage := CharacterAnimation.new()
	mage.configure(&"mage")
	_check(mage.actor_kind == &"mage" and mage.atlas != elementalist.atlas, "base Mage keeps its original atlas")
	print("Elementalista visual: %s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

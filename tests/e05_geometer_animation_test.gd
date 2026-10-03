extends SceneTree
## Bitmap presentation contracts only; frames never authorize a combat action.

var checks := 0
var failures := 0

func _initialize() -> void:
	var animation := CharacterAnimation.new()
	animation.configure(&"geometer")
	_check(animation.actor_kind == &"geometer" and animation.atlas != null and animation.atlas.get_size() == Vector2(256, 512), "Geometer owns a full 32-frame atlas")
	if animation.atlas == null:
		quit(1)
		return
	var bitmap := animation.atlas.get_image()
	for index: int in range(32):
		var region := Rect2i(Vector2i(index % 4 * 64, index / 4 * 64), Vector2i(64, 64))
		var frame := bitmap.get_region(region)
		var bounds := frame.get_used_rect()
		_check(bounds.has_area() and bounds.position.x > 0 and bounds.end.x < 64 and bounds.end.y <= 59 and frame.get_pixel(0, 0).a == 0, "pose%d alpha gutters and cell containment" % index)
		_check(animation.source_region(index) == Rect2(region) and is_zero_approx(animation.destination_rect(index).position.y + bounds.end.y - 1), "pose%d integer sampling and opaque baseline at feet" % index)
		if index < 28:
			var boots: Array[int] = []
			for y: int in range(bounds.end.y - 6, bounds.end.y):
				for x: int in range(64):
					var pixel := frame.get_pixel(x, y)
					if pixel.a > 0.5 and pixel.r > 0.14 and pixel.r > pixel.b * 1.2:
						boots.append(x)
			boots.sort()
			_check(not boots.is_empty() and absf(boots[boots.size() / 2] - CharacterAnimation.PIVOT.x) <= 5, "pose%d boot anchor centered on logical feet" % index)
	for index: int in range(3):
		_check(bitmap.get_region(Rect2i(animation.source_region(4 + index))).get_data() != bitmap.get_region(Rect2i(animation.source_region(5 + index))).get_data(), "distinct front walking steps")
		_check(bitmap.get_region(Rect2i(animation.source_region(12 + index))).get_data() != bitmap.get_region(Rect2i(animation.source_region(13 + index))).get_data(), "distinct rear walking steps")
	var corpse := animation.death_copy()
	_check(corpse.atlas == animation.atlas and corpse.destination_rect(29) == animation.destination_rect(29), "death copy preserves exact grounding")
	var mage := CharacterAnimation.new()
	mage.configure(&"mage")
	_check(mage.actor_kind == &"mage" and mage.atlas != animation.atlas, "origin Mage still uses its unchanged atlas")
	print("Geometer G7 animation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

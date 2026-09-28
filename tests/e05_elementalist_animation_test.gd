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
		var regions_valid := true
		var grounded := true
		var boots_centered := true
		for index: int in range(32):
			var region := Rect2i(Vector2i(index % 4 * 64, index / 4 * 64), Vector2i(64, 64))
			var frame := bitmap.get_region(region)
			var bounds := frame.get_used_rect()
			frames_valid = frames_valid and bounds.has_area() and bounds.end.y <= 59 and frame.get_pixel(0, 0).a == 0.0
			regions_valid = regions_valid and elementalist.source_region(index) == Rect2(region)
			grounded = grounded and is_zero_approx(elementalist.destination_rect(index).position.y + bounds.end.y - 1)
			if index < 28:
				var boots: Array[int] = []
				for y: int in range(bounds.end.y - 6, bounds.end.y):
					for x: int in range(64):
						var pixel := frame.get_pixel(x, y)
						if pixel.a > 0.5 and pixel.r > 0.14 and pixel.r > pixel.b * 1.2:
							boots.append(x)
				boots.sort()
				var boot_valid := not boots.is_empty() and absf(float(boots[boots.size() / 2]) - CharacterAnimation.PIVOT.x) <= 5.0
				if not boot_valid:
					print("Boot anchor frame ", index, ": ", boots[boots.size() / 2] if not boots.is_empty() else -1)
				boots_centered = boots_centered and boot_valid
		_check(frames_valid, "Elementalist keeps alpha gutters and the 32,58 foot contract in every frame")
		_check(regions_valid, "every rendered region stays on an integer 64px cell without adjacent-row clipping")
		_check(grounded and boots_centered, "every pose rests on the ground; upright boot anchor stays within five pixels of logical position")
		var distinct_walks := true
		for column: int in range(3):
			var front := bitmap.get_region(Rect2i(elementalist.source_region(4 + column)))
			var next_front := bitmap.get_region(Rect2i(elementalist.source_region(5 + column)))
			var back := bitmap.get_region(Rect2i(elementalist.source_region(12 + column)))
			var next_back := bitmap.get_region(Rect2i(elementalist.source_region(13 + column)))
			distinct_walks = distinct_walks and front.get_data() != next_front.get_data() and back.get_data() != next_back.get_data() and front.get_data() != back.get_data()
		_check(distinct_walks, "front and rear walking use distinct alternating steps and separate orientations")
	var corpse := elementalist.death_copy()
	_check(corpse.atlas == elementalist.atlas and corpse.destination_rect(29) == elementalist.destination_rect(29), "death copy preserves the exact atlas and grounding offsets")
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

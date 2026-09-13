extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	var state := CombatAnimationState.new()
	_check(state.frame_index() == 0, "idle starts on the frontal atlas row")
	state.advance(0.25, Vector2.ZERO)
	_check(state.frame_index() == 1, "idle advances without changing the actor position")
	state.advance(0.1, Vector2(-22, -22))
	_check(state.back_view and state.flip_h and state.frame_index() in range(12, 16), "walking northwest selects the mirrored rear walk")
	state.trigger(&"cast", Vector2.RIGHT, 0.4)
	state.advance(0.1, Vector2(-10, -10))
	_check(not state.back_view and not state.flip_h and state.frame_index() == 9, "movement cannot rotate an active cast presentation")
	state.advance(0.4, Vector2(-10, -10))
	_check(state.back_view and state.flip_h and state.frame_index() in range(12, 16), "locomotion resumes after an action without a gameplay lock")
	state.trigger(&"hurt")
	_check(state.frame_index() == 26, "rear flinch uses the rear hurt frames")
	state.trigger(&"death")
	state.trigger(&"cast", Vector2.RIGHT)
	state.advance(0.3, Vector2(30, 0))
	_check(state.frame_index() == 31 and state.dead, "death overrides hurt and rejects later actions")
	for fps: int in [30, 60, 144]:
		var paced := CombatAnimationState.new()
		for index: int in range(fps):
			paced.advance(1.0 / fps, Vector2(220.0 / fps, 0))
		_check(paced.frame_index() == 6, "walk phase follows distance consistently at %d Hz" % fps)
	for id: StringName in [&"swordsman", &"mage", &"warrior", &"archer"]:
		var animation := CharacterAnimation.new()
		animation.configure(id)
		_check(animation.atlas != null and animation.atlas.get_size() == Vector2(256, 512), "%s contains 32 native 64 px animation frames" % id)
		if animation.atlas == null:
			continue
		var bitmap := animation.atlas.get_image()
		var frames_valid := true
		for index: int in range(32):
			var region := Rect2i(Vector2i(index % 4 * 64, index / 4 * 64), Vector2i(64, 64))
			var frame := bitmap.get_region(region)
			var used := frame.get_used_rect()
			frames_valid = frames_valid and used.has_area() and used.end.y <= 59 and frame.get_pixel(0, 0).a == 0.0
		_check(frames_valid, "%s has nonempty aligned frames and genuine alpha gutters" % id)
		var clone := animation.death_copy()
		_check(clone.atlas == animation.atlas and clone.state != animation.state and not animation.state.dead, "%s death copy shares immutable art but no runtime state" % id)
	print("Animações: %s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

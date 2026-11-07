class_name CombatAnimationState
extends RefCounted
## Presentation clock only. It never delays attacks, movement or cooldowns.

# Four compact poses cover 64 world units at native sprite scale.
const WALK_FRAME_DISTANCE := 16.0

var facing := Vector2.RIGHT
var back_view := false
var flip_h := false
var moving := false
var dead := false
var idle_time := 0.0
var walk_distance := 0.0
var action: StringName = &""
var action_remaining := 0.0
var action_duration := 0.25
var hurt_remaining := 0.0
var death_time := 0.0

func face(direction: Vector2) -> void:
	if dead or not direction.is_finite() or direction.is_zero_approx():
		return
	facing = direction.normalized()
	back_view = facing.y < -0.25
	if absf(facing.x) > 0.1:
		flip_h = facing.x < 0.0

func trigger(name: StringName, direction: Vector2 = Vector2.ZERO, duration: float = 0.25) -> void:
	if dead:
		return
	if name == &"death":
		dead = true
		moving = false
		action_remaining = 0.0
		hurt_remaining = 0.0
		death_time = 0.0
		return
	if name == &"hurt":
		hurt_remaining = 0.18
		return
	if name == &"cast_cancel":
		action_remaining = 0.0
		return
	face(direction)
	action = name
	action_duration = clampf(duration, 0.14, 5.0)
	action_remaining = action_duration

## Checkpoint39: a revived actor leaves the death pose and starts from idle.
func revive() -> void:
	dead = false
	death_time = 0.0
	action_remaining = 0.0
	hurt_remaining = 0.0
	moving = false
	idle_time = 0.0

func advance(delta: float, displacement: Vector2) -> void:
	var elapsed := maxf(0.0, delta)
	if dead:
		death_time += elapsed
		return
	idle_time += elapsed
	action_remaining = maxf(0.0, action_remaining - elapsed)
	hurt_remaining = maxf(0.0, hurt_remaining - elapsed)
	moving = displacement.length_squared() > 0.0025
	if moving:
		# A teleport must not advance hundreds of walking steps in one update.
		walk_distance += minf(displacement.length(), 32.0)
		if action_remaining <= 0.0:
			face(displacement)

func frame_index() -> int:
	if dead:
		return 28 + (2 if back_view else 0) + (1 if death_time >= 0.16 else 0)
	if hurt_remaining > 0.0:
		return 24 + (2 if back_view else 0) + (1 if hurt_remaining < 0.09 else 0)
	if action_remaining > 0.0:
		if action == &"dash":
			return (12 if back_view else 4) + 1
		var progress := 1.0 - action_remaining / action_duration
		return (20 if back_view else 8) + clampi(int(progress * 4.0 + 0.00001), 0, 3)
	if moving:
		return (12 if back_view else 4) + int(floor(walk_distance / WALK_FRAME_DISTANCE + 0.00001)) % 4
	return (16 if back_view else 0) + int(idle_time * 4.0) % 4

## Four cardinal views derive from the already persisted facing. Exact diagonal
## ties use the vertical view, so a cold restore cannot choose another direction.
func direction_index() -> int:
	if absf(facing.x)>absf(facing.y): return 2 if facing.x>0.0 else 3
	return 1 if facing.y<0.0 else 0

## Same clock and precedence as the legacy atlas, reduced to a 16-pose block.
func pose_index() -> int:
	var legacy := frame_index()
	if legacy<12: return legacy
	if legacy<16: return legacy-8
	if legacy<20: return legacy-16
	if legacy<24: return legacy-12
	if legacy<28: return 12+legacy%2
	return 14+legacy%2

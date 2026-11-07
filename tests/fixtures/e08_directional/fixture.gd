extends RefCounted
const MANIFEST := "res://tests/fixtures/e08_directional/presentation.json"
const DIRECTIONS := [Vector2.DOWN,Vector2.UP,Vector2.RIGHT,Vector2.LEFT]
static func state(direction: int, pose: int) -> CombatAnimationState:
	var s := CombatAnimationState.new()
	s.face(DIRECTIONS[direction])
	if pose<4: s.idle_time=pose*0.25
	elif pose<8:
		s.moving=true; s.walk_distance=(pose-4)*16.0
	elif pose<12:
		s.trigger(&"cast",DIRECTIONS[direction],0.4); s.advance((pose-8)*0.1,Vector2.ZERO)
	elif pose<14:
		s.trigger(&"hurt"); s.advance((pose-12)*0.1,Vector2.ZERO)
	else:
		s.trigger(&"death"); s.advance((pose-14)*0.2,Vector2.ZERO)
	return s
static func animation(direction: int, pose: int, equipped: bool = true) -> CharacterAnimation:
	var result := CharacterAnimation.new(); result.configure(&"mage")
	var loaded := result.set_directional_manifest(MANIFEST)
	assert(loaded.ok,str(loaded))
	if equipped:result.set_equipment_visual({"main_hand":&"staff","off_hand":&"shield","arms":&"wooden_beads","head":&"pilot_head"})
	result.state=state(direction,pose)
	return result

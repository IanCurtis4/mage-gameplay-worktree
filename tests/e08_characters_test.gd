extends SceneTree
## P4: real imported body selection and immutable player animation boundaries.
const KINDS: Array[StringName] = [&"swordsman", &"archer", &"mage", &"berserker", &"defender", &"hunter", &"sentinel", &"elementalist", &"spiritualist", &"geometer"]
const DIRECTIONAL_KINDS: Array[StringName] = [&"swordsman",&"mage",&"archer",&"defender",&"berserker",&"elementalist",&"spiritualist",&"sentinel",&"hunter",&"geometer"]
var checks := 0
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _run() -> void:
	for kind: StringName in KINDS:
		var animation := CharacterAnimation.new()
		animation.configure(kind)
		var directional := kind in DIRECTIONAL_KINDS
		var base := animation.atlas
		var base_path := "res://assets/art/animations/directional/%s/%s.png" % [kind,"npc_body" if kind==&"archer" else "body"] if directional else "res://assets/art/animations/%s.png" % kind
		check(base != null and base.resource_path==base_path, "%s explicit base selection" % kind)
		animation.set_equipment_visual({"main_hand": &"", "off_hand": &"", "arms": &""})
		var body := animation.atlas
		var body_path := "res://assets/art/animations/directional/%s/weaponless.png" % kind if directional else "res://assets/art/animations/%s_weaponless.png" % kind
		check(body != null and body.resource_path==body_path, "%s explicit weaponless selection" % kind)
		check(not animation.set_body_atlas(base) and animation.atlas == body, "%s rejects enemy body API" % kind)
		for texture: Texture2D in [base, body]:
			check(texture != null and texture.get_size() == (Vector2(256,1024) if directional else Vector2(256,512)), "%s atlas geometry" % kind)
			if texture == null: continue
			var image := texture.get_image()
			for frame: int in (64 if directional else 32):
				var cell := image.get_region(Rect2i(frame % 4 * 64, (frame >> 2) * 64, 64, 64))
				check(cell.get_used_rect().has_area() and cell.get_pixel(0, 0).a == 0.0, "%s frame %d content and alpha" % [kind, frame])
		animation.state.face(Vector2.UP)
		animation.play(&"attack", Vector2.UP)
		var dead := animation.death_copy()
		check(dead.state.dead and dead.state.back_view and dead.atlas == body and not animation.state.dead, "%s death preserves body and orientation independently" % kind)
		animation.set_equipment_visual({})
		check(animation.atlas == base, "%s restores shared base" % kind)
	print("E08 characters: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

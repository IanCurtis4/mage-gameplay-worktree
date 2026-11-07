extends RefCounted
## Test-only profile factory and authored unit paths. No production authority duplicated.
const ORIGINS := {&"swordsman":&"swordsman",&"mage":&"mage",&"archer":&"archer",&"defender":&"swordsman",&"berserker":&"swordsman",&"elementalist":&"mage",&"spiritualist":&"mage",&"sentinel":&"archer",&"hunter":&"archer",&"geometer":&"mage"}
static func stage_path(kind: StringName) -> String:
	return "res://assets/art/e08_characters/directional/%s/presentation.json" % kind
static func make(kind: StringName,label: String) -> Dictionary:
	if not ORIGINS.has(kind):return {"ok":false,"error_code":&"unknown_test_identity"}
	var directory := ProjectSettings.globalize_path("res://.godot/verification/e08_art_units/fixtures/%s_%s_%d" % [kind,label,Time.get_ticks_usec()])
	var store := ProfileStore.new(directory)
	var facade := ProfileFacade.new(store,ProfileRewardResolver.pilot_progression())
	var created := facade.create_character("create",0,"Arte direcional",ORIGINS[kind])
	if not created.ok:return created
	var id := facade.current_profile().characters[0].character_id
	var selected := facade.select_character("select",facade.current_profile().revision,id)
	if not selected.ok:return selected
	var maxed := PlaytestProfileAdmin.grant(facade,"max",facade.current_profile().revision,id,&"max_levels")
	if not maxed.ok:return maxed
	if kind!=ORIGINS[kind]:
		var evolution := &"mg_ar" if kind==&"geometer" else kind
		var evolved := facade.change_evolution("evolve",facade.current_profile().revision,id,evolution)
		if not evolved.ok:return evolved
		var evolved_max := PlaytestProfileAdmin.grant(facade,"max_evolved",facade.current_profile().revision,id,&"max_levels")
		if not evolved_max.ok:return evolved_max
	return {"ok":true,"facade":facade,"a":id,"store":store,"directory":directory}

static func equipment_bottom(placed: Dictionary) -> float:
	# Independent geometric oracle from the exported SVG's used rectangle.
	var texture := load("res://assets/art/equipment/%s.svg" % placed.key) as Texture2D
	var bounds := texture.get_image().get_used_rect()
	var bottom := -INF
	for corner: Vector2 in [Vector2(bounds.position),Vector2(bounds.end-Vector2i.ONE),Vector2(bounds.position.x,bounds.end.y-1),Vector2(bounds.end.x-1,bounds.position.y)]:
		var local := corner-Vector2(placed.grip)
		if placed.flip:local.x=-local.x
		bottom=maxf(bottom,Vector2(placed.point).y+local.rotated(float(placed.angle)).y)
	return bottom

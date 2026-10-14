extends SceneTree
## Native 1280x720 art probe for the three E06 mobs and player equipment overlays.

const CharacterAnimationScript = preload("res://scripts/actors/character_animation.gd")
const EquipmentAttachmentVisualScript = preload("res://scripts/actors/equipment_attachment_visual.gd")
const ACTORS: Array[StringName] = [&"gel", &"beast_master", &"animal_companion", &"swordsman"]
const ACTIONS: Array[StringName] = [&"idle", &"walk", &"attack", &"hurt", &"death"]
const CELL_WIDTH := 256
const CELL_HEIGHT := 170

class SpritePreview extends Node2D:
	var animation: CharacterAnimation
	var draw_scale := 2.0
	func _draw() -> void:
		if animation != null:
			animation.draw_on(self, Color.WHITE, draw_scale)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var back_page := "back" in OS.get_cmdline_user_args()
	var suffix := "back" if back_page else "front"
	var output_path := "res://.godot/verification/fixes_art/native_animation_%s.png" % suffix
	root.size = Vector2i(1280, 720)
	var background := ColorRect.new()
	background.size = Vector2(1280, 720)
	background.color = Color("14272d")
	root.add_child(background)
	var title := Label.new()
	title.text = "E06 · %s · Mobs kawaii e equipamento · renderer 1280×720" % ("Costas" if back_page else "Frente")
	title.position = Vector2(18, 5)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("f0d29a"))
	root.add_child(title)
	var headings := ["Parado", "Andando", "Ataque", "Dano", "Morte"]
	for column: int in range(headings.size()):
		var heading := Label.new()
		heading.text = headings[column]
		heading.position = Vector2(column * CELL_WIDTH + 8, 24)
		heading.add_theme_font_size_override("font_size", 13)
		heading.add_theme_color_override("font_color", Color("c6d8cd"))
		root.add_child(heading)
	var actions := [&"idle", &"walk", &"attack", &"hurt", &"death"]
	var cold_start := Time.get_ticks_usec()
	var first := CharacterAnimationScript.new()
	first.configure(&"gel")
	var cold_us := Time.get_ticks_usec() - cold_start
	var warm_start := Time.get_ticks_usec()
	var shared := CharacterAnimationScript.new()
	shared.configure(&"gel")
	var warm_us := Time.get_ticks_usec() - warm_start
	var atlas_shared := is_same(first.atlas, shared.atlas)
	var records: Array[Dictionary] = []
	for row: int in range(ACTORS.size()):
		var actor_kind := ACTORS[row]
		var panel := ColorRect.new()
		panel.position = Vector2(0, 41 + row * CELL_HEIGHT)
		panel.size = Vector2(1280, CELL_HEIGHT)
		panel.color = Color("1d343a") if row % 2 == 0 else Color("223a3f")
		root.add_child(panel)
		var name_label := Label.new()
		name_label.text = ["Gel", "Mestre das Feras", "Companheiro", "Jogador"][row]
		name_label.position = panel.position + Vector2(8, 3)
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.add_theme_color_override("font_color", Color("f0d29a"))
		root.add_child(name_label)
		for column: int in range(actions.size()):
			var action: StringName = actions[column]
			var animation: CharacterAnimation = first if row == 0 and column == 0 else CharacterAnimationScript.new()
			if not (row == 0 and column == 0):
				animation.configure(actor_kind)
			animation.equipment_visual = _gear_for_column(column) if actor_kind == &"swordsman" else {}
			var facing := Vector2.UP if back_page else Vector2.DOWN
			animation.state.face(facing)
			match action:
				&"walk": animation.state.advance(0.2, facing * 20.0)
				&"attack":
					animation.state.trigger(&"attack", facing, 0.25)
					animation.state.advance(0.12, Vector2.ZERO)
				&"hurt": animation.state.trigger(&"hurt")
				&"death":
					animation.state.trigger(&"death")
					animation.state.advance(0.22, Vector2.ZERO)
			var sprite := SpritePreview.new()
			sprite.animation = animation
			sprite.position = Vector2(column * CELL_WIDTH + CELL_WIDTH * 0.5, 41 + row * CELL_HEIGHT + 128)
			root.add_child(sprite)
			records.append({"actor": actor_kind, "action": action, "frame": animation.state.frame_index(), "back_view": animation.state.back_view, "flip_h": animation.state.flip_h, "main_hand": animation.equipment_visual.get("main_hand", &""), "off_hand": animation.equipment_visual.get("off_hand", &""), "weaponless_atlas": actor_kind == &"swordsman" and animation.atlas.resource_path.contains("weaponless")})
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png(output_path)
	var described := _describe_probe()
	var atlas_modes := _describe_weaponless_cache()
	var report := {"size": [image.get_width(), image.get_height()], "cold_configure_usec": cold_us, "warm_configure_usec": warm_us, "atlas_shared_reference": atlas_shared, "describe_probe": described, "weaponless_cache": atlas_modes, "cells": records, "png_error": error}
	var file := FileAccess.open("res://.godot/verification/fixes_art/native_animation_%s.json" % suffix, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	print("FIXES_ART_PROBE ", JSON.stringify(report))
	quit(0 if error == OK and atlas_shared and atlas_modes["passed"] and described["default"] == {"main_hand": &"bow", "off_hand": &"shield", "arms": &""} and described["override"] == {"main_hand": &"axe", "off_hand": &"", "arms": &""} else 1)

func _describe_weaponless_cache() -> Dictionary:
	var first: CharacterAnimation = CharacterAnimationScript.new()
	first.configure(&"swordsman")
	var base_path := first.atlas.resource_path
	first.set_equipment_visual({"main_hand": &"", "off_hand": &"", "arms": &""})
	var equipped_empty_path := first.atlas.resource_path
	var second: CharacterAnimation = CharacterAnimationScript.new()
	second.configure(&"swordsman")
	second.equipment_visual = {"main_hand": &"", "off_hand": &"", "arms": &""}
	var same_weaponless_texture := is_same(first.atlas, second.atlas)
	var death := first.death_copy()
	var death_kept_variant := death.atlas.resource_path == equipped_empty_path and death.state.dead
	first.equipment_visual = {}
	var unequip_restored_baked := first.atlas.resource_path == base_path
	return {"base_path": base_path, "weaponless_path": equipped_empty_path, "same_weaponless_texture": same_weaponless_texture, "death_kept_variant": death_kept_variant, "unequip_restored_baked": unequip_restored_baked, "passed": equipped_empty_path.ends_with("swordsman_weaponless.png") and same_weaponless_texture and death_kept_variant and unequip_restored_baked}

func _gear_for_column(column: int) -> Dictionary:
	var choices: Array[Dictionary] = [
		{"main_hand": &"", "off_hand": &"", "arms": &""},
		{"main_hand": &"axe", "off_hand": &"prismatic_focus"},
		{"main_hand": &"staff", "off_hand": &"wooden_beads"},
		{"main_hand": &"bow", "off_hand": &"shield"},
		{"main_hand": &"axe", "off_hand": &"shield"},
	]
	return choices[column]

func _describe_probe() -> Dictionary:
	var catalog := BuildEffectCatalog.new()
	var snapshot := BuildSnapshot.new()
	snapshot.base_class_id = &"archer"
	_register_item(catalog, snapshot, &"starter_bow", &"starter_bow_instance", &"main_hand", &"weapon", &"one_hand", &"")
	_register_item(catalog, snapshot, &"round_shield", &"round_shield_instance", &"off_hand", &"shield", &"none", &"")
	var default_result: Dictionary = EquipmentAttachmentVisualScript.describe(snapshot, catalog)
	var override_catalog := BuildEffectCatalog.new()
	var override_snapshot := BuildSnapshot.new()
	override_snapshot.base_class_id = &"mage"
	_register_item(override_catalog, override_snapshot, &"custom_staff", &"custom_staff_instance", &"main_hand", &"weapon", &"one_hand", &"axe")
	return {"default": default_result, "override": EquipmentAttachmentVisualScript.describe(override_snapshot, override_catalog)}

func _register_item(catalog: BuildEffectCatalog, snapshot: BuildSnapshot, definition_id: StringName, instance_id: StringName, slot: StringName, kind: StringName, hand_usage: StringName, visual_key: StringName) -> void:
	var definition := EquipmentDefinition.new()
	definition.id = definition_id
	definition.display_name = String(definition_id)
	definition.slot = slot
	definition.item_kind = kind
	definition.hand_usage = hand_usage
	definition.origin_id = snapshot.base_class_id
	definition.item_level = 1
	definition.quality_id = &"common"
	definition.visual_key = visual_key
	var registration := catalog.register_definition(&"equipment", definition)
	assert(registration["ok"], "equipment fixture registration failed: %s" % registration)
	var result := EquipmentInstance.from_metadata(instance_id, definition_id, definition.metadata())
	assert(result["ok"], "equipment fixture instance failed: %s" % result)
	snapshot.equipped[slot] = instance_id
	snapshot.equipment_instances[instance_id] = result["instance"]

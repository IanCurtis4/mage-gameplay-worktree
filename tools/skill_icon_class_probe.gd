extends SceneTree
## Renderer contact sheet and real SkillWindow for one closed icon class batch.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 1)
	var group := args[0]
	var directory := "res://.godot/verification/skill_icon_batches/" + group
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/skills/manifest.json"))
	var painted: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/skills/painted/manifest.json"))
	var ids: Array[StringName] = []
	for row: Dictionary in manifest["entries"]:
		if row["class"] == group: ids.append(StringName(row["id"]))
	for row: Dictionary in painted["assets"]:
		var id := StringName(row["id"])
		if String(id).begins_with(group + "_") and not id in ids: ids.append(id)
	assert(not ids.is_empty())
	ids.sort()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var canvas := Control.new()
	canvas.size = viewport.size
	viewport.add_child(canvas)
	var backdrop := ColorRect.new()
	backdrop.color = Color("101b28")
	backdrop.size = viewport.size
	canvas.add_child(backdrop)
	var title := Label.new()
	title.text = "%s: 32/64px; fundo escuro/claro; bloqueada" % group
	title.position = Vector2(18, 8)
	canvas.add_child(title)
	var locked := ShaderMaterial.new()
	locked.shader = load("res://scripts/ui/skill_locked_icon.gdshader") as Shader
	for index: int in ids.size():
		var id: StringName = ids[index]
		var texture := SkillPresentation.icon(id)
		assert(texture != null and texture.resource_path == "res://assets/art/skills/painted/%s.png" % id)
		assert(texture.get_width() <= 128 and texture.get_height() <= 128)
		assert(SkillPresentation.icon(id) == texture)
		var cell := Control.new()
		cell.position = Vector2(16 + (index % 7) * 178, 48 + floori(float(index) / 7.0) * 316)
		canvas.add_child(cell)
		var label := Label.new()
		label.text = SkillPresentation.name_of(id)
		label.add_theme_font_size_override("font_size", 11)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size = Vector2(170, 30)
		cell.add_child(label)
		for mode: int in 3:
			var background := ColorRect.new()
			background.position = Vector2(0, 32 + mode * 82)
			background.size = Vector2(170, 78)
			background.color = Color("edf0f4") if mode == 1 else Color("132130")
			cell.add_child(background)
			for pixels: int in [32, 64]:
				var icon := TextureRect.new()
				icon.texture = texture
				icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon.size = Vector2(pixels, pixels)
				icon.position = Vector2(12 if pixels == 32 else 85, (78-pixels)/2.0)
				if mode == 2: icon.material = locked
				background.add_child(icon)
	await _capture(viewport, directory + "/contact.png")
	canvas.queue_free()
	await process_frame
	var bases := {"swordsman":"swordsman", "defender":"swordsman", "berserker":"swordsman", "mage":"mage", "elementalist":"mage", "spiritualist":"mage", "geometer":"mage", "archer":"archer", "sentinel":"archer", "hunter":"archer"}
	var base := StringName(bases[group])
	var profile_path := ProjectSettings.globalize_path(directory + "/profile_%d" % Time.get_ticks_usec())
	var facade := ProfileFacade.new(ProfileStore.new(profile_path, ProfileCatalog.pilot()), ProfileRewardResolver.pilot_progression())
	assert(facade.create_character("create", 0, "Ícones " + group, base)["ok"])
	var character_id := facade.current_profile().characters[0].character_id
	assert(facade.grant_playtest_progression("entry", facade.current_profile().revision, character_id, &"prepare_evolution")["ok"])
	if group != String(base):
		var evolution := StringName("mg_ar" if group == "geometer" else group)
		assert(facade.change_evolution("evolve", facade.current_profile().revision, character_id, evolution)["ok"])
	var window := SkillWindow.new()
	window.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	viewport.add_child(window)
	window.size = viewport.size
	window.configure(facade, character_id, true)
	window.set_embedded(true)
	if group != String(base): window._job = &"mg_ar" if group == "geometer" else StringName(group)
	window._refresh()
	await _capture(viewport, directory + "/tree.png")
	window._tree = false
	window._refresh()
	await _capture(viewport, directory + "/list.png")
	print("CLASS_ICON_ART_OK class=",group," count=",ids.size()," pixels=32,64 backgrounds=light,dark locked_shader=true shared_texture=true tree_list=true isolated_profile=true")
	quit(0)

func _capture(viewport: SubViewport, path: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().save_png(path) == OK)

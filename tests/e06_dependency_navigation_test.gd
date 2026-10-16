extends SceneTree
## Cross-job skill navigation uses the same immutable preview as the resolver.

var failures := 0

class PreviewFacade:
	extends RefCounted
	var profile := ProfileState.new()
	var options: Array[Dictionary] = []
	var summary: Dictionary = {}
	func current_profile() -> ProfileState:
		return profile
	func skill_allocation_preview(_id: String, _revision: int, sequence: Array[StringName]) -> Dictionary:
		var counts: Dictionary = {}
		for id: StringName in sequence: counts[id] = int(counts.get(id, 0)) + 1
		return {"ok": true, "skills": options.duplicate(true), "summary": summary.duplicate(true), "pending_counts": counts, "can_apply": true}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var catalog := ProfileCatalog.pilot()
	var options: Array[Dictionary] = []
	for id: StringName in catalog._skills:
		var metadata: Dictionary = catalog.skill_metadata(id)
		if &"mage" not in metadata["allowed_base_classes"]: continue
		var job := StringName(metadata.get("required_evolution_id", &""))
		if job not in [&"", &"mg_ar"]: continue
		options.append({"skill_id": id, "metadata": metadata, "rank": 0, "maximum_rank": int(metadata["free_rank"]) + int(metadata["max_purchased_rank"]), "available": true, "next_rank_available": false})
	var summary := {"job_level": 40, "base_skill_points_available": 19, "evolution_skill_points_available": 20}
	var item_options := options.duplicate(true)
	for option: Dictionary in item_options:
		if option["skill_id"] == &"teleport": option["item_rank"] = 3
	var item_inspection := SkillDependencyRules.inspect(&"geometer_translation", item_options, summary)
	_check(int(item_inspection["missing_by_wallet"][&"base"]) == 2 and not item_inspection["prerequisites_met"], "item grant does not satisfy permanent prerequisite")
	var chain_inspection := SkillDependencyRules.inspect(&"geometer_rewrite", options, summary)
	_check(int(chain_inspection["missing_by_wallet"][&"base"]) == 2 and int(chain_inspection["missing_by_wallet"][&"evolution"]) == 2, "transitive costs are consumed once from the shared resolver")
	var window := SkillWindow.new()
	root.add_child(window)
	window.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	window.size = Vector2(1160, 540)
	window.configure_catalog(options, summary, &"mage")
	window.set_embedded(true)
	await process_frame
	window._choose_job(&"mg_ar")
	var entry: Dictionary = window.skill_entries[&"geometer_translation"]
	var badge: Label = entry["card"].get_node("OriginBadge")
	_check(entry["card"].size == Vector2(92, 104) and badge.position == Vector2(2, 2) and badge.position.x + badge.size.x <= 30, "tree badge occupies the free corner before the icon")
	window._select(&"geometer_translation")
	_check(window._details.text.contains("Teleporte") and window._details.text.contains("Base 2") and window._details.text.contains("Evolução 1"), "panel consumes separate wallet costs")
	window._select(&"geometer_rewrite")
	_check(window._details.text.contains("Cadeia de requisitos") and window._details.text.contains("Translação") and window._details.text.contains("Teleporte") and window._details.text.contains("Base 2 · Evolução 2"), "full chain and deduplicated wallet costs appear in the panel")
	var facade := PreviewFacade.new()
	facade.options = options
	facade.summary = summary
	var character := CharacterState.new("navigation-test", "Teste", &"mage")
	facade.profile.characters.append(character)
	window.configure(facade, character.character_id, true)
	window._choose_job(&"mg_ar")
	_check(window.draft.add(&"geometer_trace").get("ok", false), "real allocation draft accepts a pending rank")
	window._refresh()
	window._select(&"geometer_translation")
	window._scroll.scroll_vertical = 15
	await process_frame
	var saved_scroll := window._scroll.scroll_vertical
	window._follow_requirement("skill:teleport")
	await process_frame
	_check(window._job == &"" and window._selected == &"teleport" and window.skill_entries.has(&"teleport"), "origin opens the owned base library")
	window._follow_requirement("back")
	await process_frame
	_check(window._job == &"mg_ar" and window._selected == &"geometer_translation" and window._scroll.scroll_vertical == saved_scroll and window.draft.sequence == [&"geometer_trace"], "back restores scroll and keeps pending draft")
	window._tree = false
	window._render_skills()
	entry = window.skill_entries[&"geometer_translation"]
	badge = entry["card"].get_node("OriginBadge")
	_check(entry["card"].size == Vector2(484, 50) and badge.position == Vector2(400, 2) and badge.position.x >= 398 and badge.position.x + badge.size.x <= 422, "list badge fits between name and rank controls")
	window._follow_requirement("skill:teleport")
	await process_frame
	window._follow_requirement("back")
	await process_frame
	_check(window._job == &"mg_ar" and not window._tree and window._selected == &"geometer_translation", "list navigation restores original view")
	window.queue_free()
	await process_frame
	print("E06_DEPENDENCY_NAVIGATION ", "PASS" if failures == 0 else "FAIL %d" % failures)
	quit(0 if failures == 0 else 1)

func _check(ok: bool, label: String) -> void:
	if ok: return
	failures += 1
	push_error(label)

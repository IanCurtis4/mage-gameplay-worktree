extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: _run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)
func _run() -> void:
	var ledger := ThreatService.new()
	ledger.enemy_id = "target"
	check(ledger.register("player", "player", "local_party")["ok"], "real threat participant")
	ledger.engage("player")
	check(ledger.observe("hit", &"damage", "player", 80.0)["ok"], "real effective damage event")
	var revision := ledger.revision
	var claims := ledger.claims.duplicate(true)
	var text := ExpeditionPresentation.threat_text(ledger.view())
	check("Você: 80.0" in text and "Limiar de troca: 88.0" in text, "text uses amounts and threshold provided by ThreatView")
	check(ledger.revision == revision and ledger.claims == claims, "presentation leaves ledger and receipts unchanged")
	var portal := {"portal_id": "return", "kind": "travel", "to_stage": "entry", "open": true, "from_anchor": {"stage_id": "left", "surface_id": "floor", "position": Vector3.ZERO}}
	var original := portal.duplicate(true)
	var node := ExpeditionPortal.new()
	node.configure(portal)
	check(node.get_node("Caption").text == "Entrada\nPortal aberto", "native portal caption presents return destination")
	portal["open"] = false
	node.configure(portal)
	check(node.get_child_count() == 1 and "Portal fechado" in node.get_node("Caption").text, "refresh updates one caption without inventing the eligibility cause")
	check(original["open"] and not portal["open"], "presentation does not rewrite portal eligibility")
	node.free()
	check("retome" in ExpeditionPresentation.error_text(&"locked_by_expedition").to_lower(), "pending expedition explains lobby lock")
	check("preservado" in ExpeditionPresentation.error_text(&"content_revision_unavailable").to_lower(), "incompatible checkpoint gives preservation message")
	check("recuperação" in ExpeditionPresentation.campaign_text({"lifecycle": "reconciling", "stage_id": "entry", "wave_index": 0, "remaining": 900.0}), "uncertain state does not appear active")
	var manifest := {"stages":[{"stage_id":"entry"},{"stage_id":"forest_1"},{"stage_id":"forest_2"}],"input":{"authored_presentations":{"forest_1":{"name":"Clareira das Corujas"},"forest_2":{"name":"Bosque Antigo"}}}}
	var intact := manifest.duplicate(true)
	check(ExpeditionPresentation.stage_name("forest_1",manifest) == "Clareira das Corujas", "published reference supplies stage name")
	check(ExpeditionPresentation.stage_name("entry",manifest) == "Entrada", "legacy fallback preserved")
	check(ExpeditionPresentation.stage_name("forest_2",{"stages":[{"stage_id":"entry"},{"stage_id":"forest_1"},{"stage_id":"forest_2"}]}) == "Estágio 3", "known generated stage has ordinal")
	check(ExpeditionPresentation.stage_name("forest_1",{"input":{"authored_presentations":{"forest_1":{"name":42}}},"stages":[{"stage_id":"forest_1"}]}) == "Estágio 1", "invalid reference falls back")
	check(ExpeditionPresentation.stage_name("",{}) == "Estágio desconhecido", "empty stage has safe label")
	var named_portal := portal.duplicate(true); named_portal.to_stage = "forest_1"
	check(ExpeditionPresentation.portal_text(named_portal,manifest).begins_with("Clareira das Corujas"), "button uses published name")
	var panel := ExpeditionStatusPanel.new()
	root.add_child(panel)
	var long_manifest := {"input":{"authored_presentations":{"forest_1":{"name":"Vales da Mata e das Árvores Muito Antigas"}}}}
	var before_view := named_portal.duplicate(true)
	var closed_button := panel._portal_button(named_portal, long_manifest, func() -> void: pass)
	var closed_label := closed_button.get_node("PortalText") as Label
	check(closed_label.text == "Vales da Mata e das Árvores Muito Antigas\nPortal fechado" and closed_label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "closed portal shows complete wrapping destination and state")
	check("requisitos" in closed_button.tooltip_text and "limpeza" not in closed_button.tooltip_text, "closed portal tooltip does not invent the eligibility cause")
	check(named_portal == before_view, "closed portal presentation does not mutate eligibility")
	var open_view := named_portal.duplicate(true); open_view.open = true
	var open_button := panel._portal_button(open_view, long_manifest, func() -> void: pass)
	check((open_button.get_node("PortalText") as Label).text.ends_with("Portal aberto") and "Aproxime-se" in open_button.tooltip_text, "open portal displays state and proximity guidance")
	check(open_view.open and panel.message.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "open eligibility is unchanged and long action messages wrap")
	check(closed_button.accessibility_name == closed_label.text and closed_label.text in closed_button.tooltip_text, "portal has a complete accessible name and tooltip")
	closed_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	closed_label.size.x = 160.0
	panel._fit_portal_height(closed_button, closed_label)
	var narrow_height := closed_button.custom_minimum_size.y
	closed_label.size.x = 334.0
	panel._fit_portal_height(closed_button, closed_label)
	check(narrow_height > closed_button.custom_minimum_size.y, "portal height adapts to its actual text width")
	closed_label.text = "Á".repeat(120)+"\nPortal fechado"
	closed_label.size.x = 160.0
	var smart_lines := closed_label.get_line_count()
	var required_height := closed_label.get_minimum_size().y
	panel._fit_portal_height(closed_button, closed_label)
	print("F7_PORTAL_LAYOUT "+JSON.stringify({"lines":smart_lines,"label_height":required_height,"button_min_height":closed_button.custom_minimum_size.y,"width":closed_label.size.x}))
	check(smart_lines > 2 and closed_button.custom_minimum_size.y >= required_height+12.0, "unbroken valid title fits the smart-wrapped label height")
	panel.free()
	check(ExpeditionPresentation.campaign_text({"lifecycle":"active","stage_id":"forest_2","wave_index":0,"remaining":900.0},manifest).begins_with("Bosque Antigo"), "status uses published name")
	var named_node := ExpeditionPortal.new(); named_node.configure(named_portal,manifest)
	check(named_node.get_node("Caption").text.begins_with("Clareira das Corujas"), "world caption uses published name")
	named_node.free()
	check(manifest == intact, "presentation preserves immutable references")
	print("E07 F7 presentation: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

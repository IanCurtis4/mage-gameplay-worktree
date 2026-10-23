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
	check(node.get_child_count() == 1 and "Aguardando limpeza" in node.get_node("Caption").text, "refresh updates one caption without accumulating nodes")
	check(original["open"] and not portal["open"], "presentation does not rewrite portal eligibility")
	node.free()
	check("retome" in ExpeditionPresentation.error_text(&"locked_by_expedition").to_lower(), "pending expedition explains lobby lock")
	check("preservado" in ExpeditionPresentation.error_text(&"content_revision_unavailable").to_lower(), "incompatible checkpoint gives preservation message")
	check("recuperação" in ExpeditionPresentation.campaign_text({"lifecycle": "reconciling", "stage_id": "entry", "wave_index": 0, "remaining": 900.0}), "uncertain state does not appear active")
	print("E07 F7 presentation: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

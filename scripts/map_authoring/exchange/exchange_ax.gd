@tool
extends Node
## Checkpoint45 (F9-07/09, P3c): AX for the exchange of one screen, outside its
## review window so the screen's presentation finds it. Same service and the same
## panel state as the GUI: export a request, review a proposal (three-way when the
## source moved, with explicit choices for conflicts) and apply it as one undo.
const Exchange = preload("res://scripts/map_authoring/exchange/exchange.gd")
const Preferences = preload("res://scripts/map_authoring/library/editor_preferences.gd")
var panel: Control
var screen := ""

func _ready() -> void:
	name = "ExchangeAX"; set_meta("authoring_command_provider",true)

func authoring_commands() -> Array:
	return [{"id":screen+"/exchange/export","parameters":{"path":"string (new .rpx)","sections":"id[]","ids":"id[]","protected_paths":"string[]","max_changes":"integer 1..2048","brief":"string"}},
		{"id":screen+"/exchange/review","parameters":{"request_path":"string","proposal_path":"string","resolutions":"{path: current|proposal}"}},
		{"id":screen+"/exchange/apply","parameters":{"request_path":"string","proposal_path":"string","resolutions":"{path: current|proposal}","expected_current_hash":"sha256"}}]

static func summary(result: Dictionary) -> Dictionary:
	var copy := result.duplicate(true); copy.erase("package"); copy.erase("source"); copy.erase("bundle"); copy.erase("base_package")
	return copy

func _load(parameters: Dictionary) -> Dictionary:
	if not parameters.request_path is String or not parameters.proposal_path is String or not parameters.resolutions is Dictionary: return {"ok":false,"code":"arguments_invalid"}
	var request := Exchange.load_json(parameters.request_path)
	if not request.ok: return request
	var proposal := Exchange.load_json(parameters.proposal_path)
	if not proposal.ok: return proposal
	if not request.data is Dictionary or not proposal.data is Dictionary: return Exchange.fail("exchange_invalid_type")
	var checked := Exchange.validate_bundle(request.data)
	if not checked.ok: return checked
	if checked.ticket.kind != panel.kind or request.data.source_hash != checked.ticket.base_hash: return Exchange.fail("exchange_not_request")
	panel.cancel(); panel.request = request.data.duplicate(true); panel.proposal = proposal.data.duplicate(true); panel.resolutions = parameters.resolutions.duplicate(true)
	return {"ok":true}

func ax_command(id: String, parameters: Dictionary) -> Dictionary:
	if id == screen+"/exchange/export":
		if not Preferences._keys(parameters,["path","sections","ids","protected_paths","max_changes","brief"]) or not parameters.path is String or not parameters.brief is String or not (parameters.max_changes is int or parameters.max_changes is float): return {"ok":false,"code":"arguments_invalid"}
		var permissions := Exchange.policy(parameters.sections,parameters.ids,parameters.protected_paths,int(parameters.max_changes))
		var exported := Exchange.export_bundle(panel.kind,panel.get_source.call(),permissions,parameters.brief)
		if not exported.ok: return summary(exported)
		var saved := Exchange.save_json(parameters.path,exported.bundle)
		if not saved.ok: return saved
		panel.cancel(); panel.request = exported.bundle; panel.proposal = {}; panel.resolutions = {}; panel.summarize_request()
		return {"ok":true,"code":"","output_hash":exported.output_hash,"base_hash":exported.bundle.ticket.base_hash}
	if id == screen+"/exchange/review":
		if not Preferences._keys(parameters,["request_path","proposal_path","resolutions"]): return {"ok":false,"code":"arguments_invalid"}
		var loaded := _load(parameters)
		if not loaded.ok: return loaded
		var result := Exchange.prepare(panel.request,panel.proposal,panel.get_source.call(),Callable(),panel.resolutions)
		panel.show_review(result)
		return summary(result)
	if id == screen+"/exchange/apply":
		if not Preferences._keys(parameters,["request_path","proposal_path","resolutions","expected_current_hash"]) or not parameters.expected_current_hash is String: return {"ok":false,"code":"arguments_invalid"}
		var loaded := _load(parameters)
		if not loaded.ok: return loaded
		var current: Dictionary = panel.get_source.call()
		var checked := Exchange.read(panel.kind,current)
		if not checked.ok or checked.output_hash != parameters.expected_current_hash: return Exchange.fail("stale_source")
		var result := Exchange.apply_to(panel.request,panel.proposal,current,panel.commit_source,panel.resolutions)
		panel.show_result(result)
		return summary(result)
	return {"ok":false,"code":"action_missing"}

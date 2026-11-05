extends SceneTree
const Candidate = preload("res://scripts/map_authoring/preview/gameplay_candidate.gd")
var checks := 0; var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func run() -> void:
	var package := {"source_hash":"a".repeat(64),"padding":"x".repeat(Candidate.MAX_BYTES)}
	check(not Candidate._create_approved("patrol",package,package.source_hash).ok,"private producer preserves package size cap of public create")
	check(not Candidate.create("patrol",package,package.source_hash).ok,"public create still refuses oversized input")
	var candidate := {"format_version":Candidate.VERSION,"kind":"patrol","source_hash":package.source_hash,"package":package,"candidate_hash":"b".repeat(64)}
	check(not Candidate._prepare_approved(candidate).ok,"closed handoff preserves full candidate envelope size cap")
	check(not Candidate.prepare(candidate).ok,"public prepare still rejects oversized envelope")
	print("Candidate handoff limits: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

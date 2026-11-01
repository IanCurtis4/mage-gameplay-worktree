extends SceneTree
## Checkpoint43/44 (F9-05/09): command line for regional synthesis, the same
## service as the editor screens and AX.
##   godot --headless --path <projeto> --script res://scripts/map_authoring/synthesis/headless.gd -- <fonte.json> <pedido.json> [<saída.json>]
## The source is a piece, a map, an encounter document or a patrol document (the
## kind is read from its fields). Prints MAP_SYNTHESIS_RESULT with the proposal
## summary (hashes, diff, metrics). The input is never written; the optional
## output must be a new file (an existing one is refused with io_conflict).
const Store = preload("res://scripts/map_authoring/io/source_store.gd")
const StrictJSON = preload("res://scripts/map_authoring/io/strict_json.gd")
const Synthesis = preload("res://scripts/map_authoring/synthesis/regional_synthesis.gd")
const Root = preload("res://scripts/map_authoring/synthesis/root_synthesis.gd")
const Section = preload("res://scripts/map_authoring/synthesis/synthesis_section.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var result := Synthesis.fail("arguments_invalid")
	if args.size() in [2,3]:
		var request: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[1])) if FileAccess.file_exists(args[1]) else null
		var decoded := StrictJSON.new().decode(FileAccess.get_file_as_bytes(args[0])) if FileAccess.file_exists(args[0]) else {"ok":false}
		var kind := Root.kind_of(decoded.value) if decoded.ok and decoded.value is Dictionary else ""
		if not request is Dictionary: result = Synthesis.fail("synthesis_request_invalid")
		elif kind.is_empty(): result = _piece(args,_numbers(request))
		else: result = _root(kind,decoded.value,args,_numbers(request))
	print("MAP_SYNTHESIS_RESULT " + JSON.stringify(result))
	quit(0 if result.get("ok",false) else 1)

func _piece(args: Array, request: Dictionary) -> Dictionary:
	var source := Store.load_source(args[0])
	if not source.ok: return source
	if not source.valid: return Synthesis.fail("source_invalid")
	var proposal := Synthesis.prepare(source.data,request)
	var result := Section.summary(proposal)
	if proposal.ok and args.size() == 3:
		var saved := Store.save_source(args[2],proposal.source,"")
		result["written"] = saved.ok
		if not saved.ok: result.ok = false; result.code = saved.code
	return result

func _root(kind: String, root: Dictionary, args: Array, request: Dictionary) -> Dictionary:
	var proposal := Root.prepare(kind,root,request)
	var result := proposal.duplicate(true); result.erase("source")
	if not proposal.ok: return result
	result["proposal_hash"] = proposal.source_hash
	if args.size() == 3:
		var written := false
		if not FileAccess.file_exists(args[2]):
			var file := FileAccess.open(args[2],FileAccess.WRITE)
			if file != null:
				file.store_string(JSON.stringify(proposal.source,"\t",true,true)); file.close()
				var back := StrictJSON.new().decode(FileAccess.get_file_as_bytes(args[2]))
				written = back.ok and back.value is Dictionary and Root.root_hash(kind,back.value) == proposal.source_hash
		result["written"] = written
		if not written: result.ok = false; result.code = "io_conflict" if FileAccess.file_exists(args[2]) else "io_failure"
	return result

# JSON numbers arrive as floats; counts in the request are integers.
static func _numbers(request: Dictionary) -> Dictionary:
	var copy := request.duplicate(true)
	var objects: Variant = copy.get("channels",{}).get("objects") if copy.get("channels") is Dictionary else null
	if objects is Dictionary and objects.get("count") is float and objects.count == floor(objects.count): objects.count = int(objects.count)
	return copy

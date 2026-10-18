extends SceneTree
const Fixture = preload("res://tests/fixtures/e07/f0/fixture_input.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	if not Fixture.sources_current(): push_error("stale fixture sources; run e07_f0_import_test"); quit(1); return
	_run.call_deferred()
func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures += 1; push_error(label)
func reject(input: ExpeditionGenerationInput, code: StringName, label: String) -> void:
	# One attempt exhaustively enumerates the small fixture. Do not mask production budgets.
	if input != null and not input.policies.is_empty(): input.policies[0].parameters["max_attempts"] = 1
	var a := ExpeditionAssembler.build(input)
	var b := ExpeditionAssembler.build(input)
	check(not a["ok"] and a["error_code"] == code,label+" code: "+str(a))
	check(not a["data"].has("manifest"),label+" no partial publication")
	check(ExpeditionCanonical.encode(a) == ExpeditionCanonical.encode(b),label+" deterministic diagnostic")
func _run() -> void:
	reject(null,&"invalid_payload","null input")
	var input := Fixture.make(); input.policies.remove_at(2)
	reject(input,&"policy_unresolved","missing reward declaration")
	input = Fixture.make(); input.generation_policy_id = ""
	reject(input,&"policy_unresolved","no generation default")
	input = Fixture.make(); input.traversal = null
	reject(input,&"policy_unresolved","no traversal default")
	input = Fixture.make(); input.population_policy_id = "fixture_reward"
	reject(input,&"policy_unresolved","policy domain checked")
	input = Fixture.make(); input.policies.append(input.policies[0])
	reject(input,&"duplicate_id","policy collision")
	input = Fixture.make(); input.parts.append(input.parts[0])
	reject(input,&"duplicate_id","part collision")
	input = Fixture.make(); input.parts[0].surfaces.append(input.parts[0].surfaces[0])
	reject(input,&"duplicate_id","surface collision")
	input = Fixture.make(); input.parts[0].connectors.append(input.parts[0].connectors[0])
	reject(input,&"duplicate_id","connector collision")
	input = Fixture.make(); input.parts[0].sockets.append(input.parts[0].sockets[0])
	reject(input,&"duplicate_id","socket collision")
	input = Fixture.make(); input.stages.append(input.stages[0].duplicate(true))
	reject(input,&"duplicate_id","stage collision")
	input = Fixture.make(); input.stages[0]["parts"].append(input.stages[0]["parts"][0].duplicate(true))
	reject(input,&"duplicate_id","instance collision")
	input = Fixture.make(); input.population.append(input.population[0].duplicate(true))
	reject(input,&"duplicate_id","slot collision")
	input = Fixture.make(); input.objectives.append(input.objectives[0].duplicate(true))
	reject(input,&"duplicate_id","objective collision")
	input = Fixture.make(); input.portals.append(input.portals[0].duplicate(true))
	reject(input,&"duplicate_id","portal collision")
	input = Fixture.make(); input.parts[0].connectors[1].outward = Vector3.LEFT
	reject(input,&"incompatible_connector","inverted author normal")
	input = Fixture.make(); input.parts[1].connectors[0].width = 0.8; input.parts[2].connectors[0].width = 0.8
	reject(input,&"incompatible_connector","radius does not fit")
	input = Fixture.make(); input.parts[1].connectors[0].headroom = 1.9; input.parts[2].connectors[0].headroom = 1.9
	reject(input,&"incompatible_connector","actor height does not fit")
	input = Fixture.make(); input.parts[1].connectors[0].kind = "ladder"; input.parts[2].connectors[0].kind = "ladder"
	reject(input,&"incompatible_connector","connector kind mismatch")
	input = Fixture.make(); input.parts[1].connectors[0].tags = PackedStringArray(["other"]); input.parts[2].connectors[0].tags = PackedStringArray(["other"])
	reject(input,&"incompatible_connector","connector tags mismatch")
	input = Fixture.make(); input.parts[3].allowed_rotations.assign([0])
	reject(input,&"incompatible_connector","unsupported transform cannot be invented")
	input = Fixture.make(); input.parts[0].connectors[1].direction = "out"; input.parts[1].connectors[0].direction = "out"; input.parts[2].connectors[0].direction = "out"
	reject(input,&"incompatible_connector","both endpoints out")
	input = Fixture.make(); input.objectives[0]["socket_id"] = "absent"
	reject(input,&"objective_unreachable","required objective missing")
	input = Fixture.make(); input.population[0]["socket_id"] = "absent"
	reject(input,&"population_unreachable","required population missing")
	input = Fixture.make(); input.parts[4].sockets[0].tags = PackedStringArray(["wrong"])
	reject(input,&"missing_thematic_site","memorable site cannot be substituted")
	input = Fixture.make(); input.parts[4].surfaces[0].headroom = 1.5
	reject(input,&"population_unreachable","surface headroom blocks required boss")
	input = Fixture.make(); input.objectives.clear(); input.parts[1].blockers.append(AABB(Vector3(0.1,0,0),Vector3(2,3,10))); input.parts[2].blockers.append(AABB(Vector3(0.1,0,0),Vector3(2,3,10)))
	reject(input,&"population_unreachable","wall prevents required slot witness")
	input = Fixture.make(); input.objectives.clear(); input.parts[1].connectors[0].direction = "out"; input.parts[2].connectors[0].direction = "out"
	reject(input,&"population_unreachable","reverse-only connection cannot reach population")
	input = Fixture.make(); input.portals.clear()
	reject(input,&"objective_unreachable","disconnected phase graph")
	input = Fixture.make(); input.portals[0]["from_socket"] = "root/absent"
	reject(input,&"objective_unreachable","portal anchor missing")
	input = Fixture.make(); input.stages[0]["parts"][1]["parent"] = "field"
	reject(input,&"invalid_recipe","parent cycle")
	input = Fixture.make(); input.stages[0]["parts"][1]["candidates"] = ["not_loaded"]
	reject(input,&"content_revision_unavailable","unavailable part")
	input = Fixture.make(); input.generator_revision = "future"
	reject(input,&"content_revision_unavailable","future generator")
	input = Fixture.make(); input.seed_text = "9223372036854775808"
	reject(input,&"invalid_recipe","overflow seed cannot round")
	input = Fixture.make(); input.seed_text = "01"
	reject(input,&"invalid_recipe","noncanonical seed")
	input = Fixture.make(); input.parts[0].surfaces[0].headroom = NAN
	reject(input,&"invalid_recipe","nonfinite geometry")
	input = Fixture.make(); input.parts[0].surfaces[0].vertices[2] = Vector3(3,0,3)
	reject(input,&"invalid_recipe","concave cell")
	input = Fixture.make(); input.parts[0].surfaces[0].vertices[2] = Vector3(10,1,10)
	reject(input,&"invalid_recipe","nonplanar cell")
	input = Fixture.make(); input.policies[0].parameters["max_expansions"] = 0
	reject(input,&"invalid_recipe","missing finite expansion budget")
	input = Fixture.make("-9223372036854775808"); input.policies[0].parameters = {"max_attempts":32,"max_expansions":1}
	reject(input,&"generation_exhausted","adverse seed explicit expansion exhaustion")
	var exhausted := ExpeditionAssembler.build(input)
	check(exhausted["data"]["diagnostic"]["expansions"] == 1,"budget never exceeded")
	input = Fixture.make(); input.policies[0].parameters = {"max_attempts":2,"max_expansions":4096}; input.parts[3].allowed_rotations.assign([0])
	var bounded := ExpeditionAssembler.build(input)
	check(not bounded["ok"] and bounded["data"]["diagnostic"]["attempts"] == 2 and bounded["data"]["diagnostic"]["expansions"] < 4096,"attempt exhaustion is finite")
	input = Fixture.make(); input.population[0]["species_id"] = "missing_species"
	reject(input,&"incompatible_species","species missing from exact catalog")
	input = Fixture.make(); input.species[0].biome_tags = PackedStringArray(["other_biome"])
	reject(input,&"incompatible_species","species biome mismatch")
	input = Fixture.make(); input.population[0]["occurrence_category"] = "elite"
	reject(input,&"incompatible_species","category eligibility")
	input = Fixture.make(); input.species.append(input.species[0])
	reject(input,&"duplicate_id","species collision")
	input = Fixture.make(); input.stages[0]["parts"][1]["candidates"] = [1]
	reject(input,&"invalid_recipe","malformed candidate type")
	input = Fixture.make(); input.population[0]["blocks_clear"] = 1
	reject(input,&"invalid_recipe","numeric boolean not coerced")
	input = Fixture.make(); input.parts[0].surfaces.append(Fixture.cell("overlap"))
	reject(input,&"invalid_recipe","overlapping authored supports")
	input = Fixture.make(); input.parts[4].surfaces[0].vertices = PackedVector3Array([Vector3(0,5,0),Vector3(10,5,0),Vector3(10,5,10),Vector3(0,5,10)])
	for connector: ExpeditionConnectorDefinition in input.parts[4].connectors: connector.position.y = 5
	for socket: ExpeditionSocketDefinition in input.parts[4].sockets: socket.position.y = 5
	reject(input,&"incompatible_connector","height mismatch cannot be repaired by translating y")
	# The destination is reachable from its entrance but reverse-only floor travel strands arrivals.
	input = Fixture.make(); input.objectives.clear(); input.population.clear()
	for part: ExpeditionPartDefinition in [input.parts[1],input.parts[2]]:
		part.connectors[0].direction = "in"
		part.sockets.append(Fixture.socket("arrival","portal",Vector3(5,0,5)))
	input.portals[0]["to_socket"] = "field/arrival"
	reject(input,&"objective_unreachable","arrival anchor must reach destination entrance")
	print("E07 F0 adversarial: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

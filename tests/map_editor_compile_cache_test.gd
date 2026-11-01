extends SceneTree
## Checkpoint42 (F9-10): the compile cache returns the very package a fresh compile
## gives, never a tampered or foreign one, and stays opt-in and bounded.
const Cache = preload("res://scripts/map_authoring/compiler/compile_cache.gd")
const Maps = preload("res://scripts/map_authoring/composition/map_compiler.gd")
const Population = preload("res://scripts/map_authoring/population/population_compiler.gd")
const Exchange = preload("res://scripts/map_authoring/exchange/exchange.gd")
var checks: Array[Dictionary] = []
var metrics := {}
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_CACHE_CHECK "+id+" "+str(ok))
func ms(t: int) -> float: return (Time.get_ticks_usec()-t)/1000.0
func forget(kind: String, cache_key: String) -> void:
	var path := ProjectSettings.globalize_path(Cache._path(kind,cache_key))
	if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
func run() -> void:
	OS.set_environment("RAGRPG_COMPILE_CACHE","0")
	var loaded := Exchange.load_json("res://data/map_authoring/representative_patrol.json")
	var population: Dictionary = loaded.data.population[0]; var map: Dictionary = population.map[0]
	var map_hash := Maps.Document.hash_source(map)
	check("cache_is_opt_in",Cache.key("map",Maps.REVISION,map_hash).is_empty() and not Maps.compile(map).get("metrics",{}).has("cache"))
	OS.set_environment("RAGRPG_COMPILE_CACHE","1")
	var map_key := Cache.key("map",Maps.REVISION,map_hash); forget("map",map_key)
	var t := Time.get_ticks_usec(); var cold := Maps.compile(map); metrics["map_cold_ms"] = ms(t)
	check("miss_compiles_and_stores",cold.ok and cold.metrics.get("cache","") != "hit" and FileAccess.file_exists(Cache._path("map",map_key)))
	t = Time.get_ticks_usec(); var warm := Maps.compile(map); metrics["map_hit_ms"] = ms(t)
	check("hit_returns_the_same_package",warm.ok and warm.metrics.get("cache","") == "hit" and warm.output_hash == cold.output_hash and warm.input_hash == cold.input_hash and warm.package == cold.package and warm.diagnostics == cold.diagnostics)
	# A stored package that no longer validates is ignored and replaced.
	var file := FileAccess.open(Cache._path("map",map_key),FileAccess.READ); var record: Dictionary = bytes_to_var(file.get_buffer(file.get_length())); file.close()
	record.package.barriers = []
	var writer := FileAccess.open(Cache._path("map",map_key),FileAccess.WRITE); writer.store_buffer(var_to_bytes(record)); writer.close()
	var tampered := Maps.compile(map)
	check("tampered_entry_is_recompiled",tampered.ok and tampered.metrics.get("cache","") != "hit" and tampered.output_hash == cold.output_hash)
	# Another key's file under this key is refused by its header.
	var other := map.duplicate(true); other.name = String(other.name)+" · variação"
	var other_key := Cache.key("map",Maps.REVISION,Maps.Document.hash_source(other))
	check("source_and_environment_select_the_key",other_key != map_key and Cache.key("map","map_composition_other",map_hash) != map_key)
	var previous := Cache._environment; Cache._environment = "0".repeat(64)
	var shifted := Cache.key("map",Maps.REVISION,map_hash); Cache._environment = previous
	check("changed_inputs_change_the_key",shifted != map_key and Cache.environment_hash() == previous)
	DirAccess.copy_absolute(ProjectSettings.globalize_path(Cache._path("map",map_key)),ProjectSettings.globalize_path(Cache._path("map",other_key)))
	check("foreign_entry_is_refused",not Cache.fetch("map",other_key,Maps.Document.hash_source(other)).ok)
	forget("map",other_key)
	# Population: the worker path's cache gives the same package.
	var population_key := Cache.key("population",Population.REVISION,Population.Document.hash_source(population)); forget("population",population_key)
	t = Time.get_ticks_usec(); var p_cold := Population.compile(population); metrics["population_cold_ms"] = ms(t)
	t = Time.get_ticks_usec(); var p_warm := Population.compile(population); metrics["population_hit_ms"] = ms(t)
	check("population_hit_returns_the_same_package",p_cold.ok and p_warm.ok and p_warm.get("cache","") == "hit" and p_warm.output_hash == p_cold.output_hash and p_warm.package == p_cold.package)
	check("hits_are_faster_than_compiles",float(metrics.map_hit_ms) < float(metrics.map_cold_ms) and float(metrics.population_hit_ms) < float(metrics.population_cold_ms))
	# Bounded: never more than MAX_FILES entries.
	for index: int in Cache.MAX_FILES+3:
		Cache.store("map",("bound_%d" % index).sha256_text(),{"package_hash":"x","source_hash":"y"})
	var stored := 0
	for name: String in DirAccess.get_files_at(ProjectSettings.globalize_path(Cache.ROOT)):
		if name.ends_with(".bin"): stored += 1
	check("cache_is_bounded",stored <= Cache.MAX_FILES)
	OS.set_environment("RAGRPG_COMPILE_CACHE","0")
	var ok := checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F9_CACHE_METRICS "+JSON.stringify(metrics))
	print("F9_CACHE_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)

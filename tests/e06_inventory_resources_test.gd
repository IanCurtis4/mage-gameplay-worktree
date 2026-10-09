extends SceneTree
const F = preload("res://tests/e06_inventory_fixture.gd")
var checks := 0
var failures := 0
var deaths := 0
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var base := StatCalculator.calculate({&"str": 1, &"agi": 1, &"vit": 1, &"int": 1, &"dex": 1, &"luk": 1})
	base.derived[&"max_hp"]["effective"] = 100.0
	var hp := HealthState.new(12, base)
	hp.actor_died.connect(func(_id: int) -> void: deaths += 1)
	hp.current_hp = 70.0
	base.derived[&"max_hp"]["effective"] = 80.0
	hp.set_stats_preserving_missing(base)
	_check(hp.current_hp == 50.0 and hp.hp_deficit() == 30.0, "100/70 -> max80 retains debt30 and HP50")
	for i: int in 12:
		base.derived[&"max_hp"]["effective"] = 100.0 if i % 2 == 0 else 80.0
		hp.set_stats_preserving_missing(base)
	_check(hp.hp_deficit() == 30.0, "repeated involuntary maxima never heal")
	_check(hp.heal(10.0) == 10.0 and hp.hp_deficit() == 20.0, "explicit healing reduces debt")
	_check(hp.spend_hp_nonlethal(5.0) and hp.hp_deficit() == 25.0, "HP cost increases debt without hit")
	base.derived[&"max_hp"]["effective"] = 20.0
	hp.set_stats_preserving_missing(base)
	_check(not hp.is_alive() and deaths == 1 and hp.hp_deficit() == 25.0, "involuntary lethal maximum emits one terminal and preserves excess debt")
	base.derived[&"max_hp"]["effective"] = 100.0
	hp.set_stats_preserving_missing(base)
	_check(not hp.is_alive() and hp.heal(500.0) == 0.0 and deaths == 1, "re-equip/heal cannot revive terminal actor")
	var fixture := F.make(self, "resources")
	var c: RunController = fixture["controller"]
	var p := c.player
	p.max_sp = 100.0
	p.current_sp = 10.0
	p.max_sp = 80.0
	_check(p.current_sp == 0.0 and p.sp_deficit() == 90.0, "SP clamp does not erase excess debt")
	p.recover_sp(5.0)
	_check(p.current_sp == 0.0 and p.sp_deficit() == 85.0, "regen repays hidden debt before visible SP")
	p.max_sp = 100.0
	_check(p.current_sp == 15.0, "restored maximum retains outstanding debt")
	p.max_sp = 0.0
	var before := p.sp_deficit()
	p._regenerate_sp(1.0, false)
	_check(p.sp_deficit() < before and p.current_sp == 0.0, "zero maximum still permits explicit debt recovery")
	before = p.sp_deficit()
	p._regenerate_sp(1.0, true)
	_check(p.sp_deficit() == before, "pause does not repay debt")
	p.max_sp = p.stat_breakdown.value(&"max_sp")
	p.current_sp = p.max_sp
	p.health.current_hp = p.health.max_hp - 30.0
	p.attack_cooldown = 3.0
	var result := F.change(c, &"equip", {"slot": &"armor", "item_id": &"warden_mail"})
	_check(result["ok"] and p.health.hp_deficit() == 30.0 and p.attack_cooldown == 3.0, "equipment preserves debt and cooldown")
	p.health.current_hp = 1.0
	var disk := F.disk(fixture)
	var version := c.run_state.runtime_revision
	result = F.change(c, &"equip", {"slot": &"armor", "item_id": &"traveler_vest"})
	_check(not result["ok"] and result["error_code"] == &"hp_deficit" and F.disk(fixture) == disk and c.run_state.runtime_revision == version, "extreme voluntary HP reduction rejects before disk/runtime")
	p.health.current_hp = p.health.max_hp
	_check(F.change(c, &"equip", {"slot": &"armor", "item_id": &"channeler_robe"})["ok"], "SP fixture equips")
	p.current_sp = 1.0
	disk = F.disk(fixture)
	result = F.change(c, &"unequip", {"slot": &"armor"})
	_check(not result["ok"] and result["error_code"] == &"sp_deficit" and F.disk(fixture) == disk, "extreme SP deficit rejects")
	p.recover_sp(100.0)
	result = F.change(c, &"unequip", {"slot": &"armor"})
	_check(result["ok"] and is_equal_approx(p.current_sp, 1.0), "explicit SP recovery makes removal legal without healing")
	# The boundary is strict for HP and inclusive for SP, including card removal.
	p.health.current_hp = p.health.max_hp
	_check(F.change(c, &"equip", {"slot": &"armor", "item_id": &"warden_mail"})["ok"], "HP boundary setup")
	var small_hp := p.health.max_hp - 100.0
	p.health.current_hp = 100.0 # Deficit equals the candidate maximum exactly.
	disk = F.disk(fixture)
	result = F.change(c, &"unequip", {"slot": &"armor"})
	_check(result["error_code"] == &"hp_deficit" and p.health.hp_deficit() == small_hp and F.disk(fixture) == disk, "new HP maximum equal to debt rejects atomically")
	p.health.heal(1.0)
	_check(F.change(c, &"unequip", {"slot": &"armor"})["ok"] and is_equal_approx(p.health.current_hp, 1.0), "one explicit HP recovery makes exact boundary legal")
	p.health.heal(10000.0)
	_check(F.change(c, &"equip", {"slot": &"armor", "item_id": &"channeler_robe"})["ok"], "SP boundary setup")
	var small_sp := p.max_sp - 100.0
	p.current_sp = 100.0
	_check(F.change(c, &"unequip", {"slot": &"armor"})["ok"] and is_zero_approx(p.current_sp) and is_equal_approx(p.sp_deficit(), small_sp), "new SP maximum equal to debt allows zero SP")
	p.recover_sp(10000.0)
	var cost := p.skill_cost(&"fire_spear")
	p._spend(&"fire_spear")
	_check(is_equal_approx(p.sp_deficit(), cost), "paid skill adds canonical cost to real SP debt")
	c.run_state.card_inventory.grant(&"trail_card", c.run_state.effect_catalog())
	_check(F.change(c, &"socket", {"item_id": &"starter_staff", "card_id": &"trail_card"})["ok"], "SP card setup")
	p.current_sp = 1.0
	var sockets := c.run_state.card_inventory.sockets()
	disk = F.disk(fixture)
	_check(F.change(c, &"unsocket", {"item_id": &"starter_staff"})["error_code"] == &"sp_deficit" and c.run_state.card_inventory.sockets() == sockets and F.disk(fixture) == disk, "runtime-only removal applies same debt guard without losing ownership")
	c.free()
	print("E06 inventory resources: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

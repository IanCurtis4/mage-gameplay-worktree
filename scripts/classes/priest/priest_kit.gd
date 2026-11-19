extends ClassKit
## E10a T6 — Sacerdote (`priest`, ramo 2-1): pure evolution of the Acólito.
## Contract with the numbers: docs/epics/e10a/t6_contract.md. Seam: docs/epics/e10a/t1_base_seam_api.md
## (two modules per player: the Acólito origin first, this kit second) and the E09 kit seam.
## Santuário/Graça: SanctuaryAuthority (E09 T5), untouched. The Sacerdote draws the Santuário at
## the chosen point; excess healing fills the Grace reserve and the Juízo spends it as a light
## column. Light = magic damage of a skill with element `light` (A2, D5).
## Script-cycle rule (A7): this script never names EnemyActor or its own class; enemies are
## CombatActor and are recognised by their data (hard_controls.boss).
## Data methods are pure; the variables below are run state (snapshot fragment).

const SANCTUARY := &"priest_sanctuary"
const GRACE := &"priest_grace"
const AEGIS := &"priest_aegis"
const JUDGMENT := &"priest_judgment"
const EXORCIST := &"priest_exorcist"
const LIGHT_SEAL := &"priest_light_seal"
const HOLY_HOUR := &"priest_holy_hour"
const SKILLS: Array[StringName] = [SANCTUARY, GRACE, AEGIS, JUDGMENT, EXORCIST, LIGHT_SEAL, HOLY_HOUR]

const ROLE := &"sanctuary"
const SEAL_KEY := &"priest_light_seal"
const GRACE_FAMILY := &"priest_grace"
const ICE_SOURCE := &"priest_sanctuary_ice"
const EXPOSED_SOURCE := &"priest_exposed"
const EXORCIST_MARK_SCRIPT := "res://scripts/classes/priest/priest_exorcist_mark.gd"
const SEAL_SLOW_SOURCE := &"priest_light_seal"
const GRACE_PULSE_SOURCE := &"priest_grace_pulse"
const PRAYER := &"acolyte_prayer"
const VOTIVE_SHIELD := &"acolyte_votive_shield"

# --- Numbers (t6_contract §2) ---------------------------------------------------------
const SANCTUARY_SP: Array[float] = [22.0, 23.0, 24.0, 25.0, 26.0]
const SANCTUARY_COOLDOWN := 14.0
const SANCTUARY_PLACEMENT_RANGE := 260.0
const SANCTUARY_RADIUS: Array[float] = [130.0, 135.0, 140.0, 145.0, 150.0]
const SANCTUARY_DURATION: Array[float] = [9.0, 9.5, 10.0, 10.5, 11.0]
const SANCTUARY_TAKEN: Array[float] = [0.84, 0.82, 0.80, 0.78, 0.76]
const SANCTUARY_HEAL: Array[float] = [1.20, 1.25, 1.30, 1.35, 1.40]
const SANCTUARY_BURN: Array[float] = [0.14, 0.16, 0.18, 0.20, 0.22]
const GRACE_EXCESS_NO_PASSIVE := 0.12
const GRACE_EXCESS: Array[float] = [0.08, 0.065, 0.05]
const GRACE_PULSE_HEAL: Array[float] = [0.06, 0.09, 0.12]
const GRACE_PULSE_COOLDOWN := 6.0
const AEGIS_SP: Array[float] = [22.0, 23.0, 24.0, 25.0, 26.0]
const AEGIS_COOLDOWN := 15.0
const AEGIS_BASE: Array[float] = [45.0, 60.0, 75.0, 90.0, 105.0]
const AEGIS_PULSE: Array[float] = [0.55, 0.65, 0.75, 0.85, 0.95]
const AEGIS_DURATION := 6.0
const AEGIS_RADIUS := 120.0
const JUDGMENT_SP: Array[float] = [24.0, 25.0, 26.0, 27.0, 28.0]
const JUDGMENT_COOLDOWN := 6.0
const JUDGMENT_RANGE := 300.0
const JUDGMENT_POWER: Array[float] = [1.00, 1.15, 1.30, 1.45, 1.60]
const JUDGMENT_COLUMN := 55.0
const JUDGMENT_MAX_CHARGES := 5
const JUDGMENT_MAX_CHARGES_HOUR := 10
const EXPOSED_MULTIPLIER: Array[float] = [1.10, 1.15, 1.20]
const EXPOSED_DURATION: Array[float] = [4.0, 5.0, 6.0]
## D3: bonus against undead and ghosts, recorded as data and without effect (no such category).
const UNDEAD_BONUS: Array[float] = [0.15, 0.20, 0.25]
const SEAL_SP: Array[float] = [18.0, 19.0, 20.0, 21.0, 22.0]
const SEAL_COOLDOWN := 12.0
const SEAL_RANGE := 300.0
const SEAL_DURATION: Array[float] = [4.0, 4.5, 5.0, 5.5, 6.0]
const SEAL_ROOT: Array[float] = [1.6, 1.8, 2.0, 2.2, 2.4]
const SEAL_SLOW: Array[float] = [0.30, 0.32, 0.34, 0.36, 0.38]
const HOUR_SP: Array[float] = [40.0, 42.0, 44.0, 46.0, 48.0]
const HOUR_COOLDOWN: Array[float] = [60.0, 57.0, 54.0, 51.0, 48.0]
const HOUR_DURATION: Array[float] = [7.0, 7.5, 8.0, 8.5, 9.0]
const HOUR_HEAL := 2.0

# --- Run state (scripts/classes/priest/snapshot_manifest.json) -----------------------------
## Santuário/Graça family authority (E09 T5): zone, Grace, Égide, Selo.
var sanctuary := SanctuaryAuthority.new()
## Grace charges spent by the last committed Juízo (read by resolve_cast).
var judgment_charges := 0
## Remaining seconds of the Hora Santa (gameplay clock, frozen in pause).
var hour_remaining := 0.0
## True when the Hora opened its own Santuário (none lasted long enough).
var hour_opened_zone := false
## Heal multiplier of the Santuário before the Hora doubled it (restored at the end).
var hour_saved_heal := 1.0
## Seconds until the next Grace entry pulse is allowed.
var pulse_cooldown := 0.0
## The owner was inside the Santuário at the last tick (entry detection).
var was_inside := false

# --- Catalog data (pure) ------------------------------------------------------------

func kit_id() -> StringName:
	return &"priest"

func ready_for_play() -> bool:
	return true

func display_name() -> String:
	return "Sacerdote"

func skill_definitions() -> Array[SkillDefinition]:
	var result: Array[SkillDefinition] = []
	result.append(_active(SANCTUARY, "Santuário", SkillDefinition.Targeting.POINT, SkillDefinition.ActionKind.DEFENSIVE, SANCTUARY_SP, _fill(SANCTUARY_COOLDOWN), _fill(SANCTUARY_PLACEMENT_RANGE), SANCTUARY_DURATION, SANCTUARY_BURN, [&"sanctuary_circle_at_point", &"owner_damage_taken_inside", &"heal_multiplier_inside", &"light_burn_pulse"]))
	result.append(_passive(GRACE, "Graça", GRACE_EXCESS, GRACE_PULSE_HEAL, [&"grace_excess_heal_fraction", &"grace_entry_heal_pulse_when_full"]))
	result.append(_active(AEGIS, "Égide", SkillDefinition.Targeting.SELF, SkillDefinition.ActionKind.DEFENSIVE, AEGIS_SP, _fill(AEGIS_COOLDOWN), _fill(AEGIS_RADIUS), AEGIS_BASE, AEGIS_PULSE, [&"personal_shield", &"single_light_pulse_on_break_or_expiry", &"push_radius_120"]))
	var judgment := _active(JUDGMENT, "Juízo", SkillDefinition.Targeting.SINGLE_TARGET, SkillDefinition.ActionKind.OFFENSIVE, JUDGMENT_SP, _fill(JUDGMENT_COOLDOWN), _fill(JUDGMENT_RANGE), JUDGMENT_POWER, _fill(SanctuaryRules.JUDGMENT_PER_CHARGE), [&"spend_grace", &"light_column_radius_55", &"all_enemies_in_sanctuary", &"judgment_per_charge_0_40"])
	judgment.can_crit = true
	result.append(judgment)
	result.append(_passive(EXORCIST, "Exorcista", EXPOSED_MULTIPLIER, EXPOSED_DURATION, [&"light_removes_enemy_shield_or_buff", &"exposed_to_owner_light", &"undead_bonus_dormant"]))
	result.append(_active(LIGHT_SEAL, "Selo de Luz", SkillDefinition.Targeting.SINGLE_TARGET, SkillDefinition.ActionKind.DEFENSIVE, SEAL_SP, _fill(SEAL_COOLDOWN), _fill(SEAL_RANGE), SEAL_DURATION, SEAL_SLOW, [&"seal_mark", &"root_or_boss_slow", &"grace_on_light_damage"]))
	result.append(_active(HOLY_HOUR, "Hora Santa", SkillDefinition.Targeting.SELF, SkillDefinition.ActionKind.DEFENSIVE, HOUR_SP, HOUR_COOLDOWN, _fill(0.0), HOUR_DURATION, _fill(HOUR_HEAL), [&"wide_golden_sanctuary", &"heal_doubled", &"grace_unlimited", &"judgment_without_sp"]))
	return result

func learning_entries() -> Array[Dictionary]:
	return [
		{"skill_id": SANCTUARY, "category": &"active", "free_rank": 1, "max_purchased_rank": 4, "job_level": 20, "prerequisites": {}},
		{"skill_id": GRACE, "category": &"passive", "free_rank": 0, "max_purchased_rank": 3, "job_level": 23, "prerequisites": {}},
		{"skill_id": AEGIS, "category": &"active", "free_rank": 0, "max_purchased_rank": 5, "job_level": 25, "prerequisites": {}},
		{"skill_id": JUDGMENT, "category": &"active", "free_rank": 0, "max_purchased_rank": 5, "job_level": 28, "prerequisites": {}},
		{"skill_id": EXORCIST, "category": &"passive", "free_rank": 0, "max_purchased_rank": 3, "job_level": 31, "prerequisites": {}},
		{"skill_id": LIGHT_SEAL, "category": &"active", "free_rank": 0, "max_purchased_rank": 5, "job_level": 34, "prerequisites": {}},
		{"skill_id": HOLY_HOUR, "category": &"active", "free_rank": 0, "max_purchased_rank": 5, "job_level": 37, "prerequisites": {}},
	]

func feedback_recipes() -> Dictionary:
	return {
		SANCTUARY: [&"area", &"light", &"", FeedbackRecipeCatalog.COMMIT | FeedbackRecipeCatalog.PERIODIC],
		GRACE: [&"buff", &"light", &"", FeedbackRecipeCatalog.COMMIT],
		AEGIS: [&"buff", &"light", &"", FeedbackRecipeCatalog.COMMIT],
		JUDGMENT: [&"impact", &"light", &"", FeedbackRecipeCatalog.COMMIT],
		EXORCIST: [&"buff", &"light", &"", FeedbackRecipeCatalog.COMMIT],
		LIGHT_SEAL: [&"buff", &"light", &"", FeedbackRecipeCatalog.COMMIT],
		HOLY_HOUR: [&"buff", &"light", &"", FeedbackRecipeCatalog.COMMIT],
	}

func skill_texts() -> Dictionary:
	var texts := {
		SANCTUARY: {"flavor": "Existem lugares onde o mal não entra. Ele os desenha no chão.", "effect": "Desenha um círculo de luz no ponto escolhido, um por vez. Dentro dele, o Sacerdote recebe menos dano e a cura dele rende mais, e os inimigos queimam aos poucos. Sair do círculo não o desfaz, mas o Sacerdote perde os bônus.", "combo": "A cura que passa do HP máximo dentro dele vira Graça. Entrar nele com a Graça cheia dá um pulso de cura.", "mechanics": "Círculo de luz com alcance de colocação 260; pulso de queimadura a cada 1s."},
		GRACE: {"flavor": "O que sobra da cura não se perde: vira luz.", "effect": "Liga as cargas de Graça: a cura que passaria do HP máximo rende cargas mais depressa. Entrar no Santuário com a Graça cheia dá um pulso de cura.", "combo": "Prece, Escudo Votivo e o Selo de Luz também geram Graça.", "mechanics": "Passiva automática; reserva de até 5 cargas."},
		AEGIS: {"flavor": "Um halo dourado se fecha sobre o corpo.", "effect": "Um halo absorve dano por 6s. Ao quebrar ou expirar, solta um único pulso de luz que fere e empurra os inimigos próximos.", "combo": "Dentro do Santuário, o pulso abre espaço sem tirar o Sacerdote do círculo.", "mechanics": "Escudo pessoal como o da Perseverança; pulso de raio 120."},
		JUDGMENT: {"flavor": "Firme e sem raiva: pune por dever.", "effect": "Gasta a Graça: uma coluna de luz cai sobre o alvo, e o dano cresce com cada carga gasta. Dentro do Santuário, atinge todos os inimigos no círculo.", "combo": "Na Hora Santa, não custa SP e gasta até 10 cargas.", "mechanics": "Dano de luz: % do MATQ × (1 + 0,40 por carga); até 5 cargas (10 na Hora Santa)."},
		EXORCIST: {"flavor": "A luz não pergunta o que o inimigo carrega.", "effect": "A luz do Sacerdote remove o escudo ou um buff do inimigo atingido. Sem nada a remover, o alvo fica Exposto: recebe mais dano da luz do Sacerdote por alguns segundos.", "combo": "O bônus contra mortos-vivos e fantasmas fica registrado e só vale quando essas criaturas existirem.", "mechanics": "Passiva automática; vale para golpes diretos de luz."},
		LIGHT_SEAL: {"flavor": "Um aro se fecha: o que não pertence ao mundo fica onde está.", "effect": "Um aro de luz se fecha sobre o alvo: prende e marca. No chefe, apenas o deixa lento. Todo dano de luz no marcado gera Graça.", "combo": "Com a queimadura do Santuário, o marcado rende Graça a cada pulso.", "mechanics": "Marca de um alvo por vez; raiz nos comuns, lentidão no chefe."},
		HOLY_HOUR: {"flavor": "A hora em que o círculo fica dourado.", "effect": "Por alguns segundos, o Santuário cresce e fica dourado: a cura dobra, a Graça não tem limite e cada Juízo dentro dele não custa SP.", "combo": "Cure, acumule e solte vários Juízos sobre o círculo inteiro.", "mechanics": "Círculo ampliado (× 1,6); ao fim, a Graça volta ao teto de 5."},
	}
	for skill: StringName in SKILLS:
		var ranks: Array[String] = []
		for rank: int in range(1, (3 if skill in [GRACE, EXORCIST] else 5) + 1): ranks.append(rank_tooltip(skill, rank))
		texts[skill]["ranks"] = ranks
		texts[skill]["mechanics"] = String(texts[skill]["mechanics"]) + " " + " · ".join(ranks)
	return texts

## Per-rank tooltip line (pt-BR) of one skill. Pure.
func rank_tooltip(skill_id: StringName, rank: int) -> String:
	var i := rank - 1
	match skill_id:
		SANCTUARY:
			if i < 0 or i >= 5: return ""
			return "R%d: %s SP, %ss, raio %d, dano recebido × %s, cura × %s, queima %d%% do MATQ" % [rank, _num(SANCTUARY_SP[i]), _num(SANCTUARY_DURATION[i]), int(SANCTUARY_RADIUS[i]), _num(SANCTUARY_TAKEN[i]), _num(SANCTUARY_HEAL[i]), roundi(SANCTUARY_BURN[i] * 100.0)]
		GRACE:
			if i < 0 or i >= 3: return ""
			return "R%d: 1 Graça a cada %s%% do HP máximo de cura excedente, pulso de entrada cura %d%% do HP máximo" % [rank, _num(GRACE_EXCESS[i] * 100.0), roundi(GRACE_PULSE_HEAL[i] * 100.0)]
		AEGIS:
			if i < 0 or i >= 5: return ""
			return "R%d: %s SP, escudo %d + VIT/INT, pulso %d%% do MATQ" % [rank, _num(AEGIS_SP[i]), int(AEGIS_BASE[i]), roundi(AEGIS_PULSE[i] * 100.0)]
		JUDGMENT:
			if i < 0 or i >= 5: return ""
			return "R%d: %s SP, %d%% do MATQ, até 5 cargas (× 3 com 5)" % [rank, _num(JUDGMENT_SP[i]), roundi(JUDGMENT_POWER[i] * 100.0)]
		EXORCIST:
			if i < 0 or i >= 3: return ""
			return "R%d: Exposto × %s por %ss, contra mortos-vivos +%d%% (sem efeito por ora)" % [rank, _num(EXPOSED_MULTIPLIER[i]), _num(EXPOSED_DURATION[i]), roundi(UNDEAD_BONUS[i] * 100.0)]
		LIGHT_SEAL:
			if i < 0 or i >= 5: return ""
			return "R%d: %s SP, marca %ss, raiz %ss, lentidão no chefe %d%%" % [rank, _num(SEAL_SP[i]), _num(SEAL_DURATION[i]), _num(SEAL_ROOT[i]), roundi(SEAL_SLOW[i] * 100.0)]
		HOLY_HOUR:
			if i < 0 or i >= 5: return ""
			return "R%d: %s SP, recarga %ss, %ss" % [rank, _num(HOUR_SP[i]), _num(HOUR_COOLDOWN[i]), _num(HOUR_DURATION[i])]
	return ""

func vfx_effects() -> Dictionary:
	return {
		&"priest_sanctuary_circle": {"skill_id": SANCTUARY, "kinds": [&"effect_start"], "size": 300.0},
		&"priest_sanctuary_burn": {"skill_id": SANCTUARY, "kinds": [&"impact"], "size": 48.0},
		&"priest_grace_rings": {"skill_id": JUDGMENT, "kinds": [&"effect_start"], "size": 64.0},
		&"priest_judgment_column": {"skill_id": JUDGMENT, "kinds": [&"impact"], "size": 110.0},
		&"priest_aegis_halo": {"skill_id": AEGIS, "kinds": [&"effect_start"], "size": 90.0},
		&"priest_aegis_pulse": {"skill_id": AEGIS, "kinds": [&"impact"], "size": 120.0},
		&"priest_seal_ring": {"skill_id": LIGHT_SEAL, "kinds": [&"effect_start"], "size": 80.0},
		&"priest_holy_hour_circle": {"skill_id": HOLY_HOUR, "kinds": [&"effect_start"], "size": 340.0},
		# T16 (A15): feedback events of the two passives (the kit emits `skill_committed` for them).
		&"priest_grace_gain": {"skill_id": GRACE, "kinds": [&"effect_start"], "size": 80.0},
		&"priest_exorcist_flash": {"skill_id": EXORCIST, "kinds": [&"effect_start"], "size": 80.0},
	}

const IVORY := Color(1.0, 0.97, 0.86)
const GOLD := Color(1.0, 0.84, 0.38)
const SKY := Color(0.62, 0.84, 1.0)

func draw_vfx(effect_id: StringName, canvas: CanvasItem, _pulse: Dictionary, position: Vector2, t: float) -> bool:
	var fade := clampf(1.0 - t, 0.0, 1.0)
	match effect_id:
		&"priest_sanctuary_circle":
			var reach := 140.0 * minf(1.0, t * 3.0)
			var scale := Vector2(1.0, 0.5)
			canvas.draw_set_transform(position, 0.0, scale)
			canvas.draw_circle(Vector2.ZERO, reach, Color(IVORY, 0.18 * fade))
			canvas.draw_arc(Vector2.ZERO, reach, 0.0, TAU, 48, Color(GOLD, 0.9 * fade), 3.0)
			canvas.draw_arc(Vector2.ZERO, reach * 0.72, 0.0, TAU, 40, Color(SKY, 0.5 * fade), 2.0)
			for k: int in 8: canvas.draw_line(Vector2.from_angle(k * TAU / 8.0 + t) * reach * 0.72, Vector2.from_angle(k * TAU / 8.0 + t) * reach, Color(IVORY, 0.6 * fade), 2.0)
			canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		&"priest_sanctuary_burn":
			for k: int in 3:
				var offset := Vector2(-6.0 + 6.0 * k, -8.0 - 20.0 * t - 4.0 * k)
				canvas.draw_circle(position + offset, 3.5 * fade + 1.0, Color(IVORY, 0.85 * fade))
		&"priest_grace_rings":
			for k: int in 3:
				var center := position + Vector2(0.0, -46.0 - 10.0 * t) + Vector2.from_angle(TAU * (t + k / 3.0)) * Vector2(14.0, 5.0)
				canvas.draw_arc(center, 6.0, 0.0, TAU, 14, Color(GOLD, fade), 2.0)
		&"priest_judgment_column":
			var width := 28.0 * (1.0 - 0.5 * t)
			canvas.draw_rect(Rect2(position + Vector2(-width * 0.5, -160.0), Vector2(width, 160.0)), Color(GOLD, 0.5 * fade))
			canvas.draw_rect(Rect2(position + Vector2(-width * 0.2, -160.0), Vector2(width * 0.4, 160.0)), Color(1.0, 1.0, 0.94, 0.9 * fade))
			canvas.draw_arc(position, 18.0 + 32.0 * t, 0.0, TAU, 24, Color(GOLD, fade), 3.0)
		&"priest_aegis_halo":
			canvas.draw_arc(position + Vector2(0.0, -26.0), 30.0 + 4.0 * sin(t * TAU), 0.0, TAU, 28, Color(GOLD, 0.9 * fade), 3.0)
			canvas.draw_arc(position + Vector2(0.0, -26.0), 22.0, 0.0, TAU, 24, Color(IVORY, 0.55 * fade), 2.0)
		&"priest_aegis_pulse":
			canvas.draw_arc(position, 20.0 + AEGIS_RADIUS * t, 0.0, TAU, 36, Color(GOLD, fade), 4.0 * fade + 1.0)
		&"priest_seal_ring":
			var radius := 48.0 * (1.0 - 0.6 * t)
			canvas.draw_arc(position + Vector2(0.0, -20.0), radius, 0.0, TAU, 28, Color(IVORY, fade), 3.0)
			for k: int in 4: canvas.draw_line(position + Vector2(0.0, -20.0) + Vector2.from_angle(k * TAU / 4.0 + t) * radius, position + Vector2(0.0, -20.0) + Vector2.from_angle(k * TAU / 4.0 + t) * (radius + 8.0), Color(GOLD, fade), 2.0)
		&"priest_grace_gain":
			# One ring of light rises around the Sacerdote for each charge gained.
			for k: int in 2:
				var rise := clampf(t * 1.4 - 0.25 * k, 0.0, 1.0)
				canvas.draw_arc(position + Vector2(0.0, -10.0 - 56.0 * rise), 16.0 - 4.0 * rise, 0.0, TAU, 20, Color(GOLD, (1.0 - rise) * 0.9), 2.5)
			for k: int in 3: canvas.draw_circle(position + Vector2(-10.0 + 10.0 * k, -20.0 - 40.0 * t - 5.0 * k), 2.5 * fade + 0.5, Color(IVORY, 0.85 * fade))
		&"priest_exorcist_flash":
			# A sun-cross flares at the Sacerdote's hands: the light is purging.
			var center := position + Vector2(0.0, -34.0)
			canvas.draw_arc(center, 8.0 + 22.0 * t, 0.0, TAU, 24, Color(GOLD, 0.9 * fade), 2.5)
			for k: int in 4:
				var dir := Vector2.from_angle(PI * 0.25 + PI * 0.5 * k)
				canvas.draw_line(center + dir * (6.0 + 8.0 * t), center + dir * (14.0 + 22.0 * t), Color(IVORY, fade), 2.0)
			canvas.draw_line(center + Vector2(-9.0 * fade, 0.0), center + Vector2(9.0 * fade, 0.0), Color(IVORY, fade), 2.0)
			canvas.draw_line(center + Vector2(0.0, -9.0 * fade), center + Vector2(0.0, 9.0 * fade), Color(IVORY, fade), 2.0)
		&"priest_holy_hour_circle":
			var reach := 224.0 * minf(1.0, t * 2.0)
			canvas.draw_set_transform(position, 0.0, Vector2(1.0, 0.5))
			canvas.draw_circle(Vector2.ZERO, reach, Color(GOLD, 0.22 * fade))
			canvas.draw_arc(Vector2.ZERO, reach, 0.0, TAU, 56, Color(GOLD, fade), 4.0)
			for k: int in 12: canvas.draw_line(Vector2.ZERO, Vector2.from_angle(k * TAU / 12.0) * reach, Color(GOLD, 0.35 * fade), 2.0)
			canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_:
			return false
	return true

# --- Hooks ----------------------------------------------------------------------------

func on_attach(player: PlayerActor) -> void:
	sanctuary.configure(player, GRACE_FAMILY, ICE_SOURCE)
	_apply_grace_fraction(player)

func temporary_stat_sources(player: PlayerActor) -> Array[Dictionary]:
	return sanctuary.temporary_stat_sources(player)

func on_tick(player: PlayerActor, delta: float) -> void:
	sanctuary.tick(player, delta)
	pulse_cooldown = maxf(0.0, pulse_cooldown - delta)
	if hour_remaining > 0.0:
		hour_remaining = maxf(0.0, hour_remaining - delta)
		if hour_remaining <= 0.0: _end_hour(player)
	_check_entry(player)

func can_cast(_player: PlayerActor, cast: Dictionary) -> Dictionary:
	if StringName(cast.get("skill_id", &"")) == SANCTUARY and hour_active(): return {"ok": false, "error_code": &"priest_hour_active"}
	return {"ok": true, "error_code": &""}

func on_cast_confirmed(player: PlayerActor, cast: Dictionary) -> void:
	if StringName(cast["skill_id"]) != JUDGMENT: return
	judgment_charges = sanctuary.spend_for_cast(player, cast, 1, JUDGMENT_MAX_CHARGES_HOUR if hour_active() else JUDGMENT_MAX_CHARGES)

## T1.2: the Juízo costs 0 SP during the Hora Santa while the Sacerdote is in the Santuário.
func skill_cost(_player: PlayerActor, skill_id: StringName, base_cost: float) -> float:
	return 0.0 if skill_id == JUDGMENT and hour_active() and _owner_inside() else base_cost

## T1.2: Prece and Escudo Votivo (Acólito) give +1 Grace per paid commit.
func on_base_skill_committed(player: PlayerActor, skill_id: StringName, _context: Dictionary) -> void:
	if skill_id == PRAYER or skill_id == VOTIVE_SHIELD:
		var before := grace_charges()
		sanctuary.gain({"key": "base:%s@%.5f" % [skill_id, player.kit_time]}, 1)
		_announce_grace(player, before)

func resolve_cast(player: PlayerActor, cast: Dictionary) -> bool:
	var skill := StringName(cast["skill_id"])
	var values := _rank_values(player, skill, int(cast["rank"]))
	if values == null: return false
	match skill:
		SANCTUARY:
			return sanctuary.open_zone(player, _sanctuary_config(values.rank, SanctuaryAuthority.cast_point(cast), values.power, SanctuaryRules.SHAPE_CIRCLE, false))["ok"]
		AEGIS:
			var capacity := StatCalculator.personal_shield_capacity(values.power, player.stat_breakdown)
			return sanctuary.grant_aegis(player, capacity, AEGIS_DURATION, player.stat_breakdown.value(&"magic_attack") * values.secondary_power, AEGIS, values.range)
		JUDGMENT:
			return _resolve_judgment(player, cast, values)
		LIGHT_SEAL:
			return _resolve_seal(player, cast, values)
		HOLY_HOUR:
			return _resolve_hour(player, values)
	return false

func before_hit_mitigation(player: PlayerActor, hit: Dictionary) -> Dictionary:
	return sanctuary.before_hit(player, hit)

func on_shield_broken(player: PlayerActor, hit: Dictionary, result: Dictionary) -> void:
	sanctuary.on_shield_broken(player, hit, result)

func on_heal(player: PlayerActor, requested: float, applied: float, source: StringName) -> void:
	var before := grace_charges()
	sanctuary.on_heal(player, requested, applied, source)
	_announce_grace(player, before)

## Light damage on the sealed enemy gives Grace; a direct light hit triggers the Exorcista.
func on_damage_dealt(player: PlayerActor, result: Dictionary) -> void:
	var victim := instance_from_id(int(result.get("target_id", 0))) as CombatActor
	if victim == null or not is_instance_valid(victim) or not SanctuaryHelpers.is_light_result(result): return
	if sanctuary.is_sealed(victim):
		var before := grace_charges()
		sanctuary.gain(SanctuaryHelpers.result_event(result), 1)
		_announce_grace(player, before)
	if bool(result.get("secondary", false)) or not bool(result.get("landed", false)) or not victim.is_alive(): return
	var rank := player.skill_rank(EXORCIST)
	if rank > 0: exorcise(player, victim, rank)

func on_death(player: PlayerActor) -> void:
	sanctuary.on_death(player)
	hour_remaining = 0.0
	hour_opened_zone = false
	hour_saved_heal = 1.0
	judgment_charges = 0
	pulse_cooldown = 0.0
	was_inside = false

func on_build_changed(player: PlayerActor) -> void:
	sanctuary.on_build_changed(player)
	_apply_grace_fraction(player)

func snapshot_compact_blocker(_player: PlayerActor) -> String:
	if hour_active(): return "priest_holy_hour"
	return sanctuary.compact_blocker()

# --- HUD (E10a T12, C9) -----------------------------------------------------------------------

## Pure read for the HUD (ragrpg_kit_hud_v1): Grace (unlimited with the deadline in the Hora
## Santa), the Égide and the Hora deadlines, the Santuário zone and the Selo de Luz badge.
## Values come from the SanctuaryAuthority and the kit state; no formula.
func hud_state(player: PlayerActor) -> Dictionary:
	var rank := clampi(player.skill_rank(HOLY_HOUR), 1, 5) if is_instance_valid(player) else 1
	var hour_total := HOUR_DURATION[rank - 1]
	var resources: Array[Dictionary] = [sanctuary.hud_grace(hour_total)]
	var aegis := sanctuary.hud_aegis(AEGIS, AEGIS_DURATION)
	if not aegis.is_empty(): resources.append(aegis)
	if hour_active():
		resources.append({"id": HOLY_HOUR, "label": "Hora Santa", "kind": &"timer", "remaining": hour_remaining, "total": maxf(hour_total, hour_remaining), "element": SanctuaryAuthority.HUD_LIGHT})
	var marks: Array[Dictionary] = []
	var seal := sanctuary.hud_seal_mark()
	if not seal.is_empty(): marks.append(seal)
	return {"schema": KitHudState.SCHEMA, "kit_id": kit_id(), "resources": resources, "zones": sanctuary.hud_zones(player), "target_marks": marks}

# --- Queries --------------------------------------------------------------------------

func hour_active() -> bool:
	return hour_remaining > 0.0

func grace_charges() -> int:
	return sanctuary.grace.charges

## D3: the bonus of the Exorcista against undead and ghosts. No enemy carries that category
## yet, so it is always 0; the day the category exists, only this method changes.
func undead_bonus_for(_enemy: CombatActor) -> float:
	return 0.0

## The Exorcista effect on one enemy hit by direct light: removes a shield, else the strongest
## defensive buff, else leaves it Exposed to this owner's light. Returns what happened
## (&"shield", &"buff" or &"exposed"; empty when nothing applied).
func exorcise(player: PlayerActor, victim: CombatActor, rank: int) -> StringName:
	if not is_instance_valid(victim) or not victim.is_alive() or rank < 1: return &""
	if victim.health.shield_hp > 0.0:
		victim.health.clear_shield()
		_announce_exorcism(player, victim, &"shield")
		return &"shield"
	var buff := _strongest_buff(victim)
	if not buff.is_empty():
		victim.remove_received_damage_source(buff)
		_announce_exorcism(player, victim, &"buff")
		return &"buff"
	var i := clampi(rank, 1, 3) - 1
	if not victim.add_received_damage_source(EXPOSED_SOURCE, EXPOSED_MULTIPLIER[i], EXPOSED_DURATION[i], player.get_instance_id(), SanctuaryRules.LIGHT_ELEMENT): return &""
	_announce_exorcism(player, victim, &"exposed")
	return &"exposed"

# --- Feedback events (presentation only, T16 / A15) ---------------------------------------

## The passive's own commit effect: `skill_committed` for a passive skill id, which the
## bridge turns into the `effect_start` of the recipe (the COMMIT flag) at the Sacerdote.
func _announce(player: PlayerActor, skill: StringName) -> void:
	if is_instance_valid(player): player.presentation_fact.emit(&"skill_committed", skill, Vector2.ZERO, 0.0)

## A Graça charge was gained when the count is above `before` (a full reserve gains nothing).
func _announce_grace(player: PlayerActor, before: int) -> void:
	if grace_charges() > before: _announce(player, GRACE)

## The Exorcista acted on `victim`: the flash at the Sacerdote, and the drawing on the enemy
## (the aro and seal while Exposed, or the burst of a shield or buff removed).
func _announce_exorcism(player: PlayerActor, victim: CombatActor, outcome: StringName) -> void:
	_announce(player, EXORCIST)
	var mark := load(EXORCIST_MARK_SCRIPT) as Script
	if mark == null: return
	mark.call(&"attach", victim, &"exposed" if outcome == &"exposed" else &"stripped", EXPOSED_SOURCE, player.get_instance_id())

# --- Internals --------------------------------------------------------------------------

func _owner_inside() -> bool:
	var zone := sanctuary.zone(ROLE)
	return zone != null and zone.owner_inside

## Defensive buff of an enemy: the received-damage source with the smallest multiplier below 1.
func _strongest_buff(victim: CombatActor) -> StringName:
	var best: StringName = &""
	var lowest := 1.0
	var keys: Array = victim.received_damage_sources.keys()
	keys.sort()
	for key: Variant in keys:
		var multiplier := float(victim.received_damage_sources[key].get("multiplier", 1.0))
		if multiplier < lowest:
			lowest = multiplier
			best = StringName(key)
	return best

func _resolve_judgment(player: PlayerActor, cast: Dictionary, values: SkillRankDefinition) -> bool:
	var victim := cast.get("target") as CombatActor
	if not is_instance_valid(victim) or not victim.is_alive(): return false
	var actors: Array = cast.get("actors", [])
	if actors.is_empty(): actors = [victim]
	var zone := sanctuary.zone(ROLE)
	var targets: Array[CombatActor] = []
	if zone != null and zone.owner_inside:
		targets = SanctuaryHelpers.judgment_targets(player, actors, null, JUDGMENT_COLUMN, zone)
	else:
		var point: Variant = victim.world_point() if player.world_motion != null else victim.global_position
		targets = SanctuaryHelpers.judgment_targets(player, actors, point, JUDGMENT_COLUMN)
	if victim not in targets: targets.push_front(victim)
	var base := player.stat_breakdown.value(&"magic_attack") * values.power
	var struck := 0
	for enemy: CombatActor in targets:
		if not is_instance_valid(enemy) or not enemy.is_alive(): continue
		var request := SanctuaryHelpers.judgment_request(player, enemy, JUDGMENT, base, judgment_charges, values.secondary_power, true)
		if request == null: continue
		player.kit_emit_hit(request, enemy)
		struck += 1
	return struck > 0

func _resolve_seal(player: PlayerActor, cast: Dictionary, values: SkillRankDefinition) -> bool:
	var victim := cast.get("target") as CombatActor
	if not is_instance_valid(victim) or not victim.is_alive(): return false
	if not sanctuary.seal(player, victim, SEAL_KEY, values.power, 1)["ok"]: return false
	if victim.hard_controls.boss:
		victim.apply_slow(values.secondary_power, values.power, SEAL_SLOW_SOURCE)
	else:
		victim.apply_root(SEAL_ROOT[clampi(values.rank, 1, 5) - 1], &"magic")
	return true

func _resolve_hour(player: PlayerActor, values: SkillRankDefinition) -> bool:
	var duration := values.power
	var zone := sanctuary.zone(ROLE)
	if zone != null and zone.remaining >= duration:
		var saved := float(zone.rules["heal_multiplier"])
		if not sanctuary.set_zone_shape(ROLE, SanctuaryRules.SHAPE_WIDE_CIRCLE)["ok"]: return false
		hour_saved_heal = saved
		hour_opened_zone = false
		zone.rules["heal_multiplier"] = HOUR_HEAL
	else:
		var point: Variant = null
		if zone != null: point = zone.area.anchor() if zone.area != null else zone.center
		var rank := maxi(1, player.skill_rank(SANCTUARY))
		var opened := sanctuary.open_zone(player, _sanctuary_config(rank, point, duration, SanctuaryRules.SHAPE_WIDE_CIRCLE, true))
		if not opened["ok"]: return false
		hour_opened_zone = true
		hour_saved_heal = 1.0
	hour_remaining = duration
	sanctuary.begin_unlimited(duration)
	return true

func _end_hour(player: PlayerActor) -> void:
	hour_remaining = 0.0
	var zone := sanctuary.zone(ROLE)
	if zone != null:
		if hour_opened_zone:
			sanctuary.end_zone(ROLE, player)
		else:
			sanctuary.set_zone_shape(ROLE, SanctuaryRules.SHAPE_CIRCLE)
			zone.rules["heal_multiplier"] = hour_saved_heal
	hour_opened_zone = false
	hour_saved_heal = 1.0

## Entering the Santuário (or opening it with the owner inside) with full Grace heals a
## fraction of max HP, at most once per GRACE_PULSE_COOLDOWN.
func _check_entry(player: PlayerActor) -> void:
	var inside := _owner_inside()
	var entered := inside and not was_inside
	was_inside = inside
	if not entered or pulse_cooldown > 0.0 or sanctuary.grace.charges < SanctuaryRules.GRACE_CAP: return
	var rank := player.skill_rank(GRACE)
	if rank < 1: return
	pulse_cooldown = GRACE_PULSE_COOLDOWN
	player.heal_player(player.health.max_hp * GRACE_PULSE_HEAL[clampi(rank, 1, 3) - 1], GRACE_PULSE_SOURCE)
	_announce(player, GRACE)

func _sanctuary_config(rank: int, point: Variant, duration: float, shape: StringName, hour: bool) -> Dictionary:
	var i := clampi(rank, 1, 5) - 1
	var config := {
		"role": ROLE, "skill_id": SANCTUARY, "shape": shape, "anchor": SanctuaryRules.ANCHOR_WORLD,
		"radius": SANCTUARY_RADIUS[i], "duration": duration,
		"rules": {"owner_damage_taken": SANCTUARY_TAKEN[i], "burn_ratio": SANCTUARY_BURN[i], "burn_stat": &"magic_attack", "heal_multiplier": HOUR_HEAL if hour else SANCTUARY_HEAL[i]},
	}
	if point != null: config["point"] = point
	return config

func _apply_grace_fraction(player: PlayerActor) -> void:
	var rank := player.skill_rank(GRACE) if is_instance_valid(player) else 0
	sanctuary.grace.excess_fraction = GRACE_EXCESS[clampi(rank, 1, 3) - 1] if rank > 0 else GRACE_EXCESS_NO_PASSIVE

func _rank_values(player: PlayerActor, skill: StringName, rank: int) -> SkillRankDefinition:
	var values := player.skill_rank_definition(skill) if is_instance_valid(player) else null
	if values != null: return values
	var definition := ClassKitRegistry.skill_definition(skill)
	return definition.rank_definition(clampi(rank, 1, definition.ranks.size())) if definition != null else null

# --- Data builders (pure) ------------------------------------------------------------------

static func _fill(value: float, count: int = 5) -> Array[float]:
	var result: Array[float] = []
	for index: int in count: result.append(value)
	return result

static func _num(value: float) -> String:
	return String.num(value, 2).replace(".", ",")

static func _active(id: StringName, name: String, targeting: SkillDefinition.Targeting, kind: SkillDefinition.ActionKind, costs: Array[float], cooldowns: Array[float], ranges: Array[float], powers: Array[float], secondary: Array[float], effects: Array[StringName]) -> SkillDefinition:
	var definition := SkillDefinition.new()
	definition.id = id
	definition.display_name = name
	definition.category = SkillDefinition.Category.ACTIVE
	definition.handler_id = SkillDefinition.Handler.KIT
	definition.targeting = targeting
	definition.action_kind = kind
	definition.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	definition.element = &"light"
	definition.range = ranges[0]
	for index: int in 5:
		var values := SkillRankDefinition.new()
		values.rank = index + 1
		values.sp_cost = costs[index]
		values.cooldown = cooldowns[index]
		values.range = ranges[index]
		values.power = powers[index]
		values.secondary_power = secondary[index]
		values.effect_ids = effects.duplicate()
		definition.ranks.append(values)
	return definition

static func _passive(id: StringName, name: String, powers: Array[float], secondary: Array[float], effects: Array[StringName]) -> SkillDefinition:
	var definition := SkillDefinition.new()
	definition.id = id
	definition.display_name = name
	definition.category = SkillDefinition.Category.PASSIVE
	definition.handler_id = SkillDefinition.Handler.KIT
	definition.targeting = SkillDefinition.Targeting.SELF
	definition.action_kind = SkillDefinition.ActionKind.DEFENSIVE
	definition.element = &"light"
	for index: int in 3:
		var values := SkillRankDefinition.new()
		values.rank = index + 1
		values.power = powers[index]
		values.secondary_power = secondary[index]
		values.effect_ids = effects.duplicate()
		definition.ranks.append(values)
	return definition

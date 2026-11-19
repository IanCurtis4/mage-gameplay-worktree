extends ClassKit
## E10a T7 — Cultista (`cultist`, pure evolution 2-2 of the Acólito). Contract with the
## numbers: docs/epics/e10a/t7_contract.md. Seams: docs/epics/e10a/t1_base_seam_api.md and
## docs/epics/e09/t1_kit_seam_api.md. Madness family authority: docs/epics/e10a/t4_madness_api.md.
##
## The Cultista never creates a MadnessAuthority: it reads the origin's one (`madness` field
## of the Acólito base) on every use and never stores it. It forwards on_tick (deduplicated by
## the authority) and is the only module that forwards the Ecstasy hooks
## (temporary_stat_sources, skill_cost, before_hit_mitigation). Data methods are pure; the
## variables below are run state (scripts/classes/cultist/snapshot_manifest.json). Element of
## every skill: `shadow` (magic damage with the tag, no resistance axis).

const GAZE := &"cultist_abyss_gaze"
const ECSTASY := &"cultist_ecstasy"
const IDOL := &"cultist_impossible_idol"
const SHARED := &"cultist_shared_delirium"
const PUPIL := &"cultist_open_pupil"
const GEOMETRY := &"cultist_impossible_geometry"
const REVELATION := &"cultist_revelation"
const SKILLS: Array[StringName] = [GAZE, ECSTASY, IDOL, SHARED, PUPIL, GEOMETRY, REVELATION]
const PASSIVES: Array[StringName] = [ECSTASY, PUPIL]

const PUPIL_SOURCE := &"cultist_open_pupil"
const REVELATION_SOURCE := &"cultist_revelation"
const GEOMETRY_SOURCE := &"cultist_impossible_geometry"
const GEOMETRY_MARK := &"cultist_geometry"
## Persistent drawn figures (T16, A15): kinds of cultist_figure_node.gd.
const FIGURE_GEOMETRY := &"geometry"
const FIGURE_REVELATION := &"revelation"
const FIGURE_SCRIPT := "res://scripts/classes/cultist/cultist_figure_node.gd"
const GROUND_FLAT := Vector2(1.0, 0.55)
const GROUND_WORLD := Vector2(1.202, 0.601)
const STAT_SOURCE := &"cultist_ecstasy"
## Short C1.7 sources renewed on every kit tick while their condition holds.
const SOURCE_REFRESH := 0.6

# --- Numbers (t7_contract §2) ----------------------------------------------------------
const GAZE_SP: Array[float] = [14.0, 15.0, 16.0, 17.0, 18.0]
const GAZE_COOLDOWN := 4.0
const GAZE_RANGE := 200.0
const GAZE_HALF_ANGLE := deg_to_rad(40.0)
const GAZE_DURATION := 2.0
const GAZE_INTERVAL := 0.4
const GAZE_TICKS := 5
const GAZE_POWER: Array[float] = [0.22, 0.26, 0.30, 0.34, 0.38]
const GAZE_MADNESS: Array[float] = [8.0, 9.0, 10.0, 11.0, 12.0]
const GAZE_MOVE_TOLERANCE := 24.0
const ECSTASY_PER_CHARGE: Array[float] = [0.03, 0.04, 0.05]
const IDOL_SP: Array[float] = [22.0, 23.0, 24.0, 25.0, 26.0]
const IDOL_COOLDOWN := 14.0
const IDOL_RANGE := 260.0
const IDOL_DURATION: Array[float] = [6.0, 7.0, 8.0, 9.0, 10.0]
const IDOL_HP: Array[float] = [0.25, 0.30, 0.35, 0.40, 0.45]
const IDOL_MADNESS: Array[float] = [6.0, 7.0, 8.0, 9.0, 10.0]
const SHARED_SP: Array[float] = [18.0, 19.0, 20.0, 21.0, 22.0]
const SHARED_COOLDOWN := 8.0
const SHARED_RANGE := 220.0
const SHARED_POWER: Array[float] = [0.60, 0.70, 0.80, 0.90, 1.00]
const SHARED_FRACTION: Array[float] = [0.40, 0.45, 0.50, 0.55, 0.60]
const SHARED_PULSE: Array[float] = [20.0, 25.0, 30.0, 35.0, 40.0]
const SHARED_MADNESS: Array[float] = [15.0, 20.0, 25.0, 30.0, 35.0]
const SHARED_DURATION := 8.0
const SHARED_RADIUS := 140.0
const PUPIL_MULTIPLIER: Array[float] = [1.10, 1.15, 1.20]
const GEOMETRY_SP: Array[float] = [24.0, 25.0, 26.0, 27.0, 28.0]
const GEOMETRY_COOLDOWN := 12.0
const GEOMETRY_RANGE := 260.0
const GEOMETRY_RADIUS := 110.0
const GEOMETRY_DURATION := 4.0
const GEOMETRY_INTERVAL := 0.5
const GEOMETRY_DISORIENT: Array[float] = [1.0, 1.25, 1.5, 1.75, 2.0]
const GEOMETRY_SLOW: Array[float] = [0.30, 0.32, 0.35, 0.38, 0.40]
const GEOMETRY_SLOW_DURATION := 1.0
const GEOMETRY_MADNESS := 10.0
const REVELATION_SP: Array[float] = [40.0, 42.0, 44.0, 46.0, 48.0]
const REVELATION_COOLDOWN: Array[float] = [60.0, 57.0, 54.0, 51.0, 48.0]
const REVELATION_RADIUS := 360.0
const REVELATION_DURATION: Array[float] = [5.0, 5.5, 6.0, 6.5, 7.0]
const REVELATION_INTERVAL := 0.5
const REVELATION_MADNESS: Array[float] = [12.0, 14.0, 16.0, 18.0, 20.0]
const REVELATION_DELIRIUM: Array[float] = [1.40, 1.45, 1.50, 1.55, 1.60]
const REVELATION_BOSS_DURATION: Array[float] = [5.0, 5.25, 5.5, 5.75, 6.0]
const REVELATION_BOSS := {"damage_taken": 1.4, "accuracy": 0.25, "minion_chance": 0.6, "minion_radius": 110.0, "immunity": 20.0}

# --- Run state (scripts/classes/cultist/snapshot_manifest.json) ------------------------
## Olhar do Abismo channel: seconds left, seconds to the next tick, ticks done, serial of
## the channel (Madness events), origin on the ground and rank of the cast.
var gaze_remaining := 0.0
var gaze_next_tick := 0.0
var gaze_ticks := 0
var gaze_serial := 0
var gaze_origin := Vector3.ZERO
var gaze_rank := 1
## MATK ratio per tick of the current channel.
var gaze_power := 0.0
## Prototype of the channel ticks (amount per tick, root of the cast).
var gaze_prototype: DamageRequest
## Geometria Impossível figure: seconds left, to the next pulse, serial, ground center, rank.
var geometry_remaining := 0.0
var geometry_next_pulse := 0.0
var geometry_serial := 0
var geometry_center := Vector3.ZERO
var geometry_rank := 1
## Revelação: seconds left, to the next gaze tick, serial, ticks done, rank.
var revelation_remaining := 0.0
var revelation_next_tick := 0.0
var revelation_serial := 0
var revelation_ticks := 0
var revelation_rank := 1

# --- Catalog data (pure) ---------------------------------------------------------------

func kit_id() -> StringName:
	return &"cultist"

func ready_for_play() -> bool:
	return true

func display_name() -> String:
	return "Cultista"

func skill_definitions() -> Array[SkillDefinition]:
	var result: Array[SkillDefinition] = []
	var gaze := _active(GAZE, "Olhar do Abismo", SkillDefinition.Targeting.SELF, SkillDefinition.ActionKind.OFFENSIVE, GAZE_SP, _fill(GAZE_COOLDOWN), _fill(GAZE_RANGE), GAZE_POWER, GAZE_MADNESS, [&"channel_cone_2s", &"magic_damage_per_tick", &"madness_per_tick"])
	gaze.can_crit = true
	result.append(gaze)
	result.append(_passive(ECSTASY, "Êxtase", ECSTASY_PER_CHARGE, ECSTASY_PER_CHARGE, [&"ecstasy_charges_0_5", &"magic_attack_per_charge", &"sp_cost_per_charge", &"damage_taken_from_3_charges"]))
	result.append(_active(IDOL, "Ídolo Impossível", SkillDefinition.Targeting.POINT, SkillDefinition.ActionKind.DEFENSIVE, IDOL_SP, _fill(IDOL_COOLDOWN), _fill(IDOL_RANGE), IDOL_DURATION, IDOL_MADNESS, [&"one_idol_decoy", &"commons_attack_idol", &"madness_while_gazing"]))
	var shared := _active(SHARED, "Delírio Compartilhado", SkillDefinition.Targeting.SINGLE_TARGET, SkillDefinition.ActionKind.OFFENSIVE, SHARED_SP, _fill(SHARED_COOLDOWN), _fill(SHARED_RANGE), SHARED_POWER, SHARED_MADNESS, [&"contagion_mark", &"one_hop_copy", &"delirium_pulse"])
	shared.can_crit = true
	result.append(shared)
	result.append(_passive(PUPIL, "Pupila Aberta", PUPIL_MULTIPLIER, _fill(0.0, 3), [&"damage_on_maddened_enemies"]))
	result.append(_active(GEOMETRY, "Geometria Impossível", SkillDefinition.Targeting.POINT, SkillDefinition.ActionKind.DEFENSIVE, GEOMETRY_SP, _fill(GEOMETRY_COOLDOWN), _fill(GEOMETRY_RANGE), GEOMETRY_DISORIENT, GEOMETRY_SLOW, [&"ground_figure", &"commons_walk_wrong_way", &"boss_slowed"]))
	result.append(_active(REVELATION, "Revelação", SkillDefinition.Targeting.SELF, SkillDefinition.ActionKind.OFFENSIVE, REVELATION_SP, REVELATION_COOLDOWN, _fill(REVELATION_RADIUS), REVELATION_DURATION, REVELATION_MADNESS, [&"fast_madness_in_sight", &"delirious_hurt_each_other", &"strong_boss_disorientation"]))
	return result

func learning_entries() -> Array[Dictionary]:
	return [
		{"skill_id": GAZE, "category": &"active", "free_rank": 1, "max_purchased_rank": 4, "job_level": 20},
		{"skill_id": ECSTASY, "category": &"passive", "free_rank": 0, "max_purchased_rank": 3, "job_level": 23},
		{"skill_id": IDOL, "category": &"active", "free_rank": 0, "max_purchased_rank": 5, "job_level": 25},
		{"skill_id": SHARED, "category": &"active", "free_rank": 0, "max_purchased_rank": 5, "job_level": 28},
		{"skill_id": PUPIL, "category": &"passive", "free_rank": 0, "max_purchased_rank": 3, "job_level": 31},
		{"skill_id": GEOMETRY, "category": &"active", "free_rank": 0, "max_purchased_rank": 5, "job_level": 34},
		{"skill_id": REVELATION, "category": &"active", "free_rank": 0, "max_purchased_rank": 5, "job_level": 37},
	]

## Audio (E10a T13 fix): shadow has no P6 cue of its own (C1.8), so every row uses a family whose
## physical cue exists. The Idol is a KitDecoy and Geometry a kit area, so neither emits `summon` or
## `trap_trigger`; Gaze and Revelation tick at 0.4/0.5 s, at or above the DOT gap, so no PERIODIC flag.
func feedback_recipes() -> Dictionary:
	return {
		GAZE: [&"area", &"shadow", &"", FeedbackRecipeCatalog.COMMIT],
		ECSTASY: [&"buff", &"shadow", &"", 0],
		IDOL: [&"area", &"shadow", &"", FeedbackRecipeCatalog.COMMIT],
		SHARED: [&"impact", &"shadow", &"", FeedbackRecipeCatalog.COMMIT],
		PUPIL: [&"buff", &"shadow", &"", 0],
		GEOMETRY: [&"area", &"shadow", &"", FeedbackRecipeCatalog.COMMIT],
		REVELATION: [&"area", &"shadow", &"", FeedbackRecipeCatalog.COMMIT],
	}

func skill_texts() -> Dictionary:
	var texts := {
		GAZE: {"flavor": "Ele olha, e o abismo olha junto.", "effect": "Canaliza um olhar em cone à frente: causa dano mágico de sombra contínuo e acumula Loucura em todos os inimigos no cone.", "combo": "Abra com o Ídolo e mantenha o olhar sobre o grupo; mover ou usar outra skill interrompe.", "mechanics": "Canalização de 2s, 5 tiques; cone de raio 200 e 80°."},
		ECSTASY: {"flavor": "Cada mente que se parte é uma boa notícia.", "effect": "Cada inimigo que entra em Delírio ou Desorientação dá uma carga de Êxtase (até 5): mais ATQ mágico e skills mais baratas. Com 3 cargas ou mais, o Cultista também recebe mais dano.", "combo": "Escudo Votivo e Prece compensam o dano extra do Êxtase alto.", "mechanics": "Passiva automática; cai uma carga a cada 3s depois de 6s sem ganho; +8% de dano recebido por carga acima de 2."},
		IDOL: {"flavor": "Uma coisa que não deveria ter forma pede para ser vista.", "effect": "Coloca um Ídolo com HP próprio. Inimigos comuns e elites próximos o atacam, e todos os inimigos que o olham, inclusive o chefe, ganham Loucura.", "combo": "Ídolo no meio do grupo, depois Olhar do Abismo para chegar ao Delírio.", "mechanics": "Um Ídolo por vez; raio 180; o chefe nunca troca de alvo."},
		SHARED: {"flavor": "O que um vê, os outros passam a ver.", "effect": "Fere e marca um alvo: parte da Loucura que ele recebe vai também para os inimigos próximos. Se ele entrar em Delírio, contagia os vizinhos de uma vez.", "combo": "Marque o maior grupo e acumule Loucura no marcado com o Olhar.", "mechanics": "Marca de 8s, raio 140; a cópia não se copia de novo (um salto)."},
		PUPIL: {"flavor": "Os olhos dele não fecham mais.", "effect": "Inimigos em Delírio ou Desorientação recebem mais dano do Cultista, inclusive os golpes que os delirantes trocam entre si.", "combo": "Provoque a janela de Desorientação no chefe e concentre o dano nela.", "mechanics": "Passiva automática; vale só para o Cultista que causou o estado."},
		GEOMETRY: {"flavor": "Uma figura no chão que nunca fecha.", "effect": "Desenha uma figura no chão: os inimigos comuns que entram nela andam na direção errada por um instante; o chefe só fica lento.", "combo": "Segure quem sobrou do Delírio antes da Revelação.", "mechanics": "Figura de raio 110 por 4s; cada inimigo se perde uma vez por figura e ganha 10 de Loucura."},
		REVELATION: {"flavor": "Um grande olho se abre sobre o campo.", "effect": "Por alguns segundos, todos os inimigos à vista ganham Loucura rápido, e os delirantes causam mais dano uns aos outros. O chefe entra numa Desorientação forte, mesmo imune, e acerta com mais frequência os lacaios ao lado.", "combo": "Use no pico do Êxtase, sabendo que ele também o expõe.", "mechanics": "Raio 360; Loucura a cada 0,5s; a Desorientação forte vale uma vez por Revelação e deixa 20s de imunidade."},
	}
	for skill: StringName in SKILLS:
		var ranks: Array[String] = []
		for rank: int in range(1, (3 if skill in PASSIVES else 5) + 1): ranks.append(rank_tooltip(skill, rank))
		texts[skill]["ranks"] = ranks
		texts[skill]["mechanics"] = String(texts[skill]["mechanics"]) + " " + " · ".join(ranks)
	return texts

## Per-rank tooltip line (pt-BR) of one skill. Pure.
func rank_tooltip(skill_id: StringName, rank: int) -> String:
	var i := rank - 1
	var limit := 3 if skill_id in PASSIVES else 5
	if i < 0 or i >= limit: return ""
	match skill_id:
		GAZE:
			return "R%d: %s SP, %d%% do ATQ mágico e %s de Loucura por tique" % [rank, _num(GAZE_SP[i]), roundi(GAZE_POWER[i] * 100.0), _num(GAZE_MADNESS[i])]
		ECSTASY:
			return "R%d: ATQ mágico +%d%% e SP −%d%% por carga" % [rank, roundi(ECSTASY_PER_CHARGE[i] * 100.0), roundi(ECSTASY_PER_CHARGE[i] * 100.0)]
		IDOL:
			return "R%d: %s SP, %ss, HP %d%% do seu máximo, %s de Loucura por segundo" % [rank, _num(IDOL_SP[i]), _num(IDOL_DURATION[i]), roundi(IDOL_HP[i] * 100.0), _num(IDOL_MADNESS[i])]
		SHARED:
			return "R%d: %s SP, %d%% do ATQ mágico, %s de Loucura, copia %d%%, pulso %s" % [rank, _num(SHARED_SP[i]), roundi(SHARED_POWER[i] * 100.0), _num(SHARED_MADNESS[i]), roundi(SHARED_FRACTION[i] * 100.0), _num(SHARED_PULSE[i])]
		PUPIL:
			return "R%d: +%d%% de dano em inimigos em Delírio ou Desorientação" % [rank, roundi((PUPIL_MULTIPLIER[i] - 1.0) * 100.0)]
		GEOMETRY:
			return "R%d: %s SP, perde a direção por %ss, chefe %d%% mais lento" % [rank, _num(GEOMETRY_SP[i]), _num(GEOMETRY_DISORIENT[i]), roundi(GEOMETRY_SLOW[i] * 100.0)]
		REVELATION:
			return "R%d: %s SP, recarga %ss, %ss, %s de Loucura por pulso, delirantes +%d%%, chefe %ss" % [rank, _num(REVELATION_SP[i]), _num(REVELATION_COOLDOWN[i]), _num(REVELATION_DURATION[i]), _num(REVELATION_MADNESS[i]), roundi((REVELATION_DELIRIUM[i] - 1.0) * 100.0), _num(REVELATION_BOSS_DURATION[i])]
	return ""

## Effect IDs reserved for authored flipbooks (C3.4). The Idol body is the T4 drawer.
func vfx_effects() -> Dictionary:
	return {
		&"cultist_abyss_gaze_cone": {"skill_id": GAZE, "kinds": [&"effect_start"], "size": 200.0},
		&"cultist_abyss_gaze_hit": {"skill_id": GAZE, "kinds": [&"impact"], "size": 48.0},
		&"cultist_impossible_idol": {"skill_id": IDOL, "kinds": [&"effect_start"], "size": 96.0},
		&"cultist_shared_delirium_mark": {"skill_id": SHARED, "kinds": [&"effect_start"], "size": 64.0},
		&"cultist_shared_delirium_spread": {"skill_id": SHARED, "kinds": [&"impact"], "size": 140.0},
		&"cultist_impossible_geometry": {"skill_id": GEOMETRY, "kinds": [&"effect_start"], "size": 220.0},
		&"cultist_impossible_geometry_slip": {"skill_id": GEOMETRY, "kinds": [&"impact"], "size": 48.0},
		&"cultist_revelation_eye": {"skill_id": REVELATION, "kinds": [&"effect_start"], "size": 360.0},
		&"cultist_revelation_gaze": {"skill_id": REVELATION, "kinds": [&"impact"], "size": 56.0},
	}

const ABYSS := Color(0.08, 0.07, 0.14)
const MAGENTA := Color(0.86, 0.22, 0.62)
const TURQUOISE := Color(0.32, 0.86, 0.78)
const SCLERA := Color(0.95, 0.90, 0.82)

func draw_vfx(effect_id: StringName, canvas: CanvasItem, pulse: Dictionary, position: Vector2, t: float) -> bool:
	var fade := clampf(1.0 - t, 0.0, 1.0)
	var dir: Vector2 = pulse.get("dir", Vector2.RIGHT) if pulse.get("dir") is Vector2 else Vector2.RIGHT
	if dir.is_zero_approx(): dir = Vector2.RIGHT
	match effect_id:
		&"cultist_abyss_gaze_cone":
			var angle := dir.angle()
			var reach := GAZE_RANGE * minf(1.0, t * 3.0)
			var fan := PackedVector2Array([position])
			for k: int in 13: fan.append(position + Vector2.from_angle(angle - GAZE_HALF_ANGLE + GAZE_HALF_ANGLE * 2.0 * k / 12.0) * reach)
			canvas.draw_colored_polygon(fan, Color(ABYSS, 0.45 * fade))
			for k: int in 3: canvas.draw_arc(position, reach * (0.4 + 0.3 * k), angle - GAZE_HALF_ANGLE, angle + GAZE_HALF_ANGLE, 16, Color(MAGENTA if k % 2 == 0 else TURQUOISE, 0.8 * fade), 2.0)
			_eye(canvas, position + dir * 18.0, 9.0, 0.6 + 0.4 * sin(t * PI), fade)
		&"cultist_abyss_gaze_hit":
			_eye(canvas, position + Vector2(0.0, -30.0), 7.0, minf(1.0, t * 2.0), fade)
		&"cultist_impossible_idol":
			for k: int in 4: canvas.draw_arc(position, 18.0 + 22.0 * k * t, TAU * k / 4.0, TAU * k / 4.0 + PI * 1.4, 12, Color(TURQUOISE if k % 2 == 0 else MAGENTA, 0.7 * fade), 2.0)
		&"cultist_shared_delirium_mark":
			_spiral(canvas, position + Vector2(0.0, -24.0), 26.0, t, fade)
			_eye(canvas, position + Vector2(0.0, -24.0), 6.0, 1.0 - 0.5 * t, fade)
		&"cultist_shared_delirium_spread":
			for k: int in 6: canvas.draw_line(position, position + Vector2.from_angle(TAU * k / 6.0 + t) * SHARED_RADIUS * t, Color(MAGENTA, 0.7 * fade), 2.0)
			canvas.draw_arc(position, SHARED_RADIUS * t, 0.0, TAU * 0.85, 32, Color(TURQUOISE, 0.6 * fade), 2.0)
		&"cultist_impossible_geometry":
			# The commit burst only: the figure itself is the persistent node (draw_persistent).
			var burst := PackedVector2Array()
			for k: int in 25: burst.append(position + Vector2(cos(TAU * k / 24.0), sin(TAU * k / 24.0) * 0.5) * GEOMETRY_RADIUS * minf(1.0, t * 3.0))
			canvas.draw_polyline(burst, Color(MAGENTA, 0.9 * fade), 3.0)
			canvas.draw_polyline(burst, Color(TURQUOISE, 0.5 * fade), 1.5)
		&"cultist_impossible_geometry_slip":
			_spiral(canvas, position + Vector2(0.0, -10.0), 16.0, t, fade)
		&"cultist_revelation_eye":
			# The commit burst only: the open eye and its sight ring are the persistent node.
			var open := minf(1.0, t * 2.0)
			_eye(canvas, position + Vector2(0.0, -90.0), 46.0 * (1.0 + 0.4 * t), open, fade)
			for k: int in 10: canvas.draw_line(position + Vector2(0.0, -90.0), position + Vector2(0.0, -90.0) + Vector2.from_angle(TAU * k / 10.0) * 120.0 * open, Color(MAGENTA, 0.3 * fade), 1.5)
		&"cultist_revelation_gaze":
			_eye(canvas, position + Vector2(0.0, -34.0), 8.0, 1.0, fade)
			canvas.draw_line(position + Vector2(0.0, -34.0), position + Vector2(0.0, -80.0), Color(TURQUOISE, 0.5 * fade), 1.5)
		_:
			return false
	return true

static func _eye(canvas: CanvasItem, center: Vector2, size: float, open: float, fade: float) -> void:
	var lid := PackedVector2Array()
	for i: int in 13: lid.append(center + Vector2(cos(PI * i / 12.0) * size, -sin(PI * i / 12.0) * size * open * 0.8))
	for i: int in range(11, 0, -1): lid.append(center + Vector2(cos(PI * i / 12.0) * size, sin(PI * i / 12.0) * size * open * 0.8))
	if open > 0.05: canvas.draw_colored_polygon(lid, Color(SCLERA, 0.85 * fade))
	canvas.draw_circle(center, size * 0.35 * maxf(0.2, open), Color(TURQUOISE, fade))
	canvas.draw_circle(center, size * 0.15, Color(ABYSS, fade))

static func _spiral(canvas: CanvasItem, center: Vector2, size: float, t: float, fade: float) -> void:
	var points := PackedVector2Array()
	for i: int in 21:
		var k := float(i) / 20.0
		points.append(center + Vector2.from_angle(k * TAU * 1.6 + t * 2.0) * size * k)
	canvas.draw_polyline(points, Color(MAGENTA, 0.85 * fade), 2.0)

## Pure read for the persistent figure node: {"active", "serial", "remaining", "duration", "center", "rank"}.
func figure_state(kind: StringName) -> Dictionary:
	match kind:
		FIGURE_GEOMETRY:
			return {"active": geometry_remaining > 0.0, "serial": geometry_serial, "remaining": geometry_remaining, "duration": GEOMETRY_DURATION, "center": geometry_center, "rank": geometry_rank}
		FIGURE_REVELATION:
			var duration: float = REVELATION_DURATION[clampi(revelation_rank, 1, 5) - 1]
			return {"active": revelation_remaining > 0.0, "serial": revelation_serial, "remaining": revelation_remaining, "duration": duration, "center": Vector3.ZERO, "rank": revelation_rank}
	return {"active": false, "serial": 0, "remaining": 0.0, "duration": 0.0, "center": Vector3.ZERO, "rank": 1}

## One frame of a persistent figure, drawn around the node origin. Presentation only. The
## figure fades in for 0.3 s and out for the last 0.6 s; between them it is steady, turning.
func draw_persistent(kind: StringName, canvas: CanvasItem, state: Dictionary, world: bool = false) -> bool:
	var duration := maxf(0.001, float(state.get("duration", 1.0)))
	var remaining := clampf(float(state.get("remaining", 0.0)), 0.0, duration)
	var age := duration - remaining
	var fade := minf(clampf(age / 0.3, 0.0, 1.0), clampf(remaining / 0.6, 0.0, 1.0))
	var ground := GROUND_WORLD if world else GROUND_FLAT
	match kind:
		FIGURE_GEOMETRY:
			# A figure that never closes: an open polygon that turns, with one side missing.
			var points := PackedVector2Array()
			for k: int in 7:
				var a := TAU * k / 7.0 + age * 0.8
				points.append(Vector2(cos(a) * ground.x, sin(a) * ground.y) * GEOMETRY_RADIUS * (0.9 + 0.1 * sin(age * PI + k)))
			var edge := PackedVector2Array()
			for k: int in 49: edge.append(Vector2(cos(TAU * k / 48.0) * ground.x, sin(TAU * k / 48.0) * ground.y) * GEOMETRY_RADIUS)
			canvas.draw_polyline(edge, Color(ABYSS, 0.55 * fade), 2.0)
			canvas.draw_polyline(points, Color(MAGENTA, 0.9 * fade), 3.0)
			canvas.draw_polyline(PackedVector2Array([points[1], points[4], points[0], points[3], points[6]]), Color(TURQUOISE, 0.55 * fade), 1.5)
			for k: int in 4:
				var rune := Vector2.from_angle(-age * 0.5 + TAU * k / 4.0)
				canvas.draw_circle(Vector2(rune.x * ground.x, rune.y * ground.y) * GEOMETRY_RADIUS * 0.45, 2.5, Color(TURQUOISE, 0.8 * fade))
		FIGURE_REVELATION:
			var ring := PackedVector2Array()
			for k: int in 65: ring.append(Vector2(cos(TAU * k / 64.0) * ground.x, sin(TAU * k / 64.0) * ground.y) * REVELATION_RADIUS)
			canvas.draw_polyline(ring, Color(MAGENTA, 0.28 * fade), 2.0)
			var open := clampf(0.8 + 0.2 * sin(age * 2.4), 0.0, 1.0) * (0.15 if fmod(age, 2.2) > 2.05 else 1.0) # a slow blink
			var eye := Vector2(0.0, -90.0)
			canvas.draw_circle(Vector2.ZERO, 26.0, Color(ABYSS, 0.35 * fade))
			_eye(canvas, eye, 46.0, open, fade)
			for k: int in 10: canvas.draw_line(eye + Vector2.from_angle(TAU * k / 10.0 + age * 0.3) * 56.0, eye + Vector2.from_angle(TAU * k / 10.0 + age * 0.3) * 120.0, Color(MAGENTA, 0.3 * fade), 1.5)
		_:
			return false
	return true

## Creates, replaces or releases the persistent node of a figure to match the kit state.
## The node lives under the player's parent (the arena or the expedition view), outside every
## snapshot scan; nothing here is state of the run.
func _sync_figure(player: PlayerActor, kind: StringName) -> void:
	if not is_instance_valid(player): return
	var host := player.get_parent()
	if host == null: return
	var node_name := "CultistFigure_%s_%d" % [kind, player.get_instance_id()]
	var existing := host.get_node_or_null(NodePath(node_name))
	var state := figure_state(kind)
	if existing != null:
		if bool(state["active"]) and int(existing.get(&"serial")) == int(state["serial"]) and existing.get(&"kit") == self: return
		existing.call(&"release")
	if not bool(state["active"]) or not host.is_inside_tree(): return
	var node: Node2D = (load(FIGURE_SCRIPT) as Script).new()
	node.name = node_name
	node.call(&"setup", self, player, kind, int(state["serial"]))
	host.add_child(node)

func _sync_figures(player: PlayerActor) -> void:
	_sync_figure(player, FIGURE_GEOMETRY)
	_sync_figure(player, FIGURE_REVELATION)

# --- Hooks -------------------------------------------------------------------------------

func on_attach(player: PlayerActor) -> void:
	_sync_ecstasy(player)

func on_build_changed(player: PlayerActor) -> void:
	_sync_ecstasy(player)

func on_tick(player: PlayerActor, delta: float) -> void:
	var madness := _madness(player)
	if madness != null: madness.tick(player, delta)
	if gaze_remaining > 0.0: _advance_gaze(player, delta)
	if geometry_remaining > 0.0: _advance_geometry(player, delta)
	if revelation_remaining > 0.0: _advance_revelation(player, delta)
	_refresh_sources(player)
	_sync_figures(player)

func on_cast_confirmed(player: PlayerActor, cast: Dictionary) -> void:
	# Any other skill of the Cultista interrupts the channel.
	if StringName(cast.get("skill_id", &"")) != GAZE: _end_gaze()
	_refresh_sources(player)

func on_base_skill_committed(_player: PlayerActor, _skill_id: StringName, _context: Dictionary) -> void:
	_end_gaze()

func resolve_cast(player: PlayerActor, cast: Dictionary) -> bool:
	var skill := StringName(cast["skill_id"])
	var values := _rank_values(player, skill, int(cast["rank"]))
	if values == null: return false
	match skill:
		GAZE: return _resolve_gaze(player, cast, values)
		IDOL: return _resolve_idol(player, cast, values)
		SHARED: return _resolve_shared(player, cast, values)
		GEOMETRY: return _resolve_geometry(player, cast, values)
		REVELATION: return _resolve_revelation(player, cast, values)
	return false

## Ecstasy (T4 §1.1): only this module forwards the three hooks.
func temporary_stat_sources(player: PlayerActor) -> Array[Dictionary]:
	var madness := _madness(player)
	return madness.temporary_stat_sources(player) if madness != null else ([] as Array[Dictionary])

func skill_cost(player: PlayerActor, _skill_id: StringName, base_cost: float) -> float:
	var madness := _madness(player)
	return madness.skill_cost(base_cost) if madness != null else base_cost

func before_hit_mitigation(player: PlayerActor, hit: Dictionary) -> Dictionary:
	var madness := _madness(player)
	return madness.before_hit(player, hit) if madness != null else {}

func on_death(player: PlayerActor) -> void:
	_end_gaze()
	_end_geometry()
	revelation_remaining = 0.0
	revelation_next_tick = 0.0
	_sync_figures(player)

func snapshot_compact_blocker(_player: PlayerActor) -> String:
	if gaze_remaining > 0.0: return "cultist_channel"
	if geometry_remaining > 0.0: return "cultist_geometry"
	if revelation_remaining > 0.0: return "cultist_revelation"
	return ""

# --- Queries (pure) ------------------------------------------------------------------------

func channeling() -> bool:
	return gaze_remaining > 0.0

func geometry_active() -> bool:
	return geometry_remaining > 0.0

func revelation_active() -> bool:
	return revelation_remaining > 0.0

## Live enemies of `player` inside the Olhar cone (range plus the enemy radius), by stable key.
## E10a T15 (A20): in the world, only on the Cultista's floor (ClassKit.on_anchor_floor).
func gaze_targets(player: PlayerActor, actors: Array = []) -> Array[CombatActor]:
	var result: Array[CombatActor] = []
	var origin := FlankRules.ground_position(player)
	var facing := player.gameplay_ground_facing()
	var heading := Vector2(facing.x, facing.z)
	if not origin.is_finite() or heading.is_zero_approx(): return result
	heading = heading.normalized()
	var anchor := ClassKit.world_anchor(player)
	var area := ClassKit.floor_area(player, anchor)
	for enemy: CombatActor in _live_enemies(player, actors):
		var offset3 := FlankRules.ground_position(enemy) - origin
		var offset := Vector2(offset3.x, offset3.z)
		if offset.length() > GAZE_RANGE + enemy.collision_radius: continue
		if offset.length() > 0.001 and absf(heading.angle_to(offset.normalized())) > GAZE_HALF_ANGLE + 0.0001: continue
		if not ClassKit.on_anchor_floor(area, anchor, enemy, GAZE_RANGE): continue
		result.append(enemy)
	return result

# --- HUD (E10a T12, C9) -----------------------------------------------------------------------

## Pure read for the HUD (ragrpg_kit_hud_v1): the Êxtase charges (0..5) while the passive is
## learned, and the Ídolo Impossível as a timer and a ground zone. Madness itself is published
## by the base (A18). Values come from the MadnessAuthority; no formula.
func hud_state(player: PlayerActor) -> Dictionary:
	var madness := _madness(player)
	if madness == null or not is_instance_valid(player): return {}
	var resources: Array[Dictionary] = []
	if madness.ecstasy.enabled:
		resources.append({"id": ECSTASY, "label": "Êxtase", "kind": &"pips", "value": clampi(madness.ecstasy.charges, 0, MadnessRules.ECSTASY_CAP), "max": MadnessRules.ECSTASY_CAP, "element": &"shadow"})
	var zones: Array[Dictionary] = []
	var idol := madness.idol(player)
	if idol != null and idol.is_alive():
		var remaining := float(idol.get(&"remaining"))
		var total := maxf(IDOL_DURATION[clampi(player.skill_rank(IDOL), 1, 5) - 1], remaining)
		if remaining > 0.0:
			resources.append({"id": IDOL, "label": "Ídolo Impossível", "kind": &"timer", "remaining": remaining, "total": total, "element": &"shadow"})
			var center := Vector3.ZERO
			var world := player.world_motion != null
			var found := true
			if world:
				var point: ExpeditionWorldPoint = idol.world_point()
				if point == null: found = false
				else: center = point.position
			else:
				center = Vector3(idol.global_position.x, idol.global_position.y, 0.0)
			if found and center.is_finite() and madness.idol_radius > 0.0:
				zones.append({"role": &"idol", "space": &"world" if world else &"flat", "center": center, "shape": SanctuaryRules.SHAPE_CIRCLE, "radius": madness.idol_radius, "element": &"shadow", "remaining": minf(remaining, total), "total": total})
	if resources.is_empty() and zones.is_empty(): return {}
	return {"schema": KitHudState.SCHEMA, "kit_id": kit_id(), "resources": resources, "zones": zones}

# --- Internals ------------------------------------------------------------------------------

## The origin's Madness authority, read on every use (never stored: one copy in the snapshot).
func _madness(player: PlayerActor) -> MadnessAuthority:
	return MadnessAuthority.of(player) as MadnessAuthority

func _sync_ecstasy(player: PlayerActor) -> void:
	var madness := _madness(player)
	if madness == null: return
	var rank := player.skill_rank(ECSTASY) if is_instance_valid(player) else 0
	if rank > 0:
		var per_charge := ECSTASY_PER_CHARGE[clampi(rank, 1, 3) - 1]
		madness.configure(player, {"stat_source_id": STAT_SOURCE, "ecstasy": {"matk_per_charge": per_charge, "cost_per_charge": per_charge, "onus_per_charge": MadnessRules.ECSTASY_ONUS_PER_CHARGE}})
	madness.set_ecstasy_enabled(player, rank > 0)

func _live_enemies(player: PlayerActor, actors: Array = []) -> Array[CombatActor]:
	var result: Array[CombatActor] = []
	for candidate: Variant in MadnessHelpers.enemies_of(player, actors):
		var enemy := candidate as CombatActor
		if MadnessHelpers.is_enemy(enemy) and MadnessHelpers.is_live(enemy) and enemy not in result: result.append(enemy)
	result.sort_custom(func(a: CombatActor, b: CombatActor) -> bool: return MadnessHelpers.enemy_key(a) < MadnessHelpers.enemy_key(b))
	return result

func _ground_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _cast_ground_point(cast: Dictionary) -> Vector3:
	if bool(cast.get("world", false)) and cast.get("anchor") is ExpeditionWorldPoint: return (cast["anchor"] as ExpeditionWorldPoint).position
	var point: Vector2 = cast.get("point", Vector2.ZERO)
	return Vector3(point.x, 0.0, point.y)

func _magic(player: PlayerActor, ratio: float) -> float:
	return player.stat_breakdown.value(&"magic_attack") * ratio

## Pupila Aberta and the Revelação delirium bonus: short C1.7 sources on the enemies,
## filtered by this owner, renewed while the condition holds and removed when it ends.
func _refresh_sources(player: PlayerActor) -> void:
	if not is_instance_valid(player) or not player.is_alive(): return
	var owner_id := player.get_instance_id()
	var pupil := player.skill_rank(PUPIL)
	var pupil_multiplier := PUPIL_MULTIPLIER[clampi(pupil, 1, 3) - 1] if pupil > 0 else 1.0
	var revelation_multiplier := REVELATION_DELIRIUM[clampi(revelation_rank, 1, 5) - 1] if revelation_remaining > 0.0 else 1.0
	for enemy: CombatActor in _live_enemies(player):
		var maddened := MadnessAuthority.is_maddened(enemy, owner_id)
		if maddened and pupil_multiplier > 1.0: enemy.add_received_damage_source(PUPIL_SOURCE, pupil_multiplier, SOURCE_REFRESH, owner_id)
		elif enemy.received_damage_sources.has(PUPIL_SOURCE): enemy.remove_received_damage_source(PUPIL_SOURCE)
		var delirious := enemy.marks.has_mark(MadnessRules.MARK_DELIRIUM) and enemy.marks.owner_of(MadnessRules.MARK_DELIRIUM) == owner_id
		if delirious and revelation_multiplier > 1.0: enemy.add_received_damage_source(REVELATION_SOURCE, revelation_multiplier, SOURCE_REFRESH, owner_id)
		elif enemy.received_damage_sources.has(REVELATION_SOURCE): enemy.remove_received_damage_source(REVELATION_SOURCE)

# Olhar do Abismo ---------------------------------------------------------------------------

func _resolve_gaze(player: PlayerActor, cast: Dictionary, values: SkillRankDefinition) -> bool:
	_end_gaze()
	gaze_serial += 1
	gaze_rank = clampi(values.rank, 1, 5)
	gaze_origin = FlankRules.ground_position(player)
	gaze_power = values.power
	gaze_prototype = null
	gaze_remaining = GAZE_DURATION
	gaze_ticks = 0
	gaze_next_tick = GAZE_INTERVAL
	_gaze_tick(player, cast.get("actors", []))
	return true

func _advance_gaze(player: PlayerActor, delta: float) -> void:
	if _ground_distance(FlankRules.ground_position(player), gaze_origin) > GAZE_MOVE_TOLERANCE:
		_end_gaze()
		return
	gaze_remaining = maxf(0.0, gaze_remaining - delta)
	gaze_next_tick -= delta
	while gaze_ticks < GAZE_TICKS and gaze_next_tick <= 0.0001:
		gaze_next_tick += GAZE_INTERVAL
		_gaze_tick(player)
	if gaze_ticks >= GAZE_TICKS or gaze_remaining <= 0.0: _end_gaze()

## One channel tick. The first tick that finds a target builds the prototype (amount from
## the MATK at that moment, the causal root of the cast); later ticks are scheduled ticks
## of it, as secondary hits.
func _gaze_tick(player: PlayerActor, actors: Array = []) -> void:
	gaze_ticks += 1
	var targets := gaze_targets(player, actors)
	if targets.is_empty(): return
	var tick: DamageRequest
	if gaze_prototype == null:
		gaze_prototype = player.kit_make_request(targets[0], GAZE, 0.0, _magic(player, gaze_power), DamageRequest.AccuracyMode.GEOMETRY, true)
		tick = gaze_prototype
	else:
		tick = gaze_prototype.scheduled_tick()
		if tick.cancelled: return
		tick.is_secondary = true
	var madness := _madness(player)
	var key := "gaze:%d:%d" % [gaze_serial, gaze_ticks]
	for enemy: CombatActor in targets:
		var hit := tick.copy()
		hit.target_id = enemy.get_instance_id()
		if tick.context != null: hit.context = tick.context.copy_context()
		player.kit_emit_hit(hit, enemy)
		if madness != null and MadnessHelpers.is_live(enemy): madness.add(enemy, GAZE_MADNESS[gaze_rank - 1], key, player)

func _end_gaze() -> void:
	gaze_remaining = 0.0
	gaze_next_tick = 0.0
	gaze_ticks = 0
	gaze_prototype = null

# Ídolo Impossível --------------------------------------------------------------------------

func _resolve_idol(player: PlayerActor, cast: Dictionary, values: SkillRankDefinition) -> bool:
	var madness := _madness(player)
	if madness == null: return false
	var point: Variant = cast["anchor"] if bool(cast.get("world", false)) and cast.get("anchor") is ExpeditionWorldPoint else cast.get("point", player.global_position)
	var i := clampi(values.rank, 1, 5) - 1
	return bool(madness.place_idol(player, point, {"duration": IDOL_DURATION[i], "hp_fraction": IDOL_HP[i], "madness": IDOL_MADNESS[i]})["ok"])

# Delírio Compartilhado ---------------------------------------------------------------------

func _resolve_shared(player: PlayerActor, cast: Dictionary, values: SkillRankDefinition) -> bool:
	var victim := cast.get("target") as CombatActor
	if not MadnessHelpers.is_live(victim): return false
	var i := clampi(values.rank, 1, 5) - 1
	var madness := _madness(player)
	if madness != null and MadnessHelpers.is_enemy(victim):
		madness.mark_contagion(player, victim, {"duration": SHARED_DURATION, "fraction": SHARED_FRACTION[i], "radius": SHARED_RADIUS, "pulse": SHARED_PULSE[i]})
		madness.add(victim, SHARED_MADNESS[i], MadnessHelpers.cast_event(cast, player.kit_time), player, false, cast.get("actors", []))
	player.kit_emit_hit(player.kit_make_request(victim, SHARED, 0.0, _magic(player, values.power), DamageRequest.AccuracyMode.GEOMETRY, true), victim)
	return true

# Geometria Impossível ----------------------------------------------------------------------

func _resolve_geometry(player: PlayerActor, cast: Dictionary, values: SkillRankDefinition) -> bool:
	_end_geometry()
	geometry_serial += 1
	geometry_rank = clampi(values.rank, 1, 5)
	geometry_center = _cast_ground_point(cast)
	geometry_remaining = GEOMETRY_DURATION
	geometry_next_pulse = GEOMETRY_INTERVAL
	_geometry_pulse(player, cast.get("actors", []))
	_sync_figure(player, FIGURE_GEOMETRY)
	return true

func _advance_geometry(player: PlayerActor, delta: float) -> void:
	geometry_remaining = maxf(0.0, geometry_remaining - delta)
	geometry_next_pulse -= delta
	while geometry_next_pulse <= 0.0001 and geometry_remaining > 0.0:
		geometry_next_pulse += GEOMETRY_INTERVAL
		_geometry_pulse(player)
	if geometry_remaining <= 0.0: _end_geometry()

## One pulse of the figure: a common or elite inside loses its way once per figure (and
## gains Madness then); the boss inside is slowed, never disoriented nor retargeted.
## E10a T15 (A21): in the world, only on the figure's floor; the anchor is rebuilt from the
## centre each pulse (ClassKit.anchor_on_floor), so no state is added to the snapshot.
func _geometry_pulse(player: PlayerActor, actors: Array = []) -> void:
	var i := geometry_rank - 1
	var madness := _madness(player)
	var owner_id := player.get_instance_id()
	var enemies := _live_enemies(player, actors)
	var in_world := ClassKit.world_anchor(player) != null
	var anchor := ClassKit.anchor_on_floor(player, geometry_center, enemies)
	var area := ClassKit.floor_area(player, anchor)
	for enemy: CombatActor in enemies:
		if _ground_distance(FlankRules.ground_position(enemy), geometry_center) > GEOMETRY_RADIUS + enemy.collision_radius: continue
		if in_world and (anchor == null or not ClassKit.on_anchor_floor(area, anchor, enemy, GEOMETRY_RADIUS)): continue
		if MadnessHelpers.is_boss(enemy):
			enemy.apply_slow(GEOMETRY_SLOW[i], GEOMETRY_SLOW_DURATION, GEOMETRY_SOURCE)
			continue
		if enemy.marks.owner_of(GEOMETRY_MARK) == owner_id and int(enemy.marks.value(GEOMETRY_MARK, 0)) == geometry_serial: continue
		enemy.marks.set_mark(GEOMETRY_MARK, owner_id, geometry_serial, GEOMETRY_DURATION)
		enemy.apply_disorient(GEOMETRY_DISORIENT[i])
		if madness != null: madness.add(enemy, GEOMETRY_MADNESS, "geometry:%d" % geometry_serial, player)

func _end_geometry() -> void:
	geometry_remaining = 0.0
	geometry_next_pulse = 0.0

# Revelação ---------------------------------------------------------------------------------

func _resolve_revelation(player: PlayerActor, cast: Dictionary, values: SkillRankDefinition) -> bool:
	revelation_serial += 1
	revelation_rank = clampi(values.rank, 1, 5)
	var i := revelation_rank - 1
	revelation_remaining = REVELATION_DURATION[i]
	revelation_ticks = 0
	revelation_next_tick = REVELATION_INTERVAL
	var madness := _madness(player)
	if madness != null:
		var strong := REVELATION_BOSS.duplicate()
		strong["bypass_immunity"] = true
		strong["duration"] = REVELATION_BOSS_DURATION[i]
		for enemy: CombatActor in _in_sight(player, cast.get("actors", [])):
			if MadnessHelpers.is_boss(enemy): madness.disorient(enemy, "revelation:%d" % revelation_serial, player, strong)
	_revelation_tick(player, cast.get("actors", []))
	_refresh_sources(player)
	_sync_figure(player, FIGURE_REVELATION)
	return true

func _advance_revelation(player: PlayerActor, delta: float) -> void:
	revelation_remaining = maxf(0.0, revelation_remaining - delta)
	revelation_next_tick -= delta
	while revelation_next_tick <= 0.0001 and revelation_remaining > 0.0:
		revelation_next_tick += REVELATION_INTERVAL
		_revelation_tick(player)
	if revelation_remaining <= 0.0: revelation_next_tick = 0.0

func _revelation_tick(player: PlayerActor, actors: Array = []) -> void:
	var madness := _madness(player)
	if madness == null: return
	revelation_ticks += 1
	var key := "revelation:%d:%d" % [revelation_serial, revelation_ticks]
	for enemy: CombatActor in _in_sight(player, actors):
		if MadnessHelpers.is_live(enemy): madness.add(enemy, REVELATION_MADNESS[revelation_rank - 1], key, player)

## E10a T15 (A21): in the world, only on the Cultista's floor (ClassKit.on_anchor_floor).
func _in_sight(player: PlayerActor, actors: Array = []) -> Array[CombatActor]:
	var result: Array[CombatActor] = []
	var origin := FlankRules.ground_position(player)
	var anchor := ClassKit.world_anchor(player)
	var area := ClassKit.floor_area(player, anchor)
	for enemy: CombatActor in _live_enemies(player, actors):
		if _ground_distance(FlankRules.ground_position(enemy), origin) <= REVELATION_RADIUS + enemy.collision_radius and ClassKit.on_anchor_floor(area, anchor, enemy, REVELATION_RADIUS): result.append(enemy)
	return result

func _rank_values(player: PlayerActor, skill: StringName, rank: int) -> SkillRankDefinition:
	var values := player.skill_rank_definition(skill) if is_instance_valid(player) else null
	if values != null: return values
	var definition := ClassKitRegistry.skill_definition(skill)
	return definition.rank_definition(clampi(rank, 1, definition.ranks.size())) if definition != null else null

# --- Data builders (pure) ---------------------------------------------------------------------

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
	definition.element = &"shadow"
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
	definition.element = &"shadow"
	for index: int in 3:
		var values := SkillRankDefinition.new()
		values.rank = index + 1
		values.power = powers[index]
		values.secondary_power = secondary[index]
		values.effect_ids = effects.duplicate()
		definition.ranks.append(values)
	return definition

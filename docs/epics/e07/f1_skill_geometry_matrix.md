# E07-F1 — inventário de geometria dos dez kits

18/10/2026. **Inventário; adaptação multialtura incompleta.**
[API real](f1_api.md), [despacho](f1_dispatch.md), [recibo](delivery/f1.md).
Extraído dos catálogos reais por e07_f1_inventory_test, com 93 IDs e 27 efeitos
não estatísticos de augment/equipment/card. Classificação explícita em
scripts/core/expedition/spatial/world_skill_geometry_rules.gd; ID desconhecido
retorna vazio e não recebe fallback por tipo de mira.

D05 autoriza suporte/conexões para chão, volumes 3D/oclusão e mobilidade descrita
no despacho. As linhas abaixo não mudam fórmulas, duração, alvos, causalidade ou
regras particulares de E06. A coluna de adaptação informa a prova realmente obtida.
Cada consumidor pendente ainda bloqueia o fechamento F1, mesmo tendo regra inventariada.

## Cobertura das identidades

- `swordsman` (swordsman): 13 IDs legais, incluindo a biblioteca da origem.
- `mage` (mage): 13 IDs legais, incluindo a biblioteca da origem.
- `archer` (archer): 11 IDs legais, incluindo a biblioteca da origem.
- `defender` (swordsman): 22 IDs legais, incluindo a biblioteca da origem.
- `berserker` (swordsman): 22 IDs legais, incluindo a biblioteca da origem.
- `elementalist` (mage): 20 IDs legais, incluindo a biblioteca da origem.
- `spiritualist` (mage): 20 IDs legais, incluindo a biblioteca da origem.
- `sentinel` (archer): 20 IDs legais, incluindo a biblioteca da origem.
- `hunter` (archer): 19 IDs legais, incluindo a biblioteca da origem.
- `mg_ar` (mage): 20 IDs legais, incluindo a biblioteca da origem.

## Delta de consumidores desta retomada

`e07_f1_consumer_test` prova básico real nas dez identidades, trajetória contínua
Player/Mage/Sentinel e flecha hostil, chuva/traps/blast ancorados, escudo/barreira,
piche, ocultação/budget/grace, coleta, movimento/dash temporal, AI autônoma/leash,
cast obsoleto e callbacks que removem alvos. Isso não equivale ao cast completo
dessas ativas: entrada/preview/composição nominal ainda precisam ser integrados.
A retomada seguinte acrescenta WorldSkillCast: 39 entradas nominais com preview,
preparo e commit 3D. Dreno/Procissão/Véu, áreas elementais, chuva/traps base,
projéteis e melee consomem a intenção capturada. A prova nominal é delimitada no
recibo; isso ainda não certifica os dez kits nem os 27 efeitos compostos.
SoulImpact, Assombro, Dissipação e gritos de área também receberam prova nominal
de pulso/oclusão/controles, sem alterar o dano canônico.
Geômetra, ecos, paredes/campos restantes, AoEs do Sentinela e demais mobilidades
continuam bloqueios. API e recibo contêm o escopo exato; D05 visual não foi aprovado.

## Habilidades nominais

Regra primária não esgota efeitos compostos; exceções por família seguem à tabela.
self_only não faz consulta hostil; inherit_parent conserva a aceitação da emissão
causal original e não adiciona LoS a DoT já aplicado.

| ID / nome | Regra primária | Adaptação multialtura neste checkpoint |
|---|---|---|
| `archer_cadence` — Cadência | `inherit_parent` | Herança/estatística inventariada; consumidor pendente |
| `archer_precision` — Precisão | `inherit_parent` | Herança/estatística inventariada; consumidor pendente |
| `arrow_rain` — Chuva de Flechas | `ground_connected` | Preview/preparo/commit espaciais ligados; prova nominal delimitada no recibo |
| `berserker_blood_rift` — Fenda Sangrenta | `ground_connected` | Consumidor pendente; entrada legada bloqueada no binding |
| `berserker_breath_steal` — Arrancar Fôlego | `direct_volume` | Preview/preparo/commit espaciais ligados; prova nominal delimitada no recibo |
| `berserker_deep_bleeding` — Hemorragia Profunda | `inherit_parent` | Herança/estatística inventariada; consumidor pendente |
| `berserker_execution` — Execução | `direct_volume` | Preview/preparo/commit espaciais ligados; prova nominal delimitada no recibo |
| `berserker_obstinacy` — Obstinação | `inherit_parent` | Herança/estatística inventariada; consumidor pendente |
| `berserker_pursuit` — Caça Persistente | `inherit_parent` | Herança/estatística inventariada; consumidor pendente |
| `berserker_pursuit_cut` — Talho de Perseguição | `direct_volume` | Preview/preparo/commit espaciais ligados; prova nominal delimitada no recibo |
| `berserker_rupture` — Ruptura | `direct_volume` | Preview/preparo/commit espaciais ligados; prova nominal delimitada no recibo |
| `berserker_wound_leap` — Salto Cruento | `walk_path` | Consumidor pendente; entrada legada bloqueada no binding |
| `blood_thirst` — Sede de Sangue | `inherit_parent` | Herança/estatística inventariada; consumidor pendente |
| `brutal_strike` — Golpe Brutal | `direct_volume` | Preview/preparo/commit espaciais ligados; prova nominal delimitada no recibo |
| `concentrated_rage` — Raiva Concentrada | `direct_volume` | Preview/preparo/commit espaciais ligados; prova nominal delimitada no recibo |
| `dash` — Investida | `walk_path` | PlayerActor lógico testado; apresentação pendente |
| `defender_anchor` — Marco de Guarda | `ground_connected` | Consumidor pendente; entrada legada bloqueada no binding |
| `defender_counterstroke` — Contraforte | `direct_volume` | Preview/preparo/commit espaciais ligados; prova nominal delimitada no recibo |
| `defender_guard_return` — Resguardo | `inherit_parent` | Herança/estatística inventariada; consumidor pendente |
| `defender_line_lock` — Trava de Linha | `direct_volume` | Preview/preparo/commit espaciais ligados; prova nominal delimitada no recibo |
| `defender_reprisal_wave` — Onda de Represália | `ground_connected` | Consumidor pendente; entrada legada bloqueada no binding |
| `defender_retreat_guard` — Guarda de Retirada | `walk_path` | Consumidor pendente; entrada legada bloqueada no binding |
| `defender_riposte` — Rebater | `direct_volume` | Preview/preparo/commit espaciais ligados; prova nominal delimitada no recibo |
| `defender_wall_advance` — Avanço de Muralha | `walk_path` | Consumidor pendente; entrada legada bloqueada no binding |
| `defender_watch` — Vigília | `inherit_parent` | Herança/estatística inventariada; consumidor pendente |
| `double_shot` — Disparo Duplo | `direct_volume` | Preview/preparo/commit espaciais ligados; prova nominal delimitada no recibo |
| `electric_discharge` — Descarga Elétrica | `direct_volume` | Preview/preparo/commit espaciais ligados; prova nominal delimitada no recibo |
| `elementalist_ember_path` — Trilha de Brasas | `ground_connected` | Consumidor espacial/schedule ligado; cast/preview/composição ainda pendentes |
| `elementalist_flame_burst` — Explosão de Chamas | `ground_connected` | Preview/preparo/commit espaciais ligados; prova nominal delimitada no recibo |
| `elementalist_glacial_ring` — Anel Glacial | `ground_connected` | Preview/preparo/commit espaciais ligados; prova nominal delimitada no recibo |
| `elementalist_lightning_arc` — Arco Voltaico | `direct_volume` | Consumidor pendente; entrada legada bloqueada no binding |
| `elementalist_prismatic_focus` — Foco Prismático | `inherit_parent` | Herança/estatística inventariada; consumidor pendente |
| `elementalist_prismatic_resonance` — Ressonância Prismática | `inherit_parent` | Herança/estatística inventariada; consumidor pendente |
| `elementalist_tri_nova` — Nova Tríplice | `ground_connected` | Preview/preparo/commit espaciais ligados; prova nominal delimitada no recibo |
| `explosive_trap` — Armadilha Explosiva | `ground_connected` | Preview/preparo/commit espaciais ligados; prova nominal delimitada no recibo; composição Caçadora explicitamente bloqueada |
| `extended_aim` — Mira Estendida | `self_only` | Preview/preparo/commit espaciais ligados; prova nominal delimitada no recibo |
| `fire_spear` — Lança de Fogo | `direct_volume` | Preview/preparo/commit espaciais ligados; prova nominal delimitada no recibo |
| `fire_wall` — Parede de Fogo | `ground_connected` | Consumidor pendente; entrada legada bloqueada no binding |
| `fireball` — Bola de Fogo | `direct_volume` | Preview/preparo/commit espaciais ligados; prova nominal delimitada no recibo |
| `foliage_shelter` — Abrigo de Folhagem | `ground_connected` | Consumidor espacial opt-in ligado; cast/placement/preview ainda bloqueados |
| `fury` — Fúria | `self_only` | Preview/preparo/commit espaciais ligados; prova nominal delimitada no recibo |
| `geometer_collapse` — Colapso Geométrico | `ground_connected` | Consumidor pendente; entrada legada bloqueada no binding |
| `geometer_incidence` — Teorema de Incidência | `inherit_parent` | Herança/estatística inventariada; consumidor pendente |
| `geometer_rewrite` — Reescrita | `ground_connected` | Consumidor pendente; entrada legada bloqueada no binding |
| `geometer_trace` — Traçado Elemental | `ground_connected` | Consumidor pendente; entrada legada bloqueada no binding |
| `geometer_translation` — Translação | `ground_connected` | Consumidor pendente; entrada legada bloqueada no binding |
| `geometer_triangulation` — Triangulação | `ground_connected` | Consumidor pendente; entrada legada bloqueada no binding |
| `geometer_vector_memory` — Memória Vetorial | `inherit_parent` | Herança/estatística inventariada; consumidor pendente |
| `haunt` — Assombro | `direct_volume` | Preview/preparo/commit e consumidor espacial ligados; teste nominal area_cast PASS59 |
| `hunter_covering_shot` — Tiro de Cobertura | `direct_volume` | Consumidor pendente; entrada legada bloqueada no binding |
| `hunter_easy_prey` — Presa Fácil | `inherit_parent` | Herança/estatística inventariada; consumidor pendente |
| `hunter_freezing_trap` — Armadilha Congelante | `ground_connected` | Consumidor espacial opt-in ligado; cast/placement/preview ainda bloqueados |
| `hunter_mark` — Marca do Caçador | `direct_volume` | Preview/preparo/commit espaciais ligados; prova nominal delimitada no recibo |
| `hunter_shooting_discipline` — Disciplina de Tiro | `inherit_parent` | Herança/estatística inventariada; consumidor pendente |
| `hunter_tar_trap` — Armadilha de Piche | `ground_connected` | Consumidor espacial opt-in ligado; cast/placement/preview ainda bloqueados |
| `hunter_thorn_trap` — Armadilha de Espinhos | `ground_connected` | Consumidor espacial opt-in ligado; cast/placement/preview ainda bloqueados |
| `hunter_total_cover` — Cobertura Total | `ground_connected` | Consumidor espacial opt-in ligado; cast/placement/preview ainda bloqueados |
| `ice_spear` — Lança de Gelo | `direct_volume` | Preview/preparo/commit espaciais ligados; prova nominal delimitada no recibo |
| `ice_wall` — Parede de Gelo | `ground_connected` | Consumidor pendente; entrada legada bloqueada no binding |
| `lightning` — Relâmpago | `direct_volume` | Preview/preparo/commit espaciais ligados; prova nominal delimitada no recibo |
| `lightning_wall` — Parede de Raios | `ground_connected` | Consumidor pendente; entrada legada bloqueada no binding |
| `mage_mana_regeneration` — Regeneração de SP | `inherit_parent` | Herança/estatística inventariada; consumidor pendente |
| `perseverance` — Perseverança | `self_only` | Preview/preparo/commit espaciais ligados; prova nominal delimitada no recibo |
| `phantom_barrier` — Barreira Fantasma | `ground_connected` | Consumidor espacial opt-in ligado; cast/placement/preview ainda bloqueados |
| `piercing_arrow` — Flecha Perfurante | `direct_volume` | Preview/preparo/commit espaciais ligados; prova nominal delimitada no recibo |
| `piercing_shout` — Grito Perfurante | `ground_connected` | Preview/preparo/commit e consumidor espacial ligados; teste nominal area_cast PASS59 |
| `provoke` — Provocar | `direct_volume` | Preview/preparo/commit espaciais ligados; prova nominal delimitada no recibo |
| `sentinel_absolute_focus` — Foco Absoluto | `self_only` | Preview/preparo/commit espaciais ligados; prova nominal delimitada no recibo |
| `sentinel_concussion_shot` — Tiro de Concussão | `direct_volume` | Consumidor pendente; entrada legada bloqueada no binding |
| `sentinel_explosive_shot` — Tiro Explosivo | `direct_volume` | Consumidor pendente; entrada legada bloqueada no binding |
| `sentinel_headshot` — Tiro na Cabeça | `direct_volume` | Consumidor pendente; entrada legada bloqueada no binding |
| `sentinel_net_shot` — Tiro de Rede | `ground_connected` | Consumidor pendente; entrada legada bloqueada no binding |
| `sentinel_observe` — Observar | `direct_volume` | Preview/preparo/commit espaciais ligados; prova nominal delimitada no recibo |
| `sentinel_opening_read` — Leitura de Aberturas | `inherit_parent` | Herança/estatística inventariada; consumidor pendente |
| `sentinel_piercing_shot` — Tiro Perfurante | `direct_volume` | Consumidor pendente; entrada legada bloqueada no binding |
| `sentinel_precision_stance` — Postura de Precisão | `inherit_parent` | Herança/estatística inventariada; consumidor pendente |
| `shield_wall` — Parede de Escudos | `direct_volume` | Entrada world explícita e intercepção frontal real testadas; input/visual pendentes |
| `slash` — Corte em cone | `direct_volume` | Preview/preparo/commit espaciais ligados; prova nominal delimitada no recibo |
| `slowing_arrow` — Flecha Entorpecente | `direct_volume` | Preview/preparo/commit espaciais ligados; prova nominal delimitada no recibo |
| `snare_trap` — Armadilha de Laço | `ground_connected` | Preview/preparo/commit espaciais ligados; prova nominal delimitada no recibo; composição Caçadora explicitamente bloqueada |
| `soul_impact` — Impacto das Almas | `direct_volume` | Preview/preparo/commit e consumidor espacial ligados; teste nominal area_cast PASS59 |
| `spiritualist_channel_focus` — Foco do Além | `inherit_parent` | Herança/estatística inventariada; consumidor pendente |
| `spiritualist_dissipation` — Rito de Dissipação | `ground_connected` | Preview/preparo/commit e consumidor espacial ligados; teste nominal area_cast PASS59 |
| `spiritualist_echo_curse` — Maldição do Eco | `direct_volume` | Consumidor pendente; entrada legada bloqueada no binding |
| `spiritualist_echo_recovery` — Recolhimento | `inherit_parent` | Herança/estatística inventariada; consumidor pendente |
| `spiritualist_procession` — Procissão de Espectros | `direct_volume` | Preview/preparo/commit espaciais ligados; prova nominal delimitada no recibo |
| `spiritualist_soul_drain` — Drenagem Espiritual | `direct_volume` | Preview/preparo/commit espaciais ligados; prova nominal delimitada no recibo |
| `spiritualist_spectral_veil` — Véu Espectral | `ground_connected` | Preview/preparo/commit espaciais ligados; prova nominal delimitada no recibo |
| `swordsman_resistance` — Resistência | `inherit_parent` | Herança/estatística inventariada; consumidor pendente |
| `teleport` — Teleporte | `teleport_legal` | PlayerActor lógico testado; apresentação pendente |
| `terrifying_shout` — Grito Aterrorizante | `ground_connected` | Preview/preparo/commit e consumidor espacial ligados; teste nominal area_cast PASS59 |
| `trap_technique` — Técnica de Armadilhas | `inherit_parent` | Herança/estatística inventariada; consumidor pendente |
| `vigor` — Vigor | `inherit_parent` | Herança/estatística inventariada; consumidor pendente |

## Interações e exceções que precisam acompanhar os consumidores

| Família / fontes reais | Componentes e preservação obrigatória |
|---|---|
| Ataque básico; PlayerActor/EnemyActor | Melee usa volumes/alcance 3D. Básico mágico/arqueiro e mob ranged emitem projétil. BODY_OFFSET e sprite não são altura física. Ainda bloqueado no binding; combate autônomo pendente. |
| Slash, Contraforte, Rebater, Trava de Linha, Raiva Concentrada, Assombro | Cone/linha orientados no mundo, oclusão por sólido e laje. Tokens, fear, root e budgets permanecem dos handlers reais; não criar bônus de altura. |
| Ruptura, Execução, Arrancar Fôlego, Talho, Golpe Brutal, Provocar, Marca, Observar | Alvo e alcance 3D revalidados no commit. Custos HP/SP, marca, debuff, taunt e cura seguem emissão aprovada. Ruptura/detonação e DoTs anexados não viram outra AoE por inferência. |
| Dash, Avanço de Muralha, Guarda de Retirada, Salto Cruento | Rota no suporte e sweep contínuo. Hits durante deslocamento mantêm máximo/ordem/emissão. Somente dash lógico entregue; outros três e empurrões ainda pendentes. |
| Teleporte por classe/item | Destino legal/exato, range 3D, corpo não atravessa laje. Mantém passagem por obstáculos planos E06. Entrada nova não aplica clamp/nearest silencioso. Entrada legada plana conserva seu clamp de rank. |
| PlayerProjectile/MageProjectile, ArrowProjectile e SentinelProjectile | Sweep 3D contínuo, contato mais próximo entre sólido/ator/interceptor. Separar direção fixa, homing, perfuração finita, disparo duplo/fan e consumo de foco. Preservar modificadores de impacto e limites, sem dano duplicado. Nenhum desses consumidores adaptado ainda. |
| Chuva de Flechas | Centro WorldPoint capturado; chão conectado no alcance por volley. Três impactos e telegraph existentes, alvos amostrados novamente. Não atingir piso inferior/superior só por sobreposição. |
| Laço/Explosiva e traps Caçadora | Colocação/superfície, armar, ativar, substituir/expirar e registro por dono. Filtro de alvo não substitui validação geométrica. Piche persiste em seu suporte; espinhos/bleed herdam hit; mecanismo marcado não altera geometria. |
| Paredes fogo/raios/gelo, Barreira Fantasma, Parede de Escudos | Base no suporte e volume com altura. Cruzamento, interceptação e dano são etapas distintas. Gelo altera revision/path; parede inferior não bloqueia ponte superior. Não consumir capacidade antes do contato real. |
| Marco/Onda, Gritos, Fenda, Explosão/Anel/Trilha/Nova | Chão ancorado/conectado por centro ou segmento. Refazer queries por pulso/ramo conforme handler. Nova mantém sequências e orçamento; push percorre suporte. Não aprovar raio aéreo só por nome “explosão”. |
| Arco Voltaico | Cada salto tem fonte própria, range 3D, alvo vivo e oclusão da geometria atual; ordem/limite de saltos e dano continuam canônicos. |
| Impacto das Almas | Alvo travado; três pulsos seguem o alvo como no runtime atual. A classificação espacial do cast não cria rechecagem universal de LoS a ticks já emitidos. WorldTargetLock conserva corpo/suporte/epoch, sem transformar o pacote em canal. |
| Eco Espiritualista | Marca, origem que segue portador e exceção echo_origin_fixed são distintas. Onda/propagação finita captura sua própria origem/superfície; trocar desenho não move o ponto fixo. Novos alvos usam geometria, procs preservam causalidade. |
| Drenagem e Procissão | Runtime real revalida can_target_skill antes de cada tick/evento. Movimento/controle interrompe Drenagem. Preservar cura efetiva, limite, inscrição de conclusão e foco; não inventar revive/reset. |
| Véu, Folhagem e Cobertura Total | Áreas de suporte/ocultação ancoradas à superfície; participação não atravessa laje. Grace e revelação seguem contratos atuais. Regeneração e passivas próprias não são AoE novas. |
| Geômetra: traço/triangulação/edição/colapso | Capturar âncora de chão OU ator explicitamente, WorldPoint das arestas/interior, suporte contínuo e colisão do projétil. Refresh de âncoras móveis não troca piso por proximidade. Correntes de parede/triângulo, interações hostis, manutenção e budgets ainda não adaptados. |
| Geômetra: ground_anchor, collapse_first_element, incidência/memória | ground_anchor fixa o ponto de emissão sem trocar receita. Primeiro elemento só seleciona regra existente. Movimento do alvo/remoção/triângulo/reflexão/canalização não podem perder surface_id. |
| AI/mob skills/companheiro/leash | Home e destino WorldPoint, percepção/alcance pela mesma autoridade e perseguição por rota. O teste atual dirige EnemyActor manualmente; não prova aggro, leash, retorno, summon ou habilidades em multialtura. |
| Pickup/seleção/preview | Ainda sem adaptação. Coleta precisa de suporte/rota e contexto; seleção/preview/clique aguardam apresentação D05 e devem concordar com commit. |

## Efeitos de itens, cartas e augments

Regras de count/range transformam a habilidade original; grants usam seu mesmo
adaptador sem conceder biblioteca permanente. PROC de dano herda alvo/contato causal,
sem emitir uma segunda seleção espacial. KIT_RULE precisa conservar as exceções
nominais abaixo. Conjuntos atuais têm apenas modificadores estatísticos; não foram
inventados emissores espaciais para thresholds de conjunto.

| Origem / definição | effect_id / tipo | Habilidades ou política | Regra espacial |
|---|---|---|---|
| `augment/extra_fire_spear` | `fire_spear_count_flat` / `SKILL_RULE` | fire_spear | `mesma regra da habilidade`; consumidor pendente |
| `augment/extra_ice_spear` | `ice_spear_count_flat` / `SKILL_RULE` | ice_spear | `mesma regra da habilidade`; consumidor pendente |
| `augment/geometer_collapse_first_element` | `geometer_collapse_first_element_policy` / `KIT_RULE` | geometer_collapse | `geometer_collapse_first_element`; consumidor pendente |
| `augment/geometer_ground_anchor` | `geometer_ground_anchor_policy` / `KIT_RULE` | geometer_trace, geometer_triangulation | `geometer_ground_anchor`; consumidor pendente |
| `augment/hunter_covering_fan` | `hunter_covering_fan_policy` / `KIT_RULE` | hunter_covering_shot | `hunter_covering_fan`; consumidor pendente |
| `augment/hunter_marked_mechanism` | `hunter_marked_mechanism_policy` / `KIT_RULE` | hunter_freezing_trap, hunter_tar_trap, hunter_thorn_trap | `hunter_marked_mechanism`; consumidor pendente |
| `augment/pilot_archer_pressure` | `pilot_archer_pressure_effect` / `PROC` | contato causal original | `inherit_parent`; consumidor pendente |
| `augment/pilot_berserker_a` | `pilot_berserker_a_effect` / `PROC` | berserker_rupture | `inherit_parent`; consumidor pendente |
| `augment/pilot_berserker_b` | `pilot_berserker_b_effect` / `PROC` | berserker_execution | `inherit_parent`; consumidor pendente |
| `augment/pilot_defender_a` | `pilot_defender_a_effect` / `PROC` | defender_counterstroke | `inherit_parent`; consumidor pendente |
| `augment/pilot_defender_b` | `pilot_defender_b_effect` / `PROC` | defender_line_lock | `inherit_parent`; consumidor pendente |
| `augment/pilot_elementalist_a` | `pilot_elementalist_a_effect` / `PROC` | elementalist_flame_burst | `inherit_parent`; consumidor pendente |
| `augment/pilot_elementalist_b` | `pilot_elementalist_b_effect` / `PROC` | elementalist_glacial_ring | `inherit_parent`; consumidor pendente |
| `augment/pilot_mage_pressure` | `pilot_mage_pressure_effect` / `PROC` | contato causal original | `inherit_parent`; consumidor pendente |
| `augment/pilot_sentinel_a` | `pilot_sentinel_a_effect` / `PROC` | sentinel_headshot | `inherit_parent`; consumidor pendente |
| `augment/pilot_sentinel_b` | `pilot_sentinel_b_effect` / `PROC` | sentinel_net_shot | `inherit_parent`; consumidor pendente |
| `augment/pilot_swordsman_pressure` | `pilot_swordsman_pressure_effect` / `PROC` | contato causal original | `inherit_parent`; consumidor pendente |
| `augment/spiritualist_drain_inscription` | `spiritualist_drain_inscription_policy` / `KIT_RULE` | spiritualist_soul_drain, spiritualist_echo_curse | `drain_inscription`; consumidor pendente |
| `augment/spiritualist_echo_fixed_origin` | `spiritualist_echo_fixed_origin_policy` / `KIT_RULE` | spiritualist_echo_curse | `echo_origin_fixed`; consumidor pendente |
| `equipment/arena_ember_staff` | `pilot_staff_shape` / `SKILL_RULE` | fire_spear | `mesma regra da habilidade`; consumidor pendente |
| `equipment/arena_hunters_bow` | `pilot_bow_hit` / `PROC` | contato causal original | `inherit_parent`; consumidor pendente |
| `equipment/arena_prismatic_charm` | `pilot_prismatic_access` / `ACTIVE_GRANT` | fire_spear | `mesma regra da habilidade`; consumidor pendente |
| `equipment/arena_riposte_blade` | `pilot_blade_hit` / `PROC` | contato causal original | `inherit_parent`; consumidor pendente |
| `equipment/pilot_step_neck` | `pilot_step_access` / `ACTIVE_GRANT` | teleport | `mesma regra da habilidade`; consumidor pendente |
| `card/echo_card` | `pilot_card_hit` / `PROC` | contato causal original | `inherit_parent`; consumidor pendente |
| `card/ember_card` | `pilot_card_shape` / `SKILL_RULE` | fire_spear | `mesma regra da habilidade`; consumidor pendente |
| `card/frost_card` | `pilot_card_reach` / `SKILL_RULE` | ice_spear | `mesma regra da habilidade`; consumidor pendente |

## Componentes intrínsecos

Não acrescentam fórmulas nem autorização de novas emissões. Todos precisam manter
source/target/WorldPoint quando o consumidor correspondente for adaptado.

| Componente | Fronteira |
|---|---|
| `basic_attack` | volume direto / projétil real nas dez identidades; controlador ligado; input/visual/composição dos kits pendentes |
| `burn_tick` | inherit_parent; hit/estado causal já aceito; consumidor pendente |
| `bleed_tick` | inherit_parent; hit/estado causal já aceito; consumidor pendente |
| `hunter_thorn_bleed` | inherit_parent; hit/estado causal já aceito; consumidor pendente |
| `berserker_blood_rift_tick` | inherit_parent; hit/estado causal já aceito; consumidor pendente |
| `berserker_rupture_detonation` | inherit_parent; hit/estado causal já aceito; consumidor pendente |
| `geometer_wall_entry` | construção no suporte + interação/projétil; pendente |
| `geometer_wall_exit` | construção no suporte + interação/projétil; pendente |
| `geometer_foundation_fire` | construção no suporte + interação/projétil; pendente |
| `geometer_foundation_lightning` | construção no suporte + interação/projétil; pendente |
| `geometer_rule_fire` | construção no suporte + interação/projétil; pendente |
| `geometer_rule_lightning` | construção no suporte + interação/projétil; pendente |
| `geometer_resolution_fire` | construção no suporte + interação/projétil; pendente |
| `geometer_resolution_ice` | construção no suporte + interação/projétil; pendente |
| `geometer_resolution_lightning` | construção no suporte + interação/projétil; pendente |
| `geometer_triangle_maintenance` | construção no suporte + interação/projétil; pendente |
| `geometer_incidence` | construção no suporte + interação/projétil; pendente |

Famílias causais do catálogo: `elementalist_tri_nova_ice`, `elementalist_tri_nova_lightning`, `hunter_exploit`, `sentinel_focus`, `berserker_wound`, `berserker_pursuit`, `berserker_breath_heal`, `elementalist_focus`, `spiritualist_echo`, `spiritualist_echo_recovery`, `spiritualist_channel_focus`, `spiritualist_drain_heal`, `blood_thirst`, `defender_watch`, `defender_token`, `defender_guard_return`. Foco/token/cura/recovery herdam evento aceito; não precisam ganhar LoS ou uma área própria. Nenhuma família equivale a validação multialtura concluída.

## Próximo trabalho no mesmo F1

Adaptar os consumidores nominais acima e adicionar integração real por kit/efeito antes de liberar combate multialtura. A barreira em PlayerActor continua impedindo as ativas espaciais sem adaptador de cast; isso é falha explícita, não suporte completo. D05 visual continua pendente, sem renderer/clique/inspeção nativa visual implementados. Não iniciar F2+ nem marcar F1 VALIDADA/ENTREGUE.

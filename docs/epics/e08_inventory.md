# E08 — inventário P0

Base `c8b80b13d29c468afb7f2ad7ba75eec838e7df32`, 5/11/2026.
Inspeção de fontes/consumidores e recibos existentes; existência não certifica
qualidade visual. P3 inspeciona renderer real antes de trocar assets.

| Fonte real | Consumidor confirmado | Evidência | Decisão / intervenção |
|---|---|---|---|
| assets/art/animations/{mage,mage_weaponless}.png e demais identidades | scripts/actors/character_animation.gd | preparation_report.json; docs/art/animation_contact_sheet.png | preservar contrato/atlas; corrigir somente defeito visual demonstrado no piloto |
| assets/art/animation_sources, tools/prepare_animation_assets.py e prepare_weaponless_player_animations.py | atlas 256×512, 32 células | fontes e relatório com bounds/pivô | preservar fontes e processamento; completar proveniência dos deltas P3 |
| scripts/core/combat_animation_state.gd | CharacterAnimation; CombatActor | tests/combat_animation_test.gd | preservar relógio/displacement/revive; completar testes ciclo E08 |
| scripts/actors/equipment_attachment_visual.gd e equipment_head_visual.gd | CharacterAnimation.draw_on e PlayerActor._sync_equipment_visual | contrato de equipamento E06; drawers antes/depois do corpo | preservar anexos e slots; validar Mago equipado/espelhado |
| resources/forest_phase/mob/forest_{wolf,boar,stalker,canopy_archer,ancient_warden}.tres; atlas animal_companion/warrior/archer/beast_master | EnemyActor.configure_occurrence→set_animation_kind→CharacterAnimation.draw_on | fase publicada data/expedition/phases/forest_sanctuary.json fixa forest_terraces, forest_valleys e forest_lair | preservar espécies/AI/população; completar acabamento dos consumidores reais do piloto |
| scripts/world/mob_prototype_visual.gd | RunController e admin consomem category_name; draw_on não tem chamada encontrada no runtime atual | busca de referências em scripts; os atores usam atlas | preservar nomes; não polir drawer morto como se chegasse ao jogo |
| assets/art/map_authoring/materials_provenance.json e props/provenance.json | scripts/world/expedition_geometry_view.gd e skin autorada | docs/map_editor/consumption.md; F10 terrain_performance | preservar fontes/geometria; corrigir leitura visual em piso/rampa/ponte se demonstrada |
| scripts/actors/mage_projectile.gd, player_projectile.gd; scripts/world/world_field_view.gd, battle_indicators.gd | RunController scripts/main.gd; WorldProjectileMotion/WorldEffectArea | tests/e07_f1_presentation_test.gd, e07_f1_fields_test.gd | preservar autoridades; completar bridge de eventos confirmados/lifecycle P1 e receitas visuais P3 |
| CombatActor.presentation_action; HealthState.damage_applied; PlayerActor.world_cast_status/anchor | animação/RunController | código conecta health.damage_applied na criação de atores | completar observador idempotente; não usar ataque solicitado como impacto |
| Sem .wav/.ogg/.mp3 em assets e sem Audio* nos scripts pesquisados | nenhum serviço de áudio encontrado | busca P0 em scripts/assets/project.godot/export_presets.cfg | completar serviço/catálogo/config/UI P2 e primeiros samples P3; não alegar sistema já implementado |
| export_presets.cfg, tools/verify.ps1 | export Windows, fixture F1 | F10 PCK 136d35e0d059572b633e2d743fba839e97273b1aaa11d7f41c28ad9b0b9dee3a | preservar runner/fixture, completar seleção E08 e vínculo release P0/P7 |

Lacunas deliberadamente abertas: juízo artístico e audibilidade em renderer real,
memória comparável F10/E08 e nomes finais dos samples. Elas pertencem aos pacotes
de execução, não viram PASS neste inventário documental.

Correção de rastreamento em6/11: sanctuary_woods.population.json é fonte antiga,
não os três pacotes da Floresta do Santuário publicada. A primeira leitura P0
havia associado essa fonte e o drawer prototype ao piloto; corrigida antes de P3.
Os quatro backups sanctuary_woods continuam preservados, sem serem republicados.
O Guardião Ancestral usa beast_master; lobo/javali usam animal_companion;
perseguidor usa warrior e arqueiro da copa usa archer. Compartilhamento de atlas
não autoriza redesenhar as demais identidades de P4 por efeito do piloto: usar
consumidores visuais próprios quando for necessário distinguir espécie.

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
| scripts/world/mob_prototype_visual.gd; atlas gel/beast_master/animal_companion | EnemyActor/body_drawer | população publicada data/map_authoring/sanctuary_woods.population.json | preservar espécies; completar acabamento das ocorrências reais, sem inferir cobertura pelo nome do atlas |
| assets/art/map_authoring/materials_provenance.json e props/provenance.json | scripts/world/expedition_geometry_view.gd e skin autorada | docs/map_editor/consumption.md; F10 terrain_performance | preservar fontes/geometria; corrigir leitura visual em piso/rampa/ponte se demonstrada |
| scripts/actors/mage_projectile.gd, player_projectile.gd; scripts/world/world_field_view.gd, battle_indicators.gd | RunController scripts/main.gd; WorldProjectileMotion/WorldEffectArea | tests/e07_f1_presentation_test.gd, e07_f1_fields_test.gd | preservar autoridades; completar bridge de eventos confirmados/lifecycle P1 e receitas visuais P3 |
| CombatActor.presentation_action; HealthState.damage_applied; PlayerActor.world_cast_status/anchor | animação/RunController | código conecta health.damage_applied na criação de atores | completar observador idempotente; não usar ataque solicitado como impacto |
| Sem .wav/.ogg/.mp3 em assets e sem Audio* nos scripts pesquisados | nenhum serviço de áudio encontrado | busca P0 em scripts/assets/project.godot/export_presets.cfg | completar serviço/catálogo/config/UI P2 e primeiros samples P3; não alegar sistema já implementado |
| export_presets.cfg, tools/verify.ps1 | export Windows, fixture F1 | F10 PCK 136d35e0d059572b633e2d743fba839e97273b1aaa11d7f41c28ad9b0b9dee3a | preservar runner/fixture, completar seleção E08 e vínculo release P0/P7 |

Lacunas deliberadamente abertas: juízo artístico e audibilidade em renderer real,
memória comparável F10/E08 e nomes finais dos samples. Elas pertencem aos pacotes
de execução, não viram PASS neste inventário documental.

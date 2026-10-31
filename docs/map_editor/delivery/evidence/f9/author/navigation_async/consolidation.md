# Checkpoint36 — consolidação das rotas em segundo plano

31/10/2026, Sol/Astra (Claude Opus). Base e8d6532a. Contrato:
[f9_navigation_async.md](../../../../../contracts/f9_navigation_async.md).

## Arquivos

- `scripts/core/expedition/spatial/world_geometry.gd`: `PathRequest`,
  `request_path`, `navigation_pump`, vista congelada com memo próprio,
  `segment_walkable`; `configure` troca o índice de apoio em vez de limpá-lo.
- `scripts/core/expedition/spatial/world_actor_motion.gd`: `plan_async`,
  `plan_pending`, emenda em `adopt_route`, descarte do pendente.
- `scripts/actors/enemy_actor.gd`: perseguição e volta para casa por `plan_async`.
- `scripts/actors/player_actor.gd`: perseguição do alvo por `plan_async`.
- `scripts/main.gd`: clique no chão em segundo plano, bombeamento por quadro,
  ligação em `attach_expedition_view`.
- `scripts/core/expedition/snapshot/runtime_manifest.json`: campos transitórios
  em `omitted`.
- `tests/map_editor_navigation_async_test.gd` (+uid), estágio NavigationAsync (18).
- `tools/map_editor_completion/run.ps1`: estágio NavigationAsync.

## Validação

Ver `luna/navigation_async/` e `author/navigation_async/` (saídas 119–121).
Medições no contrato, seção Resultado.

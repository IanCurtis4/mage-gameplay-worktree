# Checkpoint35 — consolidação do grafo de navegação reutilizável

31/10/2026, Sol/Astra (Claude Opus). Base 11c67b2a. Contrato:
[f9_navigation_graph.md](../../../../../contracts/f9_navigation_graph.md).

## Arquivos

- `scripts/core/expedition/spatial/world_geometry.gd`: memo compartilhado com
  epoch, A* com guarda de consistência, corte exato antes dos predicados.
- `scripts/core/expedition/snapshot/runtime_manifest.json`: `_navigation_epoch` e
  `_navigation_shared` em `omitted` (derivados).
- `tests/map_editor_navigation_astar_test.gd` (+uid): estágio NavigationAstar, 18
  checks.
- `tools/map_editor_completion/run.ps1`: estágio NavigationAstar.

## Validação (fixture compartilhada, Godot 4.7.2)

- NavigationAstar 18, NavigationLazy 24, NavigationDense 5, NavigationContext 11.
- GameplayNative 55, CandidateBatch 18, PopulationPlanner 20,
  PopulationReachability 27, SurfacePick 24, Batch 36, Ports 92, Geometry 46,
  Organic 15, WorldTargeting 16, WorldRewardPoll 10, GameplayGate 24,
  GameplayControls 29, GameplayWindow 33, GameplayCli 18, CanvasOrder 43,
  RuntimeView 12, FieldsNative 73: todos PASS.
- 32 suítes E07 legadas que tocam geometria/movimento: PASS, exceto
  `e07_f1_presentation` (1 falha conhecida da checagem de emenda ambígua,
  anterior a este checkpoint; o código dela não foi tocado).
- Primeira execução de GameplayNative falhou com `checkpoint_incomplete`
  (`world_geometry.gd:_navigation_epoch`): o registro de snapshot exige toda
  variável de script declarada. Corrigido pelo `omitted` acima; reexecução PASS.

## Medições no Bosque

Logs: `luna/navigation_astar/` (estágios) e `author/navigation_graph/`
(`110_out.txt`, `111_out.txt`, `116_out.txt`, `117_out.txt`, probes).

- casa→entrada fria: 57,9 s → 1,18 s; repetida 0,10 s; custo idêntico.
- emenda clareira→viaduto (clique do jogador, walk probe): 1,61 s → 0,76 s na
  primeira vez; 0,08 s quente.
- Restante na emenda fria: materialização de superfície (0,50 s), uma vez por
  superfície e perfil.

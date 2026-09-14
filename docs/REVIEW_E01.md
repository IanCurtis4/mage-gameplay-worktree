# Revisão E01 — personagens persistentes e alts

## E01.1 — separação de estado e IDs estáveis

Data: 13/09/2026. Estado: **ACEITE TÉCNICO ASTRA**.

- Base contratual: `247e304` (encerramento aceito de E00 sobre `73f7a03`).
- Implementação inicial: `82dd8d1`.
- Candidato aprovado: `02262cbe88dc8ef0c162c32c2b9d3c960296ea54`.
- Branch isolada: `codex/e01-persistent-characters`.

O passo introduz `ProfileState`, `CharacterState`, `BuildSnapshot` e o registro
`IdentityIds`. `RunState` recebe uma cópia profunda da build e conserva apenas
estado da run. O caminho legado do piloto continua aceitando troca de classe; uma
run originada de personagem persistente rejeita essa troca sem mutar IDs, build,
skills ou estado transitório.

A primeira revisão encontrou e devolveu dois defeitos: troca de classe permitida
numa run persistente e aceitação do par evolução/base vazio. O commit aprovado
corrige ambos. Regressões cobrem as 12 origens de evolução, pares inválidos,
isolamento entre alts, cópias de presets/equipamentos e separação da run.

### Evidência

Astra executou independentemente `tools/verify.ps1` com Godot 4.7.2 na worktree
do E01: Foundation 20, Animações 30, Marco 1 63, Perseguição 41, UI 47,
Arena 32, Layout 28, Mago 52 e Persistência 33: **346 verificações PASS**.
Importação e smoke concluídos com exit 0; `git diff --check` sem problemas e
worktree limpa no candidato revisado.

### Limites e próximo gate

Este aceite encerra somente E01.1. Escrita atômica, backup, migração e recuperação
pertencem a E01.2; fachada, criação/seleção e XP idempotente pertencem a E01.3.
Nenhum desses passos foi iniciado. `codex/playtest` e `master` não foram alteradas.

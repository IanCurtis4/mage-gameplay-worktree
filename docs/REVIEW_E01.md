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

## E01.2 — persistência versionada e recuperação

Data: 14/09/2026. Estado: **ACEITE TÉCNICO ASTRA**.

- Implementação inicial: `5717176`.
- Correção de invariantes duráveis: `efb2b48`.
- Candidato aprovado: `deaf37144e7ef78e64b064878e2221ce0e85e6c4`.

O passo introduz o codec do schema 2, um escritor transacional por perfil,
substituição por arquivo pendente validado, backup conservador, recuperação e
migração reconhecida do schema 1. Falhas, revisões obsoletas, regressão dos
contadores monotônicos e artefatos isolados bloqueiam o commit antes de publicar
estado em memória. Schema futuro e catálogo incompatível permanecem intactos e
somente leitura, sem recuo silencioso ao backup.

O catálogo mínimo de persistência passou a validar origem, slot, categoria,
carteira e tetos de rank do contrato E00: rank efetivo máximo 5 para ativas e 3
para passivas. Skills da carteira de evolução declaram `required_evolution_id`;
compras e presets só aceitam a evolução exata, inclusive quando o rank gratuito
já tornaria a skill utilizável. Esta metadata é uma fronteira de validação do
save, não a árvore completa de requisitos que pertence a E03.

### Evidência

Sol executou `tools/verify.ps1` com Godot 4.7.2: **435 verificações PASS**,
incluindo 89 de E01.2, importação/editor e smoke com exit 0 e sem `ERROR`.
Uma reprodução Luna separada aprovou 33 cenários de contadores, artefatos,
schema futuro, catálogo/equipamentos e preservação byte a byte. Astra revisou o
delta e repetiu a suíte completa com os mesmos 435 checks; sondas adicionais
confirmaram rejeição de catálogo superdimensionado e de skill gratuita na
ausência ou na evolução errada. `git diff --check` e a worktree ficaram limpos.

### Limites e próximo gate

Este aceite encerra somente E01.2 e libera E01.3-A: fachada transacional mínima
para criar e selecionar personagem. `start_run` e recompensa idempotente ficam
em E01.3-B após novo gate. Não há aceite de produto nem atualização de
`codex/playtest` ou `master`.

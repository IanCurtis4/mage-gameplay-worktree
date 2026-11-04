# F10 — redução do custo de entrada e portais

4/11/2026. Pedido humano: diminuir mais os tempos antes de fechar Q5.
Base `a8196dc7cd313673e60bb13287f2cc5e50e66b92`, branch
`codex/map-editor-f10`, checkout único `.tools/map-editor-m5`.

Sol assume sequencialmente este incremento: registro de snapshots, validador
de patrulha, planejador de população, testes dirigidos, runners e documentação. Luna pode supervisionar
o lote congelado; nenhum escritor trabalha durante a execução na fixture.

Propriedade nominal Sol: `snapshot/snapshot_registry.gd`,
`map_authoring/patrol/patrol_compiler.gd`, `population/population_planner.gd`,
`tests/e07_f3_snapshot_test.gd`, `tests/map_editor_{patrol,forest_play,population_planner_batch}_test.gd`,
`tools/map_editor_{patrol,completion}/run.ps1` e os três documentos F10 deste
incremento. Os três primeiros caminhos são relativos a `scripts/core/expedition`
exceto `map_authoring/...`, relativo a `scripts`. Não há cena ou UID novo,
nem mudança em `runtime_manifest.json`. Luna escreve somente evidência na
fixture descartável; os arquivos de fonte permanecem congelados durante o lote.

## Contrato preservado

Continuam a barreira de tick, a primeira reconstrução fora da árvore, o comando
no mundo destacado, a captura posterior e a segunda reconstrução. Só o writer
canônico confirma o perfil; o mundo instalado continua sendo restaurado do
checkpoint gravado. Identidades, alias, tipos, sinais, RNG, recibos, revisão,
falha de gravação e reconciliação mantêm as mesmas regras.

## Otimizações delimitadas

1. Reflexão de scripts/propriedades: reutilizar listas e descritores dentro de
   uma operação de captura/restauração, sem persistir caches no snapshot. Nova
   operação volta a consultar o schema; campo novo omitido continua erro.
2. Pacote de patrulha: depois de conferir estrutura, digest, pacote interno,
   catálogo/política atuais e dependências, reutilizar a prova de planejamento
   e rotas para os mesmos bytes de pacote no mesmo processo. Cache limitado a
   oito entradas, protegido por mutex. Adulteração, nova revisão, catálogo,
   política ou dependência invalidam a prova. Nenhum dado da run é cacheado.
3. Admissão de população: conservar até 32 provas booleanas de alcance da
   entrada até os mesmos alvos, com geometria, lajes derivadas e perfil exatos.
   Somente o nome do estágio é ignorado, pois a composição da fase renomeia o
   mesmo mapa. Cada build cria mundos novos e revalida espécie, política,
   testemunha e apoio de cada vaga. Chamadas canceláveis mantêm a consulta
   integral. Não se guardam slots, mundos, recompensas ou estado de campanha.

Não se remove validação de input externo nem se altera conteúdo para reduzir
tempo. A comparação usa os mesmos três mapas publicados, população e perfil.
O ganho deve aparecer no fluxo real; tempo de suíte é somente diagnóstico.

## Prova

Testes negativos de schema/tipos e de pacote adulterado após acerto de cache;
seleção de persistência F3/F4 no verify.ps1; SnapshotDensity, continuidade
da fase real até conclusão e medições de entrada, viagem e suspensão. Logs,
hashes e limites são registrados no checkpoint F10. Isso não fecha Q5.

# E01 — relatório de retomada

> Estado vigente: E01 completo tecnicamente na entrega `2127a8e`, rebased em
> `caa7011` sem alteração de código. Aguardando playtest manual pelo usuário.
> Roteiro: PLAYTEST_E01.md; handoff atual: epics/e01.md. Registros abaixo são
> históricos e não reabrem gates já aprovados. Master não integrado.

> Checkpoint vigente: E01.3-B aprovado tecnicamente por Astra em `2c04b5e`,
> com reprodução independente dos dois defeitos corrigidos e 536 checks PASS,
> importação completa e smoke OK. E01.3-C liberado para teste manual da fachada
> no Godot, com Terra sob Sol. Fechamento integrado/playtest ainda pendentes.
> O restante conserva checkpoints anteriores; não marca aceite do produto.

> Checkpoint vigente: E01.3-A aprovado tecnicamente por Astra em `ec865ac`,
> com reprodução independente do bloqueio somente leitura e 482 checks PASS,
> importação completa e smoke OK. E01.3-B liberado para Sol no mesmo épico.
> O restante conserva checkpoints anteriores. Playtest/master não atualizados.

> Gate técnico Astra E01.2 fechado em 14/09/2026 no candidato
> `deaf37144e7ef78e64b064878e2221ce0e85e6c4`. Revisão do delta e execução
> independente de tools/verify.ps1 na worktree E01: 435 checks PASS (89 de
> store), import/editor e smoke exit 0, sem ERROR. Sonda adicional rejeita
> catálogo com rank ativo 9+99. Evolução é validada nas compras e presets;
> fixtures cobrem ausência, evolução errada e correspondente. Worktree limpa.
> E01.3-A (criar/selecionar) liberado para Sol. Isso não fecha o épico,
> não atualiza playtest/master e não substitui o aceite do usuário.
> O catálogo de persistência ainda não é a árvore completa de skills E03.

> Atualização posterior, 14/09/2026: usuário liberou a retomada com Sol na
> conversa principal e subagentes Luna/Terra delimitados. Protocolo aprovado
> em REVIEW_WORK_PACKAGES.md; handoff atual em epics/e01.md. O corpo abaixo
> preserva o snapshot Luna anterior à retomada. E01.2 continua em correção/
> revisão, E01.3 aguarda esse gate. Na worktree com alterações em andamento
> sobre `efb2b48`, a sonda Astra `.tools/e012_catalog_review.gd` confirmou
> catálogo aceitando free_rank=9/max_purchased_rank=99; devolvido a Sol.
> Não atribuir essa sonda a um novo commit estável ainda não entregue.

Data do relatório: 2026-09-14

Este documento registra onde E01 parou. Ele não reabre o design, não fecha o
épico e não autoriza implementação adicional.

## Limite desta retomada

O pedido desta tarefa é a autoridade operacional: inspecionar o estado, rodar a
verificação existente, documentar o delta e integrar referências somente em
`docs/`. Os arquivos anexados foram tratados assim:

- `CODEX_HANDOFF_README.md`: handoff de contexto; seus marcadores `LOCKED`,
  `STRONG DIRECTION` e `OPEN` são referências de decisão, não autorização para
  alterar o runtime nesta tarefa.
- `CODEX_BOOTSTRAP_PROMPT.txt`: modelo de mensagem para retomadas futuras; não é
  uma ordem para implementar agora.
- `ASSET_MANIFEST.md`: identificação de snapshot por hash; não é prova de licença
  nem especificação de gameplay.

O pacote foi preservado literalmente em
[`docs/references/CODEX_HANDOFF_MVP_2026-09-14/`](references/CODEX_HANDOFF_MVP_2026-09-14/).
Nenhum arquivo de `scripts/`, `scenes/`, `tests/` ou `assets/` foi alterado nesta
retomada.

## Snapshot de branch e commits

| Referência | Commit | Significado |
|---|---|---|
| Checkout atual | `79196d595e166978028943abe8e35c84240a7d59` | `codex/playtest`, último commit visível nesta worktree; ainda sem o runtime de E01 |
| Base aceita de E01 | `247e3043f3ef02effec830ef9b55a7ef2862d50b` | encerramento aceito de E00 e base registrada para E01.1 |
| Branch de E01 | `codex/e01-persistent-characters` | branch isolada encontrada no repositório |
| HEAD de E01 | `efb2b48a4fe5f949af33dd92bae4abc3e840b661` | `Enforce durable profile catalog invariants`, último commit da branch |

O diff de E01 foi calculado como `247e304..efb2b48`; `git diff --check` não
encontrou problemas. A worktree corrente está deliberadamente suja por arquivos
do usuário, fora deste trabalho: `project.godot`, `addons/`, `build/` e
`export_presets.cfg`. Eles não foram tocados.

Commits de E01, em ordem:

1. `82dd8d1` — separação inicial de estado persistente e IDs.
2. `02262cb` — proteção dos limites de identidade da run.
3. `7e73886` — registro da aprovação técnica de E01.1.
4. `5717176` — armazenamento versionado, migração e recuperação.
5. `efb2b48` — invariantes duráveis do catálogo e correções associadas.

## Arquivos alterados na branch de E01

O delta desde `247e304` contém somente estes 25 caminhos:

### Documentação

- `docs/REVIEW_E01.md`
- `docs/epics/e01.md`

### Estado persistente e contratos de dados

- `scripts/core/build_snapshot.gd` e `.uid`
- `scripts/core/character_state.gd` e `.uid`
- `scripts/core/identity_ids.gd` e `.uid`
- `scripts/core/profile_catalog.gd` e `.uid`
- `scripts/core/profile_codec.gd` e `.uid`
- `scripts/core/profile_state.gd` e `.uid`
- `scripts/core/profile_store.gd` e `.uid`
- `scripts/core/progression_rules.gd` e `.uid`
- `scripts/core/run_state.gd`
- `scripts/data/class_catalog.gd`

### Testes e verificação

- `tests/persistent_state_test.gd` e `.uid`
- `tests/profile_store_test.gd` e `.uid`
- `tools/verify.ps1`

Esses caminhos estão na branch de E01, não no checkout atual
`codex/playtest`.

## Requisitos e estado

| Requisito | Estado | Evidência e limite |
|---|---|---|
| E01.1 — separar `ProfileState`, `CharacterState` e `RunState`, com IDs estáveis e snapshot isolado | **DONE técnico** | `persistent_state_test.gd`, commits `82dd8d1`/`02262cb` e `docs/REVIEW_E01.md` registram aprovação técnica Astra. Isso não equivale ao aceite final do produto. |
| E01.2 — save versionado, escrita transacional, backup, migração e recuperação conservadora | **PARTIAL: implementação presente, gate aberto** | `profile_codec.gd`, `profile_store.gd`, `progression_rules.gd` e `profile_store_test.gd` existem em `efb2b48`; o último ajuste ainda não tem revisão/evidência pós-commit registrada. |
| E01.2 — progresso persistente independente de augments/run | **PARTIAL** | O codec rejeita campos de runtime e o snapshot separa a run, mas ainda não há fachada de criação/seleção/XP que prove o fluxo de produto completo. |
| E01.3 — criar/selecionar personagem e conceder XP de forma idempotente | **NOT STARTED** | Não há serviço/fachada nem teste de operação idempotente nos arquivos alterados de E01. |
| Aceite do épico — dois alts, progresso, morte, reinício e recuperação sem duplicação/vazamento | **NOT READY** | E01.3 não foi iniciado; a branch não demonstra o cenário ponta a ponta no aplicativo. |

Conclusão: E01 parou depois de uma implementação de E01.2 e de uma correção de
invariantes, mas antes do fechamento técnico desse passo e antes de E01.3. Não é
seguro descrever E01 como concluído.

## Verificações e falhas reproduzíveis

### Checkout atual (`codex/playtest`)

Com Godot 4.7.2 e PowerShell 7, a suíte headless passou usando a cópia do
console extraída de `.tools/godot.zip` em `%TEMP%`:

```powershell
$godotPath = Join-Path ([System.IO.Path]::GetTempPath()) `
  'ragrpg-godot-4-7-2\Godot_v4.7.2-stable_win64_console.exe'
pwsh -NoProfile -File .\tools\verify.ps1 `
  -GodotPath $godotPath `
  -SkipEditorImport
```

Resultado observado: Foundation 20, Animações 30, Marco 1 63, Perseguição e
inércia 41, UI de batalha 47, Fluxo da arena 32, Layout 28, Gameplay do Mago
52 e smoke da cena; todos `PASS`.

A execução completa, sem `-SkipEditorImport`, falha na etapa de importação/editor
por um bloqueador ambiental já presente na worktree:

```powershell
$godotPath = Join-Path ([System.IO.Path]::GetTempPath()) `
  'ragrpg-godot-4-7-2\Godot_v4.7.2-stable_win64_console.exe'
pwsh -NoProfile -File .\tools\verify.ps1 `
  -GodotPath $godotPath
```

Godot registra `GitPlugin: Could not initialize repository ... repository path
... is not owned by current user`, seguido de `ERROR: Could not initialize
GitPlugin`. O processo termina com exit code 0, mas `verify.ps1` aborta porque
trata `ERROR:` na saída como falha. Além disso, o executável console presente
diretamente em `.tools/godot/` retorna `CreateProcess failed, error 193` nesta
máquina; por isso a reprodução acima usa a cópia extraída válida. Isso é falha
de ambiente/importação, não uma falha dos testes headless; não foi corrigido
aqui.

### Branch de E01

`docs/REVIEW_E01.md` registra, no candidato E01.1 `02262cb`, 346 verificações
passando: Foundation 20, Animações 30, Marco 1 63, Perseguição 41, UI 47,
Arena 32, Layout 28, Mago 52 e Persistência 33. Esse registro antecede os
commits de E01.2 e não substitui uma execução no HEAD `efb2b48`.

O teste específico de E01.2 está em `tests/profile_store_test.gd` na branch e
pode ser reproduzido em uma worktree limpa dessa branch com:

```powershell
$godotPath = Join-Path ([System.IO.Path]::GetTempPath()) `
  'ragrpg-godot-4-7-2\Godot_v4.7.2-stable_win64_console.exe'
pwsh -NoProfile -File .\tools\verify.ps1 `
  -GodotPath $godotPath `
  -SkipEditorImport
```

ou, isoladamente:

```powershell
$godotPath = Join-Path ([System.IO.Path]::GetTempPath()) `
  'ragrpg-godot-4-7-2\Godot_v4.7.2-stable_win64_console.exe'
& $godotPath `
  --headless --path . --script res://tests/profile_store_test.gd
```

Não há uma falha de teste E01 registrada após `efb2b48`. Há, porém, sondagens
anteriores em `.tools/e012_review_probe.gd` e em `.tools/e012_probe_381355/` que
capturaram, antes do último commit, aceitação indevida de regressão de contador
e bypass de um backup com schema futuro. `efb2b48` aparenta endereçar esses
casos; eles precisam ser reexecutados no HEAD antes de fechar E01.2.

## Bloqueadores suspeitos

1. **Evidência pós-E01.2 ausente.** O último `REVIEW_E01.md` encerra somente
   E01.1, embora a branch tenha avançado. É preciso validar `efb2b48`, inclusive
   os dois casos das sondagens antigas, sem ampliar o escopo.
2. **E01.3 ausente.** Sem a fachada de perfil, o save não comprova criar/selecionar
   alts nem XP idempotente após reinício.
3. **Documentação de estado divergente.** No checkout atual, `docs/epics/e01.md`
   ainda está `RESERVADO`; na branch de E01, o texto diz E01.1 aprovado e E01.2/E01.3
   liberados. `docs/REVIEW_E01.md` é mais antigo e ainda descreve E01.2 como não
   iniciado. A próxima revisão deve alinhar o registro somente com evidência.
4. **Importação local bloqueada pelo ambiente.** A suíte completa precisa ser
   repetida em uma worktree limpa/importável; o bypass é aceitável apenas para
   separar os testes headless, como indicado no README. Nesta máquina, o
   GitPlugin gera `repository ... is not owned by current user` durante import e
   o console em `.tools/godot/` também retorna `CreateProcess error 193`.

## Menor próxima tarefa para Sol

Fechar **somente E01.2** na branch `codex/e01-persistent-characters`, sem iniciar
E01.3:

1. Executar `tools/verify.ps1` e `tests/profile_store_test.gd` no HEAD
   `efb2b48`, em uma worktree limpa.
2. Reexecutar os dois casos das sondagens antigas: regressão de
   `next_run_counter` e backup com schema futuro sem primary.
3. Se houver falha, alterar somente codec/store/catálogo e o teste de invariantes
   correspondente; não mexer em gameplay, UI, XP operacional ou schema fora do
   contrato já existente.
4. Registrar uma revisão curta de E01.2 com comandos, resultados e limitações.

Critério mínimo de saída: testes de persistência passando no HEAD, `git diff
--check` limpo, nenhum arquivo fora do conjunto de persistência/testes/documentação
alterado e E01.3 ainda explicitamente não iniciado.

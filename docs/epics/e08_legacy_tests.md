# Testes históricos atualizados após a triagem P7

09/11/2026. Branch `claude/e08-legacy-tests` a partir de `codex/e08` (`79656308`).
Entrada: os 10 FAIL pré-existentes de [e08_p7_triage.md](e08_p7_triage.md).
Só testes e a sonda F8 mudaram; nenhum runtime, conteúdo, save ou schema.

## Resultado

| Etapa | Antes | Depois | Contrato atual exercitado | Commit que mudou o contrato |
|---|---|---|---|---|
| 68 `e05_hunter_catalog_test` | 619/1 | 619/0 | pino schema 8 | E07 F2 `3b15ae8a` (20/10) |
| 106 `e04_swordsman_integrated_closure_test` | 93/4 | 94/0 | cada preset usa as peças do próprio dono; peça alheia é recusada sem gravar (check novo) | E07 F2 `3b15ae8a` |
| 152 `e05_sentinel_builds_test` | 313/1 | 317/0 | save antigo abre protegido (`migration_required`, arquivo intacto) e migra por prévia + digest confirmado | E07 F2 `3b15ae8a` |
| 221 `e06_publication_test` | 1123/36 | 1162/0 (com `eol=lf`) | pino schema 8; posse individual; schema 2 migra por prévia, e a remoção da referência do alt aparece na prévia | E07 F2 `3b15ae8a`; ver os 34 abaixo |
| 223 `e06_ui_menu_test` | 105/3 | 113/0 | coleção publicada pertence ao primeiro personagem; o alt só tem os próprios iniciais | E07 F2 `3b15ae8a` |
| 230 `e06_permanent_cards_test` | 42/7 | 49/0 | schema 4 por prévia; o alt não vê nem desencaixa a carta do dono (check novo); pino schema 8 | E07 F2 `3b15ae8a` |
| 243 `e06_skill_downrank_test` | 112/1 | 114/0 | schema 5 por prévia; slot disfarçado ainda é recusado pela validação, não pelo bloqueio | E07 F2 `3b15ae8a` |
| 244 `e06_swordsman_cluster_test` | 186/3 | 227/0 | schema 5/6 no store real: abre protegido, digest adulterado é recusado sem gravar, falha em cada estágio preserva o primary | E07 F2 `3b15ae8a` |
| 250 `e06_export_content_test` | 162/2 | 167/0 | 16 mobs e as cinco espécies da floresta presentes pelo ID | F10 Q4 `a49459c8` (03/11) |
| 323 `e07_f8_candidate_resume` | 19/1 | 61/0 | morte gravada como uma entrada de diário no mesmo host (slot `dead`, fila vazia); a substituição de cena segue aceita como caminho de reserva | `2c597e70`/`21b0b2fd` (31/10) |

A migração confirmada usa o helper existente `tests/fixtures/e07/f2/confirmed_history.gd`
(`ProfileStore.preview_migration` → `apply_migration` com o digest da prévia), o mesmo
que a F2 usou nos 39 testes que atualizou. Os testes com mais checks antes pulavam
etapas inteiras depois da primeira falha; agora essas etapas rodam.

Nada foi afrouxado. Recusas que o bloqueio de migração deixaria passar trivialmente
(slot disfarçado, investimento inválido, coleção contrabandeada) agora exigem que a
causa não seja `migration_required`.

## Os 34 de `e06_publication_test`: fim de linha do checkout, não deriva de conteúdo

Investigação campo a campo (sonda de diff sobre `_normalize`, mesma normalização do
teste): **os 34 diferem só em `description`, e só por `\r\n` contra `\n`** dentro da
string de várias linhas. As outras propriedades são idênticas.

- Os blobs no Git são LF (`git ls-files --eol`: `i/lf w/crlf` nos 83 `.tres` de
  `resources/build_effects`). `core.autocrlf=true` grava CRLF no checkout Windows, e o
  Godot mantém o `\r` dentro da string. A publicação compilada usa `\n`.
- Prova: com esses 83 arquivos refeitos em LF (`git -c core.autocrlf=false checkout`),
  o teste passa **1162/0**. Restaurado o checkout normal, volta a 1162/34.
- O checkout habitual (`codex/playtest`) e o da E08 (`.tools/map-editor-m5`) também
  são `w/crlf`, então falham igual. Isso corrige a hipótese da triagem: a causa não é
  a evolução dos scripts E06 e há dependência de bytes do checkout.

**Decisão do usuário (09/11): `eol=lf` para `.tres`.** O `.gitattributes` ganhou
`*.tres text eol=lf`. O oráculo não mudou. Os blobs no Git não mudam, e os 152 `.tres`
(todos em `resources/`) passam a ser `i/lf w/lf` no checkout. O jogo no Windows deixa
de carregar `\r` nas descrições, e o editor do Godot já grava `.tres` com LF.

O que lê esses bytes:

- O hash do catálogo de população, fixado nos pacotes de mapa publicados, usa só
  campos de mob (sem `description`) e não muda.
- O `asset_manifest.json` não lista `.tres`.
- Os checkpoints de expedição (`SnapshotRegistry`) guardam o digest dos `.tres`
  referenciados, mas também de todos os scripts. Uma expedição suspensa já não
  retoma depois de qualquer commit de código, então esta mudança se comporta como um
  commit comum. Ao trocar de branch, uma expedição suspensa num checkout antigo não
  retoma.
- Checkouts existentes (`codex/playtest`, `.tools/map-editor-m5`) só reescrevem esses
  arquivos em LF quando forem recriados (`git rm --cached` não é preciso; basta apagar
  os `.tres` e fazer `git checkout`, ou um checkout que os toque). Até lá continuam CRLF.

### Suíte completa com a regra

Rodada na worktree com os `.tres` em LF, pela receita da F2: `e07_f0_import_test` e
`e07_f1_import_test` sem fixture, e as demais 322 etapas com `-F1Fixture`, continuando
depois de cada falha.

- **318/322 PASS**, incluindo `e06_publication_test` 1162/0 no checkout normal.
- `e07_f1_native_import`: falha conhecida da base ("Cannot get class 'GitPlugin'"; aqui
  saiu com exit −1073741819).
- 4 falhas com uma única causa, anterior a esta mudança e também de fim de linha:
  `e08_pilot_ui_test` (`release_package_invalid`), `bounded_preparation_test`,
  `map_editor_asset_manifest_test` (`F9_ASSET_MISSING …terrain_material.gdshader`) e
  `e08_p5_world_republish_test`. O `asset_manifest.json` fixa o hash LF desse shader. Numa
  worktree nova no Windows ele vem CRLF; no checkout da E08 (onde a P7 rodou) ele já
  está LF. Com só esse arquivo refeito em LF e a fixture reconstruída, as 4 passam.

**Decisão do usuário (09/11): LF também para o shader.** A regra ficou restrita a
`scripts/map_authoring/terrain/terrain_material.gdshader`, e não a `*.gdshader`. Os
hashes fixados dos shaders são mistos:

| Shader | O que o fixa | Bytes fixados |
|---|---|---|
| `terrain_material` | `asset_manifest.json` e 10 pacotes `.rpp` da floresta | LF |
| `border_material` | `asset_manifest.json` e os 3 pacotes `sanctuary_woods*.rpp` publicados | CRLF |
| `water_material` | `asset_manifest.json` | CRLF |
| `action_cooldown`, `skill_locked_icon`, `pilot_ground` | nada | — |

Uma regra global faria `border_material` e `water_material` divergirem do manifesto e
dos pacotes imutáveis do Santuário, o que exigiria republicar conteúdo. A regra restrita
deixa cada shader com os bytes que seus pinos esperam num checkout Windows. Num
checkout LF (Linux) `border`/`water` continuam divergindo, como antes desta mudança.

Suíte completa com as duas regras: **322/322**. Na rodada contínua, 320 passaram
e o par F8 falhou só porque o perfil sintético da rodada anterior ficou na fixture
("prepare requires fresh synthetic profile", pré-condição já registrada na P7). Com
essa saída apagada, o par passou (16/0 e 61/0). `e07_f1_native_import` segue com a
falha conhecida do `GitPlugin`.

## Validação

Godot 4.7.2 standard (o `_console.exe` falha com erro 193 neste caminho com acento;
usei o executável principal), `APPDATA` isolado no scratchpad e import completo do
editor na worktree.

- `tools/verify.ps1 -SkipEditorImport -Test` com as 10 etapas (publicação fora, porque o
  runner para na primeira falha): **10/10 PASS** (68, 106, 152, 223, 230, 243, 244,
  250, 322, 323), sem `SCRIPT ERROR`/`Parse Error`/`ERROR`.
- `e06_publication_test` sozinho: 1162/34 no checkout CRLF e 1162/0 com os `.tres` em LF.

## Limitações

- A suíte completa (326 etapas) não foi rodada. Só arquivos de teste e a sonda F8
  mudaram, e nenhum é entrada de outra etapa.
- A sonda F8 rodou em modo headless e debug, não no template de release
  (`tools/e07_f8_validation.ps1`). As 4 mortes injetadas tomaram o caminho do diário,
  e o caminho de substituição não foi exercitado.
- Sem commit em `master`, sem push. Saves pessoais e `codex/playtest` não foram tocados.

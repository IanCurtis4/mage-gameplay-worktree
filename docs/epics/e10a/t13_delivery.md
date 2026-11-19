# T13 — recibo da integração contínua e do candidato E10a (C10)

**Candidato:** branch `claude/e10a-candidato`, no checkout
`C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.claude/worktrees/gallant-clarke-b01192`.
- **Base:** `0605a7b0c8e4c05b6c6ba2a0f85acf9a4a8baa11`, ponta de `claude/e10a-arquitetura-a413a1`
  na hora em que a T13 começou.
- **Estado:** composição contínua em andamento. Este recibo ganha uma seção por composição.
- **Aprovação técnica:** ainda não. Faltam a suíte completa, a exportação e a supervisão da T14.
- **Git:** sem push, nada em `master`; `codex/playtest` e o save pessoal não foram tocados.

Convenção desta máquina: o motor é
`.tools/godot/Godot_v4.7.2-stable_win64.exe` (SHA256 `AB1824F8…`, A7), passado em `-GodotPath`.

## Composição 1 — T1, T2 e T3 (18/11/2026)

### Merges

Todos com `--no-ff` e **sem nenhum conflito**, na ordem do DAG.

| Ordem | Tarefa | Ponta mesclada | Merge |
|---|---|---|---|
| 1 | T1 | `c8771d20` (código em `03a2bf51`) | `0103c502` |
| 2 | T2 | `a9d055f0` | `f086d87e` |
| 3 | T3 | `db11b181` | `674f35e3` |

Ponta do candidato depois dos merges: `674f35e3`. Este recibo e o estado do índice entraram em
`d3208b7e`, só de `docs/`.

A branch da arquitetura andou depois da base: `35df9cef` (decisão A8, uma linha em
`docs/epics/e10a.md`). Entrou em seguida por merge `--no-ff`, sem conflito: `d54dcf95`.
Não mexe em código; os testes acima valem para os dois commits.

### Importação e testes de impacto

**Importação (`editor_import`)** em worktree novo, `tools/verify.ps1 -Test editor_import`:
- **1ª rodada:** terminou com exit `-1073741819` (`0xC0000005`, violação de acesso) na saída,
  depois de importar tudo (saída `6A4CA8FC…D5E9`, `.godot/verification/t13_c1_import/`). A linha
  `Cannot get class 'GitPlugin'` é a conhecida do passo 255; o crash na saída aconteceu uma vez.
- **2ª rodada**, com os recursos já importados: exit 0, saída `6D57C91C…A9DB`
  (`t13_c1_import2/`). Não investiguei a causa do crash da 1ª rodada; só a registro.

**Bootstrap da fixture F1** (mesma ordem do E09): `e07_f0_import_test` (251) passou; o
`e07_f1_native_import` (255) falhou com a saída `AB79025F…831F`, o mesmo hash da falha conhecida
do E09 e da T1 (`Cannot get class 'GitPlugin'`); o `e07_f1_import_test` (256) passou.
(Rodei o 256 antes do 255 uma vez e ele falhou com `F1 full isolated import failed`; depois do
255 passou. A ordem 255 → 256 é obrigatória.) Logs em `.godot/verification/t13_c1_boot/`.

**Impacto**, um passo por chamada, `-F1Fixture -SkipEditorImport`, timeout 300 s. Sem execução
sem fixture: `e08_feedback_vfx_test` falha sem ela por `fixture sources match frozen inputs`
(pré-requisito, não defeito), e os demais foram rodados todos com ela.

| Passo | Teste | Checks | Exit | SHA256 da saída |
|---|---|---|---|---|
| 26 | `e08_feedback_recipe_test` | 1309, 0 falhas | 0 | `AA05DF9D…E54F` |
| 27 | `e08_feedback_vfx_test` | 653, 0 falhas | 0 | `F1449C55…2EA7` |
| 329 | `equipment_items_test` | 244, 0 falhas | 0 | `EB9A6284…A2CA` |
| 330 | `hybrid_bodies_test` | 6300, 0 falhas | 0 | `B9C7E703…3F69` |
| 333 | `kit_seam_test` | 276, 0 falhas | 0 | `60643509…6C81` |
| 334 | `ui_evolution_test` | 97, 0 falhas | 0 | `DF7B1619…69EF` (igual ao do E09) |
| 335 | `base_seam_test` | 171, 0 falhas | 0 | `83E3C22E…A9BEA` |
| 336 | `enemy_target_test` | 88, 0 falhas | 0 | `61C1F89F…FEC4` |

- **Resultado:** 8 de 8, 0 timeouts. Nenhum `SCRIPT ERROR`, `Parse Error`, `Compile Error`,
  `still in use` ou `ObjectDB instances` nas saídas (`grep` em `t13_c1_impact_f1/`).
- **Logs:** `.godot/verification/t13_c1_impact_f1/<teste>/` (fora do Git).
- **Corte:** o passo 255 já falhou antes, e a 148 (A7) não foi rodada nesta composição: só
  entra na suíte completa de fechamento.

**`python tools/prepare_skill_icons.py --check`**
- **Num checkout CRLF: falha.** O worktree herda `core.autocrlf=true`, que grava os 140 arquivos
  de `assets/art/skills/` (139 SVG e `manifest.json`) com CRLF, e o `--check` compara os bytes
  com o SHA256 do manifesto (`Missing or stale: …acolyte_devotion.svg`).
- **O defeito não é da T3.** O mesmo `--check` falha no worktree `e09-candidato` (CRLF, 117 SVG
  do E09: `arcane_blade_enchanted_edge.svg`) e passa no worktree da T3 (LF).
- **Com LF: passa.** Restaurei esses 140 arquivos com `git -c core.autocrlf=false checkout` (o
  índice sempre foi LF, o `git status` não muda): exit 0, `E09=28 E10a=22 total=50`,
  `139 icons; active=104; passive=35`. Saída `0FE815E0…DADD`
  (`.godot/verification/t13_c1_icons_check_lf.txt`; a falha CRLF está em
  `t13_c1_icons_check.txt`, `DF7EFDF2…9A46993`).
- **Consequência para o fechamento:** o `.gitattributes` só fixa LF em `skills/**` (a pasta da
  raiz), não em `assets/art/skills/`. A suíte completa e o `art_pipeline_tests` do passo 347 no
  candidato precisam desses arquivos em LF. Um `assets/art/skills/*.svg text eol=lf` (e o
  manifesto) fecharia o problema para qualquer checkout; é arquivo da T3/arquitetura, não da T13.

### Evidências ignoradas pelo Git, preservadas

As worktrees removidas guardavam evidência da T1 em `.godot/verification/`. Copiei as nove
pastas citadas no recibo da T1 para o candidato, em
`.godot/verification/e10a_t1_evidence/` (2591 arquivos, ~97 MB), com o manifesto de SHA256 por
arquivo em `.godot/verification/e10a_t1_evidence_manifest.sha256`
(SHA256 do manifesto `1840B3C4…471B`).

| Pasta | Arquivos | Observação |
|---|---|---|
| `t1_suite_03a2bf51` | 1750 | suíte completa da ponta; `summary.jsonl` = `4C5ABEC1…4AEF`, igual ao do recibo da T1 |
| `t1_suite_574264e7` | 470 | rodada interrompida (antes da correção do vazamento) |
| `t1_suite_f71f564c` | 159 | rodada interrompida |
| `step148_tip_03a2bf51`, `step148_tip_burst`, `step148_tip_f1import` | 101, 1, 4 | passo 148 na ponta |
| `step148_base_6938db71`, `step148_base_burst`, `step148_base_f1import` | 101, 1, 4 | passo 148 na base |

**T2:** o arquivo fora do Git, `.tools/art_archive/e08/` (8 pastas, incluídos `e08_codex_1116` e
`e08_codex_1118`), fica onde está, fora de qualquer worktree. O índice versionado
`docs/art/archive/e08_staging_1116_1118.json` tem SHA256 `62B52F9A…C1D5`.
**T3:** a prancha de revisão está versionada (`docs/epics/e10a/t3_icons_review.png`); nada
ignorado a preservar.

### Worktrees removidas

Antes de remover, conferi que o que sobrava no `git status` era só ruído:

| Worktree | O que sobrava | Remoção |
|---|---|---|
| `e10a-t1-ae3f9f` | 609 `.import` modificados, 1371 `.import` e 20 `.gd.uid` sem rastreio (importação e fim de linha; nenhum arquivo de fonte) | `git worktree remove --force`; o Git falhou com `Filename too long` e o resto saiu com `rm -rf` |
| `e10a-t2-c0791b` | só `__pycache__` ignorado | `git worktree remove --force` |
| `e10a-t3-4515a9` | 117 SVG marcados como modificados por fim de linha (`git diff --ignore-cr-at-eol` vazio) | `git worktree remove --force` |

- **Branches mantidas:** `claude/e10a-t1-ae3f9f` = `c8771d20`, `claude/e10a-t2-c0791b` = `a9d055f0`,
  `claude/e10a-t3-4515a9` = `db11b181` (pontas intactas).
- **Disco C:** de 23 GB para 30 GB livres (446 GB, 94% usados).
- **Registro Git:** `git worktree list` não mostra mais as três.

### Pendências desta composição

- As pastas `.claude/worktrees/e10a-t1-ae3f9f`, `e10a-t2-c0791b` e `e10a-t3-4515a9` ficaram
  **vazias**, mas o `rmdir` e o `rm -rf` responderam `Device or resource busy`: alguma sessão
  (as das próprias tarefas, ociosas) ainda as usa como diretório de trabalho. Sem custo de disco;
  somem quando essas sessões forem arquivadas.
- `.gitattributes` para os SVG de `assets/art/skills/` (acima).
- O `.godot/` de importação do candidato nasceu em CRLF e foi reimportado depois da restauração
  dos SVG em LF; o `.svg.import` é recalculado na próxima importação.
- 20 arquivos `.gd.uid` sem rastreio em `docs/map_editor/delivery/evidence/` (sondas antigas do F9
  e do F10) aparecem em qualquer importação limpa; não são da família e não foram versionados.

## Limitações

Esta composição valida só o impacto de T1–T3. A suíte completa, o passo 148, a exportação, as
sondas do PCK, os perfis, o roteiro e a medição são do fechamento (§11). O playtest habitual
(`codex/playtest`) não foi tocado.

## Composição 2 — T4 e ponta da arquitetura (18/11/2026)

### Merges

`--no-ff`, sem conflito de conteúdo (o merge da arquitetura combinou `docs/epics/e10a.md`
automaticamente).

| Ordem | Origem | Ponta mesclada | Merge |
|---|---|---|---|
| 1 | T4 (`claude/wizardly-hermann-10d51a`) | `e35525c7` (entrega principal `0f9820f1`) | `7903a8f3` |
| 2 | arquitetura (`claude/e10a-arquitetura-a413a1`, decisões A8 e A9) | `0c157d47` | `d927f8aa` |

A T4 parte da ponta da T1 e editou `scripts/actors/enemy_actor.gd` por exceção registrada (A8,
retenção de combate).

### Importação e testes de impacto

- **Importação** (`editor_import`, motor `Godot_v4.7.2-stable_win64.exe`): exit 0, saída
  `3B091DA3…1980` (`.godot/verification/t13_c2/import/`).
- **Bootstrap F1** refeito, porque a T4 acrescentou fontes: 255 com a falha conhecida (`AB79025F…831F`,
  `GitPlugin`) e 256 passou (`926B80A4…8A15`).
- **Impacto**, um passo por chamada, `-F1Fixture -SkipEditorImport`, timeout 300 s. 16 de 16, 0
  timeouts, nenhum `SCRIPT ERROR`, `Parse Error`, `Compile Error`, `still in use` ou `ObjectDB`
  nas saídas e nos logs do motor.

| Passo | Teste | Checks | Saída (8) |
|---|---|---|---|
| 338 | `madness_test` (T4) | 276, 0 falhas | `D4DAEAF5` |
| 335 | `base_seam_test` | 171, 0 falhas | `83E3C22E` (igual à composição 1) |
| 336 | `enemy_target_test` | 88, 0 falhas | `61C1F89F` (igual) |
| 333 | `kit_seam_test` | 276, 0 falhas | `60643509` (igual) |
| 331 | `kit_seam_hooks_v2_test` | 38, 0 falhas | `5182F32B` |
| 332 | `kit_seam_hooks_v3_test` | 63, 0 falhas | `D1DFD323` |
| 339 | `sanctuary_test` | 155, 0 falhas | `01B74920` |
| 337 | `flank_test` | 205, 0 falhas | `D23DC5D7` |
| 111 | `e05_training_boss_test` | PASS, 17 | `F0B3638A` |
| 206 | `e06_tx_mob_test` | 27, 0 falhas | `5D56F0CD` |
| 209 | `e06_rx_mob_ai_test` | 4, 0 falhas | `B9569774` |
| 228 | `e06_gameplay_ai_test` | 76, 0 falhas | `3E3923BE` |
| 268 | `e07_f6_threat_test` | 43, 0 falhas | `C38ACB2F` |
| 298 | `e07_f3_mob_state_test` | 372, 0 falhas, 4 cenários | `A84CACBF` |
| 270 | `e07_f6_snapshot_test` | 40, 0 falhas | `2E091952` |
| 294 | `e07_f3_snapshot_test` | 52, 0 falhas | `9FC703C4` |

O `madness_test` deu 276 checks; o recibo da T4 registra 275 na rodada da tabela e 276 depois do
reforço da A8, rodado direto. O número de agora é o da ponta mesclada. Logs em
`.godot/verification/t13_c2/impact/<teste>/` (fora do Git).

### Evidências ignoradas pelo Git, preservadas

`.godot/verification_t4` (43 arquivos) e `.godot/verification_t4b` (14) foram copiados para
`.godot/verification/e10a_t4_evidence/`, com manifesto de SHA256 por arquivo em
`.godot/verification/e10a_t4_evidence_manifest.sha256` (57 linhas, SHA256 do manifesto
`A118D331…`). Nada além disso a preservar: o `git status` da worktree tinha só `.import`
reescritos e `.gd.uid` de `docs/map_editor`, que não foram versionados (pedido da arquitetura).

### Worktree removida

`wizardly-hermann-10d51a` (branch `claude/wizardly-hermann-10d51a`, mantida em `e35525c7`):
`git worktree remove --force`, que cancelou o registro mas falhou com `Filename too long`; o resto
saiu com `rm -rf`. A pasta ficou **vazia** e ocupada (`Device or resource busy`, como as de T1 a T3: a
sessão da T4 a usa como diretório de trabalho). Disco: 31 GB livres (94% usados).

### Conta da A9 para o fechamento

A9 manda T6 e T7 atualizarem, cada uma no próprio ramo, as linhas de contagem de kits prontos em
`tests/e08_feedback_recipe_test.gd` e `tests/e10a/base_seam_test.gd`. Ao compor as duas a T13
confere a soma exata: **6 kits** com `priest` e `cultist` prontos. Ainda não há nada a somar;
esta conta é preenchida nas composições de T6 e T7.

## Composição 3 — T6 (Sacerdote) e ponta da arquitetura (18/11/2026)

### Merges

`--no-ff`, sem conflito de conteúdo (o `docs/epics/e10a.md` combinou sozinho).

| Ordem | Origem | Ponta mesclada | Merge |
|---|---|---|---|
| 1 | T6 (`claude/infallible-mirzakhani-b3eda2`) | `ce629e74` | `caa13976` |
| 2 | arquitetura (A10, A11, linha nova da T10) | `2aa10bf6` | `a63e66ae` |

A T6 tocou 12 arquivos (módulo e testes do Sacerdote, `review_builds.json`, o manifesto de
snapshot, o recibo) e, por A9 e A10, só estes checks de arquivos compartilhados:
`tests/e05_evolution_catalog_test.gd` (linha do Sacerdote em `KIT_METADATA` e o filtro de base
disponível em `_ready_kit_ids()`), `tests/e08_feedback_recipe_test.gd` e
`tests/e10a/base_seam_test.gd`.

### Importação e testes de impacto

- **Importação:** exit 0, saída `8F510058…CABDE` (`.godot/verification/t13_c3/import/`).
- **Bootstrap F1** refeito: 255 com a falha conhecida (`AB79025F…831F`); 256 passou
  (`825BC43F…0F84`).
- **Impacto**, um passo por chamada, `-F1Fixture -SkipEditorImport`, timeout 300 s: **24 de 24**,
  0 timeouts, 0 `SCRIPT ERROR`, `Parse Error`, `Compile Error`, `still in use` e `ObjectDB` nas
  saídas e nos logs. Com a fixture F1 em dia, `kit_seam_hooks_v3_test` e `e08_feedback_vfx_test`
  passam (na worktree da T6 falhavam por falta de `source_hashes.json`).

| Passo | Teste | Checks | Saída (8) |
|---|---|---|---|
| 346 | `priest_kit_test` (T6) | 220, 0 falhas | `942D0B90` |
| 345 | `priest_boss_combat_test` (T6) | 32, 0 falhas | `16BBBC37` |
| 339 | `sanctuary_test` | 155 | `01B74920` (igual à composição 2) |
| 333 | `kit_seam_test` | 276 | `60643509` (igual) |
| 331 | `kit_seam_hooks_v2_test` | 38 | `5182F32B` (igual) |
| 332 | `kit_seam_hooks_v3_test` | 63 | `D1DFD323` (igual) |
| 336 | `enemy_target_test` | 88 | `61C1F89F` (igual) |
| 335 | `base_seam_test` | 171 | `83E3C22E` (igual) |
| 338 | `madness_test` | 276 | `D4DAEAF5` (igual) |
| 108 | `e05_evolution_catalog_test` | PASS, 93 | `6B7F3B5B` (igual ao E09 e ao recibo da T6) |
| 26 | `e08_feedback_recipe_test` | PASS, 1309 | `AA05DF9D` (igual) |
| 27 | `e08_feedback_vfx_test` | 667, 0 falhas | `C1554DC5` (eram 653; o Sacerdote soma 14) |
| 334 | `ui_evolution_test` | 97 | `DF7B1619` (igual) |
| 337 | `flank_test` | 205 | `D23DC5D7` (igual) |
| 341 / 340 | `mg_ac_kit_test` / `mg_ac_boss_combat_test` | 177 / 29 | `814D744C` / `66AC49C6` |
| 343 / 342 / 344 | `mg_la_kit_test` / `mg_la_boss_combat_test` / `mg_la_world_leap_test` | 231 / 33 / 49 | `B480859D` / `6710C89E` / `F2E59EE4` |
| 348 / 347 | `sp_ac_kit_test` / `sp_ac_boss_combat_test` | 170 / 25 | `2229F2DC` / `26957117` |
| 350 / 349 / 351 | `sp_la_kit_test` / `sp_la_boss_combat_test` / `sp_la_parry_ai_test` | 217 / 31 / 55 | `D2DC91B2` / `4F9C0F3F` / `4F0C254B` |

Logs em `.godot/verification/t13_c3/impact/<teste>/` (fora do Git).

### Evidências ignoradas pelo Git, preservadas

Em `.godot/verification/e10a_t6_evidence/`, com manifesto de SHA256 por arquivo em
`.godot/verification/e10a_t6_evidence_manifest.sha256` (66 linhas, SHA256 `CE141DDA…E16B`):
`t6_final.txt`, `t6_final2.txt` (a rodada final de 23 testes que o recibo da T6 cita;
`86989078…`), `t6_impact3.txt` e a pasta `verification/` (63 arquivos) da worktree. A pasta
`.godot/f1_visual_fixture` estava vazia. O `git status` da worktree só tinha `.import`
reescritos e `.gd.uid` de `docs/map_editor`, que não foram versionados.

### Worktree removida

`infallible-mirzakhani-b3eda2` (branch `claude/infallible-mirzakhani-b3eda2`, mantida em
`ce629e74`) removida por `git worktree remove --force` e, onde sobrou resíduo, `rm -rf`. O `git worktree remove` falhou com `Permission denied`, mas a worktree saiu do registro (`git worktree list` sem ela)
e a pasta ficou vazia e ocupada (`Device or resource busy`, a sessão da T6 a usa como diretório). Disco: 32 GB livres (93% usados).

### Conta das contagens (A9 e A10) até aqui

A T7 ainda não entregou, então a soma final não existe. O que o candidato tem agora:

| Contagem | Valor no candidato | Onde |
|---|---|---|
| Kits prontos no catálogo de produção | **5** (os 4 do E09 + `priest`) | `tests/e08_feedback_recipe_test.gd` |
| Skills de kit ofertadas pelo catálogo | **20 ativas, 8 passivas**, sem mudança: o filtro de base disponível (A10.2) exclui o Sacerdote enquanto o Acólito for esqueleto | idem |
| Esqueletos que seguem vazios | `cultist` | `tests/e10a/base_seam_test.gd` |
| `priest` | pronto, 7 skills | idem |

**Soma esperada ao compor a T7:** 6 kits prontos (4 do E09, `priest` e `cultist`), com o `cultist` com as
suas skills e `base_seam_test` sem esqueletos de pura. O filtro de `_ready_kit_ids()` é uma linha idêntica
em T6 e T7 (A10.4); por isso um conflito nessa linha, se vier, é mecânico e se resolve ficando com a linha
única. As linhas de contagem de `tests/e08_feedback_recipe_test.gd` e de `tests/e10a/base_seam_test.gd`
vão conflitar entre T6 e T7: a regra é escrever o número exato da soma (5 + 1 = 6), nunca `>=`, e registrar
a conta aqui. As contagens de skills publicadas (20/8) só mudam quando a T5 liga o Acólito (A10.3, A11).

## Composição 4 — T7 (Cultista) e ponta da arquitetura (18/11/2026)

### Merges e conflitos

| Ordem | Origem | Ponta mesclada | Merge |
|---|---|---|---|
| 1 | T7 (`claude/laughing-mclean-ff1bbd`, sobre a T4) | `de11f99d` | `d78501a5` |
| 2 | arquitetura (decisão A12: T9 antes da T8) | `f5940eb7` | `8a59a084` |

O merge da T7 teve **três conflitos de conteúdo, todos previstos por A9 e A10**, nos checks de
contagem dos três arquivos compartilhados. Resolvidos por mim com a soma exata, sem enfraquecer check:

| Arquivo | T6 (HEAD) | T7 | Resolução |
|---|---|---|---|
| `tests/e08_feedback_recipe_test.gd` | kits prontos `== 5` (4 + `priest`) | `== 5` (4 + `cultist`) | **`== 6`** (4 do E09 + `priest` + `cultist`). As contagens de skills publicadas ficam **20 ativas e 8 passivas**: o Acólito ainda é esqueleto e o filtro de base disponível (A10.2, idêntico nos dois lados) exclui as puras do catálogo |
| `tests/e10a/base_seam_test.gd` | `priest` pronto, 7 skills; `cultist` esqueleto | `cultist` pronto, 7 skills; `priest` esqueleto | os dois prontos com 7 skills (ramo `if`/`elif`); o resto continua esqueleto vazio |
| `tests/e05_evolution_catalog_test.gd` | linha `priest` no `KIT_METADATA` | linha `cultist` | as duas linhas (`2-1` e `2-2`). O filtro de `_ready_kit_ids()` ficou duplicado depois do merge (T6 dentro do `if`, T7 no começo do laço) e eu fiquei com **uma só linha, dentro do `if`** (A10.4); o resultado é o mesmo |

**Conta final de A9 e A10 nesta composição:** 4 + 1 + 1 = **6 kits prontos**; skills publicadas
**20/8**, sem mudança. Elas mudam quando a T5 ligar o Acólito (A10.3 e A11): a T5 atualiza o
número exato e a T13 repete esta conta. O `ui_evolution_test` e a lista de destinos continuam como
estão, sem edição, e passam.

### Importação e testes de impacto

- **Importação:** exit 0, saída `BA6F88E5…6277D` (`.godot/verification/t13_c4/import/`).
- **Bootstrap F1:** 255 com a falha conhecida (`AB79025F…831F`); 256 passou (`9503A8E6…C1BF`).
- **Impacto:** **27 de 27**, um passo por chamada, `-F1Fixture -SkipEditorImport`, timeout 300 s,
  0 timeouts e nenhum `SCRIPT ERROR`, `Parse Error`, `Compile Error`, `still in use` ou `ObjectDB`.

| Passo | Teste | Checks | Saída (8) |
|---|---|---|---|
| 342 | `cultist_kit_test` (T7) | 215, 0 falhas | `215686C4` |
| 340 | `cultist_boss_combat_test` (T7) | 50, 0 falhas | `4DFDDBDF` |
| 341 | `cultist_campaign_kill_test` (T7) | 20, 0 falhas | `212B00D3` |
| 349 / 348 | `priest_kit_test` / `priest_boss_combat_test` | 220 / 32 | `942D0B90` / `16BBBC37` (iguais) |
| 338, 339, 335, 336 | `madness_test`, `sanctuary_test`, `base_seam_test`, `enemy_target_test` | 276, 155, 171, 88 | `D4DAEAF5`, `01B74920`, `83E3C22E`, `61C1F89F` (iguais) |
| 333, 331, 332 | `kit_seam_test`, `kit_seam_hooks_v2_test`, `kit_seam_hooks_v3_test` | 276, 38, 63 | `60643509`, `5182F32B`, `D1DFD323` (iguais) |
| 108 | `e05_evolution_catalog_test` | PASS, 93 | `6B7F3B5B` (igual) |
| 26 | `e08_feedback_recipe_test` | PASS, 1309 | `AA05DF9D` (igual) |
| 27 | `e08_feedback_vfx_test` | **681**, 0 falhas | `00676B42` (eram 667; o Cultista soma 14) |
| 334, 337 | `ui_evolution_test`, `flank_test` | 97, 205 | `DF7B1619`, `D23DC5D7` (iguais) |
| 344 / 343 | `mg_ac_kit_test` / `mg_ac_boss_combat_test` | 177 / 29 | `814D744C` / `66AC49C6` |
| 346 / 345 / 347 | `mg_la_kit_test` / `mg_la_boss_combat_test` / `mg_la_world_leap_test` | 231 / 33 / 49 | `B480859D` / `6710C89E` / `F2E59EE4` |
| 351 / 350 | `sp_ac_kit_test` / `sp_ac_boss_combat_test` | 170 / 25 | `2229F2DC` / `26957117` |
| 353 / 352 / 354 | `sp_la_kit_test` / `sp_la_boss_combat_test` / `sp_la_parry_ai_test` | 217 / 31 / 55 | `D2DC91B2` / `4F9C0F3F` / `4F0C254B` |

Logs em `.godot/verification/t13_c4/impact/<teste>/` (fora do Git).

**A repetir na composição da T5:** `cultist_boss_combat_test` (e `cultist_campaign_kill_test`), porque
com a base real do Acólito ele passa a usar a base sem edição (pedido da arquitetura).

### Evidências ignoradas pelo Git, preservadas

As 14 pastas `.godot/verification_t7*` (`_t7`, `_t7_a`, `_t7_campaign`, `_t7_cultist_*` ×3, `_t7_f1b/c/d`,
`_t7_import1/2/3`, `_t7b`, `_t7c`) foram para `.godot/verification/e10a_t7_evidence/`, com manifesto de
SHA256 por arquivo em `.godot/verification/e10a_t7_evidence_manifest.sha256` (108 linhas,
`42E094E0…`). A `_t7c` é a leva final de 23 passos que o recibo da T7 cita. **Não copiei**
`.godot/verification/` da worktree (1,1 GB, 6351 arquivos): é a fixture F1 gerada (`e07_f1`, `e07_f2`,
`e07_f5`) que o recibo da T7 não cita e que `e07_f1_import_test` refaz no candidato.
O `git status` da worktree tinha só `.import` reescritos e `.gd.uid` de `docs/map_editor`.

### Worktree removida

`laughing-mclean-ff1bbd` (branch `claude/laughing-mclean-ff1bbd` mantida em `de11f99d`):
`git worktree remove --force` e, onde sobrou resíduo, `rm -rf`. O registro Git foi cancelado (`git worktree list` sem ela); a pasta ficou vazia e ocupada (`Device or resource busy`, sessão da T7). Disco: 33 GB livres (93% usados).

## Composição 5 — T5 (base Acólito) (18/11/2026)

### Merge e conflito

| Origem | Base da T5 | Ponta mesclada | Merge |
|---|---|---|---|
| T5 (`claude/upbeat-chaum-bbbb8f`) | `0f7d22ea` (tem a T6, não tem a T7) | `50fb61bd` | `58c0ea90` |

A ponta da arquitetura (`f5940eb7`) já estava no candidato, nada a mesclar dela. O merge teve **um
conflito**, no `tests/e08_feedback_recipe_test.gd`. As mudanças da T5 em `tests/e10a/base_seam_test.gd`
e `tests/e09/kit_seam_test.gd` entraram sem conflito, mas ficaram desatualizadas porque a T7 liga o
Cultista (ver "Ajustes depois do merge").

**Resolução do conflito: 36 ativas e 14 passivas.** A conta foi feita pelos módulos e confirmada pelo
próprio teste, que lê o catálogo de produção (`kit_active.size()` e `library.kit_passive.size()`) e
passou nesse check:

| Fonte | Ativas | Passivas |
|---|---|---|
| quatro kits do E09 | 20 | 8 |
| base Acólito (T5) | 6 | 2 |
| Sacerdote (T6) | 5 | 2 |
| Cultista (T7) | 5 | 2 |
| **Total** | **36** | **14** |

Kits prontos no registro: **6** (sem mudança; a base não é kit). A T5 escreveu 31/12 sem o Cultista e a
T7 escreveu 20/8 sem a base; nenhuma das duas via a soma.

### Ajustes depois do merge (`15f4c131`)

Com a base ligada pela T5 e o Cultista pronto pela T7, o catálogo oferece os dois kits puros. A T5 só
via o Sacerdote. Dois testes da própria regra A11 ficaram com número velho; ajustei só esses checks, com
o número exato e sem enfraquecê-los:

| Arquivo | Antes (T5) | Agora |
|---|---|---|
| `tests/e10a/base_seam_test.gd` | o Acólito oferece `[priest]` | `[priest, cultist]`, ordem do registro |
| `tests/e09/kit_seam_test.gd` | 13 / 15 / 17 definições | **14 / 16 / 18** (12 + 0/2/4 híbridas + Sacerdote + Cultista) |

### Importação e testes de impacto

- **Importação:** exit 0, saída `8F510058…CABDE`. **Bootstrap F1:** 255 com a falha conhecida
  (`GitPlugin`, hash `AB79025F…831F`); 256 passou (`9ECB98E8…44A4`).
- **Lote:** os 40 do recibo da T5 mais `cultist_kit_test`, `cultist_boss_combat_test` e
  `cultist_campaign_kill_test` (43), um passo por chamada, `-F1Fixture`, timeout 300 s, 0 timeouts,
  nenhum `SCRIPT ERROR`, `Parse Error`, `Compile Error`, `still in use` ou `ObjectDB`.
- **40 passaram, 3 falharam** na rodada do merge: `base_seam_test` (1), `kit_seam_test` (3) e
  `e08_feedback_recipe_test` (4). Os dois primeiros eram as contagens acima e passam depois de
  `15f4c131`; para isso refiz o bootstrap F1 (as fontes de teste mudaram). Nessa repetição o passo 255 deu
  outro hash, `1032E084…F186`, com a mesma falha `GitPlugin`: só aparece a linha de progresso
  `update_scripts_classes (2 steps)`, porque o cache de classes foi refeito.

| Passo | Teste | Resultado | Saída (8) |
|---|---|---|---|
| 340 | `acolyte_base_test` | 306, 0 falhas | `E633901A` |
| 341 | `acolyte_boss_combat_test` | 275, 0 falhas | `0FDD35B1` |
| 335 | `base_seam_test` | 172, 0 falhas (depois de `15f4c131`) | `F78A568B` |
| 333 | `kit_seam_test` | 276, 0 falhas (depois de `15f4c131`) | `60643509` |
| 108 | `e05_evolution_catalog_test` | PASS, 99 (espera Sacerdote e Cultista) | `90F3F112` |
| 334 | `ui_evolution_test` | 97 | `DF7B1619` (igual) |
| 342 | `cultist_boss_combat_test` | 49, 0 falhas (50 na composição 4, sobre a base de fixture) | `88E65883` |
| 344 / 343 | `cultist_kit_test` / `cultist_campaign_kill_test` | 215 / 20 | `215686C4` / `212B00D3` (iguais) |
| 27 | `e08_feedback_vfx_test` | 697, 0 falhas (eram 681) | `BF9FE3B0` |
| — | os demais do lote (`enemy_target`, `madness`, `kit_seam_hooks_v2/v3`, `sanctuary`, `priest_*`, os oito de kit e chefe do E09, `equipment_items`, `e05_identity_boundary`, os `e06_*`, `skill_allocation`, `persistent_state`, `stat_threshold_rules`, `e07_f5_death_kits`, `e02_character_menu`, `e05_evolution_menu_integration`, `profile_facade`, `menu_tabs`) | todos passam | hashes em `t13_c5/impact/*` |

Logs em `.godot/verification/t13_c5/` (`impact/` da rodada do merge, `fix/` da repetição).

### FALHA ABERTA — `e08_feedback_recipe_test` (4 falhas, 1425 checks)

Com a base ligada, o catálogo passa a publicar as skills do Cultista e o teste caminha por elas. Os
quatro checks `planned cue first for …` falham, com a cadeia de áudio da skill/evento sem cue planejada:

| Skill/evento | Cadeia atual |
|---|---|
| `cultist_abyss_gaze/impact` | `[world.impact]` |
| `cultist_impossible_idol/summon` | `[]` |
| `cultist_impossible_geometry/trap_trigger` | `[world.area_end]` |
| `cultist_revelation/impact` | `[world.impact]` |

- **Causa:** o mesmo caso que a lista `KIT_AUDIO_GAPS` registra para `acolyte_shadow_seal/impact` (T5) e
  `priest_sanctuary/impact` (T6). A T7 não podia ver: com a base esqueleto o Cultista não entra no
  catálogo, e o teste dela passava (composição 4).
- **Não editei a expectativa.** Registrar as quatro chaves na lista, ou dar cue planejada às quatro,
  é decisão de áudio da arquitetura e, se for a correção, volta à T7 (Sol). O restante do teste (1421
  checks, incluindo as contagens 6 kits e 36/14) passa. **Candidato vermelho nesse teste até a decisão.**
  O hash de saída do teste é `9EC405A5…`.

### Evidências ignoradas pelo Git, preservadas

`.godot/t5_evidence/` (41 arquivos, a pasta `final/` com as 40 saídas) foi para
`.godot/verification/e10a_t5_evidence/`, com manifesto de SHA256 por arquivo em
`.godot/verification/e10a_t5_evidence_manifest.sha256` (41 linhas, SHA256 `0588E1E3…`). A worktree
tinha só `.import` reescritos (os `.gd.uid` sem rastreio eram os de `docs/map_editor`). Não copiei
`.godot/verification` (1,1 GB, a fixture F1 regenerável).

### Worktree removida

`upbeat-chaum-bbbb8f` (branch `claude/upbeat-chaum-bbbb8f`, mantida em `50fb61bd`). Saiu do registro do
Git; a pasta ficou vazia e ocupada (`Device or resource busy`, sessão da T5). Disco: 32 GB livres.

### Quando rodar a primeira suíte completa

A família está inteira no candidato, mas **ainda não é a hora**: T9 (itens), T8 (corpos), T10 (UI e
perfis), T11 (augments) e T12 (HUD) ainda mexem em catálogo de itens, no menu de criação, em recursos de
augment e no `kit_hud_state`. A suíte leva ~150 min de CPU exclusiva do candidato, e qualquer merge
durante ela invalida a rodada. Pela norma de revalidação (WORKFLOW) a evidência não é reaproveitável
depois dessas tarefas. Vale uma rodada única no fechamento, depois da T11 (e da T12, se o E12 estiver em
`master`). O passo 148 e o 255 seguem a A7 nessa rodada. Se a arquitetura preferir um alarme antecipado
dos passos fora do impacto, dá para rodar já só os testes que citam base, identidade ou catálogo de
criação (o lote da T5 já cobre isso por `grep`).

## Composição 6 — correção de áudio do Cultista (A14) (18/11/2026)

**O candidato voltou ao verde.** A falha aberta na composição 5 (`e08_feedback_recipe_test`, 4 checks
`planned cue first` do Cultista) está corrigida.

### Merge

| Ordem | Origem | Ponta | Resultado |
|---|---|---|---|
| 1 | T7 (`claude/laughing-mclean-ff1bbd`), com a correção `0b67670b` | `4126ad86` | fast-forward do candidato `1f8ee4f5`, porque a branch da T7 já mesclava o candidato nessa ponta. Não há commit de merge novo; a T7 entrou no candidato antes em `d78501a5` |
| 2 | arquitetura (decisões A13 e A14) | `67383625` | merge `14ab6a29`, sem conflito |

A correção muda só `scripts/classes/cultist/cultist_kit.gd` (`feedback_recipes`, 11 linhas) e o recibo
da T7. O catálogo de áudio, o catálogo de receitas, `KIT_AUDIO_GAPS` e os `.wav` ficaram intactos (A14:
as quatro chaves reusam arquivos existentes).

### Testes (12 de 12)

Importação exit 0 (`6D57C91C…A9DB`); bootstrap F1: 255 com a falha conhecida (`AB79025F…831F`), 256
passou (`558A298C…EDE1`). Um passo por chamada, `-F1Fixture -SkipEditorImport`, timeout 300 s,
0 timeouts, nenhum `SCRIPT ERROR`, `Parse Error`, `Compile Error`, `still in use` ou `ObjectDB`.

| Passo | Teste | Resultado | Saída (8) |
|---|---|---|---|
| 26 | `e08_feedback_recipe_test` | **PASS, 1433 checks, 0 falhas** (era FAIL, 4 de 1425) | `1601B34D` |
| 27 | `e08_feedback_vfx_test` | 697, 0 falhas | `BF9FE3B0` (igual à composição 5) |
| 25 | `e08_vfx_art_test` | 1238, 0 falhas | `100CB3FA` |
| 344 | `cultist_kit_test` | 215 | `215686C4` (igual) |
| 342 | `cultist_boss_combat_test` | 49 | `88E65883` (igual) |
| 343 | `cultist_campaign_kill_test` | 20 | `212B00D3` (igual) |
| 333 | `kit_seam_test` | 276 | `60643509` (igual) |
| 331 / 332 | `kit_seam_hooks_v2_test` / `v3_test` | 38 / 63 | `5182F32B` / `D1DFD323` (iguais) |
| 335 | `base_seam_test` | 172 | `F78A568B` (igual) |
| 108 | `e05_evolution_catalog_test` | PASS, 99 | `90F3F112` (igual) |
| 338 | `madness_test` | 276 | `D4DAEAF5` (igual) |

Logs em `.godot/verification/t13_c6/` (fora do Git). Com a contagem da recipe subindo de 1425 para
1433 checks, o teste agora percorre as quatro chaves com cue planejado.

### Evidências ignoradas pelo Git e worktree

As duas pastas novas da T7, `.godot/verification_t7d1` (4 arquivos) e `verification_t7d2` (26), foram
para `.godot/verification/e10a_t7_evidence/`; o manifesto de SHA256 foi refeito
(138 linhas, `3B183327…`). A worktree reaberta da T7 só tinha `.import` e a fixture F1 regenerável
(não copiada). Removida de novo; a branch `claude/laughing-mclean-ff1bbd` fica em `4126ad86`. Saiu do registro do Git; a pasta ficou vazia e ocupada (`Device or resource busy`). Disco: 32 GB livres.

## Composição 7 — T9 (itens da família) (18/11/2026)

### Merge

| Origem | Base da T9 | Ponta mesclada | Merge |
|---|---|---|---|
| T9 (`claude/musing-austin-58a118`) | `58c0ea90` | `6b7e3df8` | `5f702caa` |

`--no-ff`, **sem conflito**, sobre o candidato `bbcf3b74`. 38 arquivos: os três itens (`e10a_*.tres`), a arte e
os ícones, `hand_rigs.json`, `equipment_loot_profiles.gd`, `equipment_art_catalog.gd`,
`equipment_attachment_visual.gd` (só `SUPPORTED` e `PROFILES`), as armaduras de tecido do Mago, o teste novo
`tests/e10a/equipment_items_test.gd` e as enumerações legadas de 89 → 92 equipamentos. Pela A13, a T9 trocou uma
linha de `scripts/core/build_effect_catalog.gd` (`_restrictions_valid` passa a usar
`IdentityIds.is_base_class`), para o catálogo aceitar `acolyte` como origem.

### O `base_seam_test:124` que a T9 relatou falhando

A T9 mediu sobre `58c0ea90`, que não tinha o meu ajuste. O `15f4c131` (composição 5) já fez a soma exata da
A11: o Acólito oferece `[priest, cultist]`. Depois deste merge o `base_seam_test` segue **verde**
(172 checks, `F78A568B`, igual às composições 5 e 6). Nada a fazer.

### Importação e testes de impacto

- **Importação:** exit 0 (`B2104F6B…9C7`). **Bootstrap F1:** 255 com a falha conhecida (`AB79025F…831F`),
  256 passou (`0013A6F1…7CC8`).
- **32 passos (31 nomes; `equipment_items_test` tem dois, o do E09 e o do E10a), todos verdes**, um passo por
  chamada, `-F1Fixture -SkipEditorImport`, timeout 300 s, 0 timeouts, nenhum `SCRIPT ERROR`, `Parse Error`,
  `Compile Error`, `still in use` ou `ObjectDB`.
- **`e07_f1_composition_test` passa** (299 checks, 27 receitas, `1C86C151`): era o que a T9 não pôde rodar, porque
  exige a fixture F1 e ela editou arquivos. No candidato, com o bootstrap refeito, roda.

| Passo | Teste | Resultado | Saída (8) |
|---|---|---|---|
| 329 | `equipment_items_test` (E09) | 244, 0 falhas | `EB9A6284` (igual) |
| 337 | `equipment_items_test` (E10a) | **301**, 0 falhas | `97A9EEBE` |
| 20 | `e08_equipment_art_test` | 83559, 0 falhas | `1D5901A8` |
| 19 | `e08_directional_units_test` | 77804, 0 falhas | `F42ED54C` |
| 18 / 21 | `e08_directional_content_test` / `e08_directional_rig_compatibility_test` | 6324 / 83328, 0 falhas | `D0CF826C` / `32793134` |
| 239 | `equipment_hand_alignment_test` | 4593, 0 falhas | `38A87BF0` |
| 236 / 250 / 227 | `e06_expanded_equipment_content_test` / `e06_export_content_test` / `e06_gameplay_content_test` | 2707 / 174 / 232 | `D170193A` / `A8D0F599` / `4472C31B` |
| 5 / 223 | `e06_migration_test` / `e06_ui_menu_test` | 150 / 120 | `7003DA6B` / `CAE15161` |
| 226 / 224 / 221 / 213 / 235 | `e06_production_loot_test`, `e06_power_progression_test`, `e06_publication_test`, `e06_content_pilot_test`, `e06_fixes_performance_cache_test` | 54 / 2439 / 1162 / 481 / 0 falhas | `7FC0CB19`, `2CBF2463`, `787D3A35`, `7BD005C8`, `B1056F0B` |
| — | os 11 testes de restrição (A13): `e06_content_authoring` 60, `e06_effects_composition` 70, `e06_effects_runtime` 53, `e06_inventory_persistence` 14, `e06_review_boundaries` 7, `e06_review_identity` 4, `e06_review_persistence_edges` 15, `e06_tx_composition` 60, `e06_tx_inventory` 24, `e06_tx_loot` 49, `e06_rewards` 51 | 0 falhas, números iguais aos do recibo da T9 | hashes em `t13_c7/impact/*` |
| 321 | `e07_f1_composition_test` | 299, 0 falhas | `1C86C151` |
| 335 / 108 / 26 | `base_seam_test` / `e05_evolution_catalog_test` / `e08_feedback_recipe_test` | 172 / PASS 99 / PASS 1433 | `F78A568B` / `90F3F112` / `1601B34D` (iguais) |

Logs em `.godot/verification/t13_c7/` (fora do Git).

### Evidências ignoradas pelo Git e worktree

A worktree da T9 não tinha pasta de evidência nomeada. Copiei os 66 arquivos soltos de
`.godot/verification/` (logs e `checks.jsonl` das rodadas dela) para
`.godot/verification/e10a_t9_evidence/`, com manifesto de SHA256 (`C3B5CFBD…`, 66 linhas). As subpastas
(`e06_*`, `e07_f1`, `e07_f2`, `e08_art_units`, 1,1 GB) são fixtures geradas e regenerável, e não foram copiadas.
A worktree só tinha `.import` reescritos. Removida; a branch `claude/musing-austin-58a118` fica em `6b7e3df8`. Registro e pasta saíram por inteiro (desta vez sem resíduo). Disco: 29 GB livres (94% usados; outras sessões também consomem).

## Composição 8 — T11 (augments), T10 (criação e UI) e T8 (corpos) (18/11/2026)

### Merges

| Ordem | Origem | Base da tarefa | Ponta mesclada | Merge |
|---|---|---|---|---|
| 1 | T11 (`claude/youthful-robinson-db714a`) | `5f702caa` | `dc99e9c1` | `3d019911` |
| 2 | T10 (`claude/admiring-proskuriakova-de00f1`) | `b0583e16` | `709f0a6b` | `a71d2713` |
| 3 | T8 (`claude/cool-northcutt-0a2f7d`) | `5f702caa` | `74317a9b` | `76b02ce7` |

`--no-ff`, **sem conflito nos três**, sobre `b0583e16`. A ponta de arquitetura (`67383625`) já estava no
candidato. Seis augments novas (T11); menu de criação com o Acólito, onboarding dos três e
`tools/e10a_review_profiles.gd` (T10); três corpos, calibração e `equipment_head_fit_data.gd` (T8).

**Contagens exatas conferidas (A9):** 37 augments, tanto em `e06_publication_test` (1162 checks) quanto em
`augments_test` (180); 4 botões de criação em `e02_character_menu_test` (26 checks); head-fit de 17 classes
e 14 peças em `e08_equipment_art_test` (de 83559 para 100863 checks, por causa das três classes novas);
grip do `prayer_book` em (10,12) nos espelhos da T9: `equipment_items_test` E10a 301 checks (a T8 trocou só
o grip esperado, número exato).

### Importação e testes de impacto

- **Importação:** exit 0 (`377F3374…FDC2`). **Bootstrap F1:** 255 com a falha conhecida (`AB79025F…831F`),
  256 passou (`0095C54D…1D2`), refeito depois do último merge, como pedido.
- **Lote de 25 passos (24 nomes; `equipment_items_test` tem dois):** um passo por chamada, `-F1Fixture
  -SkipEditorImport`, timeout 300 s, 0 timeouts. Logs em `.godot/verification/t13_c8/` (fora do Git).
  **23 verdes, 2 vermelhos** (abaixo). Os vermelhos têm a mesma causa: as augments da T11.

| Passo | Teste | Resultado | Saída (8) |
|---|---|---|---|
| 335 | `augments_test` | 180, 0 falhas | `D2E49FD9` |
| 221 | `e06_publication_test` | 1162, 0 falhas | `787D3A35` (igual) |
| 213 / 214 | `e06_content_pilot_test` / `e06_content_pilot_runtime_test` | 481 / 252 | `7BD005C8` / `4C7EF8B6` |
| 340 | `ui_family_test` | 86, 0 falhas | `9D58F18C` |
| 334 | `ui_evolution_test` | **2 falhas de 90** | `A4F195A5` |
| 39 | `e02_character_menu_test` | PASS, 26 | `92E83227` |
| 110 / 108 | `e05_evolution_menu_integration_test` / `e05_evolution_catalog_test` | PASS 25 / PASS 99 | `4971C5F9` / `90F3F112` (igual) |
| 333 / 336 | `kit_seam_test` / `base_seam_test` | 276 / 172 | `60643509` / `F78A568B` (iguais) |
| 339 / 330 | `family_bodies_test` / `hybrid_bodies_test` | 6313 / 6300 | `C5B17150` / `B9C7E703` |
| 329 / 338 | `equipment_items_test` (E09 / E10a) | 244 / 301 | `EB9A6284` / `97A9EEBE` (iguais) |
| 239 | `equipment_hand_alignment_test` | 4593 | `38A87BF0` (igual) |
| 20 | `e08_equipment_art_test` | 100863, 0 falhas | `5F377D76` |
| 19 / 21 / 18 | `e08_directional_units_test` / `rig_compatibility` / `content` | 7684 / 83328 / 6324 | `F42ED54C` / `32793134` / `D0CF826C` (iguais) |
| 26 | `e08_feedback_recipe_test` | PASS, 1433 | `1601B34D` (igual) |
| 344 / 355 / 348 | `acolyte_base_test` / `priest_kit_test` / `cultist_kit_test` | 306 / 220 / 215 | `E633901A` / `942D0B90` / `215686C4` |
| 321 | `e07_f1_composition_test` | **4 falhas de 341** | `A859E109` |

Nenhum `SCRIPT ERROR`, `Parse Error`, `Compile Error`, `still in use` ou `ObjectDB` nos 23 verdes. Durante o
lote rodei o `ui_evolution_test` por fora (para reproduzir), em paralelo com o passo do `equipment_items_test`;
o resultado dele não mudou em relação à composição 7 (mesmos hashes), e nenhum outro passo coincidiu.

### FALHAS ABERTAS (as duas vêm das augments da T11; não editei nenhum teste)

**1. `ui_evolution_test` (E09, 2 falhas, 90 checks; no candidato antes da T11 passava com 97).** O teste
instala kits de fixture (esqueleto) no registro. Com isso, `facade.build_preview` do espadachim devolve
`unknown_skill_target`, e o painel de evolução mostra "Não foi possível consultar a evolução" (zero opções),
então caem a opção `defender, berserker` e a de híbridas, mais um `SCRIPT ERROR` de nó nulo no check seguinte.
**Causa conferida:** três augments da T11 têm `target_skill_ids` em skills dos kits Sacerdote e Cultista
(`pilot_priest_b`, `pilot_cultist_a`, `pilot_cultist_b`). Com o registro em esqueleto essas skills somem do
catálogo, e `BuildEffectCatalog.validate_effect` (`build_effect_catalog.gd:146`) rejeita a augment. Prova:
retirei só essas três por um instante e o teste voltou a **97 checks, 0 falhas**; restaurei com
`git checkout` (árvore limpa). A T10 passou o teste sozinha (97) porque a T11 ainda não estava no candidato.

**2. `e07_f1_composition_test` (4 falhas, 341 checks, `recipes=31`).** O teste percorre toda receita de produção
não-stat e exige exatamente 27 (`check(evidence.size() == 27, …)`, linha 33). As augments da T11 somam 4
receitas não-stat (31) e duas delas falham os checks de PROC espacial (`causal parent contact…` e
`real catalog PROC is one claimed same-target secondary…`, `_proc_case`, linhas 104–105). A contagem 27 → 31 é
conta exata. Os dois checks de PROC pedem `_setup` do teste para as skills do Sacerdote/Cultista.

Ambos tocam o arquivo e as expectativas de outros donos (E09/E07), portanto voltam à arquitetura para decidir
com a T11. **O candidato fica vermelho nesses dois testes até lá.** Todo o resto do impacto passa, incluindo
os de corpo, item, UI de criação e `e02_character_menu_test`.

### Evidências ignoradas pelo Git, preservadas

| Tarefa | Pasta no candidato | Arquivos | Manifesto SHA256 |
|---|---|---|---|
| T11 | `.godot/verification/e10a_t11_evidence/` | 22 | `095F696B…` |
| T10 | `.godot/verification/e10a_t10_evidence/` (inclui `e10a_capture`) | 27 | `3CFF6B8D…` |
| T8 | `.godot/verification/e10a_t8_evidence/` (`t8_native`) | 40 | `4FA804B3…` |

Cada pasta tem um `…_manifest.sha256` ao lado. Não copiei as subpastas de fixture (`e07_f1`, `e07_f2`,
`e08_art_units`, `e06_publication`; cerca de 1,1 GB por worktree, regeneráveis).

### Worktrees removidas

`youthful-robinson-db714a`, `admiring-proskuriakova-de00f1` e `cool-northcutt-0a2f7d` saíram do registro do
Git (as três só tinham `.import` reescritos). As pastas ficaram vazias e ocupadas (`Device or resource busy`,
sessões ainda abertas). Branches mantidas em `dc99e9c1`, `709f0a6b` e `74317a9b`. Disco: 34 GB livres.

## Composição 9 — pontas de arquitetura e estado de espera (19/11/2026)

| Origem | Ponta | Merge | Conteúdo |
|---|---|---|---|
| arquitetura (A15, T15, T16) | `cf176e6a` | `c1fad1f3` | só `docs/epics/e10a.md`, sem conflito |
| arquitetura (A16) | `6a629434` | `5fd7dd86` | só `docs/epics/e10a.md` (1 linha), sem conflito |

Nenhum teste rodado: as duas pontas só mudam documento. **Pendente para fechar a composição 9:** o
`master` ainda não tem o E12 (fast-forward `7795f56d` → `34228347` espera a aprovação do usuário na sessão do
E12), e a T11 vai entregar a correção da A16 (`ui_evolution_test` percorrendo `hybrid_ids()`;
`e07_f1_composition_test` 27 → 31 com `_setup` da família para os PROC). Os dois vermelhos da composição 8
seguem abertos até essa entrega. As cards T15 e T16 só começam com E12 e a correção da T11 no candidato.

### Composição 9, parte 2 — `master` `34228347` (E12) no candidato (19/11/2026)

| Origem | Ponta | Merge |
|---|---|---|
| `master` (E12 `1d202bb0` mais o registro do aceite) | `34228347` | `a3a03708`, sobre `c497f26e` |

`claude/e12-candidato` é ancestral do `master`. **Três conflitos, todos mecânicos (união dos dois lados), nenhum
nos cinco arquivos de código observados:**

| Arquivo | Resolução |
|---|---|
| `tools/verify.ps1` | `foreach ($group in @('tests/e09', 'tests/e10a', 'tests/systems', 'tests/classes', 'tests/e12'))`: a lista da C1.12 do E10a mais o `tests/e12` da H1, com os dois comentários |
| `AGENTS.md` | o parágrafo do E10a e a frase do E12 (autorizado 17/11, aceito 18/11), nessa ordem |
| `docs/LONG_TERM_EPICS.md` | as linhas E10a e E10b–E10e/E11, mais a linha E12 |

`class_kit.gd`, `combat_actor.gd`, `player_actor.gd`, `enemy_actor.gd` e `main.gd` entraram por auto-merge
(sem marcador de conflito); `runtime_manifest.json` também, e continua JSON válido (127 chaves de topo). O
`codex/playtest` não foi tocado.

**Gancho `hud_state` (limitação 5 da T1): o auto-merge NÃO compõe os dois módulos, e não corrigi.**
`PlayerActor.kit_hud_state()` (`player_actor.gd:2742`) é `if kit == null: return {}` e depois
`KitHudState.checked(kit.hud_state(self), kit)`: só lê `kit`, nunca `origin_kit`, ao contrário de
`kit_modules()` (`player_actor.gd:359`, origem e depois evolução). Hoje isso é inofensivo: só `mg_ac`, `mg_la`,
`sp_ac`, `sp_la` e a fixture implementam `hud_state`; a base Acólito e os kits Sacerdote e Cultista usam o
padrão `{}`, e todos os testes passam. Mas o Acólito sem evolução tem `kit == null` e `origin_kit` preenchido e
fica sem HUD; e quando a T12 der `hud_state` à base e aos kits puros, o resultado de dois módulos precisa de
regra de composição (recursos, skills, zonas e marcas de cada módulo, e o validador `KitHudState.checked`, que
recebe um único kit para prefixo de recurso e IDs de skill). É decisão de formato, não de merge: **volta à
arquitetura (T1 e T12)**.

**Importação e testes:** importação exit 0 (`6D1E7A54…24AA`); bootstrap F1: 255 com a falha conhecida
(`AB79025F…831F`), 256 passou (`C0B81248…A7F2`), refeito depois do merge. **20 passos, todos verdes**, um por
chamada, timeout 300 s, 0 timeouts, nenhum `SCRIPT ERROR`, `Parse Error`, `Compile Error`, `still in use` ou
`ObjectDB`. Logs em `.godot/verification/t13_c9/` (fora do Git).

| Passo | Teste | Resultado | Saída (8) |
|---|---|---|---|
| 367 / 365 / 366 | `hud_seam_test` / `hud_components_test` / `hud_integration_test` (E12) | 194 / 167 / 234 | `4B5ED8FE` / `6C770612` / `940E9619` |
| 350 / 353 / 359 / 362 | `mg_ac` / `mg_la` / `sp_ac` / `sp_la` `_hud_test` | 60 / 53 / 57 / 49 | `000BB13B` / `13CB6B25` / `11A7268D` / `D74B43A7` |
| 33 | `mage_gameplay_test` | PASS, 52 | `02D14E4B` |
| 336 / 333 | `base_seam_test` / `kit_seam_test` | 172 / 276 | `F78A568B` / `60643509` (iguais à composição 8) |
| 331 / 332 | `kit_seam_hooks_v2_test` / `v3_test` | 38 / 63 | `5182F32B` / `D1DFD323` (iguais) |
| 344 / 357 / 348 | `acolyte_base_test` / `priest_kit_test` / `cultist_kit_test` | 306 / 220 / 215 | `E633901A` / `942D0B90` / `215686C4` (iguais) |
| 340 | `ui_family_test` | 86 | `9D58F18C` (igual) |
| 26 | `e08_feedback_recipe_test` | PASS, 1433 | `1601B34D` (igual) |
| 108 / 39 / 342 | `e05_evolution_catalog_test` / `e02_character_menu_test` / `madness_test` | PASS 99 / PASS 26 / 276 | `90F3F112` / `92E83227` / `D4DAEAF5` (iguais) |

Como o E12 passou a ser descoberto pelo `verify.ps1`, alguns índices mudaram (por exemplo, `priest_kit_test` de 355 para 357); o hash de cada saída conferida não mudou. Os vermelhos da composição 8
(`ui_evolution_test` e `e07_f1_composition_test`) **não foram rodados aqui** e seguem abertos até a T11 (A16).

### Ponta de arquitetura `3d0fb3d1` (A17, A18) (19/11/2026)

Merge `e3fcc23a`, só `docs/epics/e10a.md`, sem conflito; nenhum teste (documento). A A18 decide o
`hud_state` apontado acima: a T12 compõe os dois módulos em `PlayerActor.kit_hud_state()` e, com um só
módulo, nada muda. A A17 dá à T15 a posse de `grant_aegis` no Santuário. Pendentes no candidato: a correção
da T11 (A16), a T15, a T16 e a T12.

## Composição 10 — T11 corrigida (A16 e A19) e ponta A19 e A20 (19/11/2026)

| Origem | Ponta | Merge |
|---|---|---|
| T11 (`claude/youthful-robinson-db714a`) | `fddea9ed` | `37fb1211` |
| arquitetura (A19, A20) | `651d0b38` | `57001ae3` (só `docs/epics/e10a.md`) |

Sem conflito. A T11 trouxe `tests/e09/ui_evolution_test.gd` (`_install_states` percorre `hybrid_ids()`),
`tests/e07_f1_composition_test.gd` (27 → 31, `_setup` da família, `EnemyActor` reais) e o recibo.

Importação exit 0 (`00C38D09…5B76`); bootstrap F1: 255 com a falha conhecida (`AB79025F…831F`), 256 passou
(`0B8A5677…4B42`), refeito depois do último merge. Seis passos, um por chamada, 0 timeouts, sem `SCRIPT ERROR`,
`still in use` ou `ObjectDB`. Logs em `.godot/verification/t13_c10/`.

| Passo | Teste | Resultado | Saída (8) |
|---|---|---|---|
| 334 | `ui_evolution_test` | **97, 0 falhas** (era 2 falhas de 90) | `DF7B1619` (igual à composição 5) |
| 321 | `e07_f1_composition_test` | **342 checks, 2 falhas aceitas**; `recipes=31` | `36AEC768` |
| 335 | `augments_test` | 180, 0 falhas | `D2E49FD9` (igual) |
| 221 | `e06_publication_test` | 1162, 0 falhas | `787D3A35` (igual) |
| 340 | `ui_family_test` | 86, 0 falhas | `9D58F18C` (igual) |
| 333 | `kit_seam_test` | 276, 0 falhas | `60643509` (igual) |

**As 2 falhas aceitas do `e07_f1_composition_test`** (A19 e A20, abertas até a T15):
`causal parent contact respects supported body/floor: pilot_priest_b_effect` (Juízo: a coluna acerta também o
andar de cima) e `…: pilot_cultist_b_effect` (Olhar: o cone só reconhece `EnemyActor`). Os 4 checks de
PROC da composição 8 caíram para 2: o `_setup` da família e a contagem 31 passam.

Evidência da correção copiada para `.godot/verification/e10a_t11_evidence/fix_a16_a19/` (18 arquivos,
manifesto `e10a_t11_fix_manifest.sha256`, `66B2FE85…`). A worktree da T11 foi removida de novo (a pasta
ficou vazia e ocupada); a branch fica em `fddea9ed`.

## Composição 11 — T16, T15 e ponta A21 e A22 (19/11/2026)

| Ordem | Origem | Ponta | Merge |
|---|---|---|---|
| 1 | T16 (`claude/modest-franklin-aa99e3`) | `8530b3e5` | `2a1ebb8b` |
| 2 | T15 (`claude/youthful-meninsky-4da2e3`) | `223f05e8` | `2107f222` |
| 3 | arquitetura (A21, A22) | `8917268b` | `f872b025` (só `docs/epics/e10a.md`) |

**Sem conflito nos três merges.** `scripts/classes/cultist/cultist_kit.gd` (o arquivo que a A21 apontou) entrou
por auto-merge: os hunks da T16 e os da T15 estão em regiões separadas. Conferi o resultado contra as duas
pontas: contra a T15 só diferem os hunks da T16 (constantes, `draw_vfx`, `figure_state`/`_sync_figure(s)`,
`on_tick`, `on_death`, e as chamadas a `_sync_figure` em `_resolve_geometry` e `_resolve_revelation`); contra a
T16 só diferem os da T15 (`gaze_targets`, a chamada em `_advance_geometry`, `_revelation_tick`). Logo
`gaze_targets`, `_geometry_pulse` e `_in_sight` ficam com o texto da T15, como a A21 pede.

### Importação e testes de impacto

Importação exit 0 (`FBAF3F88…64F1`); bootstrap F1: 255 com a falha conhecida (`AB79025F…831F`), 256 passou
(`76870A7C…274E`), refeito depois do último merge. **33 passos (32 nomes; `equipment_items_test` tem dois),
todos verdes**, um por chamada, 0 timeouts, sem `SCRIPT ERROR`, `still in use` ou `ObjectDB`. Logs em
`.godot/verification/t13_c11/` (fora do Git).

| Passo | Teste | Resultado | Saída (8) |
|---|---|---|---|
| 321 | `e07_f1_composition_test` | **342 checks, 0 falhas** (fecha as duas falhas aceitas), `recipes=31` | `4540C933` |
| 345 | `sanctuary_test` | 155 | `01B74920` |
| 362 / 361 / 360 | `sp_ac_kit_test` / `sp_ac_hud_test` / `sp_ac_boss_combat_test` | 170 / 57 / 25 | `2229F2DC` / `11A7268D` / `26957117` |
| 341 / 340 | `family_world_test` / `family_integration_test` | 149 / 60 | `E7659AD9` / `9369764E` |
| 346 / 347 | `acolyte_base_test` / `acolyte_boss_combat_test` | 332 / 295 | `93F81F64` / `BBD898B8` |
| 359 / 358 | `priest_kit_test` / `priest_boss_combat_test` | 240 / 32 | `64BC6C0B` / `16BBBC37` |
| 350 / 348 / 349 | `cultist_kit_test` / `cultist_boss_combat_test` / `cultist_campaign_kill_test` | 237 / 49 / 20 | `3D91804D` / `88E65883` / `212B00D3` |
| 344 / 333 | `madness_test` / `kit_seam_test` | 276 / 276 | `D4DAEAF5` / `60643509` (iguais) |
| 331 / 332 / 336 | `kit_seam_hooks_v2_test` / `v3_test` / `base_seam_test` | 38 / 63 / 172 | iguais às composições 8 e 9 |
| 339 | `family_bodies_test` | 7425 | `0C332E50` |
| 329 / 338 | `equipment_items_test` (E09 / E10a) | 244 / 301 | `EB9A6284` / `97A9EEBE` (iguais) |
| 239 / 20 | `equipment_hand_alignment_test` / `e08_equipment_art_test` | 4593 / 100863 | `38A87BF0` / `5F377D76` (iguais) |
| 26 / 27 | `e08_feedback_recipe_test` / `e08_feedback_vfx_test` | PASS 1433 / 697 | `1601B34D` / `BF9FE3B0` (iguais) |
| 334 / 342 / 335 | `ui_evolution_test` / `ui_family_test` / `augments_test` | 97 / 86 / 180 | `DF7B1619` / `9D58F18C` / `D2E49FD9` (iguais) |
| 369 / 367 / 368 | `hud_seam_test` / `hud_components_test` / `hud_integration_test` | 194 / 167 / 234 | `4B5ED8FE` / `6C770612` / `940E9619` (iguais) |
| 33 | `mage_gameplay_test` | PASS, 52 | `02D14E4B` (igual) |

Os números conferem com os que a arquitetura esperava (`e07_f1_composition_test` 342, `sanctuary_test` 155,
`family_world_test` 149, `priest_kit_test` 240, `cultist_kit_test` 237, `family_bodies_test` 7425). Os índices dos
passos mudaram (a T15 trouxe dois testes novos em `tests/e10a`); os hashes das saídas dos testes que nenhuma das
duas tarefas tocou não mudaram.

### Evidências ignoradas pelo Git e worktrees

| Tarefa | Pasta no candidato | Arquivos | Manifesto SHA256 |
|---|---|---|---|
| T16 | `.godot/verification/e10a_t16_evidence/` (inclui `e10a_t16_ui` e `verification_t16`) | 93 | `14A01747…` |
| T15 | `.godot/verification/e10a_t15_evidence/` (inclui `t15_evidence` e `t15_probe`) | 99 | `37A19F32…` |

Cada pasta tem `…_manifest.sha256` ao lado. Não copiei as subpastas de fixture (`e07_f1`, `e07_f2`,
`e08_art_units`, `f1_visual_fixture`), regeneráveis. As duas worktrees só tinham `.import` reescritos; saíram do
registro do Git e as pastas ficaram vazias e ocupadas (sessões abertas). Branches mantidas em `8530b3e5` e
`223f05e8`. A T12 pode partir do candidato desta composição.

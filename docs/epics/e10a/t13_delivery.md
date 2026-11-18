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

# T10 — recibo da integração e do candidato E09 (C8), 17/11/2026

**Candidato:** `3843d32439b17442dfa9261aafd24ac84769b16b`, na branch `claude/e09-candidato`.
- **Escopo:** este é o commit exportado e testado. Os commits seguintes mexem só em `docs/`.
- **Aprovação técnica:** ainda depende da supervisão da T11.
- **Aceite de produto:** é do usuário, pelo [roteiro de playtest](playtest_guide.md).
- **Git:** sem push e nada em `master`. `codex/playtest` e o save pessoal não foram tocados.

## Composição

Partiu de `a033dcb8`. Todos os merges usaram `--no-ff` e nenhum teve conflito.

| Ordem | Tarefa | Ponta mesclada | Merge |
|---|---|---|---|
| 1 | T1 | `4fbfd9db` | `9a947996` |
| 2 | T3 | `816b7e0f` | `e37adc2a` |
| 3 | T4 (traz T2) | `b5aac165` | `aaaa8929` |
| 4 | T5 | `d855cde9` | `b1cfc81f` |
| 5 | T6 | `9a49ed69` | `a73bb013` |
| 6 | T7 | `f433e8bc` | `f4b50d4e` |
| 7 | T8 | `a9d71e04` | `b6036520` |
| 8 | T9 | `c252342e` | `e832bd77` |
| 9 | K1 | `6e37da52` | `f7ee8e73` |
| 10 | K2 | `a0a65700` | `3562d7fb` |
| 11 | K3 | `8bfb0f30` | `e4cafd6f` |
| 12 | K4 | `578e3a4a` | `407a4089` |
| 13 | Correções Sol | `475fa374` | `3843d324` |

**Commits próprios da T10**

| Commit | Conteúdo |
|---|---|
| `3eac8f83` | os 5 `.gd.uid` gerados pela importação |
| `80f69f1c` | `verify.ps1` passa a rodar os testes Python com o comando documentado pela T2 |
| `4d8d4eba` | preset Windows; `tools/e09_package.ps1`; `tools/e09_release_probe.gd` |
| `e813129f` | a sonda registra a feature `editor` como informação |
| `3e65ba25` | estado e documento de bloqueio |

**Primeira rodada, em `3eac8f83`.** Deu quatro falhas novas, além da 255 conhecida. A T10 corrigiu a
347, que era dela. As outras três e a falha nos perfis de revisão (7 de 8) voltaram para a Sol, ver
[t10_blockers_2026_11_17.md](t10_blockers_2026_11_17.md). As correções da Sol estão em
[sol_fixes_delivery.md](sol_fixes_delivery.md).

## Suíte completa no candidato

**Como rodou**

- **Comando:** `tools/verify.ps1` sem `-Test`, um passo por chamada e timeout de 300 s.
- **Motor:** `.tools/godot/Godot_v4.7.2-stable_win64.exe`, chamado pelo PowerShell.
- **Fixture:** os 4 passos de bootstrap (1, 251, 255 e 256) rodaram sem `-F1Fixture`; os outros 343,
  com ele.
- **`probe_headless`:** antes do primeiro passo com fixture, a pasta antiga foi movida para
  `probe_headless_stale_20261117161416`.

**Resultado**

| Medida | Valor |
|---|---|
| Passos | 347 |
| Falhas | 1, o passo 255 `e07_f1_native_import` (a falha conhecida) |
| Timeouts | 0 |
| `SCRIPT ERROR` ou `Parse Error` nos logs | 0 |
| Tempo | 152 min |

**Passos exigidos ou antes falhos:** todos passam.

| Passo | Teste | SHA256 da saída |
|---|---|---|
| 26 | `e08_feedback_recipe_test` | `B7782234…BBE9` |
| 48 | `e03_progression_transactions_test` | `3A00F5DA…96DD` |
| 108 | `e05_evolution_catalog_test` | `6B7F3B5B…7AB2` |
| 250 | `e06_export_content_test` | `4D20192C…081A` |
| 333 | `kit_seam_test` | `ED82D954…3E49` |
| 334 | `ui_evolution_test` | `DF7B1619…69EF` |
| 347 | `art_pipeline_tests` | `C79F471D…0FB5` |

O passo 255 teve saída com SHA256 `AB79025F…831F`, igual à da primeira rodada.

**Evidência:** `.godot/verification/t10_full_3843d324/`, na worktree `e09-candidato`, fora do Git.

| Arquivo | SHA256 |
|---|---|
| `summary.jsonl` | `D7231C6778682CDEBDDFB88F18A9A04E3E93787C7849D41ECB4415DB178EEE40` |
| Console do driver | `2C95221B551A451BB57381FF5960A728901EDEBFECFC5ECF465422AB247FC6F2` |

O `plan.json` de cada passo registra `source_commit` e o estado da árvore.

## Exportação

**Origem:** `tools/e09_package.ps1 -Stage Export`, a partir do fixture F1 que a rodada refez nesse
commit.

**Pacote**

- Motor padrão `ab1824f8…`, template release `d34d36f3…`.
- O nome do aplicativo, **RagRPG E09 Candidato**, isola o save.
- O plugin git e a arte-fonte sem `.import` rastreado ficam fora.

**Preset Windows (commitado)**

- **Entram no `include_filter`:**
  - os `snapshot_manifest.json` (`scripts/classes/`, `scripts/classes/*/` e `scripts/systems/*/`);
  - os `presentation.json` das híbridas;
  - `assets/art/equipment/hand_rigs.json`.
- **`exclude_filter`:** os três fixtures (`scripts/classes/fixture/`,
  `scripts/systems/sanctuary/fixture/` e `scripts/systems/flank/fixture/`).

Pasta de saída: `.tools/playtest_e09/e09_3843d324/`.

| Artefato | Bytes | SHA256 |
|---|---|---|
| `RagRPG-E09-Candidato.exe` | 109.127.680 | `4A9EADED8955EF789AB02651ED9D2DDE80328FBB342BD2A6DB4DB33E86305668` |
| `RagRPG-E09-Candidato.pck` | 249.413.272 | `5AFE0CDC1D88F82F23871E544AB855B45C0BA2A59B4566785A6AC94831F1A468` |
| `build_manifest.json` | 1.612 | `7BA5918B856ACFE0057186B6783A0BF36008A0019F56DB24CE2A3581432E732D` |

## Sondas no PCK exato

A pasta das sondas é `validation/`, e todas passaram.

**`inspect_pack_e09` (`tools/e09_release_probe.gd`): 20/20.** O PCK tem 3760 entradas.
- **Kits:** são exatamente quatro (`mg_ac`, `mg_la`, `sp_ac`, `sp_la`), todos prontos e válidos.
- **Evolução no job 20:** o Espadachim oferece Paladino e Duelista; o Mago, Taumaturgo e Lâmina
  Arcana. Os 4 onboardings existem.
- **Corpos:** os 4 manifestos resolvem e as 8 texturas carregam.
- **Ícones:** os 28 ícones carregam, e as 28 skills de kit resolvem o próprio ícone.
- **Receitas e efeitos:** há 28 receitas de feedback. As 35 entradas de efeito resolvem: Paladino 8,
  Taumaturgo 9, Duelista 7 e Lâmina Arcana 11.
- **Itens:** os 4 (`halo_shield`, `buckler`, `rapier`, `prism_staff`) estão definidos, no loot de
  produção (5 categorias), com ícone pintado e arte na mão. O resolvedor de loot é válido.
- **Snapshot:** os fragmentos são exatamente 7 (classes, os 4 kits, `flank` e `sanctuary`), e o
  merge passa sem erro, com 13 de 13 tipos conhecidos.
- **Fixtures:** nenhum fixture no pacote.
- **Feature `editor`:** é `true`, o que é próprio do motor padrão; fica só registrada.

**Outras sondas**
- **`export_content`:** 89 equipamentos, entre definições e catálogo; `PACK_PROBE failures=0`.
- **`inspect_pack_e08`:** os grupos de arte da E08 continuam no pacote.
- **`normal_boot` e `forest_map_pack`:** passaram, e a captura `candidate_forest_zoom.png` foi
  gerada.

## Perfis de revisão, atalhos e smoke

**Perfis**
- `tools/e09_review_profiles.gd` rodou com `--main-pack` numa pasta isolada (`review_profiles_raw`),
  fora do perfil pessoal.
- Saíram **8 perfis válidos no job 40**, sem pendentes nem inválidos.
- Cada perfil foi copiado para `profiles/<chave>/appdata/…/RagRPG E09 Candidato/`.
- O SHA256 de `profiles/index.json` é `21E44A75…3F41`.

| Perfil | SHA256 |
|---|---|
| `sp_ac__paladin_bulwark` | `f19bb68d…cb71` |
| `sp_ac__paladin_hammer` | `58651525…9b4f` |
| `mg_ac__thaumaturge_prism_altar` | `138f5e47…bc5d` |
| `mg_ac__thaumaturge_dawn_choir` | `50d55169…de94` |
| `sp_la__duelist_patient_blade` | `bfdbe502…2ccd` |
| `sp_la__duelist_arena` | `0fda77d4…9872` |
| `mg_la__arcane_blade_execution_chain` | `ca91e9e2…928d` |
| `mg_la__arcane_blade_prism_specter` | `7ca1ca8a…0e6c` |

**Atalhos:** há 8 `launch_<chave>.cmd` e 8 atalhos "Jogar E09 - <classe> - <build>.lnk".

**Smoke:** abriu o primeiro perfil.
- A janela "RagRPG E09 Candidato" seguia viva aos 25 s.
- Fechou com código 0 e sem linhas de erro.
- O SHA256 do perfil era igual antes e depois.

## Multidão contra `db7f9252` (não é certificação de FPS)

**Protocolo:** `tools/e08_crowd_compare.gd`, com 96 atores e 3 passadas por modo. Foram 2 rodadas
alternando os pacotes E08 e E09, no mesmo motor e na mesma máquina. A evidência está em
`measure_crowd01/` (`protocol.json` e `runs.json`).

| Pacote | Modo | Mediana das medianas (ms/quadro) | p95 médio (ms) | Memória estática |
|---|---|---|---|---|
| E08 `db7f9252` | parado | 3,68 | 6,06 | 139,3 MB |
| E09 `3843d324` | parado | 3,67 | 5,98 | 145,7 MB |
| E08 `db7f9252` | em movimento | 6,75 | 8,95 | 139,3 MB |
| E09 `3843d324` | em movimento | 7,07 | 10,14 | 145,7 MB |

Os dois pacotes têm 288 draw calls.

**Leitura:**
- **Parado:** E08 e E09 empatam.
- **Em movimento:** o E09 ficou cerca de 5% mais lento na mediana. A diferença está dentro da
  variação entre rodadas: a mediana do E08 variou de 6,24 a 7,06 ms.
- **Memória estática:** o E09 usa cerca de 6,4 MB a mais, compatível com a arte nova.

São duas rodadas numa máquina só, sem fixar a frequência da CPU. Não servem para afirmar FPS nem
regressão.

## Limitações concretas

1. **Aprovação.** O candidato ainda não tem aprovação técnica, que depende da T11, nem aceite de
   produto. O playtest habitual (`codex/playtest`) **não** foi avançado.
2. **Passo 255 (`e07_f1_native_import`).** Segue falhando, como em todas as rodadas desde a E08.
3. **Fim de linha nos `.import`.** Cada importação reescreve cerca de 617 `.import` só no fim de
   linha (`core.autocrlf`). Às vezes apaga também o
   `~libgit_plugin.windows.editor.x86_64.dll` rastreado. A T10 reverteu tudo antes de cada commit e
   da exportação. Os `plan.json` dos passos rodados depois de uma importação registram a árvore suja
   só por isso.
4. **Arte-fonte.** Os PNG-fonte sem `.import` rastreado ficam fora do pacote, como na E08. O jogo usa
   os atlas importados.
5. **Lacunas de áudio dos kits (Sol).** Faltam as deixas P6 `dot`, `heal` e `summon` arcanas. Por
   isso:
   - os pulsos do Juramento e do Círculo Votivo soam com o `world.impact` genérico;
   - a Refração Curativa não tem som próprio de cura;
   - o Espectro de Prisma fica sem som de invocação.

   Fica como ponto de playtest. Uma tarefa de áudio fica a critério do usuário.
6. **Nome sem prefixo (Sol).** O perfil "Corrente de Execuções" sai sem o prefixo "E09 ", por causa
   do limite de 24 caracteres do nome.
7. **Pontos de aceite visual.** Estão detalhados no roteiro:
   - **corpos (T7):** encaixe com erro de até ±1 px, Paladino virado para oeste na pose 57,
     Lâmina Arcana virada para leste na pose 0, sem `bare_head`;
   - **armas (T8):** só o quadro 0 foi conferido em captura;
   - **efeitos:** os desenhados em código não foram capturados, e o Paladino usa a cor `arcane`;
   - **escolha de evolução (T9):** a captura usou kits de fixture;
   - **dificuldade dos chefes:** fica para o playtest humano.
8. **Medição de multidão.** São só duas rodadas e não certificam FPS.
9. **Ícones fora dos kits.** Quatro skills de catálogo continuam sem ícone, listadas no item Q7 de
   [generation_queue.md](../../art/generation_queue.md).

## Adenda — respostas às ressalvas da T11 (17/11/2026)

A T11 (Luna) deu **aprovação técnica** ao candidato `3843d324`, com três ressalvas de
rastreabilidade ([t11_supervision.md](t11_supervision.md), seção 4). As respostas:

1. **Console do driver.** Ele existia, mas ficou fora da pasta da rodada: estava no scratchpad da
   sessão T10. Agora está junto da evidência, fora do Git, com o hash registrado:
   - `.godot/verification/t10_full_3843d324/driver_console.txt`, SHA256 `2C95221B…C6F2`, 348 linhas
     (os 347 passos e "round finished");
   - o console da primeira rodada também foi guardado, em
     `.godot/verification/t10_full_3eac8f83/driver_console.txt`, SHA256 `5E6BE3BC…5F20`, o hash
     citado no documento de bloqueio.
2. **Executável diferente do contrato.** O §9 cita `Godot_v4.7.2-stable_win64_console.exe`, mas as
   duas rodadas, a exportação e as sondas usaram `Godot_v4.7.2-stable_win64.exe` (SHA256
   `ab1824f8…`). É a mesma versão 4.7.2 standard. O desvio é deliberado: o exe console falha ao
   abrir o projeto num caminho com "ã" ("João"), e o exe GUI chamado pelo PowerShell não falha. O
   desvio fica registrado aqui. O contrato não foi editado, porque não é arquivo da T10.
3. **Os 617 `.import` mudam só no fim de linha.** A T10 reproduziu o caso no candidato depois da
   T11, porque as diferenças da rodada não tinham sido guardadas:
   - **Reprodução:** importação headless do editor na worktree limpa, que deixou 617 `.import` com
     status ` M`, o mesmo número da rodada.
   - **Comparação:** cada arquivo foi comparado com o blob do índice
     (`.godot/verification/t10_full_3843d324/import_eol_check.json`, SHA256 `6EBDE45B…3AA4`).
   - **Resultado:** os 617 são **idênticos byte a byte** ao blob commitado (LF), e nenhum tem
     diferença de conteúdo. O status ` M` aparece porque o checkout com `core.autocrlf=true` grava
     esses arquivos em CRLF, e o Godot os regrava em LF.
   - **Limite:** a prova vale para a reprodução, não para os bytes exatos da rodada, que não foram
     guardados. A reprodução usou o mesmo commit, o mesmo motor e o mesmo número de arquivos.

Com isso, **T10 e T11 estão entregues**. O candidato está **aprovado tecnicamente e aguarda o aceite
de produto** do usuário. O merge em `master` continua dependendo desse aceite explícito.

# H5 — recibo da integração e do candidato E12 (C6), 17/11/2026

**Candidato:** `250b094872a7e695845579afa3cf3ae8c3beaa06`, na branch `claude/e12-candidato`. É o
commit de merge que traz o `master` do E09 aceito (`7795f56d`) para cima do commit testado.

| Papel | SHA |
|---|---|
| Commit **testado pela suíte completa** (pré-merge) | `874776ec6683058ae1ac0e15755fbfdadc96baf9` |
| Recibo, roteiro e script da H5 (só `docs/`) | `25ed0f07` |
| `master` aceito do E09 | `7795f56d` |
| **Candidato exportado e sondado** (pós-merge) | `250b094872a7e695845579afa3cf3ae8c3beaa06` |

- **Escopo:** a suíte completa rodou no SHA pré-merge `874776ec`. O merge com o `master` é **só
  documental** (ver "Merge com o `master`"), por isso a suíte não foi repetida. A exportação, as
  sondas no PCK, os perfis, o smoke e a multidão foram refeitos a partir do SHA pós-merge.
- **Base:** o candidato E09 `a0c81525` (via `0405f4f6`, que só trouxe o registro da H4).
- **Aprovação técnica:** ainda depende da supervisão Luna (H6).
- **Aceite de produto:** é do usuário, pelo [roteiro de playtest](playtest_guide.md).
- **Git:** sem push e nada em `master`. `codex/playtest` e o save pessoal **não** foram tocados (D6 e
  C6: o playtest só avança depois da H6 e da aprovação técnica; a condição do aceite do E09 já está
  cumprida).
- **Código de runtime:** nenhuma linha foi editada pela H5. Não houve falha nova a corrigir.
- **Ordem do recibo:** este recibo foi escrito **depois** do fim da rodada completa (os passos 2 a
  354 e todos os hashes abaixo são de uma rodada terminada), e atualizado depois do merge.

## Composição

Partiu de `0405f4f6`. Os quatro merges usaram `--no-ff`, na ordem do DAG, e **nenhum teve
conflito**.

| Ordem | Tarefa | Ponta mesclada | Merge |
|---|---|---|---|
| 1 | H1 | `03c2c2db` | `2ffc2d2c` |
| 2 | H2 | `82fecf2f` | `269c1c91` |
| 3 | H3 | `5582539b` | `58500971` |
| 4 | H4 | `55792170` | `874776ec` |

**Conferência do diff contra `a0c81525`:** 72 arquivos, 6437 inserções e 14 remoções. Só aparecem
arquivos dos donos das tarefas H1 a H4 (documentos do épico e da norma, `scripts/ui/hud/`,
`scripts/presentation/`, os kits e o `class_kit.gd`, `scripts/actors/`, `tests/e12/`, `tests/classes/`,
`tools/verify.ps1` da H3), mais as duas exceções da H4 já registradas: as entradas `omitted` em
`scripts/core/expedition/snapshot/runtime_manifest.json` e uma asserção em
`tests/mage_gameplay_test.gd`.

## Merge com o `master`

O E09 foi aceito pelo usuário em 17/11 e está em `master` (`7795f56d`, `codex/playtest` no mesmo
commit). Foi feito **merge** (não rebase), de modo que o commit testado continua ancestral do
candidato (`git merge-base --is-ancestor 874776ec 250b0948` confirma).

- **Diferença `a0c81525` → `7795f56d`:** só `AGENTS.md`, `docs/LONG_TERM_EPICS.md` e
  `docs/epics/e09.md`.
- **Conflito:** só em `AGENTS.md` (mecânico, um parágrafo). Resolvido mantendo as duas notas: o
  aceite e a integração do E09 e a autorização do E12. `docs/LONG_TERM_EPICS.md` mesclou sozinho e
  mantém as linhas do E09 aceito e do E12.
- **Diff do commit testado `874776ec` até o candidato `250b0948`:** 8 arquivos, todos documentos:
  `AGENTS.md`, `docs/LONG_TERM_EPICS.md`, `docs/epics/e09.md`, `docs/epics/e12.md` e os quatro
  arquivos da H5 em `docs/epics/e12/`. **Nenhum** arquivo `res://` de script, cena ou recurso.
- **Diff do commit de docs da H5 `25ed0f07` até o candidato:** só os três arquivos vindos do
  `master`.
- **Prova pelo PCK:** o PCK exportado do SHA pós-merge tem SHA256 **idêntico** ao exportado do SHA
  pré-merge (`4A91F424…A7242`, 249.615.740 bytes), e o `.exe` também. O merge não mudou nenhum byte
  empacotado.

## Suíte completa no candidato

**Como rodou**

- **Comando:** `tools/verify.ps1` sem `-Test`, um passo por chamada (driver do T10) e timeout de 300 s.
- **Motor:** `.tools/godot/Godot_v4.7.2-stable_win64.exe` (SHA256 `ab1824f8…2424`), chamado pelo
  PowerShell.
- **Fixture:** os passos de bootstrap (251, 255 e 256) rodaram sem `-F1Fixture`; os outros, com ele.
- **Passo 1 (`editor_import`):** terminou a importação normalmente (226,8 s, código 0), mas o driver o
  marcou como falha pelas duas linhas `ERROR` do `GitPlugin`, a limitação 7 da H4. Seguiu-se o
  tratamento do T10: registrar e não repetir o passo, porque a importação estava completa. Os
  passos 2 a 354 rodaram em seguida, na ordem do plano.

**Resultado**

| Medida | Valor |
|---|---|
| Passos | 354 (o 1 mais os 353 de 2 a 354) |
| Falhas | 2: o passo 1 (`GitPlugin`, ambiental) e o passo 255 `e07_f1_native_import` (a falha conhecida) |
| Passos 2 a 354 | 352 passam, 1 falha (o 255) |
| Timeouts | 0 |
| `SCRIPT ERROR` ou `Parse Error` nos logs | 0 |
| Tempo | cerca de 160 min nos passos 2 a 354, mais 3,8 min no passo 1 |

Em relação ao T10, a lista de falhas dos passos 2 a 354 é a mesma (só o 255); o passo 1 é a
limitação ambiental descrita acima. O plano passou de 347 para 354 passos pelos 7 testes novos do
E12 (338, 341, 345, 348, 351, 352 e 353), e o `art_pipeline_tests` passou do passo 347 para o 354.

**Passos novos do E12 e passos exigidos pelo T10:** todos passam.

| Passo | Teste | SHA256 da saída |
|---|---|---|
| 26 | `e08_feedback_recipe_test` | `B7782234…BBE9` |
| 48 | `e03_progression_transactions_test` | `3A00F5DA…96DD` |
| 108 | `e05_evolution_catalog_test` | `6B7F3B5B…7AB2` |
| 250 | `e06_export_content_test` | `4D20192C…081A` |
| 333 | `kit_seam_test` | `ED82D954…3E49` |
| 334 | `ui_evolution_test` | `DF7B1619…69EF` |
| 338 | `mg_ac_hud_test` | `000BB13B…4CC7` |
| 341 | `mg_la_hud_test` | `13CB6B25…7A9F` |
| 345 | `sp_ac_hud_test` | `11A7268D…DAD3` |
| 348 | `sp_la_hud_test` | `D74B43A7…9607` |
| 351 | `hud_components_test` | `6C770612…DA40` |
| 352 | `hud_integration_test` | `940E9619…01F2` |
| 353 | `hud_seam_test` | `319B453D…BF1E` |
| 354 | `art_pipeline_tests` | `B3193E2E…0854` |

O passo 255 teve saída com SHA256 `AB79025F…831F`, igual à do T10. Os passos 26, 48, 108, 250, 333 e
334 têm exatamente os mesmos SHA256 de saída do T10.

**Evidência:** fora do Git, na worktree `e12-h5-67207c`.
- Passo 1: `.godot/verification/h5_boot_probe/`
- Passos 2 a 354: `.godot/verification/h5_full_874776ec/`

| Arquivo | SHA256 |
|---|---|
| `h5_full_874776ec/summary.jsonl` | `A9B7E5B73052EF6E60B52420931F08D750FB01ACB0242F19FD48200D37F5B5BA` |
| `h5_full_driver_console.txt` | `67D1F725B9070C23CD8F458676C69994209E02D084C34892D912BC7968DCF101` |
| `h5_boot_probe/summary.jsonl` (passo 1) | saída com SHA256 `049CD329…D5D2` |

## Exportação

**Origem:** `docs/epics/e12/h5_package.ps1 -Stage Export`, uma cópia de `tools/e09_package.ps1`
adaptada ao E12 (nome do aplicativo, pasta de saída, uma sonda a mais). Ela vive em `docs/epics/e12/`
porque a H5 só é dona de `docs/epics/e12/h5_*`. Exporta a partir do fixture F1 que a rodada refez.

**Pacote**
- Motor padrão `ab1824f8…`, template release `d34d36f3…`, os mesmos do E09.
- Aplicativo **RagRPG E12 Candidato**, que isola o save.
- Plugin git e arte-fonte sem `.import` rastreado ficam fora; os três fixtures de kit também.
- O fixture `scripts/classes/fixture/hud/` (da H1) cai na mesma pasta de exclusão e **não** está no
  PCK (conferido pela sonda).

Pasta de saída do candidato pós-merge: `.tools/playtest_e12/e12_250b0948/`. Uma primeira exportação
do SHA pré-merge (`e12_874776ec`) gerou os mesmos `.exe` e `.pck`; a pasta foi removida por
superada, e só a evidência da multidão dela foi mantida (ver "Multidão").

| Artefato | Bytes | SHA256 |
|---|---|---|
| `RagRPG-E12-Candidato.exe` | 109.127.680 | `4A9EADED8955EF789AB02651ED9D2DDE80328FBB342BD2A6DB4DB33E86305668` |
| `RagRPG-E12-Candidato.pck` | 249.615.740 | `4A91F424FF1C921EE8BD806639F9D8EA037A98CAE1AFE8FCD7E5C7F9B8AA7242` |
| `build_manifest.json` | 1.604 | `B515750C9EEF1FA78847E0B78D9CB7E6B29B1208D3C0E466B061534FE38C68FA` |

O `.exe` é o mesmo do E09 (mesmo template e mesmo nome de motor). O PCK tem 3786 entradas. O
`build_manifest.json` difere do da primeira exportação (`68452AE0…BCED`) só porque registra o SHA do
candidato e o horário.

## Sondas no PCK exato

Pasta `validation/`; todas passaram.

**`inspect_pack_e09` (`tools/e09_release_probe.gd`, sem mudança): 20/20.** Os kits, os corpos, os
ícones, as receitas, os itens, o snapshot e a ausência de fixtures do E09 seguem intactos no
candidato.

**`inspect_pack_e12` (`docs/epics/e12/h5_pack_probe.gd.txt`): 24/24.**
- **Scripts novos no PCK:** `kit_hud_state`, `hud_palette`, `cast_bar`, `kit_resource_panel`,
  `actor_cast_bar` e `kit_world_overlay` existem, carregam e estão registrados como classes
  globais nos caminhos certos.
- **Fixture:** `scripts/classes/fixture/hud/fixture_hud_kit.gd` **não** está no pacote.
- **Kits:** os quatro expõem `hud_state`; o validador aceita um DTO mínimo válido de cada um e
  recusa um DTO com campo extra; o painel produz 1 linha por kit.
- **Jogador e inimigo:** `cast_progress` existe em ambos e `kit_hud_state` existe no jogador.
- **Componentes:** `CastBar` (plano com razão 0,5 e oculto sem cast), `ActorCastBar.plan_overhead`,
  `KitWorldOverlay.zone_plan`, painel e overlay com estado vazio desenham sem erro.
- **Perfil isolado:** o nome do aplicativo e a pasta do usuário são os do E12.

**Outras sondas**
- **`inspect_pack_e08`:** os grupos de arte da E08 continuam no pacote.
- **`normal_boot`, `forest_map_pack` e `export_content`:** passaram (`PACK_PROBE failures=0`), e a
  captura `candidate_forest_zoom.png` foi gerada.

Todas as sondas foram **repetidas no SHA pós-merge** e passaram do mesmo modo (E09 20/20, E12
24/24, E08, `normal_boot`, `forest_map_pack`, `export_content` com `PACK_PROBE failures=0`).

Hashes das saídas pós-merge: `inspect_pack_e12.output.log` `F2A11FA4…743D`,
`review_profiles.output.log` `C4DC8BC2…A0C0`, `export.engine.log` `A5223CF0…EDDC`.

## Perfis de revisão, atalhos e smoke

**Perfis**
- `tools/e09_review_profiles.gd` (inalterado) rodou com `--main-pack` numa pasta isolada
  (`review_profiles_raw`).
- Saíram **8 perfis válidos no job 40**, sem pendentes nem inválidos.
- O SHA256 de `profiles/index.json` é `D5BC50D6…8E56`.
- Os hashes dos perfis mudam a cada geração (a pasta do perfil guarda data, hora e identificadores),
  então os da primeira exportação não valem para o candidato pós-merge.

| Perfil | SHA256 |
|---|---|
| `sp_ac__paladin_bulwark` | `c54d97ce…8f8d` |
| `sp_ac__paladin_hammer` | `f5273158…67e5` |
| `mg_ac__thaumaturge_prism_altar` | `bccc5042…504c` |
| `mg_ac__thaumaturge_dawn_choir` | `89f148da…2f91` |
| `sp_la__duelist_patient_blade` | `72e9ae51…1e8c` |
| `sp_la__duelist_arena` | `a35dffb2…c4b2` |
| `mg_la__arcane_blade_execution_chain` | `6b3febc3…f829` |
| `mg_la__arcane_blade_prism_specter` | `648c3364…3d5f` |

**Atalhos:** 8 `launch_<chave>.cmd` e 8 atalhos "Jogar E12 - <classe> - <build>.lnk".

**Smoke:** abriu o primeiro perfil.
- A janela "RagRPG E12 Candidato" seguia viva aos 25 s.
- Fechou com código 0 e sem linhas de erro.
- O SHA256 do perfil era igual antes e depois (`c54d97ce…8f8d`).

## Multidão contra E08 e E09 (não é certificação de FPS)

**Protocolo:** `tools/e08_crowd_compare.gd`, com 96 atores e 3 passadas por modo (a passada 0 é
aquecimento e fica fora da média). Foram 2 rodadas com os **três** pacotes (E08 `db7f9252`, E09
`3843d324` e este candidato), em ordem rotativa, no mesmo motor e na mesma máquina. O PCK do E12 é o
mesmo nas duas medições (hash idêntico), então são duas amostras independentes do mesmo pacote.

- **Medição A** (feita antes do merge, `measure_h5_crowd_premerge/`): `runs.json` `84798246…4CB0C`.
- **Medição B** (oficial, no SHA pós-merge, `measure_h5_crowd/`): `protocol.json` `32181388…9A20`,
  `runs.json` `5E727DA9…27BF`.

Média das medianas por quadro (ms), das passadas 1 e 2 das duas rodadas:

| Pacote | Modo | A | B (oficial) | Memória estática (B) |
|---|---|---|---|---|
| E08 `db7f9252` | parado | 3,27 | 4,51 | 139,3 MB |
| E09 `3843d324` | parado | 3,36 | 4,65 | 145,7 MB |
| E12 `250b0948` | parado | 3,58 | 5,21 | 147,0 MB |
| E08 `db7f9252` | em movimento | 6,11 | 7,94 | 139,3 MB |
| E09 `3843d324` | em movimento | 6,25 | 8,37 | 145,7 MB |
| E12 `250b0948` | em movimento | 6,49 | 8,77 | 147,0 MB |

Os três pacotes têm 288 draw calls, e todas as doze execuções saíram sem linhas de erro. A medição B
rodou com a máquina cerca de 30% mais lenta que a A (os três pacotes subiram juntos), por isso os
valores absolutos das duas medições não se comparam; vale a ordem entre os pacotes dentro de cada uma.

**Leitura:**
- O E12 ficou **acima do E09 nas duas medições**: cerca de 4% (em movimento) e 6% (parado) na A, e
  cerca de 5% (em movimento) e 12% (parado) na B. Na B há uma passada do E12 parado a 6,05 ms; sem
  ela a diferença parada cairia para cerca de 6%. Na B as passadas do E09 e do E12 se sobrepõem em
  movimento (E09 de 7,70 a 9,37 ms, E12 de 8,24 a 9,10 ms). É uma diferença pequena e consistente
  de sentido, de décimos a poucos ms por quadro, com poucas amostras.
- **O que a sonda mede e o que não mede:** ela sobe atores e os desenha, mas **não desenha o HUD
  principal** (painel, barra de cast do jogador e overlay de zonas). Mede só o caminho de desenho
  dos atores, incluindo o que o E12 pôs neles (`overhead_bar_y`, `cast_progress`, a barra de cast
  do inimigo). O custo do HUD em jogo **não foi medido**.
- A memória estática sobe 1,3 MB sobre o E09, compatível com os scripts novos.

São poucas rodadas numa máquina só, sem fixar a frequência da CPU. Não servem para afirmar FPS nem
regressão.

## Limitações concretas

1. **Aprovação.** O candidato ainda não tem aprovação técnica (H6) nem aceite de produto. O playtest
   habitual (`codex/playtest`) **não** foi avançado; isso depende da H6 e da aprovação técnica (a
   condição do aceite do E09 de D6 e C6 já está cumprida). O candidato contém o `master` por merge,
   não por rebase.
2. **Passo 255 (`e07_f1_native_import`).** Segue falhando, como em todas as rodadas desde a E08.
3. **Passo 1 (`editor_import`) e o `GitPlugin`.** Numa worktree nova o import termina, mas imprime as
   duas linhas `ERROR` do plugin e o driver conta falha. É a limitação 7 da H4; foi tratado como no
   T10 (registrado, importação completa, passo não repetido).
4. **Fim de linha nos `.import`.** A importação reescreveu cerca de 2000 `.import` só no fim de
   linha (`core.autocrlf`) e apagou o `~libgit_plugin.windows.editor.x86_64.dll` rastreado. Tudo foi
   revertido com `git checkout` antes da exportação, e nada disso entra em commit. Os `plan.json` dos
   passos rodados depois da importação registram a árvore suja só por isso. Ficaram também `.import`
   e `.gd.uid` sem rastreio, gerados pelo editor, que não foram commitados.
5. **Arte-fonte.** Os PNG-fonte sem `.import` rastreado ficam fora do pacote, como na E08.
6. **Sonda de multidão sem HUD.** Descrito acima; não há medida do custo do HUD em jogo.
7. **Limitações herdadas de H2 e H4 (ficam como pontos de playtest, ver o roteiro):**
   - texto de aviso do atalho em fonte 9 ("SEM CARGA", "OCULTO"…): a legibilidade só se confirma em
     jogo;
   - o cast **concluído** do jogador só some, sem o flash de liberação (o mago emite `cast`, não
     `cast_release`); o flash de cancelamento funciona;
   - o selo do Espectro da Lâmina Arcana não aparece com **um** inimigo e dura 0,40 s com três;
   - o cone do Paladino segue a orientação atual do sprite, não a do cast;
   - os totais das barras de prazo vêm da ficha da skill pelo rank;
   - o DTO só lista recusas que não dependem de alvo;
   - um marcador sobre um inimigo atrás de uma ponte pode aparecer acima da ponte no mundo;
   - o cast de mob no mundo não teve captura própria na entrega;
   - a cor do elemento nos efeitos por evento (`draw_vfx`) segue fora do escopo, e o Paladino ainda usa
     a cor `arcane` no feedback de luz.
8. **Lacunas de áudio dos kits do E09** continuam (pulsos do Juramento e do Círculo Votivo, cura da
   Refração e o Espectro sem som).
9. **Pontos de aceite visual** estão detalhados em [playtest_guide.md](playtest_guide.md).

## Arquivos da H5

| Arquivo | Papel |
|---|---|
| `docs/epics/e12/h5_delivery.md` | este recibo |
| `docs/epics/e12/playtest_guide.md` | roteiro de playtest em pt-BR |
| `docs/epics/e12/h5_package.ps1` | cópia de `tools/e09_package.ps1` adaptada ao E12 |
| `docs/epics/e12/h5_pack_probe.gd.txt` | sonda do PCK para os scripts do E12 (`.txt` para o editor não importar) |

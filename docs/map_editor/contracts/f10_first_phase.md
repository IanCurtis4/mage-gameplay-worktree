# F10 — primeira fase completa (Q4)

3/11/2026. Contrato de Sol (Claude Opus, papel Astra para a arquitetura). Fontes:
[inserções de 2/11](f10_insertions.md), [estudo de escala](f10_field_scale_study.md),
[arquitetura de fase](f10_phase_architecture.md) e [regras da fase](f10_phase_rules.md).

## Pedido

Pelo menos dois mapas de campo na nova escala (9.000 a 11.000 u de lado), com
arquétipos de forma distintos, e um mapa de boss. Os mapas são autorados pela
Terra no modo AX, com 40 a 70 monstros por mapa de campo (uma espécie dominante,
2–3 secundárias e um guardião), publicados e jogados de verdade.

## Estado medido

- **Publicação** (`map_release.gd`, [consumo](../consumption.md)): um pacote
  `.rpp` é um mapa, com um único estágio `map_preview`. `prepare()` e
  `gameplay_candidate.prepare` leem só `stages[0]`.
- **Campanha:** o runtime e o estado aceitam vários estágios ligados por portais
  `travel` (a Travessia das Ruínas gerada tem 4).
- **Entrada no jogo:** o painel "Expedições" (`phase_selection_panel.gd`) monta
  só a Travessia (`data/expedition/phases/ruined_crossing.gd`).
- **Conteúdo:** nenhuma espécie tem categoria `boss` e nenhuma usa `charger` ou
  `flanker`. Biomas: `ruin`, `forest`, `desert`, `meadow`. Visuais de mob:
  `warrior`, `archer`, `gel`, `beast_master`, `animal_companion`.

## Decisões de arquitetura (Sol)

1. **Fase autorada = sequência de mapas publicados.** Um registro de fase
   (`data/expedition/phases/<fase>.json`, JSON estrito) lista, em ordem, os
   `package_id` publicados e as ligações: uma saída (`early_exit` ou portal) do
   mapa A leva à entrada do mapa B. O último mapa tem a `phase_completion`. A saída indicada pode ser uma `early_exit` ou a conclusão do próprio mapa, que nos mapas do meio vira o portal para o próximo.
2. **Compositor de fase** (`scripts/map_authoring/release/phase_release.gd`; a composição é pura): de cada pacote de patrulha validado tira o manifesto de um estágio,
   renomeia o estágio (`<fase>_<n>`) e prefixa superfícies, sockets, slots,
   objetivos, testemunhas e regras. Junta tudo num `ExpeditionManifest` de
   vários estágios e transforma cada ligação num portal `travel` (ida e volta),
   com âncoras na saída e na entrada. Cada mapa já chega certificado; o
   compositor confere que âncoras, superfícies e ids batem e recusa uma fase
   inválida sem gravar nada. O hash da fase cobre os hashes dos pacotes.
3. **Entrada no jogo:** o painel "Expedições" lista as fases (Travessia e a
   nova). A nova entra pelo mesmo `ExpeditionService.enter`, então valem as
   regras do Q2 (primeira jogada por personagem, guardiões, `stage_unlock`).
4. **Autoria pela Terra via AX:** terreno em grade de altura (Q1), composição,
   bordas, população e patrulha pelos comandos AX existentes, publicadas por
   `MapRelease.publish`. Nada de JSON de mapa escrito à mão.
5. **Prova:** etapa de fase (compor, validar, entrar, viajar entre estágios,
   concluir no boss), mais jogo real na janela e o tempo medido de cada mapa.

## Escolhas humanas (3/11)

- **Tema: floresta.** A fase continua a linha do Bosque do Santuário, com
  bordas de mata, clareiras e rio, e reaproveita os props e as bordas de
  floresta.
- **Formas:** o campo 1 é um prado em terraços com rio e rampas; o campo 2 tem
  vales em árvore entre paredões.
- **Chefe:** uma espécie nova de categoria `boss`, com visual existente maior e
  tingido, kit próprio (investida e chamado de lacaios) e alguns lacaios em volta.
- **Espécies:** três ou quatro espécies novas do tema, com visuais existentes
  tingidos: a dominante usa `chaser` e as secundárias, `charger`, `flanker` e
  `archer`.

## Consequência registrada

Acrescentar espécies ao catálogo muda o `catalog_hash` que os pacotes de
população fixam. O Bosque publicado precisa ser recompilado e republicado junto,
sem mudar a fonte.

## Estado

- Compositor entregue: `PhaseRelease` 11/11 (Bosque → Bosque). Preparar um mapa
  publicado leva ~112 s no quadro principal, então uma fase de três mapas paga
  isso três vezes ao entrar (limite do Q1, `start()` fora do quadro).

- Espécies entregues (`resources/forest_phase/mob`, carregadas com o catálogo de
  jogo): Lobo da Mata (`chaser`, dominante), Javali da Encosta (`charger`),
  Espreitador da Mata (`flanker`), Arqueiro da Copa (`archer`) e o chefe
  Guardião Ancestral (`charger`, só `boss`, convoca a fera). Elas usam as origens
  já publicadas `trial_stage_1` a `3` (níveis 2, 4 e 6) e as recompensas dessas
  origens; nenhuma política nova foi aberta. `ForestSpecies` 7/7, e os 9 passos
  do `verify.ps1` que leem o catálogo de jogo passam.
- **Bosque republicado** (`tools/map_editor_release/republish.gd`: o produtor de
  patrulha sobre a fonte commitada, sem cache, 75 s, e depois
  `MapRelease.publish`). A fonte é a mesma (`58df5d63…`); o pacote novo é
  `sanctuary_woods.41a8e11a6c70.rpp` (`41a8e11a…`). O `representative.rpp` de
  referência foi recompilado da mesma forma (`b6ffc4b6…`). Passam `ReleaseApi`,
  `AreaAcceptance`, `PhaseRelease`, `Workflow`, `ExchangeAssets`,
  `CandidateBatch`, `GameplayGate` e `PopulationReachability`. O arquivo antigo
  `sanctuary_woods.rpp` fica sem referência no registro, para a limpeza do Q5. O
  release exportado (M8 `release_bosque`) não foi rodado de novo.

- **Mapas autorados pelo AX** (`tools/map_editor_phase/forest_phase.py`, receitas
  executadas pelo `ax_session.gd`; nenhum JSON de mapa escrito à mão):
  - Prado dos Terraços: 10.240 u, três terraços com quatro rampas, borda
    íngreme, córrego raso, 12 aglomerados de cones rochosos, 196 objetos;
    62 monstros (lobo 65%), guardião Javali elite, santuário e saída norte.
  - Vales da Mata: 10.240 u, tronco, quatro ramos e galhos entre maciços de
    cristas íngremes alinhadas à grade, 12 clareiras, 102 objetos; 59 monstros
    (lobo 68%), guardião Espreitador elite, santuário e saída norte.
  - Covil do Guardião: 3.072 u, anel de cones com dois portões, Guardião
    Ancestral (`boss`) e quatro lobos, conclusão ao norte.
- **Publicados** (`republish.gd --new/--update`): `forest_terraces` 4,39 MB,
  `forest_valleys`, `forest_lair`; registro da fase
  `data/expedition/phases/forest_sanctuary.json`.
- **`ForestPhase` 9/9:** a fase prepara (190 s: 141, 41 e 8 s) e compõe 3
  estágios, 4 portais, 2 santuários e 1 conclusão; a campanha aceita; a primeira
  jogada abre pela limpeza e a repetição pelo guardião e depois pelo santuário.
  O manifesto da fase tem 1,53 MB.
- **O que a autoria revelou** (regras do jogo que a receita passou a seguir):
  todo chão andável relevante precisa ser alcançável (platôs, topos de mesa, fundo
  de rio estreito e prateleiras de clareira suave foram recusados), e todo trecho
  de 1024 u precisa de chão alcançável pelo corpo real do jogador. Um rio de
  margens íngremes amostrado em diagonal sempre deixa uma faixa plana isolada; o
  rio ficou raso e andável.
- **Limites de autoria agêntica medidos:** um traço de pincel num campo de
  161×161 custa 2–5 s; cada `objects/place` custava ~14 s (trocado por
  `objects/scatter`, ~70 s por sessão de prévia+aplicação); a prévia de população
  do campo 1 levou ~400 s (a espera do cliente AX subiu de 300 s para 30 min); a
  compilação de patrulha do campo 1 levou 282 s.
- **Teto do pacote de patrulha e de publicação:** 4 → 8 MiB
  (`patrol_compiler.MAX_PACKAGE_BYTES`), porque a patrulha embute o pacote de
  encontros (até 4 MiB) e um campo dessa escala passa de 4 MiB. Os tetos de
  terreno, mapa e encontros não mudaram.
- **Correção do Q2 achada aqui:** o comando AX `population/brush/upsert`
  recusava o campo `guardian` (o painel conferia o formato antigo).

## Bloqueio de persistência (3/11)

A etapa nativa `ForestPlay` entra na fase pelo painel "Expedições" (preparo na
thread do painel) e para no `enter` com `snapshot_too_large`:

| Medida | Valor |
| --- | --- |
| Envelope do snapshot | 10,6 MB (teto 4 MiB, `snapshot_graph_encoding.MAX_BYTES`) |
| Contêineres | 18.854, com 8,8 MB (dicionários 5,5 MB, arrays 2,8 MB) |
| Registros de objetos | 1.578, com 1,7 MB |
| Geometria por mundo | 490 KB, 453 KB e 48 KB |

O perfil, onde o checkpoint é gravado, também tem teto de 4 MiB
(`ProfileCodec.MAX_FILE_BYTES`). Um campo sozinho (`GridField`) dava 1,05 MB.

Antes disso, a entrada pelo lobby mostrou que o loot exige carta para quem não
está na lista de espécies sem carta; as espécies da floresta entraram nessa
lista (sem cartas por ora).

### Resolução (decisão humana de 3/11: "Aumente o teto, ou se não for possível, quebre o snapshot em partes.")

O teto subiu; não foi preciso dividir o snapshot. Os 10,6 MB eram o envelope
lógico; a codificação compacta da fase dá **4,96 MB**, logo acima dos 4 MiB.

| Teto | Antes | Agora | Medido |
| --- | --- | --- | --- |
| Snapshot codificado (`snapshot_graph_encoding.MAX_BYTES`) | 4 MiB | 16 MiB | 4,96 MB |
| Base64 do checkpoint (`expedition_checkpoint_codec.MAX_ENCODED`) | 6 MiB | 22 MiB | 567 KB |
| Arquivo do perfil (`ProfileCodec.MAX_FILE_BYTES`) | 4 MiB | 32 MiB | 574 KB |

O perfil subiu porque toda expedição concluída guarda seu checkpoint (prova do
mundo que pagou a conclusão): ~567 KB por conclusão da fase, ou seja, 4 MiB
encheria depois de umas seis. Com 32 MiB cabem ~55; podar checkpoints de
expedições concluídas é uma decisão de persistência em aberto.

**`ForestPlay` 8/8** (janela real): o painel lista a fase; entra (preparo na
thread + transação: 345 s no total, maior quadro 1,9 s); instala o primeiro
campo com 62 encontros; o portal começa fechado; o personagem anda 400 u;
suspende para o lobby (18,7 s) e retoma.

**Regressão:** passam os 19 passos de persistência do `verify.ps1` (perfil,
E07 F2, F3 e F4) e as etapas `SnapshotDensity`, `CampaignJournal`, `PhaseRules`
e `ForestSpecies`. Os passos E07 F8 298–299 contavam 11 espécies de produção (agora
16, nomeadas) e voltaram às mesmas falhas da base `3c35f7f2`.

**Limites medidos que continuam:**

- **Quadro no campo:** andando com 62 encontros e 196 objetos, o quadro médio foi
  de **147 ms** (pior 180 ms), cerca de 7 fps. O `GridField` sem atores desenhava
  no vsync; o custo está nos atores ou nos objetos em escala de campo. Precisa ser
  investigado antes de chamar a fase de jogável.
- **Transação completa:** suspender leva 18,7 s, e viajar por portal é a mesma
  transação, então cada portal congela o jogo por uns 18 s.
- **Entrada:** 345 s para entrar na fase (190 s de preparo dos três mapas).

## Desempenho no campo (3/11)

Pedido humano: "Sim, investigar". A etapa nativa `ForestProfile` abre o Prado
dos Terraços publicado no app de teste de jogo e mede o quadro em variantes
(inimigos pausados, mapa escondido, `sync` da vista desligado, interface,
`_process` do jogo e jogador). Contadores temporários, removidos depois,
localizaram o custo.

| Causa | Custo por quadro | Correção |
| --- | --- | --- |
| Cada inimigo traçava a visibilidade de cada ator da sua tabela de ameaça a cada quadro (`_advance_threat` → `world_can_reach`), mesmo ocioso e a quilômetros | ~139 ms com 62 inimigos | No mundo, a visibilidade só é traçada quando importa: inimigo engajado, provocado ou dentro do raio de aggro. Fora disso o ator conta como não visível, e o engajamento só acontece nesses casos. O ocioso também testa a distância de aggro antes da linha de visão |
| `CanvasOrder.apply` refazia a ordem de ~980 nós do desenho do campo a cada quadro, mesmo sem mudança, e `reveal_actors` comparava os props com os pés | ~14 + 3 ms | A vista recalcula ordem e oclusão só quando um ator se move ou aparece (ou o desenho muda), no máximo a cada 50 ms no laço do jogo (`sync()` direto sempre aplica); com campo de skill ativo, todo quadro. O solver não revalida o mesmo dicionário já validado, props guardam o registro no nó e o ator usa a maior altura já vista |

| Medida (janela real, 62 inimigos, 196 objetos) | Antes | Depois |
| --- | --- | --- |
| Parado, tudo ligado | 155 ms | 19,7 ms |
| Parado, inimigos pausados | 30 ms | 13,4 ms (vsync) |
| Andando (`ForestPlay`) | 147 ms | 21,4 ms (pior 38,5 ms) |

**Regressão:** `CanvasOrder`, `OcclusionNative`, `ShadowsNative`,
`GameplayNative`, `FieldsNative` (que acusou a primeira versão, sem os campos de
skill), `RuntimeView` e `ForestPlay`; 31 de 33 passos do `verify.ps1` de IA,
rota e mundo E07 F1 (os dois que falham são os da base: import nativo e
`presentation` 1/37).

**Ainda pendente:** a transação completa de suspender ou viajar por portal
(~18 s) e a entrada na fase (~337 s).

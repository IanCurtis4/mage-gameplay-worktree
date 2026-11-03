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
- **Pendente por consequência:** o Bosque publicado é recusado (`ReleaseApi`
  falha em `package_loads_with_its_pins`) até ser recompilado e republicado pelo
  fluxo do editor.

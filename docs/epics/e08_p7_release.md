# E08 P7-C3 — release Windows e candidato de playtest

Sol (Opus), 9/11/2026. [Contrato P7](e08_p7_contract.md), [posse](e08_p7_files.json)
(`C3_sol_release`). Branch `codex/e08`, checkout `.tools/map-editor-m5`. Sem commit/push/
merge por este pacote. O checkout habitual `codex/playtest`, o piloto P3
`pilot_ad09b99d` e os saves pessoais não foram tocados. Aprovação técnica não é aceite de
produto.

> **Candidato atual para o playtest: `261801de`** (pasta `e08_261801de`), com as correções do
> primeiro playtest (C5/C6) sobre `ba2a4b18` (C4). Detalhes na
> [seção final](#candidato-atual-261801de-c5c6). As seções abaixo descrevem, em ordem, o
> primeiro candidato `79656308` e o `ba2a4b18`, preservados como histórico.

## Candidato

- Commit `79656308a7e32cf6ee344d9b3eb179180fc3ab32` (coordenador, após aprovação do
  usuário). Contém P4/P5/P6 + acabamento C1 + ferramentas C3. A árvore rastreada estava limpa na
  exportação; os `.bak` não rastreados em `data/map_authoring/` não entram no PCK.
- Pasta isolada: `C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/playtest_e08/e08_79656308`.

| Arquivo | Bytes | SHA256 |
|---|---:|---|
| RagRPG-E08-Candidato.exe | 109127680 | 4a9eaded8955ef789ab02651ed9d2dde80328fbb342bd2a6db4db33e86305668 |
| RagRPG-E08-Candidato.pck | 236839412 | a4f3d54ac3e550a15155d83d75800c131849cafbfd86670b2583ddbc2bf4f878 |

O EXE tem os mesmos bytes do piloto P3: é o template release sem recursos alterados, porque
nome, ícone e versão estão vazios no preset. O PCK cresceu de 125.350.284 B (P3) para
236.839.412 B (+111,5 MB). A F10 tinha 94.914.128 B. O crescimento vem dos corpos direcionais
P4, das folhas P6, dos 75 sons P6, dos tiles v2, dos props e dos mapas republicados.

- Engine standard 4.7.2 `ed1daf0bf`: SHA256 `ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424`.
- Template Windows release: `windows_release_x86_64.exe`, SHA256
  `d34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562` (conferido antes da
  exportação).
- Nome do aplicativo **RagRPG E08 Candidato**, cena principal `res://scenes/character_menu.tscn`.
  Diferenças de empacotamento iguais às do piloto: VCS desligado, plugin de exportação do
  editor de mapas ligado (paridade de bytes `.import`), plugin git excluído, sem console
  wrapper. `project.godot`/`export_presets.cfg` da fixture foram restaurados e conferidos por hash.

## Exportação e proveniência

Ferramenta `tools/e08_p7_package.ps1` (derivada de `build_e08_pilot.ps1`). Sincronização
`C3_sol_release_sync_c3_sync_01`: 4 entradas novas (ferramentas C3) e 2900 fontes. Na
exportação, sob o lock da fixture:
- HEAD = candidato e árvore rastreada limpa;
- 2900 entradas do manifesto iguais na fonte e na fixture;
- os 2253 arquivos rastreados de runtime (`scripts scenes assets data resources content addons`)
  presentes e idênticos na fixture.

172 arquivos rastreados não estão na fixture. São fontes de arte, receitas, `delivery.md`,
`provenance.json` de staging e scripts `.py`, sem `.import` rastreado; não são recursos
exportados. Lista em `validation/fixture_parity.json`. A exportação levou 42 s, com saída 0 e
sem erro. Manifesto: `build_manifest.json`; execuções: `validation/runs.json`.

## Sondas no PCK exato (engine standard + `--main-pack`)

| Sonda | Resultado |
|---|---|
| `inspect_pack` (`tools/e08_p7_release_probe.gd inspect`) | **20/20**, nenhum ausente |
| `normal_boot` (EXE, 120 quadros) | saída 0, sem erro |
| `forest_map_pack` (`e08_p7_release_probe.gd forest`) | **19/19** |
| `export_content` (`tools/export_content_probe.gd`) | 2 falhas esperadas: mob 16/11 (oráculo E06 intacto, [triagem](e08_p7_triage.md) nº 9) |

**`inspect_pack`.** Identidade e perfil:
- nome do aplicativo, cena principal, registro da fase floresta, manifesto de preparação e
  limitador;
- diretório de usuário isolado (`…/profile_inspect/appdata/Godot/app_userdata/RagRPG E08 Candidato`).

Assets esperados, listados do próprio commit e todos presentes e carregáveis:
- 13/13 sons E08 e 75/75 sons P6 (`assets/audio/e08/p6/*`);
- 18/18 arquivos de folha VFX (`flipbook.json` + atlas);
- 55/55 arquivos de corpos direcionais e 2/2 atlas V1 lobo/javali;
- 3/3 tiles v2 (grama, terra, areia);
- 11/11 props, incluindo bétula, samambaia, flores, cogumelos e tronco;
- 21/21 artes de equipamento (`painted`/`headgear`);
- 19/19 arquivos de mapas e fases (`.rpp`, `.navproof`, registro, catálogo de props, fase floresta).

Funcional:
- 88/88 cues registrados e carregáveis (13 + 75 P6);
- 9/9 folhas válidas pelo `VfxFlipbookCatalog`, sem queda para o desenho em código;
- 19/19 manifestos direcionais e 5/5 corpos de espécie;
- 4/4 pacotes de mapa carregados (`sanctuary_woods`, `forest_terraces`, `forest_valleys`,
  `forest_lair`).

O PCK lista 3350 entradas em `validation/pack_listing.json`.

**`forest_map_pack`** (seed 42, 62 inimigos):
- menu empacotado cria personagem; entrada na floresta;
- UI 120% sem sobrepor rodapé/barra;
- corpos V2 de espécie (40 lobos, 10 javalis, 6 espreitadores, 6 arqueiros da copa; o Guardião
  fica no covil);
- camada `feedback_vfx_layer.gd` instalada; limitador privado; cama de ambiente "forest" e
  camada `ForestAmbience`;
- malha de terreno do minimapa; população marcada 62/62, incluindo inimigos fora da câmera;
- zoom 70% sem mudar mapa ou HUD; captura;
- suspensão e retomada com a preferência de zoom; corpos de espécie preservados;
- ambiente ativo sem transientes (efeitos 0 / interface 0 / ambiente 1); minimapa reconstruído.

Tempos: entrada 50,7 s, suspensão 8,0 s, retomada 42,6 s. Essas sondas rodam o PCK no
binário standard, não scripts dentro do template release. O template foi exercitado pelo
`normal_boot` e pelo smoke.

## Perfis de revisão, atalhos e smoke

O helper `tools/prepare_e08_p4_review_profile.gd` rodou contra o PCK exato, com APPDATA em
`profiles/<grupo>/appdata` e LOCALAPPDATA em `profiles/<grupo>/localappdata`. Ele usa apenas
ProfileFacade, PlaytestProfileAdmin, inventário e barra reais, e recusa perfil não vazio ou
destino fora do candidato. Por personagem:
- níveis máximos legais e habilidades legais do modo de teste, com a barra preenchida;
- peças existentes permitidas e a cabeça da própria classe equipada.

Nenhum item ou drop novo; nenhum save copiado.

| Grupo | Personagens | Revisão | SHA256 `profile.json` |
|---|---|---:|---|
| melee | E08 Espadachim, Defendente, Berserker | 46 | adeb86fa7bc054440f72889df0c197b42312ff53522927bcce45d62dc34d3798 |
| magic | E08 Mago, Elementalista, Espiritualista, Geômetra | 60 | b6dec962b62f831fed1100ec49344c79564055cfe3c3316dae26c8e4536e617b |
| ranged | E08 Arqueiro, Sentinela, Caçadora | 43 | d676a16cc05ccf10cc28525bc1139bd130bd5e271945deaa28afd673f7d333c5 |

**Atalhos.** `Jogar E08 - Corpo a corpo.lnk`, `- Magia.lnk` e `- Arco.lnk` chamam
`launch_<grupo>.cmd`. Cada `.cmd` define APPDATA/LOCALAPPDATA em `%~dp0profiles\<grupo>` e
abre o EXE.

**Smoke.**
- EXE com o perfil melee: janela "RagRPG E08 Candidato" viva após 25 s, fechada por
  `CloseMainWindow`, saída 0, sem erro no log, `profile.json` inalterado.
- `Jogar E08 - Arco.lnk` abriu a janela com o perfil `ranged`: log e shader cache criados ali,
  `profile.json` inalterado. Foi fechada em seguida.

Não existe `%APPDATA%/Godot/app_userdata/RagRPG E08 Candidato`: o perfil pessoal real não foi
usado. Nenhuma sessão interativa de combate foi certificada; isso é o playtest humano.

**Pasta.** `LEIA-ME.md` (pt-BR) e `review/` com:
- `ROTEIRO.md`, cópia de [e08_p7_playtest_guide.md](e08_p7_playtest_guide.md);
- `audio/`: prévia A3 de 50,8 s e rótulos;
- `p6_c1_antes_depois/`: folhas C1 antes/depois;
- `p5_floresta/`: bétula, decoração, covil e a captura do candidato.

## Medições

Resumo, com tabelas e protocolo em [e08_p7_measurements.md](e08_p7_measurements.md):
- 96 atores sem regressão; preparação inalterada.
- Memória: estática +17,9 MiB no pico, +7,6 MiB retidos (abaixo de 16), RSS +≈30 MiB.
- **Floresta parada: +14–16% na mediana e +17–18% no p95 contra a F10, reproduzível.** Atribuída
  às camadas de apresentação E08 sempre ativas: +34 draw calls do ambiente P5, redesenho ocioso
  da camada de feedback P6 e áudio. Sem as três camadas, a diferença cai para +5% / +8%.
- Correções possíveis dentro de arquivos de apresentação E08 foram registradas, não aplicadas,
  para manter o SHA do candidato:
  1. pular o redesenho sem pulsos;
  2. agrupar o desenho do ambiente;
  3. pré-carregar as folhas P6 (pico ≈63 ms na primeira carga).

## Editor de mapas — release

`tools/map_editor_candidate/run.ps1 -Stage Release`, executado sobre uma cópia isolada da
fixture (`.godot/verification/p7/C3_sol_release_m8_fixture_01`) para não reescrever o manifesto
nem o preset da fixture compartilhada. Evidência:
`.godot/verification/p7/C3_sol_release_m8_release_01`.
- Resultado: import, `export_release`, `release` 6/6, `release_bosque` 8/8 e `release_forest`
  14/14 em instalação limpa fora do projeto (pasta temporária removida). `M8_SELECTED_PASS`.
- Template `d34d36f3…0562`. PCK do editor `4cfffa07…b5b3` (320.373.992 B, em `.godot/m8_release/`;
  não é o candidato de playtest).
- Entradas: árvore em `45b930ba` + trabalho P7 ainda não commitado, com conteúdo igual ao que
  entrou em `79656308`.
- Testes nativos de UI do editor seguem fora de escopo (fixture espelho completa; contrato P7).

## Falhas conhecidas

As 10 falhas pré-existentes da suíte completa (C2: 312/322) estão na [triagem](e08_p7_triage.md).
Nenhuma vem de E08. A sonda `export_content` deste PCK reproduz a nº 9: 16 mobs contra 11
esperados desde a F10 Q4, oráculo inalterado.

## Limitações

- Correções de sondas feitas só em `tools/e08_p7_*`, depois do commit, portanto não commitadas:
  a ablação resolve o bus pelo nome. Não há outra mudança. Runtime e testes do candidato são os
  de `79656308`.
- Desempenho medido num só computador e só na floresta parada e em cenas sintéticas. Combate
  real, portais, sessões longas e outras GPUs não foram medidos. Não há promessa de 60 FPS na
  campanha.
- A regressão da floresta fica registrada com causa. A decisão de corrigir antes do aceite cabe
  ao coordenador e ao usuário.
- Visual, som e movimento dependem de avaliação humana: pontos fracos C1 e ordem
  `melee_swing`×`impact` no mesmo golpe.
- O checkout habitual `codex/playtest` não foi atualizado. Aplicá-lo é passo separado, com
  confirmação do usuário.
- Entrega documental desta etapa; a suíte de gameplay não foi repetida (C2/C3a regem).

## Candidato `ba2a4b18` (C4)

Commit `ba2a4b18ef1005ac46446c1006a65ba14492fafe`, do coordenador após decisão do usuário. É
`79656308` mais:
- as três correções de custo da floresta parada de [C4](e08_p7_perf_delivery.md);
- os documentos C3 e a correção da sonda de ablação.

Mudanças de runtime em quatro arquivos, todos de apresentação: `e08_pilot_feedback.gd`,
`feedback_vfx_layer.gd`, `forest_ambience_layer.gd` e `vfx_flipbook_catalog.gd`. Árvore rastreada
limpa; só os 4 `.bak` continuam não rastreados. Pasta nova e isolada:
`C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/playtest_e08/e08_ba2a4b18`. A pasta
`e08_79656308` ficou intacta: PCK `a4f3d54a…` conferido, nenhum arquivo alterado.

| Arquivo | Bytes | SHA256 |
|---|---:|---|
| RagRPG-E08-Candidato.exe | 109127680 | 4a9eaded8955ef789ab02651ed9d2dde80328fbb342bd2a6db4db33e86305668 |
| RagRPG-E08-Candidato.pck | 236846292 | d3844a2611d51f43184ee90ed3d814e8c61ceee700955f04888a125c54264f6b |

Engine `ab1824f8…b22424` e template `d34d36f3…0562` conferidos. O EXE é o mesmo template
release. As diferenças de empacotamento e o nome de aplicativo são os mesmos.

**Exportação.**
- Sincronização `C3_sol_release_sync_c3_sync_03`: 0 entradas, porque C4 já havia sincronizado.
- Na exportação: 2900 entradas do manifesto e 2253 arquivos rastreados de runtime iguais na
  fixture; os mesmos 172 não-runtime ausentes.
- Saída 0 em 34 s; fixture restaurada.

**Sondas no PCK exato.**
- `inspect_pack` **20/20**, nenhum ausente: 13 + 75 sons, 18 arquivos de folha (9/9 válidas),
  55 arquivos de corpos (19/19 manifestos, 5/5 espécies), 3 tiles v2, 11 props, 21 artes de
  equipamento, 19 arquivos de mapas (4/4 pacotes); 3350 entradas no PCK.
- `normal_boot`: saída 0.
- `forest_map_pack` **19/19**: 62 inimigos e corpos V2. Entrada 42,5 s, suspensão 7,5 s,
  retomada 19,9 s.
- `export_content`: as mesmas 2 falhas esperadas (mob 16/11).

**Perfis.** O mesmo helper, contra este PCK:

| Grupo | Revisão | SHA256 `profile.json` |
|---|---:|---|
| melee (3) | 46 | fffc19cddb1bd71a18c350b6366b7e3b90fe45327e66852b54f4ffdaf0116195 |
| magic (4) | 60 | 0d9a41e0863fc2c57a499ebd4eed54fbc0614f3fff447727eb195338e67d6005 |
| ranged (3) | 43 | 36949ee02ea7cefd454badfcb9bb1605e8b98fc148759a482156c45185f605e5 |

**Atalhos e smoke.**
- Três atalhos e `launch_<grupo>.cmd` iguais aos anteriores.
- Smoke do EXE com perfil melee: janela viva após 25 s, saída 0, sem erros, `profile.json`
  inalterado.
- `Jogar E08 - Magia.lnk` abriu o EXE desta pasta com o perfil `magic` (log criado ali,
  `profile.json` inalterado) e foi fechado.
- `%APPDATA%/Godot/app_userdata/RagRPG E08 Candidato` não existe.

**Pasta.**
- `LEIA-ME.md` (pt-BR) indica que esta pasta substitui `e08_79656308`.
- `review/` igual à anterior, com `ROTEIRO.md` atual e a captura deste candidato.

**Medições.** Detalhes na [seção `ba2a4b18`](e08_p7_measurements.md#candidato-ba2a4b18--depois-das-correções-c4-9112026),
evidência `C3_sol_release_measure_c4_01`, 26/26 sem erro.
- Floresta parada contra a F10: de **+14–16% / +17–18%** para **+7% / +1–6%**. Contra o P3,
  +4% / +2–3%. Draw calls 616 contra 614 (antes 648).
- 96 atores: −8% em movimento. Parados, +12% na mediana (+0,4 ms), com p95 de +3%; registrado
  com causa provável no corpo direcional P4 ocioso, sem correção.
- Pico da primeira folha P6: cerca de 63 → 38 ms.
- Memória dentro da triagem (retido +7,7 MiB contra a F10). Memória privada +30–40 MiB pela
  pré-carga.
- Entrada e preparação iguais à F10.

**Editor de mapas.** O release de `79656308`/45b930ba+P7 (acima) não foi repetido. C4 não mudou
mapas, editor nem exportação do editor: só quatro scripts de apresentação do jogo, mais testes e
documentos.

**Limitações.** As mesmas da seção anterior. Além delas:
- correção de sonda feita depois do commit: nenhuma nesta rodada;
- as falhas pré-existentes da [triagem](e08_p7_triage.md) continuam;
- a suíte de gameplay não foi repetida por este pacote (C4 registra seus próprios testes).

## Candidato atual `261801de` (C5/C6)

Commit `261801def65bb9022d7d5ffdd8c3b5bc82fd1246`, do coordenador após o primeiro playtest do
usuário. É `ba2a4b18` mais duas entregas:
- [C5](e08_p7_playtest_fixes_delivery.md): sem rastro do caminho; ataque básico sem rajada de
  lançamento e com acerto branco; cues `p6.aa.hit_body/hit_blunt/hit_sharp/bow_release`;
- [C6](e08_p7_head_fit_delivery.md): peças de cabeça encaixadas por classe e quadro via
  `scripts/actors/equipment_head_fit_data.gd`.

Árvore rastreada limpa no commit; só os 4 `.bak` continuam não rastreados. Pasta nova:
`C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/playtest_e08/e08_261801de`. As pastas
`e08_79656308` e `e08_ba2a4b18` ficaram intactas (PCKs `a4f3d54a…` e `d3844a26…` conferidos,
nenhum arquivo alterado), assim como o piloto P3.

| Arquivo | Bytes | SHA256 |
|---|---:|---|
| RagRPG-E08-Candidato.exe | 109127680 | 4a9eaded8955ef789ab02651ed9d2dde80328fbb342bd2a6db4db33e86305668 |
| RagRPG-E08-Candidato.pck | 236957084 | 843d1ab723c9db22a72fe49ec5420b4c14d18f135c58127051f54ae1e95fbfc2 |

Engine `ab1824f8…b22424` e template `d34d36f3…0562` conferidos; empacotamento igual.

**Ferramentas.** Duas mudanças em ferramentas de empacotamento, feitas depois do commit e não
commitadas; nenhuma toca o runtime:
- `tools/e08_p7_release_probe.gd` verifica a tabela de encaixe e carrega o `.gd` pelo carregador
  de recursos, porque o PCK guarda scripts remapeados.
- `tools/e08_p7_package.ps1` passou a aceitar, na exportação, edições não commitadas apenas em
  `docs/` e `tools/e08_p7_*`. Qualquer outra mudança rastreada continua bloqueando.

Sincronizações `c3_sync_04`/`c3_sync_05`: 2 e 1 entradas, só essas ferramentas; 2911 fontes.

**Exportação.** 2911 entradas do manifesto e 2262 arquivos rastreados de runtime iguais na
fixture; os mesmos 172 não-runtime ausentes. Saída 0 em 37,5 s; fixture restaurada.

**Sondas no PCK exato.**
- `inspect_pack` **22/22**, nenhum ausente:
  - 13 sons E08 e **79** P6, incluindo os 4 `aa_*`; **92/92** cues registrados e carregáveis;
  - **tabela de encaixe no PCK e carregável:** formato `ragrpg_head_fit_v1`, 10 classes,
    640 quadros;
  - 9/9 folhas, 19/19 manifestos direcionais, 5/5 espécies, 4/4 pacotes de mapa;
  - 3362 entradas no PCK.
- `normal_boot`: saída 0.
- `forest_map_pack` **19/19**: 62 inimigos e corpos V2. Entrada 48,2 s, suspensão 8,2 s,
  retomada 23,7 s.
- `export_content`: as mesmas 2 falhas esperadas (mob 16/11).

**Perfis.** O mesmo helper, contra este PCK:

| Grupo | Revisão | SHA256 `profile.json` |
|---|---:|---|
| melee (3) | 46 | 60973e40aa6a73336a31591a126a683738f4f46ce5f5a62b0351f42b22be085a |
| magic (4) | 60 | 1791fd352089aadee6cd38973ef970b06662547eea2fd8ce139bf1ee98825afb |
| ranged (3) | 43 | 008ba148993ee29ff6f92e1fa0e084f4eb3ec3dd1093f60619e6a7e7eca6a9fd |

**Atalhos e smoke.**
- Três atalhos e `launch_<grupo>.cmd`, como antes.
- Smoke do EXE com perfil melee: janela viva após 25 s, saída 0, sem erros, `profile.json`
  inalterado.
- `Jogar E08 - Corpo a corpo.lnk` abriu o EXE desta pasta e foi fechado.
- `%APPDATA%/Godot/app_userdata/RagRPG E08 Candidato` não existe.

**Pasta.** `LEIA-ME.md` (pt-BR) indica que esta pasta substitui `e08_ba2a4b18`. `review/` contém:
- `ROTEIRO.md` atualizado, com a seção "Correções do primeiro playtest";
- `audio_c5_ataque_basico/`: clipe C5 antigo × novo e rótulos;
- `c6_cabeca_antes_depois/`: antes/depois de Arqueiro, Berserker, Defendente, Caçadora, Mago e
  Elementalista, a partir das capturas nativas `C6_..._fin2_b260`/`a260`;
- além da prévia A3, das folhas C1, das capturas P5 e da captura deste candidato.

**Medições.** Rodada curta (floresta + ablação, F10 contra candidato, 2 rodadas), detalhes em
[e08_p7_measurements.md](e08_p7_measurements.md). Evidência `C3_sol_release_measure_c5c6_01`:
8/8 execuções sem erro.
- Floresta natural: +5% / +6% contra a F10.
- Ablação, controle normal: +9% / +7%.
- Sem regressão nova, dentro da faixa de `ba2a4b18` numa sessão mais ruidosa (F10 em 12,0 ms).
- Draw calls 616 contra 614. Memória igual a `ba2a4b18`.

**Editor de mapas.** O release não foi repetido: C5/C6 não mudaram mapas, editor nem exportação
do editor. O resultado anterior PASS (6/8/14) continua válido.

**Limitações.**
- As falhas pré-existentes da [triagem](e08_p7_triage.md) continuam.
- A suíte de gameplay não foi repetida por este pacote; C5/C6 registram seus próprios testes.
- Limites visuais de C6 a julgar em jogo: cabelo do Berserker nas laterais; chapéu da Caçadora;
  fitas da grinalda e do véu no rosto de lado; tiaras por design.
- Sem promessa de FPS para a campanha inteira.

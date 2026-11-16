# E08 P7-C3 — release Windows e candidato de playtest

Sol (Opus), 9/11/2026. [Contrato P7](e08_p7_contract.md), [posse](e08_p7_files.json)
(`C3_sol_release`). Branch `codex/e08`, checkout `.tools/map-editor-m5`. Sem commit/push/
merge por este pacote. O checkout habitual `codex/playtest`, o piloto P3
`pilot_ad09b99d` e os saves pessoais não foram tocados. Aprovação técnica não é aceite de
produto.

> **Candidato atual P7: `d6004142`** (pasta `e08_d6004142`), que é o `6b42b305` com a arte nova
> da grinalda do Elementalista e do chapéu da Caçadora (C8). Detalhes na
> [seção final](#candidato-atual-p7-d6004142-c8). As seções abaixo descrevem, em ordem, os
> candidatos `79656308`, `ba2a4b18`, `261801de` e `6b42b305`, preservados como histórico.

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

## Candidato `261801de` (C5/C6)

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

## Candidato final P7 `6b42b305`

Commit `6b42b305abc24eec774bd20acb73cee15174b71d` (coordenador). É `261801de` mais C7, a
[rodada 2](e08_p7_playtest_fixes_delivery.md) do playtest:
- a linha de mira de habilidade não é mais desenhada nem fica presa no chão;
- acerto branco no ataque automático de todas as classes e evoluções, na garra e na flecha
  inimigas e nas habilidades físicas comuns.

Só apresentação; nenhum som ou WAV mudou. O usuário aceitou os efeitos provisoriamente (falta
o teste de um amigo) e pretende fechar a P7 com este candidato.

- Pasta: `C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/playtest_e08/e08_6b42b305`.
- Pastas intactas, com PCKs conferidos e nenhum arquivo alterado: `e08_79656308` (`a4f3d54a…`),
  `e08_ba2a4b18` (`d3844a26…`), `e08_261801de` (`843d1ab7…`) e o piloto P3 (`d91bc713…`).

| Arquivo | Bytes | SHA256 |
|---|---:|---|
| RagRPG-E08-Candidato.exe | 109127680 | 4a9eaded8955ef789ab02651ed9d2dde80328fbb342bd2a6db4db33e86305668 |
| RagRPG-E08-Candidato.pck | 236961436 | 6529da02b48ca1a02866f048b11c90bbce5728f8e7056c7f37f21e5caf73191c |

**Exportação.**
- Engine `ab1824f8…b22424` e template `d34d36f3…0562` conferidos.
- Sincronização `c3_sync_07`: 0 entradas.
- 2911 entradas do manifesto e 2262 arquivos rastreados de runtime iguais na fixture; os mesmos
  172 não-runtime ausentes. Saída 0 em 42,1 s; fixture restaurada.
- A execução foi interrompida por limite de API depois da inspeção. Na retomada, EXE e PCK foram
  conferidos contra `build_manifest.json` (bytes e SHA256) e HEAD `6b42b305`; não houve
  reexportação.

**Sondas no PCK exato.**
- `inspect_pack` **22/22**, nenhum ausente: 79 sons P6, 92/92 cues, tabela de encaixe
  `ragrpg_head_fit_v1` (10 classes, 640 quadros), 9/9 folhas, 19/19 manifestos, 5/5 espécies,
  4/4 pacotes de mapa; 3362 entradas.
- `normal_boot`: saída 0.
- `forest_map_pack` **19/19**: 62 inimigos. Entrada 50,5 s, suspensão 8,7 s, retomada 23,5 s.
- `export_content`: 2 falhas esperadas (mob 16/11).

**Perfis.**

| Grupo | Revisão | SHA256 `profile.json` |
|---|---:|---|
| melee (3) | 46 | 374d3ff8f5082a60ab5e3f41e55e1cbdae571316906d2777a82621d8d08163c9 |
| magic (4) | 60 | 71787412ed589b101207fde0663b87d437a7ba52747d8775e86beb681bb1d7f2 |
| ranged (3) | 43 | b29b04265919605792fad6ea6b5b773b7a93ea04413e7c6e9dc5f47110ca7c19 |

**Atalhos e smoke.**
- Três atalhos e `launch_<grupo>.cmd`.
- Smoke do EXE com perfil melee: janela viva após 25 s, saída 0, sem erros, `profile.json`
  inalterado.
- `Jogar E08 - Arco.lnk` abriu o EXE desta pasta com o perfil `ranged` (log criado ali,
  `profile.json` inalterado) e foi fechado.
- `%APPDATA%/Godot/app_userdata/RagRPG E08 Candidato` não existe.

**Pasta.** `LEIA-ME.md` (pt-BR) a apresenta como candidato final P7 e indica que substitui
`e08_261801de`. `review/` traz:
- `ROTEIRO.md` com a nova seção "Correções do segundo playtest";
- `c7_rodada2_antes_depois/`: linha de mira inválida 1,5 s depois e acertos físicos;
- o clipe C5, o antes/depois C6, a prévia A3, as folhas C1 e as capturas P5.

**Medições.** Detalhes na seção `6b42b305` de [e08_p7_measurements.md](e08_p7_measurements.md):
- Floresta natural contra a F10: +5% a +12% na mediana e +4% a +11% no p95, conforme a sessão.
- Contra `261801de` na mesma sessão: +0% a +3%, sem padrão entre as ablações. É ruído; o código
  C7 não roda sem impactos.
- Nenhuma regressão atribuível a C7.

**Ferramenta.** `tools/e08_p7_package.ps1` ganhou `-ReferencePack`/pacote `reference`, para medir
um candidato anterior na mesma sessão. A mudança é só de ferramenta, ainda não commitada.

**Editor de mapas.** O release não foi repetido: C7 não muda mapas, editor nem exportação do
editor. Continua valendo o PASS (6/8/14).

**Limitações.** As da seção `261801de`. Além delas:
- a linha de mira deixou de aparecer também quando válida (decisão C7);
- não houve audição nova, porque nenhum áudio mudou;
- a suíte completa não foi repetida; C7 registra seus próprios 14 testes.

## Candidato atual P7 `d6004142` (C8)

Commit `d60041425d4d1822f252816c6574877deea1308b`, do coordenador após o fechamento da P7. O
usuário aprovou gerar um novo candidato. É `6b42b305` mais
[C8](e08_p7_head_fit_delivery.md#arte-nova-do-codex-c8): redesenhos do Codex da grinalda do
Elementalista e do chapéu da Caçadora. Os IDs são os mesmos; mudaram as revisões dos PNGs, a
tabela `scripts/actors/equipment_head_fit_data.gd` regenerada e as fontes em staging com
proveniência. Só arte e dados de encaixe.

Pasta: `C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/playtest_e08/e08_d6004142`. As pastas
`e08_79656308`, `e08_ba2a4b18`, `e08_261801de`, `e08_6b42b305` e o piloto P3 ficaram intactas
(PCKs conferidos, nenhum arquivo alterado).

| Arquivo | Bytes | SHA256 |
|---|---:|---|
| RagRPG-E08-Candidato.exe | 109127680 | 4a9eaded8955ef789ab02651ed9d2dde80328fbb342bd2a6db4db33e86305668 |
| RagRPG-E08-Candidato.pck | 236941180 | 98636294a012a87b61c3ea3dee3b9f221d3bec8e9ea09d44669ddc7105a5b0e3 |

**Exportação.**
- Engine e template conferidos.
- Sincronização `c3_sync_09`: 3 entradas — as duas ferramentas abaixo e o `provenance.json` de
  staging C8. As duas peças PNG e a tabela de encaixe já estavam sincronizadas pela C8.
- 2915 entradas do manifesto; arquivos rastreados de runtime iguais na fixture.
- Saída 0 em 34,5 s; fixture restaurada.

**Sondas no PCK exato.**
- `inspect_pack` **23/23**, nenhum ausente: 79 sons P6, 92/92 cues, 9/9 folhas, 19/19 manifestos,
  5/5 espécies, 4/4 pacotes de mapa, 21/21 artes de equipamento; 3363 entradas.
- **Nova verificação `headgear_imports_match_commit_png`: 14/14.** O PCK guarda o `.ctex`
  importado, não o PNG. Para cada peça de cabeça, a cadeia conferida é:
  1. blob do commit = arquivo na árvore;
  2. MD5 do PNG da fixture = `source_md5` do import;
  3. SHA256 do `.ctex` da fixture = SHA256 do `.ctex` dentro do PCK;
  4. a textura carrega.
- As duas peças novas:
  - `class_set_elementalist_head.png`: PNG `a045332f173a6f29…e72c` → `.ctex` no PCK `c930a7c0dc4554f9…`;
  - `class_set_hunter_head.png`: PNG `a3b334d6ce0a4863…eafd` → `.ctex` no PCK `64ba89fad14be17a…`.
- **Tabela de encaixe** no PCK e carregável: `ragrpg_head_fit_v1`, 10 classes, 640 quadros.
- `normal_boot`: saída 0.
- `forest_map_pack` **19/19**: 62 inimigos. Entrada 50,6 s, suspensão 9,1 s, retomada 24,7 s.
- `export_content`: 2 falhas esperadas (mob 16/11).
- Registro honesto de `validation/runs.json`:
  - a primeira inspeção falhou na versão anterior desta verificação, que comparava pixels do PNG
    com a textura e falhou nas 14 peças, inclusive nas inalteradas. Não é válida, porque o
    import altera pixels (provavelmente a correção de borda alfa). Foi substituída pela
    cadeia acima;
  - uma repetição da sonda da floresta reutilizou o perfil já com personagem e falhou em
    `packaged_menu_creates_character`. A ferramenta passou a usar perfil novo por execução.
  - Valem a primeira floresta 19/19 e a rodada final completa: 23/23, saída 0, 19/19.

**Ferramentas.** Só ferramentas, ainda não commitadas:
- `tools/e08_p7_release_probe.gd`: verificação da cadeia de import das peças;
- `tools/e08_p7_package.ps1`: entradas `image_identity` e perfil novo por execução da inspeção.

**Perfis.**

| Grupo | Revisão | SHA256 `profile.json` |
|---|---:|---|
| melee (3) | 46 | 08bbad6418da245cb232116bcf4820617589374799cfe8d018d195b35a29123c |
| magic (4) | 60 | bbdfb735706eac2da463a325bab6455572bde52e05f68f8cfb09dce7628cd85b |
| ranged (3) | 43 | 49886911f0bcc1e83d4a3c89ca694f072883cb4e59494c9b3e4096a7b20c16d8 |

**Atalhos e smoke.**
- Três atalhos e `launch_<grupo>.cmd`.
- Smoke do EXE com perfil melee: janela viva após 25 s, saída 0, sem erros, `profile.json`
  inalterado.
- `Jogar E08 - Magia.lnk` abriu o EXE desta pasta com o perfil `magic` (log criado ali,
  `profile.json` inalterado) e foi fechado.
- `%APPDATA%/Godot/app_userdata/RagRPG E08 Candidato` não existe.

**Pasta.** `LEIA-ME.md` (pt-BR) indica que esta pasta substitui `e08_6b42b305` como candidato
atual da P7. `review/` contém:
- `ROTEIRO.md` com a seção "Arte nova de cabeça";
- `c8_arte_cabeca_antes_depois/`: Elementalista e Caçadora, personagem e página da peça, zoom
  160%, de `C8_terra_head_art_probe_c8_old160`/`_c8_fin160`;
- os conteúdos anteriores (C7, C6, C5, A3, C1, P5).

**Medições.** Não foram feitas, por decisão do coordenador: a mudança é só de arte, com o mesmo
tamanho de folha (384×96) e o mesmo caminho de desenho. Valem as de `6b42b305`.

**Editor de mapas.** O release não foi repetido.

**Limitações.** As de `6b42b305`. A avaliação visual das peças novas em jogo é humana.

## Candidato integrado E08 `db7f9252`

Commit `db7f9252f5d3f814e22dbb1ecf294ce62c605c83`, gerado em 14/11/2026 a pedido do usuário
("Preparar o release"). É `2d191956` mais `db7f9252`:
- `2d191956` traz a integração E08 pós-C8:
  - save compacto (formato 3) com a cobertura;
  - cache de sessão da fase publicada;
  - nomes simples das híbridas e os rótulos Bastião, Possesso e Rastreador;
  - ícones pintados, corpos direcionais, efeitos e a arte do Codex 1114–1118, com os briefings
    1114–1119.
- `db7f9252` tira do rastreamento os 145 `.import` que o editor gerou para arte-fonte e estudos.
  Os arquivos ficam no disco, e os PNGs continuam versionados sem import, como manda a regra do
  pacote.

Ficaram fora do commit as evidências antigas não versionadas de `docs/**/evidence` e quatro `.bak`
do editor em `data/map_authoring/`.

Pasta: `C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/playtest_e08/e08_db7f9252`. As pastas
anteriores, inclusive `e08_d6004142`, ficaram intactas; o PCK C8 continua `98636294…`.

| Arquivo | Bytes | SHA256 |
|---|---:|---|
| RagRPG-E08-Candidato.exe | 109127680 | 4a9eaded8955ef789ab02651ed9d2dde80328fbb342bd2a6db4db33e86305668 |
| RagRPG-E08-Candidato.pck | 244913684 | 3d7456fb4734d294a18940a232fcb2af1799ee3ec9aebfc18bab00f384687330 |

**Suíte.** `release_full02`, completa e sincronizada: 324/328 passos selecionados passaram. As
quatro importações no editor ficam de fora por definição do modo `-Full`. `checks.jsonl` SHA256
`18e74e825b8c51523dbb0bdb9f3b2fa94a71d9d3ddd68343aa2622e7fcfaf20f`.

A primeira tentativa (`release_full01`) parou na sonda F8 `prepare`, porque a saída de 13/11 ainda
guardava o perfil sintético e a sonda exige um perfil novo. Essa saída foi arquivada como
`probe_headless_stale_1113`, sem nenhuma mudança de código.

**Exportação.**
- Engine e template conferidos.
- Paridade da fixture: 3054 entradas do manifesto, com cinco `.uid` de scripts novos alinhados à
  fonte. Nenhuma cena ou recurso os referencia.
- Saída 0 em 34,2 s; fixture restaurada.

A primeira tentativa sobre `2d191956` foi recusada pela paridade: faltavam na fixture os `.import`
da arte-fonte. Daí veio `db7f9252`.

**Sondas no PCK exato.**
- `inspect_pack` **23/23**, nenhum ausente, 3509 entradas:
  - 13/13 sons E08 e 79/79 sons P6;
  - 38/38 manifestos de efeito e 55/55 corpos direcionais;
  - 21/21 artes de equipamento, 19/19 pacotes de mapa, 11/11 props e 3/3 terrenos v2;
  - cadeia de import das cabeças e tabela `ragrpg_head_fit_v1` (10 classes, 640 quadros).
- `normal_boot`: saída 0.
- `forest_map_pack` **19/19**, 62 inimigos. Entrada 44,8 s, suspensão 6,8 s, retomada 18,6 s; no
  C8 eram 50,6 s, 9,1 s e 24,7 s. É uma execução só, sem pareamento. A comparação pareada é
  `save_pair_02`.
- `export_content`: 0 falhas, 16 definições de mob.

**Perfis, atalhos e smoke.**
- Perfis `melee`, `magic` e `ranged`: saída 0.
- Atalhos "Jogar E08 - Corpo a corpo", "Magia" e "Arco".
- Smoke: janela viva após 25 s, fechada pedindo, sem linhas de erro, perfil `melee` inalterado.

`runs.json` SHA256 `a6cf64ae3b7c4f9e0a30eb7ffa685b796bcefe69276a5432e4bb382645926963`;
`build_manifest.json` SHA256 `54b5b026b78f789cf5a5518470f5a6014b8ba3e737f7fc4b92782a7b055de973`.

**Medições.** A etapa `Measure` (F10, piloto e candidato) não foi repetida. Valem a medição pareada
do save `save_pair_02` e a decomposição da retomada registradas em [E08](e08.md).

**Editor de mapas.** O release não foi repetido.

**Limitações.**
- Com o jogo reaberto, a retomada compacta ainda paga ~11 s de preparação da fase. O cache só vale
  dentro da mesma sessão.
- A arte do Codex 1116–1118 está versionada, mas ainda não foi empacotada no jogo. As adagas
  separadas (briefing 1119) não foram geradas.
- A avaliação visual e de produto é humana. Aprovação técnica não é aceite do usuário; o playtest
  habitual e `master` não foram tocados.

## Aceite do usuário — 16/11/2026

O usuário aprovou o candidato `db7f9252` depois do teste ("Aprovado", 16/11/2026). Aprovação de
produto do E08 com a arte atual das classes; a arte híbrida em staging (1116–1123) não entra no
pacote, e o pedido 1124 fica pendente. Seguem o avanço do playtest habitual (`codex/playtest`) e
o merge em `master`, sem push, registrados abaixo.

### Playtest habitual e master — 16/11/2026

- **Playtest habitual** (`C:/Users/João Pedro/Documents/ChatGPT/RagRPG`, `codex/playtest`): avanço por
  fast-forward de `fba777b3` até o commit aceito `fc91ea66`. Antes do avanço, as 241 alterações
  locais foram copiadas, com SHA256, para `.tools/playtest_backup_e08_20261116/`
  (`inventory_before.json`, SHA256 `53735c70c437049dc5e3386b851cae7a378fcd33bb252ad6dad6b69895094e5f`).
  - 27 caminhos locais coincidiam com o delta do candidato. 20 não rastreados eram idênticos ao
    candidato e foram removidos antes do avanço; voltaram iguais. 5 rascunhos não rastreados de
    `docs/map_editor/` eram diferentes e ficam só no backup.
  - As duas edições locais foram reaplicadas por patch de três vias (`local_changes_overlap.patch`):
    `export_presets.cfg` mantém o `export_path` local `v0.6` com os `include_filter` do E08, e
    `docs/epics/e07.md` mantém a seção local do editor de mapas junto ao encerramento do E07.
  - As outras 214 alterações locais continuam byte-idênticas, e os 5 arquivos de save pessoal
    (`profile.json`, `profile.backup.json`, `controls.cfg` e `admin_backups`) conferem por hash,
    sem abrir o conteúdo (`inventory_after.json`, SHA256 `d3c1f259c3d935c1f08d0be1b7723ab13b16eb9d339778ce40c85dfcf17fd21a`).
  - Importação headless do Godot 4.7.2 no diretório habitual com APPDATA isolado: saída 0, 259 s,
    sem linhas de erro. Smoke headless de 600 quadros na cena principal, em perfil isolado: saída 0,
    13 s, sem erro. A importação regravou 1.675 `.import` só no fim de linha (LF/CRLF), o mesmo caso
    dos 213 que já estavam modificados; só os dois arquivos acima têm mudança real.
- **master**: fast-forward de `3c35f7f2` (F9) até este registro, histórico linear como na F9, sem
  push.

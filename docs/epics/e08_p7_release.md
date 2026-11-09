# E08 P7-C3 — release Windows e candidato de playtest

Sol (Opus), 9/11/2026. [Contrato P7](e08_p7_contract.md), [posse](e08_p7_files.json)
(`C3_sol_release`). Branch `codex/e08`, checkout `.tools/map-editor-m5`. Sem commit/push/
merge por este pacote. O checkout habitual `codex/playtest`, o piloto P3
`pilot_ad09b99d` e os saves pessoais não foram tocados. Aprovação técnica não é aceite de
produto.

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

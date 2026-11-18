# E10a T8 — corpos das três classes (Acólito, Sacerdote, Cultista): recibo de entrega

Tarefa **T8** de [e10a.md](../e10a.md), contrato **C4.2** de [e10a_contract.md](../e10a_contract.md) (§5.2).
Papel: Terra (Claude Sonnet 5.5, esforço alto). Data: 18/11/2026. Estado proposto: **ENTREGUE**;
validação técnica e composição ficam com a T13. O aceite visual das mãos e da cabeça é do usuário.

## Base e entrega

| Item | Valor |
|---|---|
| SHA-base | `5f702caa6a5d38a9c59e23dab2e8e142163bd659` (`git log -1` depois de `git merge --ff-only claude/e10a-candidato`; worktree nascida de `7795f56d`) |
| T9 na base | `git merge-base --is-ancestor 6b7e3df8 HEAD` verdadeiro (A12) |
| Branch | `claude/cool-northcutt-0a2f7d` |
| Checkout | `C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.claude\worktrees\cool-northcutt-0a2f7d` |
| Commit | ponta da branch, informada na mensagem final (um recibo não contém o próprio SHA) |
| Push / `master` / `codex/playtest` / save pessoal / branch de arquitetura | não tocados nem mesclados |

## O que foi entregue

### 1. Atlas V2/64 (`ragrpg_directional_animation_v2`) em `assets/art/e08_characters/directional/<pasta>/`

Cada pasta: `body.png` = `weaponless.png` (256×1024, 64 células, pivô (32,58)), `calibration.json`,
`calibration_authoring.json` (correções manuais), `presentation.json`, `provenance.json` (v2, dois registros, quatro
vistas escolhidas e um passo `post` por vista), `recipe.md`, `source_recipe.json`, `delivery.md` e os `.import` dos
dois atlas. Sem geração nova de arte: as fontes são os 12 PNG que a T2 deixou versionados (SHA256 conferidos pelo
`selection.json`). Sem `.import` de arte-fonte.

| Pasta | Fontes (lote) | SHA256 de `body.png` | RGBA canônico | Escala global |
|---|---|---|---|---|
| `acolyte` | 1116: `south_v5`, `east_v3`, `west_v3`, `north` (as três últimas normalizadas) | `3436347ce3cccc9dd768d1c3732435f2b580a0ef50fa3d1c7ed6afc313157690` | `c3efbf64b806238962354c516e0c8034cd0071c9ab501ba131c14fb71d62bbd5` | 0,2041 |
| `priest` | 1118: `south`, `east`, `west_v2`, `north` | `ec071b784ca3a90eeb2a0f807a723a7adbce08ab1cfd3d1e81ff70c26a7634e7` | `e5ac110c42c749bc2965f44ebfc337ce8dd7342ab3e1d9fc8f30f8faa435cd22` | 0,1938 |
| `cultist` | 1118: `south`, `east`, `west`, `north` | `ac3d1aea2941def8f5fc501c51b5c8b755a571133eecb59f38cceb175ace33d9` | `8bba5b2127657eb441ba77fd06ca2edef7dbe39d6fb1adc4b26dff0e482582d5` | 0,2012 |

| Pasta | `presentation.json` | `calibration.json` |
|---|---|---|
| `acolyte` | `64ca1f656a5a390df1e57dae19cd07a3e8dfd21d8a94be9b4a0190f991802f15` | `a52fa441118eeed8e266743a11830a2b470f5de98820a8539da915d98614701e` |
| `priest` | `9e7d203ca28e6245b15f75134aeca6144a32b09b8751e6183da952c67d115026` | `3b250459b55da95a4d18b417efd71e8a73b15285ee40facdc2a0dda7d5c96306` |
| `cultist` | `b0af3f70b6698d6313c9cc7ec74922f6e4d4557632c8c1007ee40e88ca3c88de` | `977a1969ecb8df938ce9f6f58ec2389fea97b32b980bcb5c19ef7e3b425e622f` |

`provenance.py check`: 0 problemas nas três. `python -I -m unittest discover -s tools/art_pipeline/tests`: 89 testes, OK.

### 2. Validação e normalização de escala (pipeline neutro)

`validate_sheet.py --kind character_view --reference south --set …` sobre as 12 folhas: 0 erros; só avisos de véu de
alfa (o empacotador remove) em todas e `scale_mismatch` no **Acólito**: leste 0,868, oeste 0,836 e norte 1,120 da altura
parada do sul (a folha norte do 1116 é 1108×1420 e a leste/oeste 1312×1199, não quadradas). `normalize_scale.py`
(`nearest`, sem suavização) igualou as três à vista sul (246 px de altura parada, razão 0,998 depois); as folhas
normalizadas (`east_normalized.png`, `west_normalized.png`, `north_normalized.png`, 1,0–1,2 MB cada) estão versionadas
em `acolyte/` porque a receita as lê, e o `provenance.json` registra cada passo com hashes de entrada e saída. Sacerdote
e Cultista chegaram na mesma escala nas quatro vistas e não foram normalizados. O teste confere que as alturas paradas
dos quatro lados ficam a ≤ 6 % entre si.

### 3. Empacotador, calibração e proveniência

- `tools/prepare_e08_directional_art.py`: três identidades novas em `KINDS` (nada mais mudou; o código de empacotamento
  é o mesmo, então as 14 identidades anteriores continuam byte a byte).
- `tools/prepare_e10a_family_calibration.py` (**novo**, fora da lista de dono, sem conflito possível): embrulha o
  `prepare_e09_hybrid_calibration.py` (mesmo schema, mesmas pranchas `overlay`) para as três identidades, com três
  acréscimos: (a) máscara de pele mais rosada (r ≥ 200, r−g 34–62, g−b 16–34; a do E09 pegava o robe creme da família:
  palmas medidas em r−g 40–56 e g−b 21–27, robe em r−g 20 e g−b 12); (b) `main_hand_angle` por direção em
  `calibration_authoring.json`; (c) o comando `provenance`, que escreve `provenance.json` v2.
- **Correções manuais** (`calibration_authoring.json`; o que não consta é a proposta automática): Acólito 6 quadros
  (prece sul 8, norte 24, oeste 56; mão erguida sul 9 e 10; mão distante oeste 55), Sacerdote 14 (prece, mãos erguidas,
  mão distante oculta nas vistas laterais), Cultista 7 (ombro ou rosto tomado por mão distante no oeste 48, 49, 53–55;
  leste 36; sul 0).
- Convenções do E08/E09: `main` = mão direita anatômica (sul: esquerda da imagem; norte: direita; leste: perto; oeste:
  longe), ponto de cabeça 8 px abaixo do topo medido, mortes com armas soltas horizontais atrás do corpo.

### 4. Encaixe da cabeça

`tools/prepare_e08_head_fit.py` ganhou `acolyte`, `cultist` e `priest` em `KINDS`; `write` regenerou
`scripts/actors/equipment_head_fit_data.gd`. Conferido: as 14 classes anteriores e as 14 peças ficam idênticas
(comparação dos dicionários antes e depois); entram só as 3 entradas novas, medidas sobre `weaponless.png`. Largura de
cabeça por vista (sul/norte/leste/oeste): Acólito 18/19/21/22, Sacerdote 16/13/17/19, Cultista 18/20/21/21.
O halo do Sacerdote faz o topo medido cair no arco (3 px acima do cabelo) e a largura sair menor; na captura as peças
de cabeça assentam bem mesmo assim (Limitações 3).

### 5. Mãos conferidas com livro, cetro e relicário (A12)

Capturas **nativas** (renderer real, janela, `CharacterAnimation` + `EquipmentAttachmentVisual` + `EquipmentHeadVisual`,
corpo escolhido pelo mesmo caminho do jogo) com o item da T9 na mão principal, 64 poses por classe e marcadores de grip.
- **Livro e relicário:** seguem a mão calibrada nas 56 poses vivas, nas quatro vistas, sem folga visível.
- **Cetro:** a inclinação de perfil (0,2) levava o aro sobre o rosto no sul e no leste, e os props da T9 não aceitam
  sobrescrita por arma (`WEAPON_KEYS` do `DirectionalAnimationSet` não os lista), então o ângulo é o do perfil mais o
  ângulo do slot. Usei o ângulo do slot só no **Sacerdote**, portador típico (`main_hand_angle`: sul −0,35, leste −0,45,
  poses vivas): o cetro fica ao lado do corpo no sul, atrás no norte e longe do rosto no leste
  (`zoom_priest_scepter_idle.png`).
- Os 112 grips vivos de cada corpo caem em pixel opaco dentro do recorte de 3×3 dedos (teste), e os três itens chegam
  ao ponto da palma em todas as combinações (3 itens × 3 corpos × 56 poses, teste).
- **Grip do livro (transferência autorizada pelo usuário em 18/11, depois da primeira entrega):** com o grip (10,18) da T9
  o livro 20×30 subia até o queixo e cobria o rosto e o torso no sul e no leste. Troquei **só o grip** de `prayer_book`
  de (10,18) para (10,12), nos três lugares que a T9 mantém espelhados: `assets/art/equipment/hand_rigs.json`,
  `PROFILES` de `scripts/actors/equipment_attachment_visual.gd` e `EXPECTED` de `tests/e10a/equipment_items_test.gd`
  (a expectativa do grip, número exato). O tamanho lógico 20×30 não muda (o teste da T9 exige o tamanho ×4 igual ao PNG
  de 80×120). Resultado nas poses paradas: o livro fica na altura do quadril, longe do rosto, e passa 4 px do chão
  (`zoom_acolyte_book_idle.png`); nas poses de ataque, com a mão erguida, ainda encosta no rosto. O cetro e o relicário
  não mudaram.

## Testes e regressão por impacto

Importação do editor feita por inteiro com `Godot_v4.7.2-stable_win64.exe --headless --editor --import --quit`
(worktree sem cache, saída 0); depois cada teste em invocação própria de `tools/verify.ps1 -SkipEditorImport -Test <t>`
(o `-F1Fixture` recusa árvore com arquivos editados, como já registrou a T9). Nenhum `SCRIPT ERROR` nem
`still in use` nos logs de engine e de saída.

| Etapa | Resultado | SHA256 do `.output.log` |
|---|---|---|
| `family_bodies_test` | 6.313 checks, 0 falhas | `c5b1715002e956509a650f3bbf32de85203600961a80e9c9df12c230df9b4511` |
| `hybrid_bodies_test` | 6.300, 0 | `b9c7e7033e7a19d443afd4a3b15ff4080152634e2d4d91066b113e5a00c53f69` |
| `e08_equipment_art_test` | 100.863, 0 | `5f377d76e832657ff84ba0350bf420124df8ce62cc1fc865f8c0201a338c07ac` |
| `e08_directional_units_test` | 77.804, 0 | `f42ed54c4034fdeb0eafa67999a8bece16dcb2da5454478ec66a94dcd8ba5436` |
| `e08_directional_content_test` | 6.324, 0 | `d0cf826cf99564723b6c4d204fd4b41bdbbb69912700e54f9ebb3eef4363cc88` |
| `e08_directional_rig_compatibility_test` | 83.328, 0 | `327931343ac222a254af8b4969f558063bfd0392bbcc2499d8c9e101dd16c20c` |
| `equipment_hand_alignment_test` | 4.593, 0 | `38a87bf0439bdb473aba8b25a1455d60554e8f41f99e1e0dc53853009a3c9145` |
| `equipment_items_test` | E09 244, 0; E10a 301, 0 | `eb9a6284a69d053a831b7302afe2c42db336f816f57b4eb290bd5ebbd9a2ca90` |
| `base_seam_test` | 172, 0 | `f78a568bc3e312e688ec95446908bdb3a1282143e2a5eb0aa53e47c07c2c1dc7` |
| `e08_characters_test` | 1.350, 0 | `f75b72b7ccc3036a420f8a7a0ffd1363968fd11eb8a28202b18aadec53ef361c` |
| `e08_directional_animation_test` | 814, 0 | `f3b1a95db5367ab902cb07e7685fad6c33a8c10c53aa01b52dd65b81dc6d3fab` |
| `e08_directional_integration_test` | 84, 0 | `6be2b53c8f07a98bab9161bd3fbd90235aadfa1a628d8629012a504a638f6f2e` |
| `e08_directional_npcs_test` | 1.292, 0 | `0673a9dcaa71cee13ab406d41398f57fe33dda1fb797d727c6bcc1d40d2c4b37` |
`tests/e10a/family_bodies_test.gd` (novo): resolução da base e das duas puras pela costura (inclusive o Acólito sem
evolução usando o próprio corpo, não o do Mago, e a cadeia de fallback até o Mago); atlas (256×1024, poses distintas,
laterais não espelhadas, goteiras, escala comum); manifesto, receita e proveniência (hash das 4 fontes e dos atlas);
calibração (64 quadros, 112 grips, convenção sul/norte, mortes); dados de encaixe; renderer em 3 combinações de item e
peça de cabeça nas 64 poses; 3 itens × 3 corpos × 56 poses de grip; corpos vizinhos intactos e manifesto de outra
identidade recusado.

Depois do grip do livro refiz a captura do Acólito (sonda do Acólito: 821 checks, 0 falhas) e rodei de novo
`family_bodies_test` (6.313, 0), `equipment_hand_alignment_test` (4.593, 0), `equipment_items_test` (E09 244 e E10a 301, 0),
`e08_equipment_art_test` (100.863, 0), `e08_directional_rig_compatibility_test` (83.328, 0) e `e08_directional_units_test`
(77.804, 0): mesmos contadores e mesmos hashes de log da primeira rodada, sem `SCRIPT ERROR`.

### Ajustes de enumeração (A15 do E09), cada um com número exato

| Arquivo | Antes → depois |
|---|---|
| `tests/e10a/equipment_items_test.gd`, só `EXPECTED[prayer_book]` | grip `Vector2(10, 18)` → `Vector2(10, 12)` (acompanha a troca do grip autorizada pelo usuário) |
| `tests/e08_equipment_art_test.gd`, só em `head_fit_checks` | lista `kinds` acrescida de `acolyte`, `priest`, `cultist`; `data.classes.size()==14` → `==17` (as 14 peças ficam em 14) |

Nenhum outro teste legado quebrou: `e08_directional_units/content/rig_compatibility/npcs` varrem as pastas por
`presentation.json` e passaram sem mudança; `base_seam_test` (172) passou com o Acólito já resolvendo o próprio corpo.

## Capturas nativas

Em `docs/epics/e10a/t8_evidence/` (rodada completa: **2.463 checks, 39 capturas, 0 falhas**; depois uma segunda só do
Sacerdote, 821 checks, 13 capturas, 0 falhas, depois do ajuste do cetro). Por classe: 64 poses nuas (`bare_*`, sul+norte
e leste+oeste), com o item típico (`book_acolyte`, `scepter_priest`, `reliquary_cultist`), marcadores de grip (vermelho)
e dedos (verde) com o livro (`grip_*`), `class_set_mage_head` e `shared_set_mid_head` em 7 poses (`head_*`) e três
recortes ampliados das poses paradas (`zoom_*`). As demais (item cruzado, `shared_set_high_head`) ficam em
`.godot/verification/t8_native/`, fora do Git. A sonda é `tools/e10a_t8_body_probe.gd` (+ `.uid`, nova). Leitura visual
por mim, a 2× e 3×.

| Arquivo | SHA256 |
|---|---|
| `bare_acolyte_ew.png` | `f4c9810457f9495256bfeeefe47233f0dc7e188823a40a95c4f68f40ee7bc96f` |
| `bare_acolyte_sn.png` | `31e6b393a72012725ad1b0390b4d6d16819be876e1710afdf3a362f430df3274` |
| `bare_cultist_ew.png` | `31c1d357544b53ceb2f5cda422ac15aa6a463a10eb33ec00b24ad6a2f63c62ae` |
| `bare_cultist_sn.png` | `29467fceb59807ed711e268020fe2407095383aadffca218861f8831eed10528` |
| `bare_priest_ew.png` | `8b23384d410c4aacfb23e67a6f44dc979a145d0a3584d8bdfcd42e86607ffad8` |
| `bare_priest_sn.png` | `892e6cbb4127eecc041032227144b545cc94d10a038ceed9559f4ca6ff677322` |
| `book_acolyte_ew.png` | `d44f9c6e9faea7cb9fbc89582ba1ce60d37296aa98adb31b8d9d4511499e562b` |
| `book_acolyte_sn.png` | `19a8fbcb3d1567d4a34d1d20a6dac88d713c4b1300dbbcfc6fa3bbb58e523d3b` |
| `grip_acolyte_ew.png` | `67666b781edfd0eb5303aaed4bfb73424d40bd7369131cc1ad054379821bbcda` |
| `grip_acolyte_sn.png` | `c9413548a7d9861961e548139dc9e09e959426d34c87202af14a5f8ffea67dc7` |
| `grip_cultist_ew.png` | `9a31a0bdc5af0c08011672e6f2b617fc40700effd9bd7fafdde8544e2151e677` |
| `grip_cultist_sn.png` | `e24ef20910fc27158612d9b954b30e7c732db2f6de9183afb350ce29432f0a14` |
| `grip_priest_ew.png` | `2f31ed81ff36a50f7f57594aaa9188bee52fb73044389f5b3660c33890d44ce0` |
| `grip_priest_sn.png` | `917c159760fe0a9187a813f6deedf8ce67d2923b871ee0e431f07bd3a26416be` |
| `head_acolyte_class_set_mage_head.png` | `ab5ad17f0b1d9f7d33584e27d41a6e21762bb87cfad94ea5120f82b96cabb1a0` |
| `head_acolyte_shared_set_mid_head.png` | `3a00e3769a60bbaa25cc0e9336f2cfee25f16dbc5696dc625486a7ab04e2c1cb` |
| `head_cultist_class_set_mage_head.png` | `33f8bb44efc6fc7b1c7b046eefb12ca7cf2cad48c8eb2b2c66fdd83ee43f816a` |
| `head_cultist_shared_set_mid_head.png` | `21ce7847021590d97fe5d305dc4546a0d5cc1535b2d12a0e4b02fc4fc45ec8e7` |
| `head_priest_class_set_mage_head.png` | `afa379886cd673f697ba7c07905ca72a80fa356b52cb09345471faa8c99ebeea` |
| `head_priest_shared_set_mid_head.png` | `8c0b2e3cac4e6b5b21e329bfa7654c90f3d43fcd7cb6394c4bac769ee67f77d0` |
| `reliquary_cultist_ew.png` | `7771fb07351f9cdffbdeb399aa98e3e559e2172b85b958f06b103c964c7b59aa` |
| `reliquary_cultist_sn.png` | `a1fcc9cfa51f344cd2f14650aea53d5370e937f112e13c225c92b5149ed9022a` |
| `scepter_priest_ew.png` | `db6e43132a8f65818524763aa4d5db908494a486416cefe9b0c2c9879aff98f1` |
| `scepter_priest_sn.png` | `8d3a2fa2035e7af8dccdeab1b13b3ab757c239f5be0e7b798c01f376c33ee5f5` |
| `zoom_acolyte_book_idle.png` | `661b17d60074ca57f93b0ffef6ebab3627b2726347efc8406af5f1f98e5d4ea9` |
| `zoom_cultist_reliquary_idle.png` | `516eea0d42826a3b9e0678e2d083113cd767046b4ed3c3a047ba654f84d4bf08` |
| `zoom_priest_scepter_idle.png` | `6fdd538acd75dd136d73d5c3d1a77802b73c0e77c7d44eb4c6902de51707773f` |
## Limitações e pendências

1. **Livro e relicário (escala de T9).** Com o grip ajustado (seção 5) o livro ainda é grande para o corpo: nas poses de
   ataque encosta no rosto e na parada passa 4 px abaixo do chão. Reduzir o prop exigiria regenerar o PNG (o teste da T9
   amarra tamanho lógico ao arquivo); fica para o aceite visual. O relicário pende abaixo dos pés no sul e no leste;
   lê-se como corrente longa e não colide com o rosto, mas a escala é da T9.
2. **Ângulo do cetro nos outros portadores.** O ângulo de slot do Sacerdote vale para qualquer item que ele empunhe:
   o livro e o relicário ficam inclinados nele (−0,35 no sul e −0,45 no leste), sem problema para o relicário (pende) e
   com leve tombo no livro. O caminho completo é aceitar ids de prop em `WEAPON_KEYS`/`angle_overrides`
   (`directional_animation_set.gd`, fora do meu escopo). Nas poses de ataque o cetro e o livro não balançam (sem
   sobrescrita por ação). Na vista oeste a mão principal é a distante e o cetro some atrás do corpo, como as armas do E08.
3. **Sem `bare_head.png`.** Cabelo longo, chifres de carneiro do Cultista e o halo do Sacerdote aparecem sob ou junto
   das peças de cabeça nas poses de dano e queda; o halo (3 px acima do cabelo) deixa o topo medido do Sacerdote mais
   alto e a largura medida 13–19 px (outras classes 18–22), então a peça fica um pouco menor e mais alta que nas demais
   classes, mas dentro da razão 1,0–1,3 do teste e sem choque visível na captura. Um `bare_head` sem halo exigiria
   editar arte; fica como decisão de produto.
4. **Calibração aproximada (±1 px).** Mãos em manga larga (prece, mãos erguidas) foram posicionadas sobre células
   ampliadas e conferidas por captura, não no jogo em movimento nem nos zooms 50/100/160. Mortes usam as inclinações do
   E08 sem ajuste fino. Aceite artístico e de produto: do usuário.
5. **Ambiente.** O editor reescreveu cerca de 650 `.import` rastreados, criou `.import` de arte-fonte e `.uid` em
   `docs/map_editor`; restaurei ou removi tudo e deixei só os `.import` dos seis atlas. `.godot` fresco exige o
   `--import` direto. Arquivos novos fora da lista de dono: `tools/prepare_e10a_family_calibration.py`,
   `tools/e10a_t8_body_probe.gd` (+ `.uid`), `tests/e10a/family_bodies_test.gd.uid`, `docs/epics/e10a/t8_evidence/`.
6. **Não rodei a suíte completa** (`verify.ps1` sem `-Test`): a mudança toca arte, dados de encaixe e ferramentas, sem
   alteração de runtime além do dado gerado.
7. **Próximo passo.** T13 compõe esta branch (sem conflito esperado com a T9: não toquei `hand_rigs.json` nem os
   `PROFILES`). T10 refaz a captura de criação e onboarding com os três corpos. Decisão pendente para a arquitetura:
   grip e tamanho do livro (item 1).

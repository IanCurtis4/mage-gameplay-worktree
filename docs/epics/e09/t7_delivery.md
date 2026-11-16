# E09 T7 — corpos das quatro híbridas: recibo de entrega

Tarefa **T7** de [e09.md](../e09.md), contrato **C6** (segunda parte) de [e09_contract.md](../e09_contract.md#7-c6--arte-do-épico-tarefas-t4-e-t7).
Papel: Terra (Claude Sonnet 5.5, esforço alto). Data: 16/11/2026. Estado proposto: **ENTREGUE**; validação técnica e
integração ficam a cargo de Sol/T10. Duas expectativas de testes legados mudam por contrato (seção Limitações, itens 1–2).

## Base e entrega

| Item | Valor |
|---|---|
| Base | `git merge --ff-only 337aa7df…` (ponta da T1) e `git merge --no-ff b5aac165…` (ponta da T4), sem conflito; merge `07687482d34f3ad9ccf6bcd03c6c8ce30fbea270` |
| Branch | `claude/zealous-roentgen-c183e9` |
| Checkout | `C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.claude\worktrees\zealous-roentgen-c183e9` |
| Commit | ponta da branch, informada na mensagem final (um recibo não contém o próprio SHA) |
| Push / `master` / playtest habitual / save pessoal | não tocados |

## O que foi entregue

### 1. Empacotador lê a seleção (`tools/prepare_e08_directional_art.py`)

- `source_recipe.json` aceita `"selection": "res://…/selection.json"` no topo e `"@south"`, `"@north"`, `"@east"`, `"@west"`
  (também em `overrides`) nas vistas. O caminho vem de `load_selection()` de `tools/art_pipeline/selection.py`, que confere o
  SHA256 antes de ler; o registro de cada pose passa a trazer `source_sha256` só nesse modo.
- Quatro identidades novas em `KINDS`: `paladin`, `thaumaturge`, `duelist`, `arcane_blade`.
- O empacotador agora também grava no manifesto as variantes opcionais que existiam só editadas à mão: `bare_head.png`
  (Arqueiro, Caçadora, Sentinela, Geômetra, Mago) e `npc_body.png` (Arqueiro), com a mesma regra de hash RGBA do corpo.
  Isso era a única diferença do `presentation.json` regenerado.
- **Prova de bytes idênticos.** Rodei o empacotador, sem a nova receita, sobre as nove classes que têm `source_recipe.json`
  (`geometer`, `sentinel`, `mage`, `hunter`, `archer`, `berserker`, `defender`, `swordsman`, `elementalist`) e `git status`
  ficou limpo nelas: `body.png`, `weaponless.png` e `presentation.json` iguais byte a byte. Antes da mudança, `geometer` e
  `sentinel` perdiam o `bare_head` e `archer` trocava o corpo por `body.png`; por isso o passo extra acima. A Espiritualista
  não tem `source_recipe.json` e não é regenerável.

### 2. Atlas V2/64 (`ragrpg_directional_animation_v2`) em `assets/art/e08_characters/directional/<pasta>/`

Cada pasta: `body.png` = `weaponless.png` (256×1024, 64 células, pivô (32,58)), `calibration.json`, `presentation.json`,
`provenance.json` (v2, dois registros), `recipe.md`, `source_recipe.json`, `delivery.md`, os `.import` dos dois atlas e
`calibration_authoring.json` (correções manuais, ver abaixo). Sem `.import` de arte-fonte: as folhas ficam em
`e08_codex_1123/characters/` e não são copiadas.

| Pasta | Classe | SHA256 de `body.png` | RGBA canônico (manifesto) | Escala global |
|---|---|---|---|---|
| `paladin` | `sp_ac` | `e68b4bd709ad6d2e79abda31ea18c3905d8253b41a0ed3c13df287e03baaa641` | `5d058e8abf3c5f66dfd1f5c6dc6a0625336a6342b630a758928db2b172ad9a21` | 0,1992 |
| `thaumaturge` | `mg_ac` | `768a03e7e4581a4bb176459230b58bb1fdd1d3390c3205ac280123c397b92768` | `c5e3022813dfe7e36caa223eed74a954075a97c5cb57bff728b9853eb6d2c942` (ver `presentation.json`) | 0,1976 |
| `duelist` | `sp_la` | `14b573c7c9524b31f04d6d9f8c0414eab5fbd44f7f0d1ec73bc450eead7302a3` | `5d6b5e05cce3e03f7fc8294910402e3097f9644151f4bd2f5830d216ac472a95` | 0,2066 |
| `arcane_blade` | `mg_la` | `f27ef129457d68735aaef46e08c26883933a9f44c153587a064a6976422c38c8` | `ce1aa89cbcf8680ed9b042744208dc913301d99b019238239956d104d344e4af` | 0,2066 |

O hash RGBA completo de cada corpo está em `presentation.json` (`body.rgba_sha256`) e coincide com
`calibration.json` (`authored_rgba_sha256`); o teste confere. SHA256 dos manifestos e das calibrações:

| Pasta | `presentation.json` | `calibration.json` |
|---|---|---|
| `paladin` | `fb49d690f33fdf3a075e7c81fd1df0c74b57ec913a2a3a10ecfa8062834193d7` | `db654898ad5fb85c850917a210e9ecce171ae87cf8ebdcb3bb18f05fea9d72ac` |
| `thaumaturge` | `66cfbf1bf94df0531c7f30c096aab2fb3528fc2172775336ef9fc4391d15d923` | `8677a89f2d22a8531af40b6d76776f3c415d39f284b9d9bee9088afb55a418e5` |
| `duelist` | `633137fb2e72b5554e280d0a7e4f66e765dbd012dc44afc26d136ee2a579b4ca` | `41c0970cb51e53efa6cd203c1664a5b0b0417693013000debbeaae7633279829` |
| `arcane_blade` | `eed0b0a5979630c0f67b4c037486e9509a2dd2bc0ec87bac233bbc16e16441d2` | `6b42b848fcd25b7a66471f31c85ae638373da418ae9387821d51b292f2e17a5b` |

`provenance.json`: `provenance.py check` com 0 problemas nas quatro. Cada registro lista as quatro folhas escolhidas
(`refs`, com SHA256), um passo `post` por vista (`input_sha256` da folha, `output_sha256` do atlas), `review.status =
pending` e a nota de termos herdada do lote Codex 1123. Os prompts exatos continuam no `provenance.json` de
`e08_codex_1123/characters/<classe>/`. Gerado por `tools/art_pipeline/record_generation.py`.

### 3. Calibração de mãos, dedos e cabeça (`tools/prepare_e09_hybrid_calibration.py`, novo)

Ferramenta nova: propõe as palmas por componentes de pele (com fusão de dedos), mede o topo e o centro da cabeça,
escreve `calibration.json` no schema das classes do E08 e desenha pranchas ampliadas com grade (`overlay`) para
revisão. As correções que a revisão pediu ficam em `calibration_authoring.json` de cada pasta; o que não consta lá
é a proposta automática. Correções manuais por quadro vivo: Paladino 17, Taumaturgo 25, Duelista 56 (luvas de couro
vermelho-escuro sem pele visível: todos os quadros vivos à mão), Lâmina Arcana 9. Convenções, as mesmas do E08:
`main` = mão direita anatômica (sul: esquerda da imagem; norte: direita; leste: perto; oeste: longe), depth por vista,
`flip` verdadeiro no oeste com ângulos negados, ângulos de ataque no padrão legado, mortes com armas soltas
horizontais e atrás do corpo, ponto de cabeça 8 px abaixo do topo medido e ângulos de queda ±0,2/0,6 (sul/norte) e
±0,3/1,2 (leste/oeste).

### 4. Encaixe da cabeça

`tools/prepare_e08_head_fit.py` ganhou as quatro identidades em `KINDS`; `python tools/prepare_e08_head_fit.py write`
regenerou `scripts/actors/equipment_head_fit_data.gd`. Conferido: as 10 classes anteriores e as 14 peças ficam
idênticas (comparei os dicionários antes e depois); só entram as quatro entradas novas, medidas sobre `weaponless.png`.
Largura de cabeça por vista: Paladino 20/19/21/22, Taumaturgo 18/18/19/21, Duelista 20,5/19/22,5/21, Lâmina Arcana
19/19/21/22 (sul/norte/leste/oeste).

### 5. Testes

`tests/e09/hybrid_bodies_test.gd` — **6.300 checks, 0 falhas**:
- cada evolução (`sp_ac`, `mg_ac`, `sp_la`, `mg_la`) resolve o corpo da própria pasta por `ClassKitRegistry.actor_kind`,
  e o retrato (`BuildPresentation.portrait_identity`) também;
- o atlas carrega e valida (256×1024, corpo = sem arma, poses distintas, laterais não espelhadas, goteiras
  transparentes nas 64 células);
- a calibração cobre os 64 quadros, com o chão, os 112 grips vivos em pixel opaco dentro do recorte de dedos,
  duas palmas distintas, convenção sul/norte de mão principal e armas soltas das mortes;
- dados de encaixe de cabeça com 64 quadros e quatro direções, medidos sobre o atlas;
- `CharacterAnimation.configure(<pasta>)` seleciona V2 nas 64 poses, com o chão exato, a cabeça na direção do corpo,
  grips autorados em duas combinações de equipamento (espada, escudo, contas, touca; cajado, foco, boné) e morte;
- fallback: sem pasta o caminho do manifesto é vazio, manifesto ausente é recusado, evolução sem pasta usa a origem,
  os corpos Espadachim e Mago ficam intactos, manifesto de outra identidade é rejeitado de forma atômica.

### 6. Captura nativa (renderer real, janela)

`tools/e09_t7_body_probe.gd` (novo; estende a sonda direcional do E08) seleciona cada corpo pelo `kind` da pasta, como
o jogo faz pela costura da T1. Rodada completa: **2.536 checks, 40 capturas, 0 falhas**, depois uma segunda só do
Paladino (634 checks, 10 capturas) depois de uma correção de calibração revertida (ver Limitações 5). Em
`docs/epics/e09/t7_evidence/` (SHA256 no fim): por classe, espada+escudo+contas e cajado+foco nas 64 poses (sul+norte e
leste+oeste, linhas idle, walk, action, hurt e death), peças de cabeça `shared_set_mid_head` e marcadores de grip do
Paladino leste/oeste. As demais capturas (corpo nu, marcadores de grip das outras três, `shared_set_high_head`) ficam
em `.godot/verification/t7_native/`, fora do Git.

Leitura visual (por mim, a 2×): armas, escudos e cajados seguem as mãos nas quatro vistas e em todas as linhas; peças de
cabeça assentam sobre a cabeça nas quatro direções e nas poses 0, 4, 8, 9, 12, 14 e 15 (touca de faixa sobre o capuz
da Lâmina Arcana e sobre o cabelo dos demais); espadas e escudos do Espadachim e cajado e foco do Mago foram os itens
existentes usados.

## Regressão por impacto

Importação do editor feita **uma vez por inteiro** com `Godot_v4.7.2-stable_win64.exe --headless --editor --import --quit`
(saída 0): o passo `editor_import` do `verify.ps1` estoura os 120 s numa worktree sem cache, então as demais etapas
usaram `-SkipEditorImport`. Cada etapa em invocação própria (o runner para na primeira falha).

| Etapa | Resultado | SHA256 do `.output.log` |
|---|---|---|
| `hybrid_bodies_test` | 6.300 checks, 0 falhas | `b9c7e7033e7a19d443afd4a3b15ff4080152634e2d4d91066b113e5a00c53f69` |
| `e08_characters_test` | 1.350, 0 | `f75b72b7ccc3036a420f8a7a0ffd1363968fd11eb8a28202b18aadec53ef361c` |
| `e08_directional_animation_test` | 814, 0 | `f3b1a95db5367ab902cb07e7685fad6c33a8c10c53aa01b52dd65b81dc6d3fab` |
| `e08_directional_integration_test` | 84, 0 | `6be2b53c8f07a98bab9161bd3fbd90235aadfa1a628d8629012a504a638f6f2e` |
| `e08_directional_content_test` | 3.461, 0 | `b4f85dded47ea1b48df58a310901cc3c2aebcca706530482c398ba9caa1823f6` |
| `e08_directional_units_test` | 47.494, 0 | `41cde8285acd0b73908c8d828ef97e6161120bcc9189da0316a9fe3993473b29` |
| `e08_directional_rig_compatibility_test` | 41.888, 0 | `f88bd4eec04639424d3ebc9607335fe4f8e3329fb649c27c7e2fe32157f7bd3e` |
| `e08_directional_npcs_test` | 1.292, 0 | `2cad462f390622d3c9124303f82f5ac82938fc69d364327c508b75918d95ce63` |
| `e08_species_presentation_test` | 172, 0 | `7a85c7ade6f7bbb41f80c8f62781c01da358327c40dd26951c118707d052e7ec` |
| `combat_animation_test` | 39, PASS | `df1d52002e18c5524fa60801186a018cdbc71c91e0248051e38f6565c154fb1e` |
| `e08_equipment_art_test` | 60.459 checks, **1 falha** (limitação 2) | `7b1038a2d584c839b4a191df238438461e89ef74b87c9f41876ffb332378c970` |
| `kit_seam_test` | 175 checks, **5 falhas** (limitação 1) | `8dd9cccd554f3595f96668a672123443ad1f17f6b4f37092d03f208d559464f5` |
| `e08_presentation_test` | **não executável** neste checkout (limitação 3) | — |

Busca por `SCRIPT ERROR` e `still in use` em todos os logs de engine e de saída dessas etapas e das duas rodadas da
sonda nativa: **nenhuma ocorrência**. Os WARNING que aparecem são dos negativos forçados dos testes de espécie e NPC.
Também: `python -I -m unittest discover -s tools/art_pipeline/tests` → 89 testes, OK.

Não rodei a suíte completa (`verify.ps1` sem `-Test`): a mudança toca arte, dados de encaixe de cabeça e ferramentas,
não o gameplay; sem alteração de runtime.

## Limitações e pendências

1. **`tests/e09/kit_seam_test.gd` (T1) falha em 5 checks** (linhas 175, 470, 471, 474, 478): assumem "kit sem arte → corpo
   da origem". Com a arte presente, `kit_body_path(&"paladin")` não é vazio, `actor_kind(sp_ac)` é `paladin`, etc. O
   fallback funciona (coberto em `hybrid_bodies_test`); o teste da T1 só precisa de um corpo-fixture sem arte. Não editei
   (dono T1). Perguntei à sessão de arquitetura quem ajusta; sem resposta até este recibo.
2. **`tests/e08_equipment_art_test.gd:250` exige 10 classes** na tabela de encaixe; agora há 14 e o laço `kinds` da
   linha 248 não cobre as híbridas. Os demais 60.458 checks passam. Mesmo encaminhamento do item 1; sugerido T10 na
   composição.
3. **`e08_presentation_test` não roda** aqui: `tests/fixtures/e07/f1/fixture_input.gd:48` lê `res://source_root.txt` e
   `source_hashes.json`, que só existem na cópia isolada do `-F1Fixture`. Não rodei esse modo; falha por ambiente, não
   por este conjunto de mudanças.
4. **Sem `bare_head.png`.** A captura de touca (`shared_set_mid_head`) sobre as quatro híbridas mostrou encaixe aceitável
   sem a variante, mas cabelo e capuz aparecem sob a faixa nos quadros de dano e queda. Se o conjunto de classe das
   híbridas (D6, fora deste épico) trouxer elmo fechado, pede-se o `bare_head` então.
5. **Mão principal nas vistas laterais com braço estendido.** No Paladino oeste, pose 57, a espada fica na mão baixa e o
   escudo no punho estendido; trocar as mãos escondeu a lâmina atrás da cabeça (depth 0 da mão distante), então mantive a
   atribuição do detector. Em geral, na vista oeste a mão principal é a distante e fica atrás do corpo na posição de
   repouso (a espada some atrás do corpo, como nas classes do E08). Na Lâmina Arcana leste, pose 0, o cajado atravessa o
   rosto.
6. **A calibração é aproximada (±1 px).** As mãos em luva ou manga foram posicionadas sobre células ampliadas e
   conferidas por captura a 2×, não por inspeção do jogo em movimento nem nos zooms de câmera 50/100/160. Cabeça nas
   mortes usa as mesmas inclinações do E08 sem ajuste fino por quadro. Aceite artístico e de produto: do usuário.
7. **Ambiente.** `.godot` fresco exige o `--import` direto (limitação do passo `editor_import`, acima). O editor reescreveu
   cerca de 570 `.import` rastreados; restaurei todos com `git checkout` e deixei só os oito `.import` dos atlas novos.
   Arquivos novos fora da lista de dono, todos sem conflito possível: `tools/prepare_e09_hybrid_calibration.py`,
   `tools/e09_t7_body_probe.gd` (+ `.uid`), `tests/e09/hybrid_bodies_test.gd.uid` e a pasta `t7_evidence/`.
8. **Próximo passo.** K1–K4 só precisam declarar `ready_for_play`: o corpo de cada evolução já é resolvido pela costura.
   T10 deve ajustar as expectativas dos itens 1 e 2 na composição e refazer a sonda do PCK com os quatro corpos.

## SHA256 das capturas (`docs/epics/e09/t7_evidence/`)

| Arquivo | SHA256 |
|---|---|
| `sword_paladin_sn.png` | `8bcd06eee6e572492253cebe2350f22af8b77f0b6f336a61f2f424b0002b2c82` |
| `sword_paladin_ew.png` | `8df773eae4a5d2bdb45da45e40d6b58536a61724b4902032b147744aa6ae462d` |
| `sword_thaumaturge_sn.png` | `5645a7d0fd2e60f256a4fc08ce092d59735d7acadfcaf18652152292f55f91c8` |
| `sword_thaumaturge_ew.png` | `01042756bff8fdca91e9e5df40354a4cddee9b73ef3aa76df31199897ddcce7b` |
| `sword_duelist_sn.png` | `4891d976c1b9689b1d2d7744069e2632ba960d7fb67b9f871771c3e077d8159f` |
| `sword_duelist_ew.png` | `ed509091174bc7ba9cb898b6caa1eb3b82e14bdea40563b217c7ba7c56d4538e` |
| `sword_arcane_blade_sn.png` | `299da41078d6d923ba9bf5203de2b23c97a661317b081bd34efbd0beaaeb17b7` |
| `sword_arcane_blade_ew.png` | `525caefd8489e224a3e98dba272099de0faf49219fa57e31e7fffa39653fd113` |
| `staff_paladin_sn.png` | `c1400bca9c53fd095a250e01cb02f0c7c9e6883219a0408b03abc4d140847e65` |
| `staff_paladin_ew.png` | `5982493b7828d28942db121b96149a6487b27082e3429138b64dacdc8745fb99` |
| `staff_thaumaturge_sn.png` | `4b816d4f695fdefb983c7334123a6c6f031fdd5822210da96f25d1f6cb741de8` |
| `staff_thaumaturge_ew.png` | `b2fec70ea9f72b54fe288f86a214102ea208e78b3d1506ee4dd769f375984652` |
| `staff_duelist_sn.png` | `6b23087a167b5e6409dd9d72138e78d96cdfb5810c04ec997747ef401fc53e4e` |
| `staff_duelist_ew.png` | `93f0fde3aa31b7a158f98c28f3829e192c4e677d71b98cf63f9b2af18cf8d602` |
| `staff_arcane_blade_sn.png` | `50a900ad75012656ea5059ec2012cf4d962d1e7efcee282f820ca39f6a0ff30f` |
| `staff_arcane_blade_ew.png` | `89bb41c9724b144c6c14a2548de204cccbffb0ce873fcd4f5b8bb5d4ec2e61fa` |
| `head_paladin_shared_set_mid_head.png` | `2179de5f786ea0142f79507cbf892ff2dc30bc0d8a58f972803e82182910bc3b` |
| `head_thaumaturge_shared_set_mid_head.png` | `795659f0db6e0beb774d7b468c399ded7ef585b40a9d5c2b1aefe27963d6a313` |
| `head_duelist_shared_set_mid_head.png` | `57c336f3e7c732d787562a5ef35364f64117ac80b25dc325f1bf06286037ebe6` |
| `head_arcane_blade_shared_set_mid_head.png` | `6ce223d87b37f9c02c483fb76974af208bf5f5038697e5e3a872cb0b7076e711` |
| `grip_paladin_ew.png` | `eefc02b4eb0eb251ce0fba8d1828746695127ee0afda98a1d5aa5324dc080b5d` |

# E10a T16 — correções visuais (decisão A15)

Tarefa **T16** de [e10a.md](../e10a.md) (linha T16, decisão A15). Papel: Terra (Claude Sonnet 5.5, esforço alto).
Data: 19/11/2026. Estado proposto: **ENTREGUE**; a composição e a prova no candidato ficam com a T13, o aceite visual é do usuário.

## Base e entrega

| Item | Valor |
|---|---|
| SHA-base | `71d57a1134ee0793b7bb11f82b918946ca5a9dfc` (`git log -1` depois de `git merge --ff-only claude/e10a-candidato`; composição 9) |
| Guarda do E12 | `git merge-base --is-ancestor claude/e12-candidato HEAD` verdadeiro |
| Branch | `claude/modest-franklin-aa99e3` |
| Checkout | `C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.claude\worktrees\modest-franklin-aa99e3` |
| Commit | ponta da branch, informada na mensagem final (um recibo não contém o próprio SHA) |
| Push / `master` / `codex/playtest` / save pessoal | não tocados |
| Leitura de A15 | a versão de `e10a.md` do candidato (a da arquitetura `cf176e6a` é mais antiga: não tem as linhas de estado da T13); a linha T16 é idêntica |

Nota de caminho: `directional_animation_set.gd` fica em `scripts/presentation/`, não em `scripts/actors/` como a linha da tarefa diz.

## Arquivos fora da lista de dono (declarados)

- `assets/art/e10a_equipment/manifest.json`: o teste de itens confere o hash do prop contra ele, então o passo de redução tinha de entrar ali (a proveniência pedida).
- `tools/prepare_e10a_family_calibration.py`: ferramenta da própria T8, sem outro dono; só a função `apply_main_hand_angles` virou `apply_prop_angles` (item 2).
- Novos, todos de `scripts/classes/{priest,cultist}/` ou de nome `t16`: `cultist_figure_node.gd` e `priest_exorcist_mark.gd` (com `.uid`), `tools/e10a_t16_{effects,book,ui}_probe.gd`, `assets/art/e10a_equipment/prayer_book_full.png` e `prayer_book_reduce.py`.
- Nenhum arquivo de T15 (`bases/acolyte/**`, `class_kit.gd`, `combat_actor.gd`, `review_builds.json`) foi tocado. Os `snapshot_manifest.json` dos dois kits não mudaram: nenhum campo de estado novo.

## 1. Livro menor

- **Redução:** o PNG da T9 (`prayer_book_full.png`, 80×120, SHA256 `5a9b433e…de84e`, guardado como entrada) passa por vizinho mais próximo, sem suavização nem geração nova, para **64×96 = 16×24 lógicos ×4**. Script `assets/art/e10a_equipment/prayer_book_reduce.py` (determinístico; recusa uma entrada de hash diferente). Saída `props/prayer_book.png`, SHA256 `d9510d53e282f785257740ba39b683bae3f987969e72853cbaaaa3d778a3a09d`.
- **Proveniência:** o item `prayer_book` de `manifest.json` ganhou `prop_size` [64, 96], o novo `prop_sha256` e um passo em `post` (`prayer_book_reduce.py`, `filter: nearest`, `smoothing: false`, tamanhos de entrada e saída, `input_sha256` e `output_sha256`). A origem (folha B1, objeto 1) e o ícone de 128 px **não mudam** (o ícone vem do objeto da folha, não do prop).
- **Grip:** de (10, 12) sobre 20×30 para **(8, 12) sobre 16×24** (o centro do livro). Números exatos nos três espelhos, pela A15 do E09:

| Espelho | Antes | Depois |
|---|---|---|
| `assets/art/equipment/hand_rigs.json` (`props.prayer_book`) | size [20, 30], grip [10, 12] | size [16, 24], grip [8, 12] |
| `PROFILES` de `equipment_attachment_visual.gd` | `Vector2(20,30)`, `Vector2(10,12)` | `Vector2(16,24)`, `Vector2(8,12)` |
| `EXPECTED[prayer_book]` de `tests/e10a/equipment_items_test.gd` | `Vector2(80, 120)`, `Vector2(10, 12)` | `Vector2(64, 96)`, `Vector2(8, 12)` |

- **Medida da escolha** (calibração real dos três corpos, 168 poses vivas, livro desenhado na frente do corpo; "cabeça" = as 14 linhas a partir do topo do corpo; "chão" = a linha `ground_y`):

| Livro e grip | Poses que tocam a cabeça | Pixels de cabeça cobertos | Poses paradas (de 48) com a base abaixo do chão |
|---|---|---|---|
| T9: 20×30, (10, 18) | 50 | 2.210 | 0 |
| T8: 20×30, (10, 12) | 11 | 315 | 47 |
| **T16: 16×24, (8, 12)** | **11** | **243** | **0** |

  Nenhum grip testado (varredura de todos os pares inteiros) zera os toques sem passar do chão parado: as 11 poses são as de prece e mão erguida (sul 9 a 11, leste 8 e 10), onde a própria palma fica ao lado do rosto. Esse limite é da calibração das mãos (T8), não do prop; fica como ressalva visual. O teste novo trava o número exato (11) e a base do livro parado no chão, nos três corpos.
- **Capturas nativas** (secção 5): `book_*`, `grip_*`.

## 2. Ângulo por prop

- `DirectionalAnimationSet` (`scripts/presentation/directional_animation_set.gd`): nova lista `PROP_KEYS` (`prayer_book`, `halo_scepter`, `eye_reliquary`); `angle_overrides` e `depth_overrides` aceitam esses ids além dos de `WEAPON_KEYS`. Nada mais mudou nesse arquivo.
- `calibration_authoring.json` do Sacerdote: `main_hand_angle` (ângulo do slot, que tombava todo item da mão) virou `prop_angle: {"halo_scepter": {"south": -0.15, "east": -0.25}}`, o ângulo **inteiro** do cetro (era 0,2 do perfil + (−0,35 / −0,45) do slot, as mesmas posições de antes). `tools/prepare_e10a_family_calibration.py` grava isso em `angle_overrides.halo_scepter` do slot da mão principal nas poses vivas (0 a 13) do sul e do leste; o ângulo do slot fica 0.
- Dados regenerados, só do Sacerdote: `calibration.json` (SHA256 `0190bf29…83433`) e `presentation.json` (`8d7d7c3e…dfc1ed`) pelo empacotador (`write`, depois `tools/prepare_e08_directional_art.py priest`). O diff de `calibration.json` é exatamente o ângulo do slot saindo e o override entrando, em 28 poses (14 do sul e 14 do leste); `presentation.json` repete o mesmo diff. `body.png` do Sacerdote não mudou (`ec071b78…a7634e7`).
- **As 14 identidades antigas continuam byte a byte:** nenhum arquivo delas está no diff; `e08_directional_units_test` (77.804), `e08_directional_rig_compatibility_test` (83.328) e `hybrid_bodies_test` (6.300) dão os mesmos contadores e os mesmos hashes de log da T8.
- Acólito e Cultista não ganham override algum. Livro e relicário ficam retos (ângulo do perfil, 0) em qualquer portador, provado nas 3 × 3 × 4 × 14 combinações (`family_bodies_test`).

## 3. Cultista: nó persistente da Geometria e da Revelação

- Novo `scripts/classes/cultist/cultist_figure_node.gd` (sem `class_name`): um `Node2D` de apresentação, filho do pai do jogador (arena ou vista da expedição), fora de qualquer grupo de snapshot. Lê `figure_state(kind)` do kit, nunca escreve. A figura fica no ponto do chão do cast (`top_level`, projetada no mundo; z do chão); o olho segue o Cultista e fica acima dos atores, com um aro de visão (raio 360) fraco no chão.
- Duração inteira: entra em fade em 0,3 s, fica estável e gira, e sai em 0,6 s no fim (4 s a Geometria; 5 a 7 s a Revelação, pelo rank).
- O kit (`cultist_kit.gd`) ganhou `figure_state`, `draw_persistent` e `_sync_figure(s)`, chamados no commit de cada skill, em todo `on_tick` e na morte. O desenho do `effect_start` virou só o estouro do commit (anel que abre; flash do olho), para não dobrar a figura.
- **Limpeza:** no fim da duração (o tick libera o nó), na morte (`on_death`), ao recomeçar a skill (outro `serial` troca o nó) e num snapshot (o estado do kit muda por baixo: o nó se reconhece obsoleto, inclusive se `player.kit` deixa de ser o mesmo objeto, e um estado restaurado com figura ativa ganha o nó de volta no tick seguinte).
- **Formato compacto:** os bloqueios `cultist_geometry` e `cultist_revelation` de `snapshot_compact_blocker` seguem iguais; o nó não entra em `player_effects` (um teste confere), então o corte exato não tenta serializá-lo.
- Testes: `cultist_kit_test` 215 → **237** checks (nó durante 4 s e durante 5,5 de 7 s, liberação no fim, na morte e por troca de série, desenho em passagem `_draw` real, posição e z, snapshot).
- **Captura nativa:** `cultist_figures_{early,mid,late}` (0,6 s, 2,5 s, 3,7 s) com um Cultista real (base e kit de produção).

## 4. Sacerdote: desenho do Exorcista e eventos de Graça e Exorcista

- **Desenho do Exorcista** (novo `scripts/classes/priest/priest_exorcist_mark.gd`, filho do inimigo, sem `class_name`): inimigo **Exposto** ganha um aro dourado quebrado no chão e um selo de luz sobre a cabeça, enquanto durar a fonte `priest_exposed` deste dono (some quando expira, quando outro dono a substitui ou quando o inimigo morre); escudo ou buff arrancado ganha uma rajada de 0,6 s. Um segundo Exposto troca o nó, nunca empilha.
- **Eventos de feedback:** as duas passivas passam a publicar `skill_committed` no jogador (o que a ponte transforma em `effect_start` da receita): receitas `GRACE` e `EXORCIST` agora com `COMMIT` (família buff, luz), efeitos novos `priest_grace_gain` (anéis de luz que sobem) e `priest_exorcist_flash` (cruz-sol nas mãos). A Graça emite um evento por ganho de carga (cura excedente, Prece e Escudo Votivo, luz no marcado pelo Selo) e no pulso de entrada do Santuário; reserva cheia não emite. O Exorcista emite quando age (escudo, buff ou Exposto). Sem estado novo no kit: a comparação é de antes e depois dentro do próprio gancho.
- **Áudio:** nenhum `.wav` nem catálogo novo. A cadeia de `effect_start` das duas receitas é a da Égide (buff × luz), que já tem deixa planejada; o teste confere que a cadeia é idêntica à da Égide e que o primeiro item é planejado. Sem lacuna a registrar. A conferência sonora por ouvido continua pendente (o recibo da T7 já registra o mesmo para a Égide).
- Testes: `priest_kit_test` 220 → **240** checks (eventos, receitas, nó, desaparecimento, áudio); a contagem de efeitos reservados passa de 8 para 10 e o desenho em `_draw` de 9 para 11 (número exato).
- **Capturas nativas:** `priest_exorcist_burst` (Exposto e rajada) e `priest_exorcist_exposed` (2 s depois).


## 5. Capturas nativas

Janela Godot 1280×720, **renderer real** (OpenGL, `Godot --path . --script …`, sem `--headless`), em `docs/epics/e10a/t16_evidence/`. Três sondas versionadas em `tools/`:

- `tools/e10a_t16_effects_probe.gd`: **efeitos de código da base (T5), do Sacerdote (T6) e do Cultista (T7), que nunca tiveram captura.** As pranchas `effects_<módulo>_<n>` desenham cada efeito reservado com o desenho do próprio módulo (`ClassKitRegistry.draw_vfx`, a mesma chamada que a `FeedbackVfxLayer` faz por pulso) em t = 0,12, 0,35, 0,60 e 0,85 (escala 0,6; 1,4 nos de até 100 px): Acólito 6 efeitos em 2 pranchas, Sacerdote 10 em 3, Cultista 9 em 3. Em seguida, cenas vivas com jogador real (base e kits de produção): `cultist_figures_*` e `priest_exorcist_*`. A prancha **não passa pela camada nem pelos limitadores de pulso**: prova o desenho, não o fluxo do evento (que é do `e08_feedback_recipe_test` e dos testes de kit).
- `tools/e10a_t16_book_probe.gd` (estende a sonda da T8): o livro reduzido nos três corpos (`book_*`, 64 poses, 2×), os marcadores de grip e dedos (`grip_*`), o cetro do Sacerdote com o ângulo por prop (`scepter_priest_*`) e o relicário reto (`reliquary_priest_*`). Mesmo renderer do jogo (`CharacterAnimation`, `EquipmentAttachmentVisual`, corpo escolhido por `actor_kind`).
- `tools/e10a_t16_ui_probe.gd`: a **criação** (`ui_creation_fresh`: quatro bases; `ui_creation_acolyte_selected`: Acólito criado e escolhido) e o **onboarding em combate** com o corpo da T8 sobre uma arena real (`ui_onboarding_acolyte`, `_priest`, `_cultist`). O menu de criação não mostra corpos (só botões e texto); o corpo aparece no onboarding. As capturas da T10 eram anteriores à integração dos corpos.

Resultados das sondas (`result_effects.json`, `result_book.json`, `result_ui.json`): 125, 1.040 e 9 checks, 0 falhas; 13, 16 e 5 capturas. Leitura visual por mim, a 1× e 2×: a Geometria e o olho aparecem do começo ao fim e a figura esvanece nos últimos 0,6 s; a Geometria só aparece na captura porque a página de fundo fica no z −2 da vista da arena, como em jogo (a primeira rodada, com o fundo em z 0, a escondia).

| Arquivo | SHA256 |
|---|---|
| `book_acolyte_ew.png` | `a46b33f87c4b6258e37ef971a8882c80a66351e55ee2386469d222a4f4eb7174` |
| `book_acolyte_sn.png` | `2cffebe86c682ae38ff7b3ca6445d28055e499a4286f22c70cef53c219e1f41f` |
| `book_cultist_ew.png` | `9b22b42edb443ddd947c3e674b5a73cc8a94071ba006de8b79b99b4a79b645dd` |
| `book_cultist_sn.png` | `88504b46c84c0e0fdb1b0fc7732f66809a5ba765672c2b811068b426fea9d37d` |
| `book_priest_ew.png` | `0981c50f5a390de56b348c24502fc717779783c7177c6dcb7df1e76cd1c317e7` |
| `book_priest_sn.png` | `bf9caa16d89d3f756097b09b2f6ff6bee82d75becacaa852b64ef7a194fe8667` |
| `cultist_figures_early.png` | `16b067a36c175c1be868c591f39363d8aeca2679b77a0a7e6445d237d09922d5` |
| `cultist_figures_late.png` | `a3c1a350bf2886da686da97a2540ec7ebe4c8d998f6fd266a8dc54d847ea35f4` |
| `cultist_figures_mid.png` | `3cf42205f71edec81041e79dd174751e3db8f43ec60c7cd667e751c5a9171576` |
| `effects_acolyte_1.png` | `097e60a468e3bf50716ca0977769ade38f045ed35d91f6a0074291ec55d51493` |
| `effects_acolyte_2.png` | `2a09034890313e7771c1102ec930829c9f521b641ba45394a5fdea7dca7fea1c` |
| `effects_cultist_1.png` | `0c3d26e52115f88d6c75b0d7ab7561c1c25854c8b9ba509564e1733f12346cb8` |
| `effects_cultist_2.png` | `c547ffa89c2a23f8f1e0c063b9c1f7e85c5c9addb70378f5822b90520f4384ea` |
| `effects_cultist_3.png` | `d899c9f29ba85b6e1c6877bb202c46f8934d7893fe832a40d37fb9d4f44c1bac` |
| `effects_priest_1.png` | `eb6935d8e72eb69683c4c3f1f5d64cfc93f3beae3660058c9e5c6315774aa562` |
| `effects_priest_2.png` | `8d2b15d24812bab21e43e0928f856f460a105db02a3e8f65548c36d2bc440470` |
| `effects_priest_3.png` | `ea3c21d1864124ab707c5b6e56706b357aca3931f2f0e126e5e7306d703c1178` |
| `grip_acolyte_ew.png` | `5a90c785c3a006ad61960a9688600d27d38ae570de733860aa216134151b76f2` |
| `grip_acolyte_sn.png` | `58f93296d6c7789d622197ff74c771cf23ba750050115331d734d6c4428fa306` |
| `grip_cultist_ew.png` | `1544def9b8ffe64b7971517a8392ab8af9ba82e2e628fae71f4a11dd218b9908` |
| `grip_cultist_sn.png` | `e5e5b87df7ed1e211f822c41b8ec3c62884a2f1df1ee69bf3f316025f79d6e61` |
| `grip_priest_ew.png` | `2d9d050cc423849c29d92a6c61f6d75c4f78637ace7241af841079503e22f2f9` |
| `grip_priest_sn.png` | `03caa95692fd0a816f6476ebddd092957689c68b845d70f5f0ec87d90453f68f` |
| `priest_exorcist_burst.png` | `0e906e1a2bb1a78da143eee978101698292508c351e95e27754b279a9bdc0e09` |
| `priest_exorcist_exposed.png` | `8f0f722807315c6968c6715265ae4cf3e52b3ee4c17458d17e8dcf785e670918` |
| `reliquary_priest_ew.png` | `016115ba51b506367a81e3aa635a2593fd5f7bdd0c1e4a18a21fba4e7b2850ae` |
| `reliquary_priest_sn.png` | `13b00388f58648fbe1cbb486e96c49f10549f2e85a7c306145a4e664912d6918` |
| `scepter_priest_ew.png` | `7241aa2d200f4cc820256971f3444f4bf277cccd3b4bfe592d149967c0ce549e` |
| `scepter_priest_sn.png` | `48889f3e98d7b24dc5baa68ed524b15cc30a94403c887f5cadf4d0597a546ec4` |
| `ui_creation_acolyte_selected.png` | `ec67a1c7ec1a3b3608fa69892dca4b338cddb7c84bc850829d0450f683c26b5f` |
| `ui_creation_fresh.png` | `810ccc5583640c9e14e767e157548b63f8028248985276e82a7b1caec062d2e5` |
| `ui_onboarding_acolyte.png` | `3edcb0f4c7249a7fcd50da8d12dffc87b607e72895e58d03c7c044f869a5608b` |
| `ui_onboarding_cultist.png` | `e2ccc01dbba1d40fc36c5319b638d6360379a0bb4bb79e97c0015fadc8c74a97` |
| `ui_onboarding_priest.png` | `eef2b7e8d7587c0a27780b9845c1c6566aa3cba1fe62397e9e5867ff6b8de90e` |

## Testes

Ambiente: Godot 4.7.2 standard (`Godot_v4.7.2-stable_win64.exe`), importação do editor por inteiro antes (`--headless --editor --import --quit`, saída 0, uma passada); cada teste em invocação própria de `tools/verify.ps1 -SkipEditorImport -CheckTimeoutSeconds 300 -GodotPath … -Test <t>` (rodado por `pwsh`). Sem a suíte completa. Nenhum log tem `SCRIPT ERROR`, `still in use` nem `ObjectDB instances leaked` (conferido por busca). SHA256 do `.output.log`.

| Teste | Resultado | SHA256 da saída |
|---|---|---|
| `family_bodies_test` | **7.425** checks, 0 falhas (eram 6.313: +1.112 de ângulo por prop e de livro) | `0C332E505B6369E586B3D3BAD8F9798149E555CD59B4E95A921AAF4C23CB5F21` |
| `equipment_items_test` | E09 244, E10a 301, 0 falhas | `EB9A6284A69D053A831B7302AFE2C42DB336F816F57B4EB290BD5EBBD9A2CA90` |
| `equipment_hand_alignment_test` | 4.593, 0 | `38A87BF0439BDB473ABA8B25A1455D60554E8F41F99E1E0DC53853009A3C9145` |
| `e08_equipment_art_test` | 100.863, 0 (só os dois avisos de fixture de sempre) | `5F377D76E832657FF84BA0350BF420124DF8CE62CC1FC865F8C0201A338C07AC` |
| `e08_directional_units_test` | 77.804, 0 | `F42ED54C4034FDEB0EAFA67999A8BECE16DCB2DA5454478EC66A94DCD8BA5436` |
| `e08_directional_rig_compatibility_test` | 83.328, 0 | `327931343AC222A254AF8B4969F558063BFD0392BBCC2499D8C9E101DD16C20C` |
| `hybrid_bodies_test` | 6.300, 0 | `B9C7E7033E7A19D443AFD4A3B15FF4080152634E2D4D91066B113E5A00C53F69` |
| `priest_kit_test` | **240**, 0 (eram 220) | `64BC6C0B4DF6CC046790A7CE872C031DE5FA4290EBF12D7AFCBE5B94330878F2` |
| `cultist_kit_test` | **237**, 0 (eram 215) | `3D91804DB4B2916C6B57D1C7E7BE9318B139CC41E192BD8E963EE2969C797763` |
| `e08_feedback_recipe_test` | PASS, 1.433, 0 (mesmo número e mesmo hash do recibo da T7 depois da A14) | `1601B34D112F1352392E09F17542BBE6A3C6EC4BC8148E9A38CA6F13A3E823BA` |
| `priest_boss_combat_test` (extra) | 32, 0 | `16BBBC37182E6FCE188BCA2AD7E7209E9581C66D5A45B70D09E79BDE3F97C329` |
| `cultist_boss_combat_test` (extra) | 49, 0 | `88E65883F8333B3D3A7AFC390CDE505B204E4F912CFBF6B581317901E386962C` |
| `cultist_campaign_kill_test` (extra) | 20, 0 | `212B00D3EAEF50D157FD8D3011AE42B3E5CB0DB5DF0FCC92B83521E3F2031BF0` |
| `kit_seam_test` (extra) | 276, 0 | `60643509690EB7E2D61089293F064B839EEB322B92DAD5C671E0581CD81A6C2F` |
| `e07_f1_import_test` (preparo do fixture F1, depois da última edição de teste) | PASS, 3.659 arquivos idênticos | `205C045EEF260AC285D6FECD96BD2A97819884B10A9C3065F4451BEEB56A3245` |
| `e08_feedback_vfx_test` (`-F1Fixture`, extra) | 697, 0 (sem o fixture falha 1 check, o do fixture F1 desatualizado, como a T6 já registrou; com ele passa) | `BF9FE3B061909EE6B5679566EA06FB54893237A84AB4A849156C04186F4E6439` |
| `e08_vfx_art_test` (`-F1Fixture`, extra) | 1.238, 0 | `100CB3FA5F22769134755234BA5792EEF140627BBD899E6E403C6D0203926D89` |

Os hashes de `equipment_items_test`, `equipment_hand_alignment_test`, `e08_equipment_art_test`, `e08_directional_units_test`, `e08_directional_rig_compatibility_test` e `hybrid_bodies_test` são iguais aos da rodada da T8 porque a saída só carrega contadores; o que mudou está nos testes (o `EXPECTED` do livro) e nos dados, e as verificações passam sobre o novo PNG e o novo grip.

### Ajustes de testes (A15 do E09), cada um com número exato

| Arquivo | Antes → depois |
|---|---|
| `tests/e10a/equipment_items_test.gd`, `EXPECTED[prayer_book]` | `Vector2(80, 120)`, `Vector2(10, 12)` → `Vector2(64, 96)`, `Vector2(8, 12)` |
| `tests/classes/priest/priest_kit_test.gd` | efeitos reservados 8 → 10; desenhados em `_draw` 9 → 11 (10 + o ID desconhecido) |
| `tests/classes/cultist/cultist_kit_test.gd` | sem contagem alterada (nove efeitos reservados) |

Nenhuma expectativa foi afrouxada; os testes novos só acrescentam checks.

## Limitações

1. **Livro e a cabeça.** Nas 11 poses vivas de prece e de mão erguida o livro ainda toca as linhas da cabeça (243 pixels no total, contra 315 do grip anterior e 2.210 do original da T9); com a palma ao lado do rosto, nenhum grip evita isso sem passar do chão parado. Só uma calibração de mão diferente, ou uma pose de mão sem o livro, resolve.
2. **Redução por vizinho mais próximo com razão 0,8** (80→64, 120→96): perde pixels de forma desigual e não é arte nova. O resultado foi lido a 2× nos três corpos; o aceite de produto é do usuário. O ícone de 128 px do livro não foi tocado.
3. **Prova do evento do Exorcista e da Graça na ponte.** O kit emite `skill_committed` e a receita é `COMMIT`; o `effect_start` completo (ponte → `FeedbackVfxLayer`) não foi provado ponta a ponta em jogo, só o emissor, a receita, o desenho e a cadeia de áudio. O som usa a deixa do tipo buff × luz, a mesma da Égide; ainda sem conferência por ouvido.
4. **O desenho do Exposto some num snapshot** que reconstrói o inimigo (o nó é de apresentação e o estado `received_damage_sources` volta, mas o nó só é criado pelo Exorcista no golpe); aceitável por ser só cosmético.
5. **Nó do Cultista no mundo da expedição.** Provado em arena plana (teste e captura); a projeção do mundo (`ProjectionMath`, escala `GROUND_WORLD`, z por altura) vem do mesmo cálculo do `KitWorldOverlay` e do `FeedbackVfxLayer`, mas não foi capturada numa expedição real; fica para a T13 ou o playtest.
6. **Posição de `directional_animation_set.gd`** (`scripts/presentation/`): a linha de dono da tarefa dizia `scripts/actors/`.
7. **Ambiente.** O editor reescreveu cerca de 650 `.import` rastreados e criou `.import` de arte-fonte; nada disso entra no commit, nem o `.import` de `prayer_book_full.png`. Os `.uid` das três sondas em `tools/` não foram gerados (a sonda roda por `--script`); o próximo `--import` os cria.
8. **Não rodei a suíte completa** (`verify.ps1` sem `-Test`): a mudança toca arte, dados de encaixe, dois kits e um validador de manifesto; o impacto foi coberto pelos testes acima.

## Próximo passo

T13 compõe esta branch junto da T15 (donos de arquivo disjuntos). A T12 (HUD) parte do candidato depois das duas.

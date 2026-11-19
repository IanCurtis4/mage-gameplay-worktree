# E10a T15 — recibo das correções de costura e jogabilidade (A15, A17, A19–A22)

Papel: Sol (Claude Opus 5.5, esforço alto). Decisões: A15 de [e10a.md](../e10a.md) (itens 3 e 5;
linha T15), A17 (`a5b1ce04`), A19 (`fe12a023`), A20 (`651d0b38`), A21 (`b4f054f9`) e A22
(`8917268b`: escolha do usuário, "Só o próprio andar", para o Juízo do Sacerdote e do Paladino).
Todas estão na branch de arquitetura e chegaram por mensagem da Astra durante a tarefa. APIs:
[t1_base_seam_api.md](t1_base_seam_api.md) (com o adendo abaixo) e
[t4_madness_api.md](t4_madness_api.md). Recibos lidos: [t5](t5_delivery.md), [t6](t6_delivery.md),
[t7](t7_delivery.md), [t10](t10_delivery.md) e [t11](t11_delivery.md).

## Base e checkout

| Item | Valor |
|---|---|
| SHA-base | `71d57a11` (`git merge --ff-only claude/e10a-candidato`; composição 9) |
| Guarda E12 | `git merge-base --is-ancestor claude/e12-candidato HEAD`: verdadeiro |
| Arquitetura | `claude/e10a-arquitetura-a413a1`: A15 em `cf176e6a` e A16 em `6a629434`, já no candidato; A17–A21 chegaram por mensagem da Astra |
| Merge da T11 | `fddea9ed` (branch `claude/youthful-robinson-db714a`: `e07_f1_composition_test` com 31 receitas e `EnemyActor` reais), pedido pela A20, merge `c3ccb431` |
| Branch | `claude/youthful-meninsky-4da2e3` |
| Checkout | `C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.claude\worktrees\youthful-meninsky-4da2e3` |
| Commit entregue | o commit que contém este recibo (ponta da branch) |
| Engine | `Godot_v4.7.2-stable_win64.exe` (A7), `-GodotPath`; `editor_import` duas vezes (as duas primeiras rodadas estouraram os 300 s, a terceira passou), depois `e07_f1_import_test` refeito a cada edição de teste |

Sem push, sem `master`, sem `codex/playtest`, sem save pessoal. Perfis só de fixture, nada
gravado em disco. Os `.import` reescritos pelo editor ficaram fora do commit.

## Arquivos

Todos dentro do dono exclusivo da linha T15, mais as duas transferências da arquitetura:

| Arquivo | Mudança | Posse |
|---|---|---|
| `scripts/classes/class_kit.gd` | gancho novo `barrier_received(player, capacity, context) -> float`; filtro estático de andar (`floor_area`, `on_anchor_floor`, `world_anchor`, `anchor_on_floor`, A21) | T15 |
| `scripts/actors/combat_actor.gd` | caminho novo `grant_barrier(capacity, source) -> float` | T15 (caminho de barreira) |
| `scripts/systems/sanctuary/sanctuary_authority.gd` | `grant_aegis` passa por `grant_barrier` e guarda a capacidade efetiva | **A17**, só `grant_aegis` |
| `scripts/systems/sanctuary/sanctuary_helpers.gd` | `judgment_targets` filtra pelo andar do ponto | **A19**, só `judgment_targets` |
| `scripts/classes/cultist/cultist_kit.gd` | `gaze_targets`, `_geometry_pulse` e `_in_sight` filtram pelo andar | **A20** (`gaze_targets`) e **A21** (as outras duas), só essas três funções |
| `scripts/systems/madness/madness_authority.gd` | `_idol_gaze` filtra pelo andar do Ídolo | **A21**, só `_idol_gaze` |
| `scripts/systems/madness/madness_helpers.gd` | `neighbours` (contágio) filtra pelo andar do centro | **A21**, só `neighbours` |
| `scripts/classes/bases/acolyte/acolyte_base.gd` | Fé Protetora pelo gancho; Escudo Votivo por `grant_barrier`; textos | T15 |
| `scripts/classes/cultist/review_builds.json` | ranks 0 removidos | T15 (só os ranks 0) |
| `tests/systems/sanctuary/sanctuary_test.gd` | linha 640: enumeração legada da A22 (abaixo) | **A22**, só a linha 640 |
| `tests/classes/acolyte/acolyte_base_test.gd` | invariantes do gancho (`_check_barrier_hook`) | T15 |
| `tests/classes/acolyte/acolyte_boss_combat_test.gd` | cenário do Delírio | T15 |
| `tests/e10a/family_integration_test.gd`, `tests/e10a/family_world_test.gd` (+ `.uid`) | novos | T15 |
| `docs/epics/e10a/t15_delivery.md` | este recibo | T15 |

Em `scripts/classes/{priest,cultist}/**` (T16) só toquei o JSON e as três funções da A20/A21.
Não editei `health_state.gd`, `player_actor.gd`, o resto de `madness/**` nem
`e07_f1_composition_test.gd` (veio pelo merge da T11). `class_base_registry.gd` não
precisou de mudança.

**Enumerações legadas (A15 do E09):**
- **Gancho de barreira: 0.** O Votivo com a Fé dá o mesmo número de antes, e as Égides do
  Paladino e do Taumaturgo não têm módulo que responda ao gancho.
- **Filtro de andar: 1**, `tests/systems/sanctuary/sanctuary_test.gd:640`, pela A22:
  - antes: `lower in column and upper in column and far not in column`, "the Juízo column is
    vertical (x/z radius, height band)";
  - depois: `lower in column and upper not in column and far not in column`, "the Juízo column
    reaches only its floor (A22)".
  - É a mudança de contrato do E09 que o usuário escolheu. O check ficou mais estrito, e o total
    continua 155. A falha apareceu na regressão (155 checks, 1 falha, só essa) e foi à
    arquitetura antes de qualquer edição.

## Entregas

### 1. Gancho de barreira recebida (A15.3, A17)

- `CombatActor.grant_barrier(capacity, source)` é o caminho único de barreira. Num jogador, ele
  encadeia `ClassKit.barrier_received` dos módulos (origem, depois evolução) antes de
  `HealthState.grant_shield`. O valor devolvido é a capacidade concedida, ou 0 se nada foi
  concedido. Os módulos são chamados por método: `combat_actor.gd` não nomeia `ClassKit`, pela
  regra de ciclos da A7.
- Fé Protetora: `acolyte_base.barrier_received` multiplica toda barreira por 1,10/1,15/1,20.
  O Escudo Votivo pede agora a capacidade simples e guarda a concedida. Assim conta uma vez só,
  e o número com a Fé é o mesmo de antes.
- Égide (A17): `SanctuaryAuthority.grant_aegis` chama `player.grant_barrier(capacity, skill_id)`
  e grava em `aegis_capacity` a capacidade efetiva. O vencimento continua reconhecendo a barreira
  dela, também reforçada. Vale para o Sacerdote, o Paladino (`sp_ac`) e o Taumaturgo (`mg_ac`).
  Os dois últimos não respondem ao gancho, então nada muda para eles.
- `HealthState` não foi subclassificado (A17): o snapshot o identifica pelo caminho do script.
- Lista exata vigiada (`family_integration_test`). Chamam `HealthState.grant_shield` direto só:
  - o próprio `combat_actor.gd`;
  - a Muralha do Espadachim (`player_actor.gd`, nunca ao lado de um módulo Acólito);
  - a base de teste da T7 (`cultist/fixture/cultist_fixture_base.gd`, fora do registro).
- Texto pt-BR: "toda barreira recebida fica mais forte: o Escudo Votivo, a Égide do Sacerdote e
  as outras"; por rank, "cura recebida e barreiras recebidas +N%".

### 2. Cultista e Sacerdote sobre a base real (`family_integration_test`)

Sem base de fixture. O `PlayerActor.configure` liga os módulos de produção a partir de um
`BuildSnapshot`, como `RunController._ready`, e os golpes passam pelos handlers do
`RunController`.
- **Cultista:**
  - há uma autoridade só, o campo `madness` da base, achada por `MadnessAuthority.of`;
  - Sussurro R5 dá 40, Selo R5 soma 26, e o Olhar soma às mesmas marcas até o Delírio;
  - o Delírio dá 1 carga de Êxtase e mira o outro inimigo;
  - o Êxtase só liga com a passiva;
  - custo −15% uma vez nas skills da base e do kit, MATQ +15% publicado uma vez, ônus ×1,08 uma vez;
  - o Votivo (com a Fé R1) absorve e a Prece cura sob o ônus;
  - o chefe nunca é empurrado nem redirecionado.
- **Sacerdote:**
  - a Égide sai com Fé R0 e R3 (×1,00 e ×1,20, uma vez) e vence no prazo, também reforçada;
  - Votivo e Égide juntos guardam a maior barreira, nunca a soma;
  - a Prece e o Escudo da base dão Graça.

### 3. Mundo da expedição (`family_world_test`)

As skills passam por `RunController.cast_world_skill` e `PlayerActor.request_world_skill`, sobre
a geometria F1, com módulos de produção e mobs reais ligados ao mundo. Em cada ativa, confiro a
prévia do mundo, o pagamento (SP e recarga) e o efeito.
- **Acólito:**
  - o projétil da Luz Punitiva voa e acerta;
  - o Selo marca e dá 26;
  - o Sussurro dá Loucura ao lobo e ao chefe, empurra o lobo e não o chefe, e poupa quem está atrás;
  - a Visão aumenta o alcance do básico e carrega;
  - a Prece cura;
  - o Votivo dá ×1,20 uma vez.
- **Sacerdote:**
  - o Santuário abre no ponto;
  - a Égide dá ×1,20;
  - a Prece e o Escudo pelo mundo dão Graça;
  - o Selo de Luz sela;
  - o Juízo gasta Graça e fere;
  - a Hora Santa abre.
- **A19:** coluna do Juízo por andar (abaixo).

Nenhuma lacuna de runtime apareceu nesse caminho.

### 4. Delírio no combate integrado da base (`acolyte_boss_combat_test`)

Os 19 combates continuam como estavam: o job 19 dá 17,2 s e 584/624, igual ao recibo da T5. Um
20º combate, no job 19, muda só o cenário:
- a ordem legal de pontos, contemplativa: Luz 2, Prece 2, Escudo 1, Selo 5, Sussurro 5 e Visão 3;
- um lobo da floresta ao lado do mestre, como segundo alvo;
- o posto do mestre no lugar da luta.

Nenhum número de balanceamento mudou. Resultado: Delírio 1 vez (5,0 s), Loucura máxima 80 antes
do Selo, mestre vencido em 19,2 s, 560/624 HP.
- **Achado de cenário.** Sem o ajuste do posto, o Delírio aconteceu, mas o mestre ficou preso em
  `returning` pelo resto da luta: imune, sem atacar, com 3% de dano.
- **Causa.** `configure_occurrence` grava `spawn_home` com a posição do momento, que é a origem.
  O teste só posiciona o mestre depois. O empurrão do Sussurro R5 tira o mestre da guia de 850,
  e ele tenta voltar a (0,0), na borda da navegação.
- **Alcance.** É artefato do teste, e não do jogo: no jogo o posto é o ponto de nascimento. Por
  isso o 20º combate fixa o posto, e o lobo é posicionado antes do `configure`.

### 5. `review_builds.json` sem rank 0

Removi `cultist_impossible_geometry: 0` do Profeta e `cultist_ecstasy: 0` do Vidente.
- O leitor estrito do E09 (`E09Profiles.read_builds`) aceita os dois arquivos puros (`ready`, 2
  builds).
- A ferramenta da T10 lê o arquivo no lugar: `_tolerant_root` devolve a raiz, sem cópia saneada.
- Os perfis continuam legais (`ui_family_test`).
- A tolerância da T10 ficou, agora sem efeito.

### 6. Coluna do Juízo por andar (A19)

`SanctuaryHelpers.judgment_targets`, no mundo, mantém o raio x/z e a faixa de altura e passa a
exigir o mesmo andar do ponto.
- O teste do andar é a seleção canônica de chão do E07: `WorldEffectArea` com
  `ground_connected`, o mesmo alcance (raio da coluna mais o raio do alvo) e o perfil de travessia
  do dono.
- Se o ponto não ancora uma área para esse perfil, decide a mesma superfície.
- O mapa plano e a zona do Santuário não mudaram.
- Prova em `family_world_test`, com dois inimigos empilhados na F1 (root y=0, bridge y=40):
  - a coluna no andar de baixo pega só o de baixo, e a da ponte só o da ponte;
  - longe em x/z, não pega ninguém;
  - o Juízo pelo comando do mundo fere o lobo de baixo e não toca o javali da ponte.
- `e07_f1_composition_test` (base T11 `fddea9ed`): 342 checks, 0 falhas, 31 receitas; o check
  "never projected other floor" passa no `pilot_priest_b` (Juízo) e no `pilot_cultist_b` (Olhar).

### 7. Filtro de andar das seleções da família (A20, A21)

Auditoria das seleções espaciais da família no mundo:

| Seleção | Antes | Agora | Invariante de andar (`family_world_test`) |
|---|---|---|---|
| Juízo (`SanctuaryHelpers.judgment_targets`) | faixa de altura de 200 | filtro de andar (A19) | coluna embaixo / na ponte; Juízo pelo comando do mundo |
| Olhar do Abismo (`CultistKit.gaze_targets`) | distância no plano | filtro de andar (A20) | seleção pura e comando do mundo |
| Sussurro (`acolyte_base._resolve_whisper`) | distância no plano | filtro de andar | comando do mundo: Loucura e empurrão só embaixo |
| Geometria (`CultistKit._geometry_pulse`) | distância no plano | filtro de andar, âncora refeita do centro a cada pulso | comando do mundo; âncora reconstruída no andar certo (embaixo e na ponte) |
| Revelação (`CultistKit._in_sight`) | distância no plano | filtro de andar | seleção pura e comando do mundo |
| Ídolo (`MadnessAuthority._idol_gaze`) | reta 3D (raio 180 > 40) | filtro de andar do Ídolo | comando do mundo: só o andar de baixo mira o Ídolo |
| Contágio (`MadnessHelpers.neighbours`) | reta 3D (raio 140) | filtro de andar do centro | vizinhos e cópia de Loucura só embaixo |
| Santuário (`SanctuaryZone.contains`), modo zona do Juízo | já canônico (`WorldEffectArea.contains_actor`) | sem mudança | — (o `sanctuary_test` já prova) |
| Selo de Luz | alvo único do comando | sem mudança | — |
| `nearest_non_boss` (alvo do delirante) | o delirante anda até lá por rota | sem mudança (A21) | — |

- **Filtro único:** `ClassKit.floor_area(actor, anchor)` + `ClassKit.on_anchor_floor(area,
  anchor, target, reach)`. É a seleção canônica de chão do E07: `WorldEffectArea`,
  `ground_connected`, o alcance da própria seleção mais o raio do alvo no mundo, com o perfil de
  travessia de quem ancora (o dono, o Ídolo ou o inimigo do centro).
- **Casos de borda:**
  - no mapa plano o filtro não atua (âncora nula);
  - sem área, decide a mesma superfície;
  - alvo fora do mundo ou do estágio fica de fora.
- **Teste e alcance:** cada seleção conserva o próprio teste de distância ou cone, e o filtro de
  andar vem por cima: ele só restringe.
- **Geometria:** ela guarda só o centro (`Vector3`, no fragmento da T16). Por isso
  `ClassKit.anchor_on_floor` refaz a âncora a cada pulso: procura, entre as superfícies do dono e
  dos inimigos, a que tem suporte na altura do centro. Sem campo novo no snapshot.
- **Semântica:** "mesmo andar" é chão conectado dentro do alcance da seleção, como no Santuário.
  Um inimigo de outro andar que se alcança a pé, pela rampa, dentro do raio, conta como chão
  conectado.
- **Cenário de prova:** na F1, a ponte fica a cerca de 460 a pé de quem está embaixo, acima de
  todo raio da família (a Revelação tem 360). A pilha do teste fica em x=20: o andar de baixo vai
  de x 0 a 100, e a rampa sai em x=100.

## Validação

Comando: `tools/verify.ps1 -SkipEditorImport -F1Fixture -CheckTimeoutSeconds 300 -GodotPath
".../Godot_v4.7.2-stable_win64.exe" -Test <t>`, um teste por chamada, depois de `editor_import` e de
`e07_f1_import_test` refeito a cada edição. O sha256 é o do log completo de cada chamada, em
`.godot/t15_evidence/` (ignorada pelo Git). Nos 31 logs não há `SCRIPT ERROR`, `still in use`,
`Parse Error` nem `FAIL:`. Ao fim, um `editor_import` gerou os `.uid` dos dois testes novos.

| Teste | Resultado | sha256 do log |
|---|---|---|
| `e07_f1_import_test` (última) | PASS | `8F49CBA191C96804C012B756277505C0669522EAAF177EEF2F987CDB4A4AEEEE` |
| `family_integration_test` (novo) | 60 checks, 0 falhas | `878DFE99A5B0D5E0363D79E56CB3E3B71FAC20E43CE7EC7DF5189925F98FB270` |
| `family_world_test` (novo) | 149 checks, 0 falhas | `74CD338F70977418F148636CAEC2F3E5C20566D105E789D02C79D60F6E934F76` |
| `e07_f1_composition_test` (base T11 `fddea9ed`) | 342 checks, 0 falhas, 31 receitas | `E44DF02F86A11836DFD7760159D6951AA670733104AADA531868B9F98C68FE61` |
| `sanctuary_test` (com a linha 640 da A22) | 155 checks, 0 falhas | `CC852122F6DFA7BB5D10F52232B4BB173C6D4A3C3B7E2E767195644EF681C3EF` |
| `acolyte_base_test` | 332 checks, 0 falhas (304 da T5 + 28 do gancho) | `9FBE87DE93D0EB31BEA53B0C6CAE960AB7DB5395F31BA5436B5B52F971F3016E` |
| `acolyte_boss_combat_test` | 295 checks, 0 falhas (20 combates) | `C4417FB73D7EC4163D5DA04BEC777F3886B4E322614772CF1F887CFF75B3F967` |
| `base_seam_test` | 172 checks, 0 falhas | `C18A463BCB892B15E5709E9A68CD7E69630AE3D04309E1AC59893AD19F76C87C` |
| `kit_seam_test` | 276 checks, 0 falhas | `99C5EEF55140296F42792BECBABBAB78FA99C03B1F63ADFB09E080D22C80F203` |
| `kit_seam_hooks_v2_test` / `v3` | 38 / 63, 0 falhas | `77561B103E6CDC634BD9BE2CDA66CB21B2AE69FD192F2013D7D20D4F0FDE4A79` / `14E320F45BBE26E3E989918063FEF5840979919A43E7D3F5E7B840A9260779CE` |
| `priest_kit_test` / `priest_boss_combat_test` | 220 / 32, 0 falhas | `E39AA92D2F194E8ECCC140957D36DE514DC3A9121AD54ED905313BB24CC9D6C0` / `DAA46A0FAB62FB1AB5C5F4483802C704C2374547810620A6CB76CBDB0EFAA869` |
| `cultist_kit_test` / `cultist_boss_combat_test` / `cultist_campaign_kill_test` | 215 / 49 / 20, 0 falhas | `C4C1262E3986AE0F1E3B62C3E1AF358B69774BBCE7C6ACAECE87CB75091FE86F` / `AA614A19ACA6316BA9AF98995C8CEF09DDF11CAF598C79F7CB1EC1366E2A697C` / `2EA742DD8794B36F7E9E9BD186AA772761955475F4D73031AAD976031B3764BC` |
| `madness_test` (Ídolo, Delírio e contágio da T4) | 276 checks, 0 falhas | `E04720FC612CB79505D55740EA0538D687CF3D76F41678083032241DD9EE4A0E` |
| `enemy_target_test` | 88 checks, 0 falhas | `628CF98F9C90CF48C1A24456812A026B1E41A28ED2914E44A704D5D13A3A2939` |
| `sp_ac_kit_test` / `sp_ac_boss_combat_test` / `sp_ac_hud_test` (Paladino) | 170 / 25 / 57, 0 falhas | `6089EA930923FE255F052B7C6A2397B8E2D9AE0AD3291126861599764B19F6A8` / `F0DCA85FF7C7937F3BEF407C93D41B0456F89ED5DC7EB985072E7586A82E2EE6` / `33595D525A39EA160DFC2126F092C0C570A23CEC30E6F49FCB27670B152058E8` |
| `mg_ac_kit_test` / `mg_ac_boss_combat_test` / `mg_ac_hud_test` (Taumaturgo) | 177 / 29 / 60, 0 falhas | `460A77A1B10D72E8D0C34B8D4CDA0687A9645888596FA92BBCD92A9CF0EE6FAB` / `F7C3CF48C38FED9521EE77C28EB3D31198843F76ADD2E8AB68C50DCA1563A082` / `FA32159E0B3DE84C60494190CFE79724AE22F036E37941F7872703D410EDF785` |
| `augments_test` | 180 checks, 0 falhas | `2E25F5BFF9D42098457D53486C479DA7B3477875C21A911AF3B9D19AF3F6DF20` |
| `ui_family_test` | 86 checks, 0 falhas | `692BBCEA5B15142D85DE4113D2400414EE76596983FF8466ABE54C783913F979` |
| `ui_evolution_test` | 97 checks, 0 falhas | `6F34CFC38CD2248E0FB6C377F2535B63C71A827B3498999849993D6E60231258` |
| `e08_feedback_recipe_test` | PASS, 1433 checks | `125BD6A5EBB3D5E8846BC8DC2BAB2B0EF0785E5D590CFCE7159DD5596BC0C254` |
| `hud_components_test` / `hud_integration_test` / `hud_seam_test` (E12, tocam `combat_actor`) | 167 / 234 / 194, 0 falhas | `883DB38B6D3A0EDC849001642015C87D5109B86439F996507C7CFDBC34AED5E9` / `34420AA87BE93A21BB96418686B3FA2E747778BD95AF744D6C4037F509D0EE35` / `1DF9BD02C15B2DCABA46B44BB856DC2A05EAF5030B00DE46A02D298490508A9E` |

O lote completo rodou numa só passada sobre o código final, menos a linha 640. Depois da edição
da A22, refiz o `e07_f1_import_test` e, de novo, o Santuário, o Paladino, os dois testes novos e o
`e07_f1_composition_test`. Os hashes desses saíram iguais aos da primeira passada, exceto o do
Santuário, que é o da segunda. Não rodei a suíte completa, que é do fechamento.

## Adendo à API da T1 (`t1_base_seam_api.md`)

### §4 — composição: gancho novo

| Gancho | Regra |
|---|---|
| `barrier_received(player, capacity, context) -> float` | encadeado, origem e depois evolução. Cada módulo recebe a capacidade até ali e devolve a nova. Resposta não finita ou negativa mantém o valor anterior; 0 recusa a barreira. `context`: `source` (StringName, a skill ou o sistema que concede; vazio se desconhecido) e `raw_capacity` (float, antes de todo módulo). Puro: não concede barreira, não cura, não conjura, não gasta. Não há proteção contra reentrada, como no `skill_cost` |

### Caminho de barreira (`CombatActor`)

`grant_barrier(capacity: float, source: StringName = &"") -> float`
- Num jogador, chama o gancho dos módulos (por método, sem nomear `ClassKit`) e depois
  `HealthState.grant_shield`. Em outro ator, concede a barreira como veio.
- Devolve a capacidade concedida (a composta), ou 0 com ator morto ou capacidade inválida ou
  recusada.
- O `HealthState` continua guardando a maior entre a barreira atual e a nova. O produtor guarda
  a resposta para reconhecer a própria barreira no vencimento, como fazem o Votivo e a Égide.
- **Toda barreira nova passa por aqui.** Só a lista vigiada do `family_integration_test` chama
  `grant_shield` direto: `combat_actor.gd`, a Muralha em `player_actor.gd` e a base de teste da T7.

### Filtro de andar (`ClassKit`, estático, A21)

| Função | Uso |
|---|---|
| `world_anchor(actor) -> ExpeditionWorldPoint` | ponto do ator no mundo; nulo no mapa plano |
| `floor_area(actor, anchor) -> WorldEffectArea` | área de chão (`ground_connected`) da âncora, com a travessia do ator; nula sem mundo ou quando a âncora não ancora |
| `on_anchor_floor(area, anchor, target, reach) -> bool` | o alvo está no andar da âncora, ao alcance pelo chão (`reach` mais o raio do alvo); verdadeiro com âncora nula (mapa plano); sem área, a mesma superfície decide |
| `anchor_on_floor(actor, position, around) -> ExpeditionWorldPoint` | refaz a âncora de um ponto guardado só como `Vector3`, entre as superfícies do ator e de `around` |

Toda seleção espacial nova de um módulo, no mundo, conserva o próprio teste de distância ou de
cone e soma esse filtro.

## Limitações

1. **"Mesmo andar" é chão conectado dentro do alcance**, como no Santuário do E09. Se o raio de
   uma seleção for maior que o caminho a pé até outro andar, a seleção alcança esse andar. Na F1
   isso não acontece com nenhum raio da família: a ponte fica a cerca de 460 a pé, e o maior raio
   é 360. Num mapa com rampas curtas, pode acontecer.
2. **Geometria:** a âncora é refeita do centro a cada pulso, procurando entre as superfícies do
   dono e dos inimigos. Um centro numa superfície sem nenhum ator não acha âncora, e então o pulso
   não pega ninguém no mundo (o mapa plano não muda).
3. **Integração pelo `RunController`:**
   - os testes usam o caminho de partida do `RunController`: `PlayerActor.configure` a partir de
     um `BuildSnapshot`, com os handlers reais;
   - o controlador vem com o `_ready` desligado, como os testes T5 a T7, sem UI nem entrada de
     fase;
   - o projétil mágico do mapa plano cai na hora (substituto do voo). No mundo, o projétil do
     `RunController` voa de verdade.
4. **Cenário do Delírio:** o 20º combate fixa o posto do mestre (`spawn_home`) no lugar da luta.
   Sem isso, o posto ficaria na origem, porque o `configure_occurrence` vem antes do
   posicionamento. Os 19 combates originais não mudaram. É prova de laço, não de balanceamento.
5. **O efeito `votive_shield_up`** da Fé Protetora ficou com o nome antigo, embora agora cubra
   toda barreira. Mudar o ID mexeria em dado de catálogo sem necessidade. Os textos visíveis já
   dizem "barreiras recebidas".
6. **Achado fora do escopo, sem correção.** No mapa plano, um inimigo `returning` sem rota para o
   posto fica imune e sem atacar (F10 Q2). No mundo, a regra já exclui a volta sem rota. Só
   apareceu pela origem do posto no teste; registro para a arquitetura.
7. **Nada daqui foi ao playtest nem foi capturado.** A T15 não tem parte visual.
8. **Composição:** a T16 edita `cultist_kit.gd` em paralelo. As três funções da A20/A21 são
   minhas, e a A21 diz que o meu filtro prevalece no merge.

## Próximo passo

A T13 compõe esta branch, que já traz o merge da T11 `fddea9ed`, com a T16 no candidato. Depois
roda `e07_f1_composition_test`, `sanctuary_test` e os testes novos. A T12 parte do candidato com a
T15 e a T16.

# E08 — Briefing de arte 1121 (escrito em 14/11/2026): híbridas do Necromante

Escolha do usuário em 14/11, depois da entrega 1120
([e08_codex_art_1120_brief.md](e08_codex_art_1120_brief.md)). Este pedido cobre:
- **A.** o corpo (traje) das **sete híbridas do Necromante**, nas quatro vistas;
- **B.** uma folha com os três equipamentos novos dessas híbridas;
- **C.** uma folha com os objetos da família no chão, por último e só se sobrar limite.

Fonte: as fichas em [HYBRIDS_56_V3.md](../HYBRIDS_56_V3.md), seção "Aprofundamento — as sete
híbridas do Necromante", com os nomes simples de 14/11. O khopesh do Ceifador já veio na folha
H1 de 1120. O Carniçal de Raiz, o Colosso Suspenso, os efeitos e as camadas de placa do Cavaleiro
ficam para rodadas seguintes (seção D). As classes ainda não existem no jogo; tudo entra em
staging.

## Regras para esta rodada

Iguais às de [e08_codex_art_1120_brief.md](e08_codex_art_1120_brief.md):
- **só imagegen**, saída salva byte a byte; edições viram nova versão (`_v2`, `_v3`);
- **destino exclusivo:** `assets/art/e08_codex_1121/characters/<id>/`,
  `assets/art/e08_codex_1121/equipment/` e `assets/art/e08_codex_1121/props/`; não tocar em mais
  nada do projeto;
- não rodar o Godot nem scripts do projeto; sem commit;
- `provenance.json` em cada pasta, com `path`, `sha256`, `width`, `height`,
  `generator: "Codex built-in imagegen"`, `request`, as referências usadas (caminho e SHA256),
  o **`prompt` exato** e **`"selected": true`** na versão escolhida de cada vista ou folha;
- se faltar limite, seguir a prioridade e listar o que ficou de fora.

## Prioridade

1. **Vista sul dos sete trajes**, na ordem da tabela da seção A. O usuário confere as sete vistas
   sul antes de seguir.
2. **Folha N1** de equipamento.
3. Vistas **leste** e **oeste** de cada traje, na mesma ordem.
4. Vista **norte** de cada traje.
5. **Folha P1** de objetos.

**Escala entre vistas.** Na rodada 1120, algumas vistas saíram com o corpo até 30% menor ou 20%
maior que a vista sul. Nesta rodada, **o corpo parado (linha 1) de cada vista tem a mesma altura
em pixels da vista sul aprovada**, e a folha mantém o mesmo tamanho dela.

## A. Trajes das sete híbridas do Necromante

### Formato (igual a 1118 e 1120)

- Uma folha por vista (`south`, `east`, `west`, `north`), PNG **RGBA transparente**, cerca de
  1200×1300, grade **4×4 = 16 sprites** em células iguais, com espaço transparente entre elas.
- **Linha 1:** parado (4). **Linha 2:** andando (4). **Linha 3:** ação (4, gesto da tabela).
  **Linha 4:** dano (2) e morte caída (2).
- Proporção chibi do elenco, pixel art nítida, contorno escuro, sombreamento de 2–3 tons.
- **Mãos vazias e visíveis em todas as poses vivas**, com dedos legíveis; no perfil, a mão
  próxima e a distante distintas. **Nenhuma arma, cajado, rosário, foco, livro ou lâmina no
  corpo**: são equipamentos separados.
- Sem servo, resto, cova, efeito mágico solto, chão, sombra projetada, texto ou grade. Ossos,
  cogumelos e manchas valem só como parte do traje (presos ao tecido, ao couro ou ao corpo).
- O perfil é desenhado como perfil, não espelhado nem retingido.

**Continuidade.** Como em 1120, a híbrida é **a mesma pessoa da base de origem**, com o rosto, o
cabelo e o porte dela. Quatro das sete são o Bruxo (Cavaleiro de Ossos, Lich, Coveiro e Arauto da
Peste). Por isso **as silhuetas dessas quatro precisam ser bem diferentes entre si**: o Cavaleiro
é pesado e largo, o Lich é alto e velado, o Coveiro é de trabalho (capuz e avental), e o Arauto é
assimétrico e inclinado. Na entrega 1120, Alfa, Encarnado e Domador ficaram parecidos demais.

O Necromante entra pelos detalhes de família: o pano mortuário, ossos usados como fechos, manchas
de musgo podre, pequenos cogumelos. As cores são verde-musgo apodrecido, ocre, marfim de osso e
roxo-hematoma, sem verde neon.

**Referências para anexar,** nesta ordem:
1. a pessoa e a classe de origem (coluna "Referências de origem");
2. a vista sul do Necromante, `assets/art/e08_codex_1118/characters/necromancer/south_v3.png`
   (`0938f9fd398462b0ac2302331803b49c4b22e9aab4b12b38eca5e19a1459e61e`), para os detalhes de
   família;
3. `assets/art/animations/directional/swordsman/body.png`
   (`f390cee8e028c4ec82c7310455107dfcc03e9e5f12a417167e8a108edeb05a7a`), para a escala do elenco.

Para as vistas leste, oeste e norte, anexar também a vista sul aprovada da própria híbrida.

| Referência | Caminho | SHA256 |
|---|---|---|
| Bruxo (1116) | `assets/art/e08_codex_1116/characters/warlock/south.png` | `c4bace0bef0af4b8a26801cace8be09b4b28291c3281c7e723e7fbf25ec1b338` |
| Defendente (no jogo) | `assets/art/animations/directional/defender/body.png` | `376cff77afffde2ce602e1fec1f233ef489dec90f3a86fb6ca079fb19e292766` |
| Espiritualista (no jogo) | `assets/art/animations/directional/spiritualist/body.png` | `dd3df46e2a80926b7e67f175bcd05397ae4e37f096b0a694a4d343975036ec8a` |
| Caçadora (no jogo) | `assets/art/animations/directional/hunter/body.png` | `9785d676c0c1eaa9aa4ad73db9e4e3645c174ab2c6c05cd9120744feba06dc7a` |
| Cultista (1118) | `assets/art/e08_codex_1118/characters/cultist/south.png` | `2c894b80576dc613070f977426ef886134f6bb774d0936eb1317e18452a67948` |
| Naturalista (1118) | `assets/art/e08_codex_1118/characters/naturalist/south.png` | `4ef6eaff803e9d56af6fe758e38c7a9321ab6f331b13c99833a428703f2a124b` |
| Dervixe (1118) | `assets/art/e08_codex_1118/characters/dervish/south.png` | `28dd850c0b9961e3d6220bb4d6b5a3c7cb4e2e86c8450fec3f1a39fb3dd283c4` |
| Elevado (1118) | `assets/art/e08_codex_1118/characters/ascended/south.png` | `cddf6996b95e6334baf2d2194bc270dceaec6c3f97a49a8a5f7d40aa6a8b6b4d` |

Os atlas do jogo têm várias direções; usar a vista correspondente.

### Gabarito de prompt

O mesmo de 1120, trocando a referência 2 pelo Necromante e acrescentando a regra de escala:

> Use case: stylized-concept. Production 2D pixel-art game animation sprite sheet for RagRPG.
> Reference images: (1) the origin person and class of this character, (2) the Necromancer's
> family details, (3) the existing cast scale (chibi proportions, crisp pixel art, dark outline,
> 2–3 tone shading). Keep the SAME person as reference 1 (face, hair, build), now in a hybrid
> class outfit: [DESCRIÇÃO]. Create exactly 4x4 separate full-body sprites in equal cells with
> transparent gaps, all facing [SOUTH/front | EAST/right profile | WEST/left profile |
> NORTH/back]. Row 1 idle 4; row 2 walk 4; row 3 action 4: [GESTO]; row 4 hurt 2 and collapsed
> death 2, all in that direction. Exactly two arms and two empty hands visible and separated from
> the body in every living pose, visible fingers; in profile, near and far hands clearly
> separated. Weapons, staffs, rosaries, books and blades are separate game equipment: do not draw
> them. No servant, skeleton minion, corpse pile, grave, magical effects, ground, cast shadows,
> captions, grid lines or text. Keep the outfit and asymmetry consistent across poses. Original
> design. Genuine transparent background.

Para leste, oeste e norte, acrescentar: *"Same character as the attached south sheet; redraw as a
true [direction] view, do not mirror or recolor it. Keep the same canvas size and the same body
height in pixels as the attached south sheet."*

### As sete classes

| Ordem | id | Híbrida (origem → afinidade) | Pessoa e referências de origem | Descrição para o prompt | Gesto de ação (linha 3) |
|---|---|---|---|---|---|
| 1 | `br_sp` | Cavaleiro de Ossos (Bruxo → Espadachim) | Bruxo; Bruxo e Defendente | *a heavy, wide blocky silhouette like the Defender: the Necromancer's hooded burial mantle worn as armour, a rib cage of bone tied over the chest like a breastplate, big shoulder guards made of bone, skull-shaped knee guards, iron-grey straps; bone ivory, rotten moss green, ochre, iron grey* | golpe de maça de cima para baixo com as duas mãos fechadas juntas; avançar de ombro, em guarda; puxar algo do chão para o corpo com as duas mãos; soco no chão com um joelho apoiado |
| 2 | `br_mg` | Lich (Bruxo → Mago) | Bruxo; Bruxo e Espiritualista | *tall and gaunt for the chibi cast, slightly hunched, the Necromancer's torn burial mantle with long pale silver-white veils of the Spiritualist hanging from the hood and shoulders, a small bone lantern clasp at the belt (empty, no flame), pale skin with grey-green shadows; moss green and ochre with silver-white veils* | mão erguida segurando algo invisível (canalizar); mão estendida soltando à frente; braços abertos, pés um pouco acima do chão; apontar para baixo, erguendo algo do chão |
| 3 | `br_ar` | Coveiro (Bruxo → Arqueiro) | Bruxo; Bruxo e Caçadora | *a gravedigger: rough hood, a long dirty leather work apron stained with earth, rolled sleeves, ropes, hooks and small pouches on the belt like the Hunter's trap kit, a bone clasp on the hood; moss green, ochre, earth brown, bone ivory* | agachar armando algo no chão; cavar com as duas mãos fechadas, como se segurasse uma pá; puxar algo do chão com força; arremessar por baixo |
| 4 | `br_ac` | Arauto da Peste (Bruxo → Acólito) | Bruxo; Bruxo e Cultista | *the Cultist's asymmetric, forward-leaning silhouette and torn strip robe, now made of stained burial cloth, eye-shaped rot spots painted on the cloth and arms, a magenta lining, small oxidised bells; magenta and sickly turquoise over moss green and ochre* | braços abertos pregando; mão em concha junto à boca, sussurrando; apontar com dois dedos; erguer as duas mãos para o alto |
| 5 | `dr_br` | Semeador (Druida → Bruxo) | Druida; Naturalista | *the Naturalist's low, rooted stance under a heavy mantle of rotting leaves, small mushrooms on the shoulders, dead-wood bracers, bruise-purple flowers, bone beads tied in the hair, barefoot; rotten moss green, earth brown, ochre, bruise purple* | palma no chão plantando; espalhar sementes com um gesto lateral; erguer as mãos fazendo algo brotar; abrir os braços |
| 6 | `la_br` | Ceifador (Ladino → Bruxo) | Ladino; Dervixe | *the Dervish's open silhouette caught mid-step, the same light silks and long ribbons but rotten and tattered, small bone charms instead of bells, a faded dark red sash; grey-green, ochre, bone ivory, faded dark red* | giro com os braços abertos; avanço girando; corte em arco de cima para baixo (mão vazia); reverência |
| 7 | `mo_br` | Titereiro (Monge → Bruxo) | Monge; Elevado | *the Ascended's light, serene silhouette, feet slightly above the ground in idle, the white robe stained with ochre and moss at the hem, blue-violet sash, small bone beads sewn on the sleeves, fingers held like a puppeteer's; white and blue-violet over bone ivory and moss green* | dedos movendo fios invisíveis, as duas mãos à frente; palma erguendo algo à distância; arremessar com as duas mãos; meditação flutuando |

## B. Equipamento novo

### Folha N1 (`equipment/weapons_n1.png`)

Formato igual às folhas H1 e H2 de 1120: RGBA transparente, cerca de 2172×724, **uma fileira**,
um objeto de cada, **separados e sem se tocar**, ilustração pintada (não pixel art), na vertical
como é segurado. Referências: `assets/art/e08_codex_1118/equipment/weapons_b1.png`
(`a4a088a4601b5c245aea177a6aaa37da058514f727cf734d8c6aae33d445fdfa`), onde estão o cajado de ossos,
o cajado vivo e o rosário flutuante; e `assets/art/e08_codex_1120/equipment/weapons_h1_v2.png`
(`b36825e12f9d3729bb5943ccf4ec5c9182b26616ac75c3dd76ee52e00b83016d`), o formato.

| Ordem | id | Objeto | Híbrida |
|---|---|---|---|
| 1 | `grave_spade_staff` | o cajado de ossos do Necromante com uma lâmina de pá de ferro na ponta | Coveiro |
| 2 | `deadwood_staff` | cajado de madeira morta e seca, com raízes e pequenos ossos amarrados | Semeador |
| 3 | `bone_rosary` | o rosário flutuante do Elevado em círculo, com contas de osso | Titereiro |

**Gabarito:** o de 1120, com *"exactly 3 separate hand-painted fantasy equipment objects"* e a
lista acima. O Cavaleiro usa o cajado de ossos de 1118 e o Ceifador, o khopesh de 1120. Lich e
Arauto não têm arma nova.

## C. Objetos da família (folha P1, `props/necro_props.png`)

Por último e só se sobrar limite. Uma folha RGBA transparente, cerca de 2172×724, **uma fileira**,
sete objetos separados e sem se tocar. São **objetos do mundo, vistos de cima em ângulo**, como os
props do mapa, e **pintados** como eles (não pixel art). Referências:
`assets/art/map_authoring/props/mushroom_ring.png`
(`7469f50a4a230c73d649838bad6caa2fc1f638133740ef49180d6cf13fdc1db7`) e
`assets/art/map_authoring/props/broken_pillar.png`
(`2e2edc9c889ae124632a2863c5ee989b69b8b66f8ee0e014e6163236dfa776d1`), para o ângulo e a pintura;
`assets/art/e08_codex_1117/creatures/bone_servant/south.png`
(`0c49b6278b8c96bcb5ca7da7953f2b5b511979178eaa49accbdd5cf807577c9b`), para o osso da família.
Gore estilizado e leve: osso, pano e um pouco de vermelho escuro, sem vísceras.

| Ordem | id | Objeto | Uso |
|---|---|---|---|
| 1 | `remains_carcass` | resto: uma carcaça pequena caída, com pano rasgado e costelas à mostra | resto comum da família |
| 2 | `remains_bones` | resto: um monte baixo de ossos soltos e um crânio | variação do resto |
| 3 | `phylactery` | Filactério: lanterna de osso em pé no chão, com uma chama pálida pequena | Lich |
| 4 | `corpse_idol` | ídolo cadavérico: um totem de carcaça e pano amarrado num poste, com marcas em forma de olho | Arauto da Peste |
| 5 | `shallow_grave` | cova rasa: um retângulo de terra revolta, levemente afundado | Coveiro |
| 6 | `bone_hand` | mão de osso grande saindo da terra, agarrando para cima | Coveiro |
| 7 | `corpse_flower` | flor-cadáver: flor grande roxo-hematoma, murcha, com um bulbo de pétalas grossas | Semeador |

## D. Rodadas seguintes (não pedir agora)

- **Corpos novos:** Carniçal de Raiz (Semeador) e Colosso Suspenso (Titereiro), se não for feito
  em código.
- **Camadas de placa do Cavaleiro de Ossos:** as placas em três estágios, como sobreposições.
- **Variantes de criatura do Demonólogo:** a seção C de
  [e08_codex_art_1120_brief.md](e08_codex_art_1120_brief.md).
- **Trajes das outras 36 híbridas**, em lotes.
- **Efeitos:** parede de carcaças, Onda Pútrida, eco, Procissão, Exumação, olho de carne, Jardim,
  esporos e Ciranda.

## Depois da entrega (Claude)

Conferir hashes, prompts e versões marcadas; medir a altura do corpo entre as vistas; igualar a
escala onde faltar; montar os atlas e calibrar mãos, dedos e cabeça; recortar a folha N1, medir os
grips e criar os ícones; recortar os objetos da P1 e definir pivô e escala no consumidor. Tudo fica
em staging até as classes ganharem kit.

## Entrega — 14/11/2026

O Codex entregou tudo, inclusive a folha P1, em `assets/art/e08_codex_1121/`. A conferência
automática passou:
- todos os PNG listados, com SHA256, largura e altura conferindo;
- todos em RGBA, com o gerador certo e o prompt exato;
- as referências conferem pelos SHA256;
- nenhum arquivo ficou sem registro;
- uma versão marcada por vista ou folha.

Cada folha de traje separa em 4×4 pelas faixas transparentes. O Codex registrou dois cortes
manuais (`crop_overrides`) entre as colunas 3 e 4 da linha 4: em `br_ac/east_v5` e em
`br_ar/west_v2`.

**Versões escolhidas.** A tabela traz as versões marcadas pelo Codex, com uma troca nossa, e a
altura do corpo parado em cada vista em relação à vista sul.

| id | Sul | Leste | Oeste | Norte |
|---|---|---|---|---|
| `br_sp` Cavaleiro de Ossos | `south` | `east_v2` 1,02 | `west_v2` 1,02 | `north_v3` 1,02 |
| `br_mg` Lich | `south` | `east_v2` 0,98 | `west` 1,01 | `north_v2` 1,00 |
| `br_ar` Coveiro | `south` | `east_v2` 1,00 | `west_v2` 1,00 | `north_v3` 1,02 |
| `br_ac` Arauto da Peste | **`south_v2`** (troca nossa) | `east_v5` 1,00 | `west_v5` 1,01 | `north_v4` 1,04 |
| `dr_br` Semeador | `south` | `east` 1,01 | `west_v2` 1,00 | `north_v2` 1,02 |
| `la_br` Ceifador | `south` | `east` 1,01 | `west` 0,98 | `north_v3` 1,03 |
| `mo_br` Titereiro | `south_v2` | `east_v2` 0,97 | `west` 0,99 | `north_v3` 1,02 |

A regra de escala funcionou: todas as vistas ficaram entre 0,97 e 1,05 da vista sul. Em 1120, a
diferença chegou a 30%. Só o norte do Arauto tem uma folha de outro tamanho (1068×1473 contra
1113×1413); o recorte é por grade e não muda.

**Troca no Arauto.** A vista sul marcada (`south`) esconde a mão direita inteira sob o manto na
linha 1 (parado), e o pedido era as duas mãos visíveis em toda pose viva. A `south_v2` corrige isso
com a mesma roupa, os mesmos gestos e o mesmo lado do manto. As vistas leste, oeste e norte
combinam com ela. Fica `south_v2`; o `provenance.json` não foi editado.

**Poses e braços.** Nas sete classes, todas as poses vivas têm dois braços. As mãos estão vazias e
nenhuma pose tem braço sobrando, faltando ou preso no lugar errado. Nos perfis, a mão próxima e a
distante se distinguem. O lado do traje assimétrico se mantém nas quatro vistas:
- o manto e o braço tatuado do Arauto;
- o ombro nu do Titereiro;
- a corda e a bolsa do Coveiro;
- o braço erguido do Ceifador.

Os gestos da linha 3 seguem a tabela no Arauto, no Semeador, no Ceifador e no Titereiro. Nos
outros:
- **Lich:** a mão erguida "segurando algo" saiu na altura do peito. As colunas 2 e 3 ficaram quase
  iguais (braços abertos) e os pés não saem do chão.
- **Coveiro:** "cavar" e "puxar" ficaram parecidos, com os punhos juntos na cintura. O "arremesso
  por baixo" virou as duas palmas para a frente. Nos perfis os gestos leem melhor; "cavar" mostra
  a pá imaginária.
- **Cavaleiro de Ossos:** a coluna 3 ("puxar algo do chão para o corpo") aparece no norte como
  braços erguidos para fora, diferente das outras vistas.

Esses gestos ficam aceitos para o staging, exceto o do Cavaleiro (veja o briefing 1122).

**Leitura entre classes.**
- **Cavaleiro de Ossos:** não lê como armadura. O pedido era silhueta pesada de Defendente, com
  ombreiras de osso e correias de ferro. Saiu um manto de folhas podres com ombros de pelagem; o
  tórax de costelas e as joelheiras de crânio vieram. A massa de folhas é a mesma do Semeador e da
  cobertura do Lich, e no tamanho do jogo os três viram montes de folha marrom-musgo. Pedimos de
  novo (1122).
- **Lich, Coveiro e Arauto:** bem distintos entre si e do Cavaleiro. O Lich tem véus prateados,
  capuz pontudo e lanterna no cinto; o Coveiro, avental e corda; o Arauto vem sem capuz, inclinado
  e assimétrico.
- **Semeador:** no norte aparece com botas (solas marrons na linha 4); nas outras vistas está
  descalço. Pedimos de novo só o norte (1122).
- **Ceifador:** as pontas das fitas trazem guizos dourados nos perfis e no norte, em vez de
  amuletos de osso. Aceito.

**Folha N1.** Três objetos separados, na ordem pedida:
- cajado de ossos com lâmina de pá de ferro, crânio e cogumelos;
- cajado de madeira morta bifurcada, com dois ossos amarrados;
- rosário circular de contas de osso, com borlas.

Aprovada.

**Folha P1.** Sete objetos separados, pintados no ângulo do mapa. A ordem na folha é a do pedido do
Codex: carcaça, ossos, filactério, **ídolo**, **cova**, mão de osso e flor-cadáver. Na tabela da
seção C, cova e ídolo estão invertidos; o recorte usa a ordem da folha.

A folha tem um véu quase invisível (alfa 1–16) espalhado pelo fundo, cerca de 129 mil pixels. O
empacotamento zera alfa ≤ 16, como nas outras folhas. A N1 tem o mesmo resíduo em menor
quantidade. Aprovada.

**Resultado.** Aprovados para staging:
- seis trajes (Lich, Coveiro, Arauto com `south_v2`, Semeador exceto o norte, Ceifador e
  Titereiro);
- as folhas N1 e P1.

Vão para o briefing [e08_codex_art_1122_brief.md](e08_codex_art_1122_brief.md):
- as quatro vistas do Cavaleiro de Ossos;
- a vista norte do Semeador.

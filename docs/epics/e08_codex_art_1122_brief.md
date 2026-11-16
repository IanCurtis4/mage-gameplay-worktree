# E08 — Briefing de arte 1122 (escrito em 14/11/2026): correções de 1121

Correção da entrega 1121 ([e08_codex_art_1121_brief.md](e08_codex_art_1121_brief.md), seção
"Entrega"). Dois pedidos curtos:
- **A.** refazer as **quatro vistas do Cavaleiro de Ossos** (`br_sp`) com outro material;
- **B.** refazer só a **vista norte do Semeador** (`dr_br`), descalço.

O resto de 1121 está aprovado e não deve ser refeito.

## Regras para esta rodada

Iguais às de 1121:
- **só imagegen**, saída salva byte a byte; edições viram nova versão (`_v2`, `_v3`);
- **destino exclusivo:** `assets/art/e08_codex_1122/characters/br_sp/` e
  `assets/art/e08_codex_1122/characters/dr_br/`; não tocar em mais nada do projeto, nem nas pastas
  de 1121;
- não rodar o Godot nem scripts do projeto; sem commit;
- `provenance.json` em cada pasta, com:
  - `path`, `sha256`, `width`, `height`;
  - `generator: "Codex built-in imagegen"`, `request` e o **`prompt` exato**;
  - as referências usadas, com caminho e SHA256;
  - `idle_height_px`, como em 1121;
  - **`"selected": true`** na versão escolhida de cada vista.
- **Escala:** a mesma regra de 1121. O corpo parado (linha 1) de cada vista tem a mesma altura em
  pixels da vista sul aprovada, e a folha mantém o mesmo tamanho.

**Prioridade:** 1) vista sul do Cavaleiro; 2) leste e oeste do Cavaleiro; 3) norte do Cavaleiro;
4) norte do Semeador.

## A. Cavaleiro de Ossos (`br_sp`), quatro vistas

**O que deu errado em 1121.** O traje saiu como um manto de folhas podres com ombros de pelagem.
No tamanho do jogo ele se confunde com o Semeador e com a cobertura do Lich, e não lê como um
cavaleiro. O tórax de costelas, as joelheiras de crânio e o capuz estavam certos e continuam.

**O que muda.**
- **Silhueta pesada e quadrada, como a do Defendente:** ombros largos, tronco em bloco, pernas
  firmes e afastadas.
- **Ombreiras grandes de osso:** placas de escápula e crânios achatados, presas por **correias de
  ferro cinza com fivelas**.
- **Peitoral:** a caixa torácica de osso amarrada sobre um gibão escuro, como em 1121.
- **Joelheiras de crânio, botas e braçadeiras** de couro escuro com tiras de ferro.
- **Capuz:** o capuz rasgado de pano mortuário do Necromante, curto, sem cobrir os ombros.
- **Sem folhas, pelagem ou cogumelos** no corpo. O musgo é só mancha pequena no osso e no pano.
- **Paleta:** marfim de osso, cinza-ferro e marrom escuro, com pouco verde-musgo.
- **Pessoa:** a mesma do Bruxo (rosto jovem, cabelo escuro volumoso).

**Gestos (linha 3), iguais nas quatro vistas:**
1. golpe de maça de cima para baixo, com as duas mãos fechadas juntas;
2. avançar de ombro, em guarda;
3. puxar algo do chão para o corpo com as duas mãos, com o tronco inclinado para trás;
4. soco no chão com um joelho apoiado.

No norte, o gesto 3 também é um puxão para o corpo, **não** braços erguidos.

**Formato.** O mesmo de 1121:
- folha 4×4 RGBA de **1254×1254**, uma por vista;
- linha 1 parado, linha 2 andando, linha 3 ação, linha 4 com dano (2) e morte caída (2);
- mãos vazias e visíveis em toda pose viva;
- sem arma, cajado, chão, sombra ou efeito;
- altura do corpo parado na vista sul em torno de **260 px**, como em 1121.

**Referências da vista sul.** Não anexar as folhas `br_sp` de 1121; elas puxam de volta para o
manto de folhas.

| Referência | Caminho | SHA256 |
|---|---|---|
| Bruxo (pessoa) | `assets/art/e08_codex_1116/characters/warlock/south.png` | `c4bace0bef0af4b8a26801cace8be09b4b28291c3281c7e723e7fbf25ec1b338` |
| Defendente (silhueta) | `assets/art/animations/directional/defender/body.png` | `376cff77afffde2ce602e1fec1f233ef489dec90f3a86fb6ca079fb19e292766` |
| Necromante (família) | `assets/art/e08_codex_1118/characters/necromancer/south_v3.png` | `0938f9fd398462b0ac2302331803b49c4b22e9aab4b12b38eca5e19a1459e61e` |
| Elenco (escala) | `assets/art/animations/directional/swordsman/body.png` | `f390cee8e028c4ec82c7310455107dfcc03e9e5f12a417167e8a108edeb05a7a` |

Para leste, oeste e norte, anexar também a nova vista sul aprovada do Cavaleiro.

**Prompt (descrição do traje).** Entra no gabarito de 1121 no lugar de `[DESCRIÇÃO]`:

> a heavy, wide, square armoured silhouette like the Defender: broad shoulders, blocky torso,
> planted stance. Large shoulder guards made of flat bone plates (shoulder blades and flattened
> skulls) strapped on with iron-grey straps and buckles; a rib cage of bone tied over a dark
> doublet like a breastplate; skull-shaped knee guards; dark leather boots and bracers with iron
> bands; a short torn burial hood from the Necromancer that does not cover the shoulders. NO
> leaves, NO fur, NO mushrooms, NO leafy mantle on the body; moss only as small stains on bone and
> cloth. Palette: bone ivory, iron grey, dark brown, a little moss green.

Acrescentar ao prompt: *"In row 3, column 3, both hands pull something from the ground toward
the body, torso leaning back; keep this same gesture in every direction."*

## B. Semeador (`dr_br`), só a vista norte

A vista norte de 1121 (`north_v2`) mostra botas e solas marrons; nas vistas sul, leste e oeste ele
está **descalço**, com faixas nas canelas. Refazer só o norte:
- mesmo traje, gestos e tamanho de folha (1254×1254);
- mesma altura do corpo parado que a vista sul (em torno de **237 px**);
- **pés descalços**: calcanhares e solas cor de pele, com faixas nas canelas; na linha 4 (caído),
  as solas dos pés descalços.

| Referência | Caminho | SHA256 |
|---|---|---|
| Semeador, vista sul aprovada | `assets/art/e08_codex_1121/characters/dr_br/south.png` | `ebdbfc0e9ffdc3ddb5f88040b73f7004d56f0eed55fe032ef1bfed30f9021c7f` |
| Semeador, norte de 1121 (só pose e roupa) | `assets/art/e08_codex_1121/characters/dr_br/north_v2.png` | `811f5ab1ca1949d607dcf7f95dc4eb0658535eb2a424230b3cd9b30a625f4b53` |

Acrescentar ao prompt: *"Same character, poses and outfit as the attached north sheet, but
BAREFOOT like the attached south sheet: bare skin-coloured heels and soles with cloth wraps on the
shins, no boots or shoes in any frame, including the collapsed poses."*

## Depois da entrega (Claude)

Conferir hashes, prompts e versões marcadas; medir a altura entre as vistas. Comparar o novo
Cavaleiro com o Semeador e o Lich no tamanho do jogo. Se aprovado, ele substitui `br_sp` de 1121,
e o norte do Semeador substitui `dr_br/north_v2` no empacotamento. Tudo continua em staging.

## Entrega — 14/11/2026

O Codex entregou os dois pedidos em `assets/art/e08_codex_1122/`. A conferência automática passou:
- todos os PNG listados, com SHA256, largura e altura conferindo;
- todos em RGBA, com o gerador certo, o prompt exato e `idle_height_px`;
- as referências conferem pelos SHA256;
- nenhum arquivo ficou sem registro;
- uma versão marcada por vista.

As folhas `br_sp` de 1121 não foram usadas como referência. As vistas leste, oeste e norte
referenciam a nova vista sul, `south_v2`. Cada folha separa em 4×4 pelas faixas transparentes.

**Versões escolhidas e escala.** Altura do corpo parado em cada vista em relação à vista sul:

| id | Sul | Leste | Oeste | Norte |
|---|---|---|---|---|
| `br_sp` Cavaleiro de Ossos | `south_v2` (264 px) | `east_v2` 0,99 | `west_v2` 0,99 | `north_v3` 1,00 |
| `dr_br` Semeador | `south` de 1121 (237 px) | — | — | `north_v2` 1,02 |

**Cavaleiro de Ossos.** Agora lê como armadura. As peças:
- ombreiras grandes cor de osso;
- tórax de costelas sobre gibão escuro;
- braçadeiras e botas com faixas de ferro;
- correias de ferro cruzadas nas costas;
- joelheiras de crânio;
- capuz curto.

Não há folha, pelagem nem cogumelo no corpo. No tamanho do jogo, ao lado do Lich, do Coveiro, do
Arauto e do Semeador, a silhueta é a mais quadrada e a mais escura das quatro híbridas do Bruxo, e
não se confunde com o Semeador.

As poses vivas têm dois braços e as mãos vazias, fechadas em punho. Os quatro gestos da linha 3
seguem o pedido nas quatro vistas, inclusive o puxão para o corpo no norte, agora corrigido.

**Uma diferença aceita na morte.** Na linha 4, a coluna 3 cai **de costas** e a coluna 4 fica **de
bruços**. Nas outras classes, a coluna 3 cai de joelhos e mãos. A sequência é a mesma nas quatro
vistas. Ao montar o atlas, vale ver se a virada entre os dois quadros incomoda. Se incomodar, o
corpo final pode ficar na coluna 3.

**Semeador, norte.** Descalço em todas as poses: calcanhares e solas cor de pele, faixas nas
canelas, solas dos pés descalços na morte. O resto continua igual ao norte de 1121.

**Resultado.** Aprovados para staging. No empacotamento:
- `br_sp` de 1122 (`south_v2`, `east_v2`, `west_v2`, `north_v3`) substitui `br_sp` de 1121;
- `dr_br/north_v2` de 1122 substitui `dr_br/north_v2` de 1121.

Com isso, as sete híbridas do Necromante estão completas nas quatro vistas.

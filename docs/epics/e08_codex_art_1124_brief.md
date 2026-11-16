# E08 — Briefing de arte 1124 (escrito em 15/11/2026): correções de 1123

Correção da entrega 1123 ([e08_codex_art_1123_brief.md](e08_codex_art_1123_brief.md), seção
"Entrega"). Dois pedidos curtos, os dois sobre a **pessoa do Mago**:
- **A.** refazer as vistas **leste, oeste e norte do Tempestário** (`mg_dr`) a partir da vista sul
  alternativa `south_v4`, que passa a ser a aprovada;
- **B.** refazer as **quatro vistas do Magister** (`mg_mo`), com o cabelo da pessoa e um gesto 4
  novo.

O resto de 1123 está aprovado e não deve ser refeito.

**15/11:** o limite do Codex acabou. O mesmo pedido segue primeiro como teste no Nano Banana:
[e08_nanobanana_1124_brief.md](e08_nanobanana_1124_brief.md).

**16/11 — pausado.** O teste no Nano Banana não trocou a pessoa nem o cabelo. Os testes no ComfyUI
local (Qwen-Image-Edit-2511 Q4 com Lightning, GTX 1080) levaram de 20 a 37 min por folha e travaram
com a memória da placa disputada, e as páginas grátis do Hugging Face recusaram ou falharam. Por
decisão do usuário, a arte das classes fica como está por ora e as entregas do E08 seguem. Este
pedido continua pendente para quando houver um gerador viável.

## Regras para esta rodada

Iguais às de 1123:
- **só imagegen**, saída salva byte a byte; edições viram nova versão (`_v2`, `_v3`);
- **destino exclusivo:** `assets/art/e08_codex_1124/characters/mg_dr/` e
  `assets/art/e08_codex_1124/characters/mg_mo/`; não tocar em mais nada do projeto, nem nas pastas
  de 1123;
- não rodar o Godot nem scripts do projeto; sem commit;
- `provenance.json` em cada pasta, com:
  - `path`, `sha256`, `width`, `height`;
  - `generator: "Codex built-in imagegen"`, `request` e o **`prompt` exato**;
  - as referências usadas, com caminho e SHA256;
  - `idle_height_px` de cada folha;
  - **`"selected": true`** na versão escolhida de cada vista.
- **Formato:** o mesmo de 1123. Folha 4×4 RGBA de **1254×1254** por vista:
  - linha 1 parado, linha 2 andando, linha 3 ação, linha 4 com dano (2) e morte (2);
  - na morte, a coluna 3 cai de joelhos e mãos e a coluna 4 fica de bruços;
  - mãos vazias e visíveis em toda pose viva, sem manto escondendo uma mão;
  - sem arma, cajado, chão, sombra ou efeito;
  - os gestos da linha 3 são os mesmos nas quatro vistas.
- **Escala:** o corpo parado de cada vista tem a mesma altura em pixels da vista sul aprovada da
  própria classe.

**Prioridade:** 1) vista sul do Magister; 2) leste e oeste do Tempestário; 3) leste e oeste do
Magister; 4) norte dos dois.

## A pessoa do Mago

As quatro híbridas do Mago são **a mesma pessoa**. A âncora é a vista sul aprovada do
**Taumaturgo** (`mg_ac`):
- pele clara;
- cabelo **castanho médio, curto e desalinhado**, com mechas soltas na testa;
- olhos castanhos e o mesmo rosto.

Em 1123, o Tempestário saiu com pele morena e cabelo comprido e ondulado, e o Magister com cabelo
bege-claro e fofo. Os dois prompts abaixo pedem a pessoa da âncora de forma explícita.

## A. Tempestário (`mg_dr`): leste, oeste e norte

**Vista sul aprovada:** `south_v4` de 1123 (260 px). Ela tem a pessoa certa, o traje e os gestos.
Não refazer a vista sul.

**O que refazer.** As vistas leste, oeste e norte de 1123 foram feitas a partir da vista sul
antiga, com a outra pessoa. Refazer as três a partir de `south_v4`:
- mesma pessoa, traje e gestos de `south_v4`;
- mesma altura do corpo parado que `south_v4`, em torno de **260 px**;
- **não anexar** as folhas `mg_dr` de 1123 que não sejam `south_v4`; elas puxam de volta para a
  pele morena e o cabelo comprido.

**Gestos (linha 3), como em 1123:**
1. agachar plantando, palma no chão;
2. espalhar sementes com um gesto lateral;
3. braços erguidos chamando chuva;
4. mão estendida à frente, a outra no peito.

| Referência | Caminho | SHA256 |
|---|---|---|
| Tempestário, vista sul aprovada (traje, pessoa, gestos) | `assets/art/e08_codex_1123/characters/mg_dr/south_v4.png` | `ea17a4009cd88bd31f3e74be80f563ed32efd06eb677c933499022d5316852b8` |
| Taumaturgo (pessoa) | `assets/art/e08_codex_1123/characters/mg_ac/south.png` | `fd17dfb2d2a28e06b4557f0f0f8086f05b120e3aea414dbca30aa8a2c936f189` |
| Mago (pessoa) | `assets/art/animations/directional/mage/body.png` | `7fbf2b93a17168b0d6b5893fcf8315cc50eb5395b12245011bd54c3099ca026a` |
| Elenco (escala) | `assets/art/animations/directional/swordsman/body.png` | `f390cee8e028c4ec82c7310455107dfcc03e9e5f12a417167e8a108edeb05a7a` |

Usar o gabarito de 1123 com a descrição do Tempestário da tabela de 1123 e acrescentar:

> Same character as the attached south sheet; redraw as a true [EAST/right profile | WEST/left
> profile | NORTH/back] view, do not mirror or recolor it. Keep the same canvas size and the same
> body height in pixels as the attached south sheet, and the same four row-3 gestures. Same person
> as the attached Thaumaturge sheet: fair skin, short tousled medium-brown hair, brown eyes, the
> same face. NOT tan skin, NOT long wavy hair, NO centre parting.

## B. Magister (`mg_mo`): quatro vistas

**O que muda.**
- **Pessoa:** a da âncora. Cabelo castanho médio, curto e desalinhado, do mesmo tom do
  Taumaturgo. Não bege, não claro, não fofo ou volumoso.
- **Gesto 4:** uma mão erguida bem acima da cabeça, com o indicador apontando para cima e
  traçando um pequeno círculo; a outra mão aberta no peito. **As mãos não tocam a cabeça.** Em
  1123 o gesto lia como as mãos segurando a cabeça.

**O que continua.**
- O traje de 1123: túnica branca leve de mangas largas, faixa azul-violeta, facetas de cristal na
  gola e nos punhos, contas azuis, vermelhas e amarelas na faixa.
- Os gestos 1 a 3:
  1. mãos em concha em volta de algo invisível;
  2. braço estendido soltando para a frente;
  3. braços abertos com as palmas para cima.
- **Altura da vista sul:** em torno de **255 px**, como o Taumaturgo (253 px).

**Referências da vista sul.** Não anexar as outras folhas `mg_mo` de 1123; elas puxam de volta
para o cabelo bege.

| Referência | Caminho | SHA256 |
|---|---|---|
| Taumaturgo (pessoa) | `assets/art/e08_codex_1123/characters/mg_ac/south.png` | `fd17dfb2d2a28e06b4557f0f0f8086f05b120e3aea414dbca30aa8a2c936f189` |
| Magister de 1123 (só traje) | `assets/art/e08_codex_1123/characters/mg_mo/south.png` | `25d73119cf18e32804e80ce45a9f140fec32a050a1d4808342009f512a42901a` |
| Elevado (material) | `assets/art/e08_codex_1118/characters/ascended/south.png` | `cddf6996b95e6334baf2d2194bc270dceaec6c3f97a49a8a5f7d40aa6a8b6b4d` |
| Elenco (escala) | `assets/art/animations/directional/swordsman/body.png` | `f390cee8e028c4ec82c7310455107dfcc03e9e5f12a417167e8a108edeb05a7a` |

Para leste, oeste e norte, anexar também a nova vista sul aprovada do Magister, com a frase de
direção do gabarito de 1123.

**Prompt.** O gabarito de 1123, com a descrição do Magister da tabela de 1123, o gesto 4 novo, e
acrescentando:

> Reference 1 is the person: fair skin, short tousled medium-brown hair exactly like the attached
> Thaumaturge, brown eyes, the same face. NOT beige, light or fluffy hair. The attached Magister
> sheet is for the outfit only. Row 3, column 4: one hand raised high above the head, index finger
> pointing up and tracing a small circle, the other open hand at the chest; the hands never touch
> the head. Keep this same gesture in every direction.

## Depois da entrega (Claude)

Conferir hashes, prompts e versões marcadas; medir a altura entre as vistas. Comparar as quatro
híbridas do Mago lado a lado (rosto, pele e cabelo) e no tamanho do jogo. Se aprovado:
- o Tempestário fica com `south_v4` de 1123 mais leste, oeste e norte de 1124;
- o Magister de 1124 substitui o de 1123;
- com isso, as oito híbridas de origem Espadachim e Mago ficam completas.

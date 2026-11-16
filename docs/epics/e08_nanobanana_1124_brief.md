# E08 — Briefing 1124 para o Nano Banana (escrito em 15/11/2026)

Variante do [briefing 1124](e08_codex_art_1124_brief.md) para o Nano Banana gratuito, no app
Gemini, porque o limite do Codex acabou. O pedido é o mesmo: corrigir a **pessoa do Mago** no
Tempestário (`mg_dr`) e no Magister (`mg_mo`). Muda só o caminho.

Começa por um **teste com duas folhas**. As outras cinco só seguem depois que Claude revisar o
teste.

## O que muda em relação ao Codex

| Codex | Nano Banana |
|---|---|
| Fundo transparente | **Fundo de cor chapada.** Claude recorta depois. Tempestário: magenta `#FF00FF` (o traje é verde). Magister: verde `#00FF00` (o traje tem violeta). |
| Gerar a folha do zero | **Editar a folha existente de 1123**, trocando só o que está errado. A grade, as poses e o tamanho ficam como estão, e é nisso que ele é mais forte. |
| `provenance.json` escrito pelo Codex | **Você anota** o que mandou; Claude monta o arquivo. |
| Até 5 referências | **2 ou 3 imagens**, na ordem pedida. |

As imagens para anexar já estão prontas, sobre o fundo certo, em `assets/art/e08_nb_1124/refs/`.
São cópias das folhas de 1123; os originais não mudam.

## Como rodar cada folha

1. Abrir o [Gemini](https://gemini.google.com) e começar **uma conversa nova por folha**.
2. Se o plano gratuito oferecer o modelo de imagem **Pro**, usá-lo: ele erra menos em grades.
   Anotar qual modelo foi usado.
3. Anexar as imagens **na ordem da tabela** e colar o prompt **inteiro, sem mudar nada**.
4. Se o resultado vier com um erro pequeno, mandar no máximo **duas** correções curtas na mesma
   conversa, por exemplo: *"Keep everything, but the hair in row 4 is still long."* Se não
   resolver, começar uma conversa nova.
5. Baixar pelo **botão de download** do Gemini, no tamanho cheio. Não usar captura de tela nem
   "copiar imagem".
6. Salvar em `assets/art/e08_nb_1124/characters/<id>/` com o nome da vista: `east.png`; as
   tentativas seguintes viram `east_v2.png`, `east_v3.png`.
7. Em `assets/art/e08_nb_1124/characters/<id>/notes.txt`, uma linha por arquivo: o nome, o código
   do prompt (por exemplo `A1`), o modelo, as correções mandadas, **palavra por palavra**, e qual
   versão você escolheu.

**Antes de mandar para Claude, olhar rápido:**
- os 16 bonecos estão lá, cada um na sua célula, sem se tocar;
- o fundo é a cor chapada, **sem xadrez** desenhado;
- o logo do Gemini, se aparecer no canto, não está em cima de um boneco. Se estiver, avisar:
  sobre o fundo, Claude apaga no recorte.

## Teste (agora)

| Código | Folha | Anexar, nesta ordem |
|---|---|---|
| **A1** | Tempestário, leste | 1. `refs/mg_dr_east_old.png` · 2. `refs/mg_dr_south_v4.png` · 3. `refs/mg_ac_south_on_magenta.png` |
| **B1** | Magister, sul | 1. `refs/mg_mo_south_old.png` · 2. `refs/mg_ac_south_on_green.png` |

### Prompt A1: Tempestário, leste

```text
Edit image 1, a 4x4 pixel-art sprite sheet of one character seen from the right side (east view). Change ONLY the person: in all 16 sprites, give the character the face, fair skin and short tousled medium-brown hair of the character in images 2 and 3, with brown eyes. Fair skin on the face, neck and hands. NOT tan skin, NOT long wavy hair, NO centre parting. Image 2 is the same character seen from the front; image 3 is the same person in another outfit, only to confirm the face and hair.

Keep everything else exactly as in image 1: the same poses in the same cells, the same outfit (short mantle of fresh living green leaves over the shoulders, roots wrapping the forearms with small blue, red and yellow crystals, green robe), the same size and position of every figure, the same crisp pixel-art style with dark outline and 2-3 tone shading. Every living pose keeps two empty hands with readable fingers.

Keep the flat solid magenta (#FF00FF) background everywhere outside the figures. No checkerboard, no gradient, no shadows, no text, no grid lines. Keep the square image and the same layout.
```

### Prompt B1: Magister, sul

```text
Edit image 1, a 4x4 pixel-art sprite sheet of one character seen from the front (south view). Make exactly two changes:

1. In all 16 sprites, give the character the hair of the character in image 2: short tousled medium-brown hair of the same brown tone, with loose strands on the forehead. NOT beige, NOT light, NOT fluffy or voluminous hair. Keep the same face, fair skin and brown eyes.

2. Row 3, column 4 only: redraw the pose. One hand raised high above the head with the index finger pointing up, tracing a small circle; the other open hand at the chest. The hands do not touch the head.

Keep everything else exactly as in image 1: all other poses in the same cells, the white robe with wide sleeves, the blue-violet sash with small blue, red and yellow beads, the small crystal facets at the collar and cuffs, the same size and position of every figure, the same crisp pixel-art style with dark outline and 2-3 tone shading. Every living pose keeps two empty hands with readable fingers.

Keep the flat solid pure green (#00FF00) background everywhere outside the figures. No checkerboard, no gradient, no shadows, no text, no grid lines. Keep the square image and the same layout.
```

## Depois do teste (só se Claude aprovar)

As cinco folhas restantes usam os mesmos prompts, trocando o que está entre colchetes:

| Código | Folha | Prompt | Anexar, nesta ordem |
|---|---|---|---|
| A2 | Tempestário, oeste | A1 com *"seen from the left side (west view)"* | `mg_dr_west_old` · `mg_dr_south_v4` · `mg_ac_south_on_magenta` |
| A3 | Tempestário, norte | A1 com *"seen from behind (north view)"* | `mg_dr_north_old` · `mg_dr_south_v4` · `mg_ac_south_on_magenta` |
| B2 | Magister, leste | B1 com *"seen from the right side (east view)"* | `mg_mo_east_old` · **o novo Magister sul aprovado** |
| B3 | Magister, oeste | B1 com *"seen from the left side (west view)"* | `mg_mo_west_old` · **o novo Magister sul aprovado** |
| B4 | Magister, norte | B1 com *"seen from behind (north view)"* | `mg_mo_north_old` · **o novo Magister sul aprovado** |

Nos B2 a B4, a imagem 2 passa a ser o novo Magister sul. Claude prepara essa referência sobre o
fundo verde depois de aprovar o B1.

## Se a edição não funcionar

Se, em duas conversas, o Nano Banana redesenhar a folha inteira, perder bonecos ou não trocar o
cabelo, parar e avisar Claude. A saída seguinte é gerar a folha do zero com o gabarito de 1123,
adaptado ao fundo chapado. Isso custa mais tentativas e arrisca mais o estilo, então só vale
depois do teste.

## Referências preparadas

Composições sobre o fundo chapado, sem outra mudança, das folhas aprovadas ou entregues em 1123:

| Arquivo em `refs/` | Origem | SHA256 da origem |
|---|---|---|
| `mg_dr_south_v4.png` | `e08_codex_1123/characters/mg_dr/south_v4.png` | `ea17a4009cd88bd31f3e74be80f563ed32efd06eb677c933499022d5316852b8` |
| `mg_dr_east_old.png` | `e08_codex_1123/characters/mg_dr/east_v2.png` | `3234a8198e17ab1b873222f28844a40e4016cc118b70e86634fd60a09c4fb7ef` |
| `mg_dr_west_old.png` | `e08_codex_1123/characters/mg_dr/west_v2.png` | `99564728c7d6691dd30afbc6194cd899427878febd4a410dafa6cd2d05e3a093` |
| `mg_dr_north_old.png` | `e08_codex_1123/characters/mg_dr/north_v3.png` | `d8cb1ed0613806f868f029a38d72d45d8a52f78477f8cd2bda52ec7a36d23e3d` |
| `mg_ac_south_on_magenta.png`, `mg_ac_south_on_green.png` | `e08_codex_1123/characters/mg_ac/south.png` | `fd17dfb2d2a28e06b4557f0f0f8086f05b120e3aea414dbca30aa8a2c936f189` |
| `mg_mo_south_old.png` | `e08_codex_1123/characters/mg_mo/south.png` | `25d73119cf18e32804e80ce45a9f140fec32a050a1d4808342009f512a42901a` |
| `mg_mo_east_old.png` | `e08_codex_1123/characters/mg_mo/east_v2.png` | `a108f4ddb1805f81fbafcc21a2cfd63579f26a6bb3da4287f2d63719577fc38f` |
| `mg_mo_west_old.png` | `e08_codex_1123/characters/mg_mo/west_v3.png` | `f97d65aceae8885f72735667d762748a567b88da466866fb0eb2b0ddcaf713b5` |
| `mg_mo_north_old.png` | `e08_codex_1123/characters/mg_mo/north.png` | `0abe926c536e9c0a56f899d56413968f1428eeb0a8fe5d8424a5447b080e525c` |

## Depois da entrega (Claude)

1. Recortar o fundo chapado para RGBA, limpando a franja de cor nas bordas.
2. Montar o `provenance.json` com:
   - o hash e o tamanho de cada arquivo;
   - o gerador ("Gemini Nano Banana, plano gratuito", com o modelo anotado);
   - o prompt deste briefing e as correções do `notes.txt`;
   - as referências;
   - `idle_height_px`.
3. Fazer a mesma revisão de sempre:
   - a grade e a separação;
   - a altura de cada vista em relação à vista sul;
   - braços e gestos;
   - as quatro híbridas do Mago lado a lado;
   - o tamanho do jogo.
4. Verificar se o **traço** combina com as folhas do Codex. Se destoar no tamanho do jogo, o
   Nano Banana não serve para os lotes seguintes.

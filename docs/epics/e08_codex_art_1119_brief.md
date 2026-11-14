# E08 — Briefing de arte (19/11/2026): adagas com lâminas separadas

Correção da folha B2 entregue em [e08_codex_art_1118_brief.md](e08_codex_art_1118_brief.md).
As **adagas retas** (`daggers`, Ladino) e as **adagas curvas** (`curved_daggers`, Assassino)
vieram cruzadas: uma lâmina passa por cima da outra, e não dá para recortar cada uma inteira.
A causa foi o próprio pedido, que dizia "cruzadas". O design aprovado continua o mesmo; só
muda a disposição. As cimitarras, as faixas e as manoplas da B2 ficam como estão.

## Regras para esta rodada

Iguais às de [e08_codex_art_1118_brief.md](e08_codex_art_1118_brief.md):
- **só imagegen**, saída salva byte a byte; edições viram nova versão (`_v2`, `_v3`);
- **destino exclusivo:** `assets/art/e08_codex_1119/equipment/`; não tocar em mais nada do
  projeto (nem na folha B2 de 1118);
- não rodar o Godot nem scripts do projeto; sem commit;
- `provenance.json` na pasta, com `path`, `sha256`, `width`, `height`,
  `generator: "Codex built-in imagegen"`, `request`, as referências usadas (caminho e SHA256),
  o **`prompt` exato** e **`"selected": true`** na versão escolhida.

## O pedido

Uma folha, `equipment/weapons_daggers.png`, no mesmo formato das folhas de armas: RGBA
transparente, uma fileira horizontal, ilustração pintada (não pixel art).

| Ordem | id | Objeto |
|---|---|---|
| 1 | `dagger` | uma adaga reta, igual às da posição 1 da B2 de 1118 |
| 2 | `curved_dagger` | uma adaga curva escura, igual às da posição 2 da B2 de 1118 |

- **Uma lâmina de cada**, sozinha, em pé, cabo para baixo e ponta para cima.
- **Nada se toca nem se sobrepõe**: espaço largo e transparente em volta de cada lâmina.
- Mesmo design, cores, proporção e acabamento da B2 de 1118. O par para as duas mãos sai da mesma
  lâmina no jogo; não é preciso desenhar a segunda.
- Sem mãos, personagem, texto, sombra projetada ou moldura.

Referências, nesta ordem:
1. `assets/art/e08_codex_1118/equipment/weapons_b2.png`
   (`bd26c9d138506907140a6200f2aa519e2e3104f095fd4c819d3d475e1a5bb534`): o design das duas adagas;
2. `assets/art/e08_equipment_redesign/weapons_source_v2.png`
   (`7c40563cf810daefa4a16a21e945e83aa34eb7a53ebf4ac3a258c8a2d7b6e9ca`): formato e estilo da folha.

**Prompt sugerido:** *"Use case: stylized-concept. Asset type: original in-game equipment sprite
source sheet, hand-painted fantasy material study, transparent background. Image 1 is the approved
design sheet: copy EXACTLY the straight dagger from its first position and the dark curved dagger
from its second position (same blade shape, guard, handle wrap, colors and painting), but draw ONE
single blade of each, never a pair and never crossed. Image 2 gives the existing weapon sheet's
single-row format and rendering style. Produce an ultrawide landscape native PNG around 2172 × 724,
real RGBA, exactly ONE horizontal row with exactly 2 objects, left to right: (1) one straight
dagger; (2) one dark curved assassin dagger. Each upright as gripped, handle at the bottom and tip
at the top, alone in its own column on its own horizontal center, with a very wide, completely
clean transparent gap around it; the two objects never touch or overlap anything. Read well at
about 80×130 px in game. Painted art, not pixel art, neutral upper-left highlights, strong clear
silhouette. The whole background is genuine clear alpha without haze or glare. No hands, people,
captions, letters, imitation text, frame, grid, floor, cast shadow, drop shadow or effects."*

## Depois da entrega (Claude)

Conferir hash, prompt e versão escolhida; comparar com a B2 de 1118; recortar as duas lâminas e
usá-las no lugar das posições 1 e 2 da B2 no empacotamento.

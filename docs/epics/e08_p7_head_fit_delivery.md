# E08 P7-C6 — encaixe de peças de cabeça

Pacote `C6_terra_head_fit` (Terra), base `ba2a4b18`, branch `codex/e08`, checkout
`.tools/map-editor-m5`. Origem: primeiro playtest do usuário (touca de folha do
Arqueiro alta, estreita, cabelo para fora). Apresentação apenas: nenhum item,
atributo, loot, save, snapshot, corpo, atlas ou arte de chapéu foi alterado.
Sem commit/push/merge. Aceite de produto continua do usuário.

## Diagnóstico (causas medidas, não suposições)

1. Âncora fixa por pose. `head.point` do manifesto V2 é o mesmo ponto (ex.: Arqueiro
   sul (31,18)) nas 14 poses vivas; a cabeça do corpo, porém, sobe/desce e recua
   (hurt, ação). Em dano a cabeça cai vários pixels e o chapéu ficava no ar.
2. Escala fixa 1:1. As 14 peças foram pintadas com 11–19 px lógicos de largura; a
   cabeça medida nos corpos tem 17–25 px. O chapéu ficava 10–25% mais estreito que a
   cabeça, e o cabelo aparecia ao redor.
3. Âncora na arte (12,13) do recorte 24×24, não no “assento” do chapéu: o topo da
   peça pairava 3–5 px acima do cabelo, sem cobrir a coroa.
4. Troca por `bare_head` já funcionava (Arqueiro, Caçadora, Sentinela, Geômetra, Mago
   usam `bare_head.png` quando há peça; os cinco de cabelo exposto usam
   `weaponless.png`). A ordem de desenho também estava correta (peça `depth 1`, depois
   do corpo, em todas as 64 poses). Nenhum dos dois era a causa. Para os cinco de
   cabelo pintado no corpo a peça não pode apagar cabelo; ela precisa cobrir mais.
5. Quedas/cadáver: o ponto autorado é o do chapéu antigo; com peça maior ela afundaria
   no chão (o oráculo existente `head_bottom <= 0.05` falhou em 40+ casos antes do
   ajuste abaixo).

## Regra nova (assento na coroa)

Dados mecânicos gerados por `tools/prepare_e08_head_fit.py` (`write`) para
`scripts/actors/equipment_head_fit_data.gd` (const GDScript: `*.json` fora do
`include_filter` de `export_presets.cfg` não entra no PCK, e esse arquivo não é meu):

* Por classe/quadro: centro-x, linha do topo e largura da cabeça medidos no atlas
  realmente desenhado com peça (`bare_head.png` quando declarado, senão
  `weaponless.png`). Largura = mediana da direção (constante por direção); centro
  e topo seguem cada quadro (bob, caminhada, ação, recuo). Mão/braço levantado que
  funde com a coroa é rejeitado por filtro de largura e limite de ±5 px do centro
  da direção. Topo = primeira linha com corrida opaca ≥4 px perto do centro (a
  mesma regra que o teste aplica de forma independente sobre os pixels).
* Por peça/vista: caixa pintada (cx, y0, largura do corpo da peça sem fitas/véu,
  caixa total) e três parâmetros decididos por mim após olhar cada peça:
  `width_k` (largura da peça / cabeça), `drop` (onde o topo da peça cai em relação
  ao topo da cabeça, em larguras de cabeça; negativo = acima do cabelo) e `vk`
  (escala vertical relativa à horizontal).
* `EquipmentHeadVisual.fit(descriptor)`: origem = (centro, topo + drop·largura);
  escala = width_k·largura/largura_da_peça; ponto de assento na arte = (cx, y0).
  `resolved_transform` e `draw_resolved` usam esse resultado; a profundidade/ordem
  continua a do descritor (corpo → peça).
* Quedas/cadáver (poses 14–15): a posição vem do ponto autorado + deslocamento
  vertical-para-rotacionado medido nas poses em pé (`rotated_offset`), com o ângulo
  autorado; depois a peça é levantada apenas o necessário para não passar do chão.
* Qualquer peça em qualquer classe (14 × 10 × 64). Peças de estudo (maçã/flecha,
  casca de ovo) não são IDs reais e ficam fora da tabela. Classe/peça desconhecida ou
  corpo V1: caminho antigo inalterado. `EquipmentHeadVisual.fit_enabled=false`
  reproduz exatamente o encaixe antigo (usado para as capturas “antes”).

Perfis: `cover` (touca, elmo, capuz, véu, lenço) cobre a coroa e usa largura
1,05–1,25× a cabeça; `band` (coroa/grinalda/tiara) assenta na linha do cabelo.
Nas peças tiara (`class_set_mg_ar_head`, `shared_set_high_head`) e grinalda
(Elementalista) o cabelo acima da faixa continua visível: é o design da peça.

## Resultados por classe (peça de classe; capturas em `.godot/verification/p7/`)

Capturas nativas, renderer real, janela 1280×720, grama, 4 direções × (repouso,
caminhada, ação, dano, cadáver). Zoom 160 = `after_*`/`before_*` sem sufixo; folhas
de leitura ampliada (`_z260`). Pastas: `C6_terra_head_fit_probe_c6_fin2_a160`,
`..._a260` (depois) e `..._b160`, `..._b260` (antes) em `/probe/`. Cada classe
também tem a página `*_piece_<id>.png` com as 14 peças em todas as 10 classes.

| Classe | Peça | Resultado (olhado nas capturas) |
|---|---|---|
| Arqueiro | class_set_archer_head | bom: touca cobre a coroa, largura da cabeça, acompanha dano; costas cobrem a nuca |
| Mago | class_set_mage_head | bom |
| Sentinela | class_set_sentinel_head | bom; capuz largo (1,25) por ser peça estreita |
| Espiritualista | class_set_spiritualist_head | bom (véu) |
| Defensor | class_set_defender_head | bom; elmo menos alto (vk 0,72) para não cobrir os olhos |
| Espadachim | class_set_swordsman_head | bom (cobre a coroa pintada) |
| Berserker | class_set_berserker_head | aceitável: lenço cobre mais a coroa; cabelo pintado no corpo ainda aparece nas laterais |
| Caçadora | class_set_hunter_head | aceitável: chapéu de aba larga assenta sobre o cabelo; cabelo grande em volta nas costas |
| Elementalista | class_set_elementalist_head | aceitável: grinalda na linha do cabelo; fitas cobrem parte do rosto de lado |
| Geômetra | class_set_mg_ar_head | bom (tiara na linha do cabelo; cabelo acima visível por design) |

Limitações honestas: (a) em `berserker` quadro 9 (ação, braço erguido) a linha do topo
medida é 12 (cabeça real ≈14) por causa do punho próximo; erro de ~2 px nesse quadro;
(b) as fitas da grinalda e do véu pintadas na arte cruzam o rosto em vistas
laterais; (c) a prévia Python da ferramenta (`sheet`) não aplica a elevação de
cadáver; a evidência válida é a nativa.

## Peças que não encaixam só com reposição mecânica (brief WIP para Codex)

Nenhuma bloqueia o jogo. Duas pioram a leitura e só melhoram com arte nova:

1. `class_set_elementalist_head` (grinalda): redesenhar as quatro vistas (384×96, 4 vistas
   de 96×96, mesmo recorte) com as fitas curtas e laterais atrás das orelhas (não
   cruzando bochecha/olho), anel mais fino e baixo; largura do anel ≈ 18 px lógicos.
2. `class_set_hunter_head` (chapéu): copa mais baixa e aba menos larga na vista sul/norte;
   abertura inferior transparente rasa para o rosto; mesmo recorte 96×96 por vista.
   Resto do jogo não depende disso; usar o prompt “painted equipment v1”.

## Testes e evidência

* `tests/e08_equipment_art_test.gd`: nova `head_fit_checks()` (10 classes × 14 IDs × 64
  quadros): tabela cobre 10 classes/14 IDs e exclui estudos; peça `depth 1` e visível;
  largura da peça/cabeça entre 1,0 e 1,3; proporção vertical/horizontal entre 0,65 e
  1,3; topo medido = topo dos pixels desenhados (±1); origem do assento = topo + drop
  (acompanha bob/recuo, ±1,01); cobertura do topo em peças `cover`; centrada na
  cabeça; cadáver/queda acima do chão; chave desligada devolve o caminho antigo.
* Pino alterado (com justificativa em comentário): “authored west view has no second
  mirror” comparava a base x com escala 1 ×1,6; agora multiplica pela escala
  horizontal ajustada (positiva, sem espelho). O oráculo `F.head_bottom` do
  `content_fixture.gd` (não meu) modela o ponto antigo; `e08_equipment_art_test` e
  `e08_directional_units_test` usam `head_bottom_fitted` (mesmos limites PNG,
  mesmo limite de 0,05). Nenhuma verificação foi removida ou relaxada.
* Wrapper `./tools/e08_p7_fixture.ps1 -Package C6_terra_head_fit`: sync, import (nova
  `class_name`), probes e verify. Resultado final do verify: ver rodapé.

## Rodapé de validação

Wrapper `-Package C6_terra_head_fit`: sync/import/probes e verify `c6_verify4` (evidência
`.godot/verification/p7/C6_terra_head_fit_verify_c6_verify4`), todos com 0 falhas:
e08_equipment_art_test 60273 checks; e08_directional_rig_compatibility_test 41888;
e08_directional_units_test 47494; e08_directional_content_test 3461;
e08_directional_integration_test 84; e08_characters_test 1350;
e06_appearance_integration_test 302; equipment_hand_alignment_test 4593;
e08_pilot_test 350; e07_f7_presentation_test 27. Capturas finais:
`C6_terra_head_fit_probe_c6_fin2_{a160,a260,b160,b260}/probe/`. Sonda:
`tools/e08_p7_head_fit_probe.gd` (args `<pasta> <before|after> [160|260]`).
Não repeti a suíte inteira (322 passos): somente os testes pedidos. Falta aceite
humano; a verificação visual acima é minha, não auditoria independente.

## Arte nova do Codex (C8)

Pacote `C8_terra_head_art` (Terra). Codex redesenhou as duas peças do brief acima; esta
seção registra a integração mecânica. Nenhum item, atributo, loot, save, caminho ou ID
mudou: as duas peças são novas revisões dos mesmos arquivos. O catálogo de arte
(`equipment_art_catalog.gd`) não fixa hashes de PNG; nenhum pino de teste precisou mudar.

**Fontes** (somente leitura, RGBA transparente 2172×724, quatro vistas lado a lado) em
`assets/art/e08_equipment_redesign/p7_head_fit_staging/`, com `provenance.json`
(prompt `null`, status `generated_project_art_prompt_unrecorded`, sha256/tamanho):
`class_set_elementalist_head_source_v1.png` (72ff3a4f…b033, 333511 B) e
`class_set_hunter_head_source_v1.png` (1dca30d6…3010, 560787 B).

**Mapeamento de vistas**: colunas S, N, E, W, a mesma ordem das folhas 384×96 anteriores.
Conferido, não presumido: nas folhas antigas e nas fontes novas a vista 3 (E) tem a gema
(grinalda) e a fivela (chapéu) no lado esquerdo da imagem, e a vista 4 (W) tem a gema no
lado direito/argola central. Mesma convenção do pipeline existente (`views: S,N,E,W`).

**Pipeline** (`python tools/prepare_e08_equipment_redesign.py p7_head_art`, estendido; as
demais peças não são regeneradas): recorte por bbox alfa (alfa ≥ 32, margem 3 px) por
vista; escala única por peça (vista mais larga = 76 px = 19 px lógicos; elementalista
0,1954, caçadora 0,2021); LANCZOS; colocado como no pipeline antigo (centrado em x, base
em y=68 da célula 96×96); alpha-bleed (RGB de pixels alfa 0 = cor opaca vizinha, 4 px)
antes e depois da redução. Caixas por vista (x0,y0,x1,y1 em px 4×): elementalista
[10,44,86,68] [10,46,85,68] [13,44,82,68] [12,44,83,68]; caçadora [10,14,85,68]
[10,29,86,68] [10,12,85,68] [10,22,85,68]. Anel da grinalda ≈ 17–19 px lógicos de
largura, 5–5,5 de altura (antes 15 de altura com fitas).

**Hashes** (384×96): `class_set_elementalist_head.png` 08d2dc53…bd4f → a045332f173a6f29…e72c
(16306 B); `class_set_hunter_head.png` 767c7e9b…933979b → a3b334d6ce0a4863…eafd (30556 B).
`.import` não mudaram. Tabela de encaixe regenerada (`prepare_e08_head_fit.py write`;
só as linhas das duas peças mudam).

**Parâmetros de encaixe** (decididos olhando as capturas): elementalista
`band, width_k 1,06, drop 0,08, vk 1,0` (antes 1,05/−0,02/0,75: a arte nova é uma linha
fina, vk 0,75 a deixava quase invisível; drop leve a assenta na linha do cabelo);
caçadora `cover, width_k 1,14, drop −0,12, vk 0,9` (antes 1,08/−0,09/0,85; chapéu menor
pede mais largura relativa; testei drop −0,05, que deixava um arco de cabelo claro
aparecendo acima da copa).

**Capturas nativas** (janela 1280×720, grama, 10 classes × 4 direções × repouso/caminhada/
ação/dano/cadáver, mais a página de cada peça em todas as 10 classes), em
`.godot/verification/p7/`: antes (arte antiga, encaixe C6) `C8_terra_head_art_probe_c8_old160`;
depois `..._c8_fin160` (zoom 160) e `..._c8_fin260` (leitura ampliada); iterações
`..._c8_new160`, `..._c8_new260`, `..._c8_t1_160`. Arquivos `after_z160_elementalist.png`,
`after_z160_hunter.png`, `after_z160_piece_class_set_{elementalist,hunter}_head.png`.

**Avaliação visual (minha, não auditoria independente)**:
* Elementalista: as fitas sumiram, nada cruza bochecha ou olho em nenhuma das quatro
  direções nem no dano; o anel fino assenta na linha do cabelo, a gema aparece no lado
  correto em E/W. Limitação: em escala 160 o anel é discreto (é o pedido: fino).
* Caçadora: a copa é baixa, a aba mais estreita e levanta da testa; rosto e olhos ficam
  visíveis em S/E/W, chapéu não engole a cabeça; acompanha o dano e o cadáver. Limitações:
  a franja/cabelo claro do corpo continua à mostra sob a aba (é o corpo, não a peça);
  na vista W o chapéu fica ligeiramente recuado sobre a nuca.
* Página “todas as classes”: ambas as peças assentam nas 10 classes sem afundar no chão.

**Testes** (wrapper `-Package C8_terra_head_art`, sync, import das PNGs, verify
`c8_verify1`, 0 falhas): e08_equipment_art_test 60273; e08_directional_rig_compatibility_test
41888; e08_directional_units_test 47494; e08_characters_test 1350;
e06_appearance_integration_test 302; equipment_hand_alignment_test 4593; e08_pilot_test
350; e07_f7_presentation_test 27. Nenhuma verificação alterada ou relaxada. Não repeti
a suíte inteira. Falta aceite humano da aparência.

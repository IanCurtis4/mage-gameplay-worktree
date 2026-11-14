# Briefing de arte para o Codex — 14/11/2026 (efeitos e ícones de equipamento)

Estado: **WIP, aguardando geração pelo Codex** a pedido do usuário. Claude não gera
raster. O encaixe no jogo (recorte, empacotamento, catálogo, testes) fica com Claude
depois da entrega, pelos pipelines existentes. Até lá o jogo segue com a versão
atual (efeito desenhado em código, ícone vetorial genérico).

## Regras para esta rodada

- **Só gerar imagens.** Usar o imagegen embutido e salvar a saída byte a byte, sem
  editar o raster por código.
- **Destino exclusivo:** `assets/art/e08_codex_1114/`. Subpastas `vfx/` e
  `equipment_icons/`. Não tocar em `scripts/`, `tests/`, `tools/`, `docs/`, `.godot/`,
  catálogos, atlas ou arte já em uso.
- **Não rodar o Godot nem scripts Python** do projeto: há uma suíte rodando na mesma
  máquina e fixture.
- **Sem commit.** O checkout tem trabalho de save não commitado.
- **Proveniência obrigatória com prompt exato.** Em cada subpasta, um
  `provenance.json` com, por arquivo: `path`, `sha256`, `width`, `height`,
  `generator: "Codex built-in imagegen"`, `request` (seção deste briefing) e
  **`prompt` com o texto exato enviado**. Nas rodadas anteriores o prompt ficou
  `null`; desta vez ele é necessário para gerar variações depois que o Codex sair.
- Se faltar limite, entregar na ordem de prioridade abaixo e listar o que ficou
  de fora.
- Ao terminar: avisar o usuário com a lista de arquivos e qualquer item refeito ou
  pulado.

## Prioridade

1. Efeitos A1–A8 (oito assinaturas sem animação própria).
2. Ícones B1 (conjuntos de classe: tronco + pés).
3. Ícones B2–B5 (conjuntos compartilhados, arena, joias, peças de corpo avulsas).
4. Efeitos opcionais A9–A10.

---

## A. Efeitos animados (flipbooks)

Hoje há nove folhas (`assets/art/e08_vfx/staging/*.png`, mesmo formato abaixo).
Use-as como referência de estilo, escala e leitura. Treze assinaturas usam essas
folhas; as oito abaixo ainda caem no efeito desenhado em código.

### Formato comum (igual às nove existentes)

- Um PNG **RGBA transparente** por efeito, `vfx/<id>.png`, **1254×1254**.
- Grade **4×4 = 16 quadros** em células iguais, lidos da esquerda para a direita e
  de cima para baixo: início → pico (por volta do quadro 8) → dissipação; o último
  quadro quase vazio.
- Efeito centrado na célula, **mesma escala e mesmo centro em todos os quadros**
  (o empacotador usa uma única caixa comum aos 16 quadros), sem nada encostando
  na borda da célula.
- Vista 3/4 de cima do jogo: o chão é uma elipse achatada ~2:1.
- Sem personagens, inimigos, chão, texto, moldura, fundo ou sombra projetada.
- Pixel-art pintada à mão, coerente com as nove folhas existentes e com
  `assets/art/vfx/spiritualist_effects.png`. Bordas limpas sobre alfa; núcleo
  luminoso com 2–3 tons; sem bloom cobrindo a célula. Indicadores de perigo
  vermelhos/amarelos do jogo precisam continuar legíveis por cima.
- Efeitos com direção (marcados "→") são desenhados **apontando para a direita**;
  o jogo rotaciona.

### Folhas

| # | id do arquivo | Habilidade (classe) | Quando aparece | Direção artística |
|---|---|---|---|---|
| A1 | `arrow_rain` | Chuva de Flechas (Arqueiro) | início da área escolhida | flechas caindo em diagonal sobre uma elipse de chão, impactos curtos e poeira; madeira/aço com brilho dourado discreto |
| A2 | `wound_leap` → | Salto Cruento (Berserker) | aterrissagem do salto | impacto de aterrissagem com rachaduras no chão e rastro curto vermelho-escuro do salto chegando da esquerda; sem gore |
| A3 | `tri_nova` | Nova Tríplice (Elementalista) | ao redor do personagem | anel em expansão dividido em três terços: fogo laranja, gelo ciano, raio violeta, girando levemente e se dissipando juntos |
| A4 | `spirit_dissipation` | Rito de Dissipação (Espiritualista) | rito contra alvos marcados | pulso espectral branco-lavanda em ondas concêntricas, com fiapos de almas subindo e se desfazendo; clima sereno, não assustador |
| A5 | `triangulation` | Triangulação (Geômetra) | disparo da figura | triângulo de linhas douradas se formando a partir de três vértices luminosos, runas geométricas finas, fecha e emite um clarão |
| A6 | `headshot` → | `sentinel_headshot`, disparo de precisão (Sentinela) | disparo | clarão de disparo preciso: mira em forma de retículo que se fecha num ponto e uma estria de luz branca-azulada para a direita |
| A7 | `covering_shot` → | `hunter_covering_shot`, tiro de cobertura (Caçadora) | disparo | flecha partindo para a direita com rastro de folhas e espinhos verdes que se espalham em leque curto |
| A8 | `warden_charge` → | Investida do Guardião Ancestral (chefe da floresta) | início da investida | rajada de terra, raízes e folhas arrancadas do chão, levantando para trás enquanto a força parte para a direita; verde-musgo/marrom |

### Opcionais (só se sobrar limite)

| # | id do arquivo | Hoje usa | Direção |
|---|---|---|---|
| A9 | `geometer_collapse` | onda de choque tingida | figura geométrica dourada implodindo para o centro e estourando em fragmentos de linha |
| A10 | `shield_bash` → | corte em arco tingido (Contraforte, do Defensor) | impacto frontal de escudo: placa de luz azul-aço em forma de escudo e faíscas |

Aceite: 16 quadros, só o último pode estar vazio; centro e escala estáveis;
nada fora da célula; leitura clara do início, pico e fim em tamanho pequeno
(o efeito ocupa de 60 a 130 px no mundo).

---

## B. Ícones de equipamento pintados

Hoje cabeças, armas, escudos e focos já usam arte pintada. As peças
abaixo ainda caem em um ícone vetorial genérico por tipo de superfície
(`assets/art/icons/equipment/*.svg`), então peças diferentes aparecem iguais no
inventário.

### Estilo e formato

- **Mesmo estilo das cabeças e armas pintadas** em
  `assets/art/e08_equipment_redesign/` (`contact_sheet.png` mostra o conjunto):
  ilustração pintada de RPG de fantasia, vista 3/4 de frente, iluminação suave
  vinda de cima à esquerda, contorno limpo, sem pixel-art.
- **Fundo RGBA transparente**, sem sombra projetada, moldura, texto ou chão.
- Folhas com várias peças: **uma peça por célula**, todas na mesma escala relativa,
  com **espaço transparente generoso entre as células** (o recorte é por alfa).
  Folha ~1254 px no lado maior.
- Cada peça precisa ser reconhecível a **48×48 px**: silhueta forte, poucos
  detalhes pequenos.
- **Consistência de conjunto:** o tronco e os pés de um conjunto de classe usam a
  paleta e os motivos da cabeça desse conjunto
  (`assets/art/e08_equipment_redesign/class_set_<classe>_head.png`,
  `shared_set_<nível>_head.png`). Use a cabeça como referência de entrada.

### B1 — Conjuntos de classe (10 folhas, prioridade alta)

Uma folha por classe, `equipment_icons/class_set_<classe>.png`, **2 células lado a
lado: tronco à esquerda, pés à direita**. Referência: a cabeça do mesmo conjunto.

| Classe (`<classe>`) | Tronco | Pés |
|---|---|---|
| `swordsman` | Jaqueta do Duelista | Botas do Avanço |
| `mage` | Túnica do Aprendiz Lunar | Sapatos de Conjuração |
| `archer` | Colete da Flecha Certa | Botas do Passo Leve |
| `defender` | Couraça do Portão | Grevas do Baluarte |
| `berserker` | Peitoral do Rugido | Botas do Impacto |
| `elementalist` | Manto das Marés e Chamas | Sandálias do Círculo Elemental |
| `spiritualist` | Manto dos Ecos Gentis | Sandálias do Caminho Silencioso |
| `mg_ar` (Geômetra) | Manto da Figura Perfeita | Botas do Compasso |
| `sentinel` | Jaqueta do Vigia | Botas da Linha Segura |
| `hunter` | Casaco de Batedora | Botas de Rastreamento |

### B2 — Conjuntos compartilhados (3 folhas)

`equipment_icons/shared_set_<nível>.png`, 2 células (tronco, pés). Referência:
`shared_set_<nível>_head.png`.

| Nível | Tronco | Pés |
|---|---|---|
| `low` | Colete de Caminhante | Botas de Trilha |
| `mid` | Casaco Lunar | Sapatos de Luar |
| `high` | Manto das Constelações | Grevas Celestes |

### B3 — Troncos da arena (1 folha, 3×2)

`equipment_icons/arena_torso.png`, nesta ordem (linha 1, depois linha 2):

1. `arena_traveler_vest` — Colete do Viajante (couro simples)
2. `arena_trailcoat` — Casaco da Trilha (couro longo de viagem)
3. `arena_channeler_robe` — Veste do Condutor (tecido de conjurador)
4. `arena_warden_mail` — Cota do Guardião (cota de malha)
5. `arena_epic_ward` — Couraça de Treino da Arena (placa, qualidade épica)
6. `arena_legendary_ward` — Armadura da Guarda da Arena (placa ornamentada, lendária)

### B4 — Joias (1 folha, 3×2)

`equipment_icons/jewelry.png`, nesta ordem:

1. `arena_traveler_charm` — Pingente do Viajante
2. `arena_prismatic_charm` — Amuleto Prismático
3. `pilot_sp_jewel` — Joia da Reserva (tema: mana/reserva, azul)
4. `pilot_stride_jewel` — Joia da Passada (tema: velocidade, verde)
5. `pilot_ward_jewel` — Joia da Guarda (tema: proteção, âmbar)
6. `pilot_step_neck` — Colar do Passo Distante (colar)

### B5 — Peças de corpo avulsas (1 folha, 3×2)

`equipment_icons/body_pieces.png`, nesta ordem. Referência das cinco primeiras:
`assets/art/e08_equipment_redesign/pilot_head.png` (elmo de aço simples).

1. `pilot_shoulders` — Ombreiras do Baluarte
2. `pilot_arms` — Braçadeiras da Arena
3. `pilot_cloak` — Manto do Vigia
4. `pilot_legs` — Grevas do Guardião
5. `pilot_feet` — Botas de Passo Leve
6. `spiritualist_prayer_beads` — Japamala do Eco Calmo (contas de madeira enroladas no pulso; referência `assets/art/e08_equipment_redesign/wooden_beads.png`)

Aceite: uma peça por célula, na ordem pedida; fundo transparente; mesma escala
relativa dentro da folha; tronco e pés coerentes com a cabeça do conjunto;
legível a 48 px.

---

## Depois da entrega (Claude)

- A: estender `tools/prepare_e08_vfx_art.py` para os novos ids, gerar os atlas
  4×4 de 160 px e registrar em `VfxFlipbookCatalog` e `SIGNATURE_ART`, com
  testes de efeito e captura nativa.
- B: recortar por alfa, registrar ícones pintados por id de item com o vetor atual
  como fallback (mesmo padrão dos ícones de habilidade), com teste de inventário.
- Aceite visual continua humano.

---

## Entrega e integração — 14/11/2026

O Codex entregou as 26 folhas pedidas (10 efeitos, incluindo os dois opcionais, e 16
folhas de ícones), só em `assets/art/e08_codex_1114/`, com `provenance.json` contendo
o prompt exato de cada folha. Os SHA256 registrados conferem com os arquivos.

**Efeitos.** `python tools/prepare_e08_vfx_art.py codex_1114` empacota as dez folhas
com o mesmo pipeline do P6 (sem tocar no staging P6), em `assets/art/e08_vfx/<id>/`.
Todas têm 16 quadros, no máximo o último vazio. O empacotador agora encurta a
reprodução se sobrar mais de um quadro vazio no fim e recusa quadro vazio no meio
(não ocorreu nesta entrega). `VfxFlipbookCatalog` passa de 9 para 19 folhas.
`SIGNATURE_ART` passa a cobrir as 21 assinaturas:

| Assinatura | Folha | Diâmetro (px) | Avanço (px) |
|---|---|---|---|
| `archer_arrow_rain` | `arrow_rain` | 120 | 0 |
| `berserker_wound_leap` | `wound_leap` | 96 | 30 |
| `elementalist_tri_nova` | `tri_nova` | 140 | 0 |
| `spiritualist_dissipation` | `spirit_dissipation` | 116 | 0 |
| `geometer_triangulation` | `triangulation` | 96 | 0 |
| `sentinel_headshot` | `headshot` | 70 | 24 |
| `hunter_covering_shot` | `covering_shot` | 70 | 24 |
| `warden_charge` | `warden_charge` | 110 | 0 |
| `geometer_collapse` | `geometer_collapse` (antes onda de choque tingida) | 116 | 0 |
| `defender_counterstroke` | `shield_bash` (antes corte em arco tingido) | 82 | 26 |

`headshot`, `covering_shot` e `warden_charge` giram com a direção do evento mesmo
fora de golpe/movimento (`DIRECTIONAL`). `headshot`, `shield_bash` e
`spirit_dissipation` ganham o contorno escuro simples (`OUTLINED`), por serem claros.
Os diâmetros foram escolhidos pela proporção das assinaturas existentes, não por
medição em jogo.

**Ícones.** `python tools/prepare_e08_equipment_icons.py` recorta as 16 folhas em 44
ícones de 128 px (`assets/art/icons/equipment/painted/<item_id>.png` e
`manifest.json`). Cada peça foi conferida dentro da sua célula. A ordem segue a
seção B. `EquipmentPresentation.icon` usa o ícone pintado do item logo depois da cabeça e
antes do sprite de arma/escudo/foco na mão e do SVG por superfície, que continua como
reserva. Correção do briefing: o japamala já mostrava o sprite pintado das contas;
agora mostra o ícone próprio, e é o único item com as duas artes.
Os seis itens antigos (`traveler_vest`, `trailcoat`, `warden_mail`, `channeler_robe`,
`traveler_charm`, `prismatic_charm`) reutilizam o ícone da revisão de arena.

**Testes alterados.** `e08_vfx_art_test` (19 folhas; prompt registrado no segundo
lote), `e08_feedback_vfx_test` (21 assinaturas com folha, antes 13),
`e08_equipment_art_test` (44 ícones pintados, aliases, reserva SVG, cabeças
preservadas) e a sonda de release `e08_p7_release_probe` (19 folhas). As mudanças de
expectativa acompanham o novo conteúdo; nenhuma esconde falha.

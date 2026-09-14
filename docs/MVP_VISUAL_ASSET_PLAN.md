# Plano visual de assets do MVP

Data: 2026-09-14

Este é um plano de referência para produção e integração visual. Não implementa
sprites, VFX, cenas, input ou runtime, e não transforma concept art em
especificação fechada onde o handoff marcou `OPEN` ou `STRONG DIRECTION`.

## Como as fontes foram interpretadas

O pedido do usuário é a autorização desta tarefa: ler as concept arts e o
handoff e produzir um plano documental. O `CODEX_HANDOFF_README.md` e o
`CODEX_BOOTSTRAP_PROMPT.txt` fornecem contexto, status e restrições de retomada;
não autorizam implementação neste passo. O `ASSET_MANIFEST.md` identifica
snapshots, mas não substitui licença nem aceite de sprite final.

Fontes visuais consultadas:

- concept sheets anexadas nesta tarefa para Warder, Ravager, Sentinel, Waylayer,
  Elementalist, Snare-Reaver, Runebound Knight, Astral Ravager, Siege Bastion,
  Geometer e Hollow-Marker/The Between Marks;
- handoff preservado em
  [`docs/references/CODEX_HANDOFF_MVP_2026-09-14/`](references/CODEX_HANDOFF_MVP_2026-09-14/),
  especialmente `CODEX_HANDOFF_README.md` e `art/`;
- direção e pipeline existentes em `docs/ART_DIRECTION_NEXT.md`,
  `docs/MAGE_ANIMATION_PLAN.md`, `docs/PLAYTEST_MAGE_ANIMATION.md`,
  `docs/ARCHITECTURE.md`, `docs/ART_PROMPTS_PILOT.md` e nos assets atuais.

As concept arts são referência de linguagem, paleta, equipamento e VFX. Não são
sprites finais e não devem ser recortadas diretamente para o jogo.

## Contrato visual comum

Estas regras já existem no handoff/arquitetura e valem como base compartilhada:

- fantasia de RPG coreano de 2000–2006, personagem compacto e expressivo,
  leitura forte em tela pequena e contraste entre fofo e estranho;
- célula inicial de 64×64, corpo aproximadamente 40–52 px, pivô nos pés,
  nearest nos personagens e armas longas/VFX em camada ou célula maior quando
  necessário;
- blocos de cor, contorno seletivo escuro colorido, luz quente e sombras frias;
  a direção sugere 4–6 valores por material e aproximadamente 24–40 cores úteis,
  sem tratar esses números como novo contrato rígido;
- o atlas de animação atualmente integrado usa 256×512, 32 células de 64×64,
  frente/costas e espelhamento para esquerda/direita. Isso cobre quatro vistas
  práticas, não oito desenhos independentes;
- animação visual não altera hitbox, alcance, dano, velocidade ou cooldown.
  `CombatAnimationState` controla apresentação; `CharacterAnimation` compartilha
  atlas imutável e mantém estado por ator;
- assets de conceito permanecem fora do runtime. Os assets jogáveis atuais estão
  em `assets/art/animations/` e `assets/art/pilot/`; fontes e prompts ficam
  preservados em `assets/art/animation_sources/` e `docs/`.

## Primitivas reutilizáveis e dependências comuns

O handoff recomenda um conjunto pequeno de componentes concretos, parametrizáveis
e testáveis. O plano os trata como dependências de apresentação, não como
arquitetura já implementada:

| Recurso reutilizável | Uso previsto |
|---|---|
| `CharacterAnimation` / `CombatAnimationState` | idle, caminhada, ação, dano e morte com pivô comum; ações preservam a direção visual do lançamento |
| `TrailVFX` / `AfterimageVFX` | dash, perseguição, ecos, deslocamento espectral e rastros |
| `BurstVFX` / hit flash / hitstop / screenshake | impacto melee, sangue, explosões elementais e confirmação de acerto |
| `GroundAreaVFX` / decal de chão / ground trace | paredes, círculos, armadilhas, marcas, trilhas e áreas de controle |
| `AuraVFX` / `TetherVFX` | guardas, fúria, posse, vínculos, linhas e efeitos persistentes |
| `FloatingGlyphVFX` / `ProjectileTrailVFX` | runas, vértices, glifos, flechas, projéteis e canais elementais |
| `BattleIndicators` | preview/telegraph de cone, linha, círculo, alvo e clique; continua dono dos marcadores |
| `ArenaView` / `ArenaObstacleView` | piso, profundidade 2D simulada e oclusão visual; não alterar a geometria de colisão por causa da arte |

Dependências técnicas transversais: importação Godot 4.7.2 Compatibility,
texturas imutáveis, filtragem coerente com o piloto, alinhamento de pés, sinais
de `presentation_action`, `cast_cancel`, dano positivo e morte, e revisão no
renderer real. A migração para chão 3D continua separada; este plano assume a
arena 2D com profundidade simulada atual.

## Classes base do MVP

As três bases não recebem nova direção visual destas concept sheets. O plano
preserva o piloto e os prompts já existentes.

### Espadachim

- **Paleta:** azul/teal da túnica, creme, aço claro, marrom de botas/luvas e
  cabelo castanho; luz quente, sombras frias e contorno escuro colorido do piloto.
- **Silhueta:** corpo compacto, cabeça expressiva, espada curta/larga legível e
  ombro de aço simples; não adicionar o escudo ou os ornamentos das classes
  estendidas.
- **Materiais:** tecido teal, aço simples, couro marrom, madeira/metal da espada.
- **VFX signature:** arco curto do corte, rastro/impacto da investida e sinal
  contido da passiva de resistência; a geometria do corte continua compartilhada
  com a mira e não vira um novo sprite de dano.
- **Animações mínimas:** idle, caminhada, auto/corte, investida, dano e morte;
  usar a gramática atual do atlas, com frente/costas e espelhamento.
- **Assets reutilizáveis:** `assets/art/animations/swordsman.png`, fonte em
  `assets/art/animation_sources/`, `CharacterAnimation`, `TrailVFX`, `BurstVFX`,
  `BattleIndicators` e o preview do corte/investida.
- **Dependências técnicas:** `CombatAnimationState` para `slash`/`dash`, direção
  capturada no lançamento, `SkillGeometry` para o cone e `ActorDeathVisual` para
  a morte cosmética. Não alterar fórmulas, colisão ou alcance para acomodar arte.

### Mago

- **Paleta:** plum/violeta, creme, marrom e cristal turquesa do cajado; fogo,
  gelo e elementos de mira devem permanecer separados e legíveis.
- **Silhueta:** personagem compacto com capuz pontudo, casaco curto, botas e
  cajado com cristal; o cajado precisa permanecer dentro da célula ou usar camada
  maior sem redimensionar o corpo.
- **Materiais:** tecido plum/creme, couro marrom, madeira do cajado e cristal
  turquesa; VFX geométrico não deve ser confundido com material do corpo.
- **VFX signature:** projétil/`ProjectileTrailVFX`, quatro pilares da Parede de
  Fogo, trilha de fogo e gelo, e anel/traço curto de Teleporte. Fogo e gelo devem
  continuar visualmente distintos; a lógica de queimadura/lentidão permanece no
  gameplay já contratado.
- **Animações mínimas:** idle, caminhada, conjuração, dano e morte; a skill
  específica é comunicada pelo VFX e pela direção do cast, não por um atlas novo
  para cada magia.
- **Assets reutilizáveis:** `assets/art/animations/mage.png`, fontes, desenho
  geométrico de fogo/projétil/parede, `GroundAreaVFX`, `ProjectileTrailVFX`,
  `BattleIndicators` e sinais de cancelamento.
- **Dependências técnicas:** `presentation_action`/`cast_cancel`, pausa, orientação
  do lançamento, preview direcional e `FireWall`; os sprites não podem duplicar
  dano, cooldown, mana ou duração.

### Arqueiro

- **Paleta:** musgo/oliva, ocre/âmbar, marrom, lenço vermelho tijolo e madeira;
  manter contraste com o Espadachim e leitura do arco em escala pequena.
- **Silhueta:** capuz ou cobertura simples, corpo compacto, arco médio diagonal e
  aljava legível; poucos ornamentos, conforme o prompt do piloto.
- **Materiais:** madeira do arco, couro, tecido ocre/oliva, corda e metal discreto
  da ponta/quiver.
- **VFX signature:** flecha limpa com `ProjectileTrailVFX`, linha de disparo e
  marca de alvo; partículas devem ser discretas para não esconder a trajetória.
- **Animações mínimas:** idle, caminhada, preparação/disparo, dano e morte; uma
  pose de ataque legível é prioridade antes de variações de arco.
- **Assets reutilizáveis:** `assets/art/animations/archer.png`, fontes, `TrailVFX`,
  `ProjectileTrailVFX`, `BattleIndicators` e ground trace para marcações.
- **Dependências técnicas:** direção fixa do projétil, colisão contínua com alvo e
  obstáculos, miras existentes e futura validação de precisão sem duplicar fórmula
  no HUD ou no asset.

## Classes puras estendidas

### Defendente / Warder

- **Paleta:** carvão/ferro, prata quente, marfim, couro marrom e ouro velho;
  usar o ouro como acento de juramento, não como preenchimento dominante.
- **Silhueta:** massa vertical e pesada, placas e retângulos, tower shield/pavês,
  arma curta e pequenos pendentes/banners; o escudo é o identificador principal.
- **Materiais:** aço, couro, pedra, tecido de bandeira, lanternas e amuletos de
  juramento.
- **VFX signature:** `Guardian Aura`, `Shield Wall`, `Counter Impact` e `Sanctuary
  Sigil`: impactos curtos, sigilos defensivos e ondas contidas.
- **Animações mínimas:** idle, caminhada pesada, ataque melee, guarda/parede,
  impacto recebido e morte; uma pose de implantação do escudo pode reutilizar a
  ação de guarda.
- **Assets reutilizáveis:** base de atlas de personagem, escudo/pavês, banner,
  `AuraVFX`, `GroundAreaVFX`, `BurstVFX`, hit flash e sombra de contato.
- **Dependências técnicas:** `presentation_action` para guarda e contra-impacto,
  áreas de chão que não alteram navegação por si mesmas, marcadores legíveis em
  pisos claros/escuros e separação entre aparência de cobertura e colisão real.

### Berserker / Ravager

- **Paleta:** carvão/preto, sangue seco, crimson ativado, couro escuro e osso;
  vermelho vivo aparece principalmente na ativação, ferida e frenesi.
- **Silhueta:** diagonais, dentes, rasgos, assimetria, cleaver/garra, pelo e
  troféus; deve parecer uma evolução agressiva, não uma recoloração do Warder.
- **Materiais:** ferro escuro, couro, pelo, osso, tecido rasgado e talismãs de
  batalha.
- **VFX signature:** `Rage Aura`, `Leaping Strike`, `Blood Burst` e `Pursuit Trail`;
  trails agressivos, pulsação e explosões curtas, sem partículas contínuas que
  apaguem a silhueta.
- **Animações mínimas:** idle, caminhada/pursuit, ataque pesado, skill feral,
  dano e morte; a entrada em fúria precisa ser legível como mudança de estado.
- **Assets reutilizáveis:** cleaver/gauntlet, troféus e pele, `TrailVFX`,
  `AfterimageVFX`, `BurstVFX`, hitstop e screenshake.
- **Dependências técnicas:** `presentation_action` para salto, ataque e fúria,
  timing de afterimage e feedback de dano positivo; não converter o melee em
  caster por causa dos ecos visuais.

### Sentinela / Sentinel

- **Paleta:** sage, azul pálido, creme, couro claro e metal frio; azul/branco
  devem ser linhas de orientação, não uma aura cheia.
- **Silhueta:** mais leve e linear que Warder/Siege Bastion, com arco ou besta,
  lente de observação, bandeira e mochila de campo; linhas longas e chevrons são
  os marcadores visuais.
- **Materiais:** madeira clara, tecido, metal polido, couro, papel/mapa,
  instrumentos de observação e bandeiras.
- **VFX signature:** `Lane Marker`, `Watch Line`, `Guiding Volley` e `Rally Mark`;
  indicadores direcionais limpos, projéteis finos e círculos de leitura.
- **Animações mínimas:** idle, caminhada, preparação/disparo ranged, scout/mark,
  dano e morte; uma pose de implantação da bandeira pode ser compartilhada com
  marcação.
- **Assets reutilizáveis:** arco/besta, lente, banner, `ProjectileTrailVFX`,
  `GroundAreaVFX`, `TetherVFX` e `BattleIndicators` de linha.
- **Dependências técnicas:** mira e marcação de linha, alcance/precisão centralizados,
  telegraph que não duplica geometria de dano e `ArenaObstacleView` para leitura
  de cobertura.

### Caçador / Waylayer

- **Paleta:** musgo escuro, oliva, marrom escuro, tan e osso/linho; pouco vermelho,
  reservando violência ativada ao Snare-Reaver.
- **Silhueta:** fieldcraft compacto, capuz/folhagem, arco ou ferramenta curta,
  cordas, bolsas e trap pack; a leitura deve ser de mecanismo preparado, não de
  armadura pesada.
- **Materiais:** corda, madeira bruta, couro, osso, folhagem, ferro de armadilha
  e tecido gasto; o pequeno companheiro pode ser asset separado.
- **VFX signature:** `Trap Trigger`, `Tether Line`, `Camouflage Setup` e `Pursuit
  Mark`: poeira, folhas, marcas no chão e mecanismos acionando.
- **Animações mínimas:** idle, caminhada, ataque ranged, implantação/ativação de
  armadilha, preparação de camuflagem, dano e morte.
- **Assets reutilizáveis:** arco, trap pack, armadilhas modulares, `GroundAreaVFX`,
  `TetherVFX`, decal/ground trace, `ProjectileTrailVFX` e companion separado.
- **Dependências técnicas:** ponto de colocação no chão, estado visual de trap
  armada/disparada, linhas que não viram colisão falsa, marcação de rota e
  sincronização com o sistema de navegação/obstáculos.

### Elementalista / Elementalist

- **Paleta:** navy, azul, branco frio, vermelho de fogo e amarelo elétrico; é a
  identidade mais saturada entre as mágicas do MVP. Fogo, Gelo e Raio precisam
  permanecer distinguíveis em qualquer piso.
- **Silhueta:** estudioso-aventureiro com casaco dividido, prismas, astrolábio,
  staff e cristais; os três elementos aparecem como focos separados ao redor do
  corpo, não como roupa RGB.
- **Materiais:** cristal, vidro, metal arcano, tecido, papel/grimório e madeira
  do cajado; familiares elementais são efeitos/companheiros separados.
- **VFX signature:** `Flame Burst`, `Glacial Wall`, `Lightning Arc` e `Tri-Element
  Nova`, com fogo vermelho, gelo azul e raio amarelo em formas distintas.
- **Animações mínimas:** idle, caminhada, conjuração, canalização/descarga,
  dano e morte; variações elementais devem reutilizar a pose e trocar VFX, sem
  multiplicar atlas antes de validar uma animação completa.
- **Assets reutilizáveis:** prismas, cristais, familiares, `FloatingGlyphVFX`,
  `GroundAreaVFX`, `BurstVFX`, `ProjectileTrailVFX` e paleta elemental compartilhada.
- **Dependências técnicas:** catálogo de efeitos por elemento, timing de cast,
  telegraphs de área e parede, camada de VFX separada do sprite e regras centrais
  de dano/cooldown/mana; não fechar coeficientes visuais como balanceamento.

### Espiritualista

- **Paleta:** branco pálido, prata/cinza, azul-cinza, carvão e preto; VFX
  translúcido e dessaturado, com dissipação e atraso.
- **Silhueta:** **OPEN**. O handoff diz que a referência de mood contaminou a
  forma com vocabulário de ranger/ghost-hunter e não deve ser tratada como
  model sheet final do Espiritualista puro. Este plano não inventa um corpo,
  roupa ou arma final.
- **Materiais:** tecido, névoa, ectoplasma e metal ritual; usar a divisão entre
  objeto físico e fenômeno espectral, não uma recoloração definitiva.
- **VFX signature:** afterimages, vestígios, trilhas espectrais, glifos apagando e
  projéteis que deixam rastro; transparência, atraso e dissipação são a assinatura.
- **Animações mínimas:** idle, caminhada, ação ritual/cast, dano e morte como
  gramática compartilhada. O atlas final, poses específicas e equipamento ficam
  pendentes da decisão de silhueta; nenhum asset da prancha `The Between Marks`
  fecha essa decisão.
- **Assets reutilizáveis:** `AfterimageVFX`, `TrailVFX`, `ProjectileTrailVFX`,
  `FloatingGlyphVFX`, decal espectral e `AuraVFX`; companion/lanterna da referência
  são estudos, não dependências locked.
- **Dependências técnicas:** sinais de ação/cancelamento, blending/transparência,
  ordem de desenho e pausa; decisão posterior de identidade visual antes de
  encomendar sprites finais ou converter o mood em equipamento.

## Híbridas direcionais do MVP

Todas respeitam a regra do handoff: a classe de origem fornece objeto/material/
silhueta; a segunda identidade fornece o fenômeno. Quando há melee + ranged/
caster, o payoff principal continua tendo precedência melee.

### Cavaleiro Rúnico / Runebound Knight

- **Paleta:** base de Warder em aço, marfim, couro e ouro velho, com canais
  saturados de Fogo, Gelo e Raio; elementos aparecem em runas, não em toda a roupa.
- **Silhueta:** armadura pesada e aegis do Warder, com inscrições, rune disk,
  oathblade e lanterna; a leitura continua de cavaleiro protetor.
- **Materiais:** aço, tecido, couro, cristal/rune, madeira/metal da lanterna e
  inscrições no escudo.
- **VFX signature:** `Rune Guard`, `Glacial Bulwark`, `Thunder Discharge` e
  `Tri-Rune Burst`; canais elementais contidos em placas e escudo.
- **Animações mínimas:** idle, caminhada, ataque melee, guarda/canalização,
  troca/seleção rúnica, descarga, dano e morte.
- **Assets reutilizáveis:** atlas/escudo do Warder, glifos e familiares elementais
  do Elementalista, `FloatingGlyphVFX`, `AuraVFX`, `GroundAreaVFX` e `BurstVFX`.
- **Dependências técnicas:** seleção rúnica e UI/input dedicado, sem forçar runas
  a slots comuns; feedback do elemento selecionado, ação de guarda e payoff melee.

### Devastador Astral / Astral Ravager

- **Paleta:** preto/carvão, vermelho escuro e sangue, com branco/cinza espectral
  nas mãos e ecos; o vermelho perde saturação conforme a possessão cresce.
- **Silhueta:** corpo e diagonais do Ravager, invadidos por mãos, braços e
  afterimages espectrais; não virar caster distante.
- **Materiais:** couro, pelo, osso, tecido rasgado, talismãs e ectoplasma.
- **VFX signature:** `Afterimage Slashes`, `Possession Aura`, `Blood Eruption` e
  `Astral Echo Strike`; ecos atrasados devem continuar acompanhando golpes melee.
- **Animações mínimas:** idle, caminhada/ataque, entrada em possessão, golpe com
  eco, dano e morte; a transição de estado é mais importante que uma pose nova
  para cada eco.
- **Assets reutilizáveis:** base de Ravager, `AfterimageVFX`, `TrailVFX`,
  `AuraVFX`, `BurstVFX`, mãos espectrais e hitstop.
- **Dependências técnicas:** eventos de ação e duração de ecos, estado de
  possessão, cópias visuais sem colisão/dano próprio e prioridade melee do kit.

### Baluarte de Cerco / Siege Bastion

- **Paleta:** Warder em prata/branco/ouro velho combinado com sage, azul pálido e
  creme da Sentinela; azul e branco definem linha, mira e bandeira.
- **Silhueta:** corpo pesado e escudo/pavês do Warder, com lente, bandeira e
  corredores visuais da Sentinela; não reduzir a fortificação a uma recoloração.
- **Materiais:** metal, couro, madeira, tecido de banner, lentes e acessórios de
  campo.
- **VFX signature:** `Watch Line`, `Shield Wall`, `Counter-Volley` e `Mark the
  Lane`; linhas direcionais, cobertura e represália legíveis.
- **Animações mínimas:** idle, caminhada pesada, guarda/posicionamento do pavês,
  disparo de represália, marcação de lane, dano e morte.
- **Assets reutilizáveis:** escudo/bandeira do Warder, lente/banner da Sentinela,
  `GroundAreaVFX`, `TetherVFX`, `ProjectileTrailVFX` e `BattleIndicators` de linha.
- **Dependências técnicas:** implantação visual que não cria colisão por acidente,
  linhas/corredores ligados à mira e cobertura real, além de sincronização entre
  ação melee defensiva e contra-disparo.

### Saqueador / Snare-Reaver

- **Paleta:** musgo, couro, ferrugem e terra do Waylayer; crimson e sangue vivo
  só quando trap, rush ou frenzy são ativados.
- **Silhueta:** estado neutro de trapper; estado ativado revela diagonais,
  lâminas, correntes e rasgos do Berserker. A rota feita pelas próprias traps é
  parte da leitura da silhueta em movimento.
- **Materiais:** corda, madeira, couro, ferro de armadilha, osso, tecido rasgado
  e manchas de sangue estilizadas.
- **VFX signature:** `Blood Trap`, `Self-Trigger Launch`, `Unstoppable Rush` e
  `Frenzy/Reset`; corrente, linha de rush, knockback e rearmamento devem ter
  estados visuais distintos.
- **Animações mínimas:** idle, caminhada, armar trap, auto/ataque, autoativação
  com rush, impacto/knockback, dano e morte.
- **Assets reutilizáveis:** traps/tethers do Waylayer, `TrailVFX`, `BurstVFX`,
  ground decals, blood accents e afterimage curta do Ravager.
- **Dependências técnicas:** ativação das próprias traps, rush `Unstoppable`,
  bleed/movespeed e redução/rearmamento de cooldown; visual não pode simular
  invulnerabilidade ou colisão fora do contrato.

### Geômetra / Geometer

- **Paleta:** branco, azul-claro/navy, ouro e cristal, com cores elementais nos
  vértices/arestas; a composição deve permanecer limpa e não cobrir o corpo inteiro.
- **Silhueta:** scholar-archer com arco-staff modular, astrolábio, prismas,
  triângulos e elementos flutuantes; leitura de instrumento de desenho espacial.
- **Materiais:** tecido, metal dourado, cristal/vidro, pergaminho/mapa, madeira e
  componentes modulares do arco-staff.
- **VFX signature:** `Elemental Vertices`, `Directed Wall`, `Triangle Field` e
  `Converging Projectiles`; vértices, paredes e triângulos precisam ser formas
  espaciais legíveis antes do impacto.
- **Animações mínimas:** idle, caminhada, puxada/disparo, colocar vértice,
  construir parede, fechar triângulo/convergir, dano e morte.
- **Assets reutilizáveis:** markers/linhas da Sentinela, prismas do Elementalista,
  `FloatingGlyphVFX`, `GroundAreaVFX`, `TetherVFX` e `ProjectileTrailVFX`.
- **Dependências técnicas:** input/UI dedicado para colocar vértices e selecionar
  relações, 6 paredes direcionais e 27 triângulos sem virar 33 botões, preview
  geométrico compartilhado e marcadores de chão/alvo; não simplificar a gramática
  para caber no sistema comum.

### Caçador de Espectros / Hollow-Marker

- **Paleta:** carvão/preto, cinza/azul-cinza, marrom de equipamento e branco/azul
  espectral; o corpo permanece terreno e só o fenômeno fica pálido/translúcido.
- **Silhueta:** tracker com chapéu largo, lanterna, talismãs, field pack e
  ferramentas de armadilha; a prancha `The Between Marks` informa mood e
  relação ranger/ghost-hunter, enquanto a concept sheet do Hollow-Marker informa
  a leitura híbrida.
- **Materiais:** tecido gasto, couro, madeira, osso, papel/talismãs, metal da
  lanterna, névoa e ectoplasma.
- **VFX signature:** `Haunting Trail`, `Soul Projectile`, `Banishment Circle` e
  `Soul Capture`; Soul Dust escreve o terreno e o disparo espectral lê essa rota.
- **Animações mínimas:** idle, caminhada, tiro espectral, armadilha, captura,
  banishment/haunting, dano e morte; o corpo não precisa de uma pose fantasma
  independente para cada estado de trilha.
- **Assets reutilizáveis:** traps/ground trace do Waylayer, lanternas e charms,
  `TrailVFX`, `ProjectileTrailVFX`, `GroundAreaVFX`, `TetherVFX` e afterimages do
  mood Espiritualista.
- **Dependências técnicas:** Soul Dust no chão, trilha que transforma flecha,
  Spectral/Banishment/Haunting Traps, medo/banimento, propagação controlada e
  telegraphs de área. O VFX não deve aplicar dano ou estado diretamente.

## Ordem de produção visual sugerida pelo material existente

Esta ordem não cria novo escopo; apenas organiza dependências já descritas:

1. Validar uma animação completa e o contrato de escala/pivô com o pipeline atual,
   começando pelas bases existentes, antes de multiplicar classes.
2. Extrair um kit reutilizável de `Trail`, `Burst`, `GroundArea`, `Aura`, `Tether`,
   `Glyph` e `ProjectileTrail` com testes/preview de apresentação.
3. Produzir primeiro as assinaturas que dependem de objetos claros: escudo/linha
   do Warder/Sentinel, traps do Waylayer/Snare-Reaver e elementos do
   Elementalist/Runebound.
4. Validar as gramáticas especiais de Runebound Knight e Geometer com seus
   marcadores/input próprios antes de desenhar um catálogo inteiro.
5. Fechar a silhueta OPEN do Espiritualista antes de encomendar seu atlas final;
   Hollow-Marker pode usar o material híbrido explicitamente aprovado, sem
   converter o mood em regra para a classe pura.

Critérios transversais de revisão: silhueta e arma legíveis em 64×64, pivô sem
salto, frente/costas coerentes com espelhamento, VFX visível em pisos claros e
escuros, telegraph separado do dano, ausência de assets proprietários e nenhuma
mudança de contrato de gameplay motivada apenas por apresentação.


# E09 — contrato de arquitetura

Índice, decisões e tarefas: [e09.md](e09.md). Fonte do design das classes:
[HYBRIDS_56_V3.md](../HYBRIDS_56_V3.md) (Paladino, Taumaturgo, Duelista, Lâmina Arcana) e as
fichas do Sacerdote e do Assassino em [EXTENDED_CLASS_SPECS.md](../EXTENDED_CLASS_SPECS.md).
Precedência: [WORKFLOW](../WORKFLOW.md) para o fluxo; este contrato para o E09; E00 e as
autoridades de [ARCHITECTURE](../ARCHITECTURE.md) nos pontos não substituídos.

Números (raios, durações, multiplicadores, limiares) não estão aqui. Cada tarefa de sistema
ou de kit fecha os seus num contrato curto antes de implementar, a partir das fichas. São
ajuste de playtest e não exigem nova decisão de arquitetura.

## 1. Identidades e IDs

| Identidade | ID | Origem | Afinidade (rótulo) | Pasta de corpo | Prefixo das skills |
|---|---|---|---|---|---|
| Paladino | `sp_ac` | `swordsman` | `acolyte` | `paladin` | `paladin_` |
| Taumaturgo | `mg_ac` | `mage` | `acolyte` | `thaumaturge` | `thaumaturge_` |
| Duelista | `sp_la` | `swordsman` | `rogue` | `duelist` | `duelist_` |
| Lâmina Arcana | `mg_la` | `mage` | `rogue` | `arcane_blade` | `arcane_blade_` |

`acolyte` e `rogue` entram como bases **reservadas, não jogáveis**: servem só de rótulo de
afinidade e não aparecem na criação de personagem.

Skills (ID estável em inglês; nome visível pt-BR provisório, vindo da ficha):

| Job | Paladino | Taumaturgo | Duelista | Lâmina Arcana |
|---|---|---|---|---|
| 20 ativa, entrada | `paladin_oath` Juramento | `thaumaturge_votive_circle` Círculo Votivo | `duelist_parry` Aparo | `arcane_blade_refracted_mark` Marca Refratada |
| 23 passiva | `paladin_guard_grace` Graça de Guarda | `thaumaturge_votive_prism` Prisma Votivo | `duelist_read_opponent` Leitura do Oponente | `arcane_blade_enchanted_edge` Lâmina Encantada |
| 25 ativa | `paladin_consecrated_impact` Impacto Consagrado | `thaumaturge_healing_refraction` Refração Curativa | `duelist_fatal_riposte` Riposte Fatal | `arcane_blade_refraction` Refração |
| 28 ativa | `paladin_oath_aegis` Égide do Juramento | `thaumaturge_altar_shift` Mudança de Altar | `duelist_feint` Finta | `arcane_blade_prismatic_leap` Salto Prismático |
| 31 passiva | `paladin_unshaken_faith` Fé Inabalável | `thaumaturge_elemental_choir` Coro dos Elementos | `duelist_patient_guard` Guarda Paciente | `arcane_blade_light_fracture` Fratura de Luz |
| 34 ativa | `paladin_condemned_seal` Selo do Condenado | `thaumaturge_prismatic_judgment` Juízo Prismático | `duelist_guarded_retreat` Recuo em Guarda | `arcane_blade_prismatic_sentence` Sentença Prismática |
| 37 ativa | `paladin_oath_hour` Hora do Juramento | `thaumaturge_convergent_dawn` Aurora Convergente | `duelist_duel` Duelo | `arcane_blade_prism_specter` Espectro de Prisma |

As regras de aprendizado são as vigentes: entrada gratuita no job 20 ao evoluir; ranks 1–5 nas
ativas e 1–3 nas passivas; barra de 24 atalhos; passivas legais automáticas
([MVP](../MVP.md)). A biblioteca da origem continua disponível (regra do E06).

## 2. C1 — costura de kits (tarefa T1)

**Problema.** Os kits atuais passam por arquivos compartilhados: `player_actor.gd` (4.093
linhas), `main.gd`, `combat_actor.gd`, `class_catalog.gd`, `profile_catalog.gd`,
`skill_definition.gd`, `build_effect_catalog.gd`, `feedback_recipe_catalog.gd`,
`feedback_vfx_layer.gd`, `skill_copy.gd`, `character_animation.gd`,
`directional_animation_set.gd`, `build_presentation.gd`, `equipment_eligibility_rules.gd`,
`identity_ids.gd`, `threat_service.gd`, o manifesto do snapshot e `tools/verify.ps1`. Duas
classes não podem ser feitas ao mesmo tempo.

**Regra.** T1 é a única tarefa do E09 que edita esses arquivos. Ela cria uma costura, e
depois dela cada classe vive em `scripts/classes/<id>/`, cada sistema em
`scripts/systems/<nome>/`, e os testes em `tests/classes/<id>/`, `tests/systems/<nome>/` ou
`tests/e09/`. Os kits existentes **não** migram, e o comportamento das 10 identidades atuais
não muda.

Obrigações (assinaturas a cargo de Sol, publicadas em `docs/epics/e09/t1_kit_seam_api.md`):

1. **Registro.** `scripts/classes/class_kit_registry.gd` já lista os quatro IDs da seção 1,
   cada um apontando para `scripts/classes/<id>/<id>_kit.gd`. T1 entrega esses quatro
   módulos como esqueletos vazios. As tarefas de kit só editam a própria pasta; ninguém mais
   edita o registro.
2. **Dados por módulo.** O módulo fornece definições e ranks de skill, entradas de
   aprendizado (níveis da seção 1), efeitos de build, receitas de feedback e textos pt-BR.
   `ClassCatalog`, `ProfileCatalog`, `BuildEffectCatalog`, `FeedbackRecipeCatalog` e
   `SkillCopy` agregam esses dados. Preview e execução usam a mesma composição, como hoje.
3. **Disponibilidade.** O módulo declara `ready_for_play`. Enquanto for falso,
   `ProfileCatalog` não oferece a evolução, como fazia com `mg_ar` antes de G7. Perfis de
   fixture podem forçar a evolução para teste.
4. **Ganchos no jogador.** Um objeto de kit por personagem com a evolução ativa. Ele recebe:
   - tick, com o congelamento da pausa;
   - cast pedido, confirmado e resolvido, com skill, rank, elemento, âncora e facing;
   - substituição do ataque básico: alcance, corpo a corpo ou distância, composição do dano;
     é a intrínseca explícita do E00;
   - pipeline de golpe recebido, numa ordem fixa:
     1. antes da mitigação, podendo cancelar (é o que permite o aparo);
     2. depois da mitigação, com a informação "de frente";
     3. escudo quebrado;
   - cura, com o pedido e o aplicado, para medir o excedente;
   - dano causado e abate confirmado, depois do claim;
   - morte e retorno;
   - troca de build e aprendizado, sem cura nem reset implícitos.
5. **Inimigos.**
   - `ActorMarks` genérico em `CombatActor`: marcas por chave, com dono, valor e expiração no
     relógio de gameplay. Fica no manifesto uma única vez.
   - **Facing de gameplay autoritativo** em `CombatActor`, o mesmo que a apresentação
     desenha, com override temporário ("girar").
   - Evento de ataque inimigo com tipo (corpo a corpo, projétil ou área), atacante, alvo,
     instante do commit e instante do impacto.
6. **Ameaça.** Primitivas genéricas `force_target(enemy, owner, duração)` e
   `break_sight(enemy, owner, duração)`. Não mudam a escolha de alvo atual nem a ocultação da
   Caçadora.
7. **Ocultação própria.** `is_concealed` aceita uma fonte de ocultação vinda do kit, que não é
   um lugar. Valem as regras de revelação da Caçadora.
8. **Apresentação.**
   - A camada de efeitos aceita desenhadores registrados pelo módulo, em código. Quando
     existir um flipbook com o mesmo ID, ele é usado; senão, o desenho em código.
   - Evolução → `actor_kind` pelas pastas da seção 1. Sem a pasta de arte, o corpo usado é o
     da origem.
9. **Snapshot.** Cada módulo e cada sistema traz um fragmento de manifesto
   (`snapshot_manifest.json` na própria pasta), que o `SnapshotRegistry` agrega, com as mesmas
   regras de revisão e `omitted`. Regras para o estado de kit:
   - o estado no jogador sobrevive à suspensão e à retomada, nos formatos exato e compacto;
   - marcas em inimigos seguem a restauração do inimigo: o formato compacto devolve o inimigo
     à origem e sem marcas;
   - zona ativa ou entidade temporária torna o corte compacto inelegível (o save usa o formato
     exato), a menos que haja projeção contratada;
   - a pausa congela todos os relógios de kit.
10. **Evolução e equipamento.**
    - A origem pode ter mais de duas híbridas no ramo 2-3.
    - `IdentityIds` e `EquipmentEligibilityRules` incluem os quatro IDs, e `IdentityIds` ganha
      `acolyte` e `rogue` como reservados.
    - Perfis existentes continuam válidos. A versão do catálogo só sobe se o contrato de save
      exigir, e nesse caso o decoder anterior continua válido.
11. **Verificador.** `tools/verify.ps1` descobre `tests/classes/**/*_test.gd`,
    `tests/systems/**/*_test.gd` e `tests/e09/**/*_test.gd` num grupo próprio, e também os
    testes Python de `tools/art_pipeline/tests/`.
12. **Onboarding.** Se `res://scripts/ui/classes/<id>_onboarding.gd` existir, ele é
    carregado, pela mesma convenção do `geometer_onboarding`.
13. **Prova.**
    - Um kit de teste de fixture, fora do catálogo de produção, exercita cada gancho.
    - Suíte completa (`tools/verify.ps1` sem filtro `-Test`; `-SkipEditorImport` só quando a
      importação for feita à parte), porque T1 toca o código de todas as
      classes.
    - Nenhum teste existente muda de expectativa.

## 3. C2 — Santuário e Graça (tarefa T5)

Autoridade de família do Sacerdote, usada agora pelo Paladino e pelo Taumaturgo e depois pelo
Sacerdote, Inquisidor, Exorcista, Hierofante e Asceta. Pasta `scripts/systems/sanctuary/`.

- **Zona.**
  - Dono, forma e âncora. Formas:
    - círculo;
    - cone preso ao facing do dono;
    - círculo ampliado nas formas de pico.
  - Âncora: ponto do mundo ou presa ao dono.
  - Duração e modo de elemento: nenhum, fogo, gelo, raio ou tricolor.
  - Uma zona por dono e por papel.
  - Pertencer à zona usa a geometria do mundo e a mesma projeção do targeting; o desnível
    conta.
  - Sair da zona não a desfaz; só tira os bônus.
- **Regras de dentro, como dados:**
  - multiplicador de dano recebido do dono (só frontal no cone);
  - multiplicador de cura;
  - queimadura periódica nos inimigos, por `DamageRequest`;
  - efeitos por elemento: fogo pune, gelo dá DEF ao dono e lentidão aos inimigos, raio acelera
    o SP.
  - Nenhuma regra se aplica duas vezes no mesmo tick.
- **Graça.**
  - Cargas de 0 até o teto (5), com um modo sem limite para os picos. Ao fim do modo, volta ao
    teto.
  - `gain(evento, quantidade)` é deduplicado por evento pelo `EffectProcLedger`.
  - O gasto (total ou parcial) é atômico com o commit do cast.
  - Fonte própria do sistema: cura excedente, medida depois de aplicar.
  - Fontes trazidas pelo kit: golpe frontal mitigado, alternância de elemento, dano de luz no
    selado.
- **Ajudantes.**
  - Juízo: coluna vertical de luz cujo dano escala com as cargas, por `CombatMath` (sem
    fórmula duplicada).
  - Égide: escudo por `HealthState.grant_shield`, com um único pulso de empurrão ao quebrar ou
    expirar.
  - Selo: marca em `ActorMarks` mais `force_target`.
- **Dano de luz** é dano mágico com a etiqueta `light` na skill. Não há eixo de resistência
  novo, e nenhum inimigo resiste ou é fraco a luz neste épico. Exorcismo e mortos-vivos ficam
  fora.
- **Invariantes mínimas:**
  - a pausa congela duração e ticks;
  - o snapshot exato preserva a zona e as cargas;
  - o corte compacto com zona ativa é inelegível;
  - cura sem excedente não gera Graça;
  - nenhum evento gera Graça duas vezes;
  - trocar a build não recarrega a Graça.

## 4. C3 — costas, ocultação própria e Sentença (tarefa T6)

Autoridade de família do Assassino, decidida pelo usuário em 14/11 ("regra de costas"). Usada
agora pelo Duelista e pela Lâmina Arcana e depois pelo Assassino, Emboscador, Executor,
Sicário, Envenenador e Metamorfo felino. Pasta `scripts/systems/flank/`.

- **Lados.** A posição do atacante em relação ao facing de gameplay do alvo dá frente,
  flancos ou costas. Os ângulos de corte são definidos por Sol; a classificação usa o plano
  do chão. Um teste de matriz cobre os ângulos limite e alturas diferentes.
- **Girar.** Override temporário do facing do inimigo (API de T1), que expira no relógio de
  gameplay e congela na pausa.
- **Perder de vista.** Pela primitiva `break_sight` de T1.
- **Ocultação própria.**
  - Fonte de ocultação do kit, com duração.
  - Atacar revela.
  - O primeiro golpe saindo da ocultação é marcado no `DamageRequest`.
- **Vítima.** Uma por dono, visível através de obstáculos (flag de apresentação). Some quando
  a vítima morre ou quando outra é marcada.
- **Sentença.**
  - De 0 a 5 cargas na vítima, em `ActorMarks`.
  - Fontes: golpe pelas costas +2, primeiro golpe saindo da ocultação +2, combo do kit +2,
    outro golpe direto +1.
  - O kit escolhe quais eventos contam; o sistema deduplica por evento.
- **Execução.**
  - Gasta todas as cargas, e o dano escala com elas.
  - Com as cargas cheias e o HP do alvo abaixo do limiar da categoria (normal, raro, elite,
    raro-elite), é morte certa.
  - No chefe, não há morte certa: é só dano alto.
  - A morte passa por `DamageRequest` marcado como execução, nunca por escrita direta de HP,
    e respeita claims, callbacks de morte e o ledger.
  - Abate confirmado chama o kit uma única vez, para devolver a ocultação ou o SP.
- **Invariantes mínimas:**
  - matriz de lados;
  - giro expira e congela na pausa;
  - limiar por categoria;
  - nenhuma execução em chefe;
  - callback de abate único, inclusive em retry;
  - snapshot exato preserva vítima e cargas.

## 5. C4 — requisitos comuns dos kits (tarefas K1–K4)

1. Antes do código, contrato curto em `docs/epics/e09/<tarefa>_contract.md`, com os números e
   as respostas às cinco perguntas, a partir da ficha. Sem mudar o núcleo da ficha. Mudança de
   núcleo volta ao usuário pela sessão de arquitetura.
2. O kit funciona sozinho contra um chefe sem adds, sem augment, e tem duas builds legais
   nomeadas, com os 19 pontos de base e os 20 de evolução.
3. As interações com a base de origem citadas na ficha estão cobertas.
4. Efeitos em código, pelo desenhador do módulo. Cada efeito tem um ID de flipbook reservado
   (`<prefixo><efeito>`) e listado no recibo, para a arte pintada substituir depois.
5. Textos pt-BR de nome, descrição e tooltip por rank.
6. Testes em `tests/classes/<id>/`, com invariantes das regras novas e um combate integrado
   curto. `ready_for_play = true` só depois que esses testes passam.
7. A tarefa não edita arquivo de outra pasta. Se faltar API, Sol de T1, T5 ou T6 a acrescenta
   na própria tarefa, ou a necessidade volta à sessão de arquitetura.

Especificidades:
- **K1 Paladino.**
  - O Juramento usa a zona em cone de C2.
  - Golpe frontal mitigado e cura excedente geram Graça.
  - O Impacto Consagrado gasta a Graça.
  - A Égide e o Selo usam os ajudantes de C2.
  - Na Hora do Juramento, o cone vira um círculo completo, a Graça não tem limite e o Impacto
    não custa SP.
  - Parede de Escudos e Perseverança enchem a Graça; Provocar soma ao Selo.
- **K2 Taumaturgo.**
  - No Círculo Votivo, o primeiro feitiço lançado dentro define o elemento.
  - Alternar o elemento dentro do círculo gera Graça.
  - Mudança de Altar solta um pulso do elemento antigo.
  - O Coro deixa o círculo tricolor.
  - O Juízo Prismático cai em três pulsos.
  - A Aurora amplia o círculo, a Graça fica sem limite e os feitiços custam metade do SP.
  - Os feitiços de fogo, gelo e raio da base alimentam a alternância.
- **K3 Duelista.**
  - O Aparo tem uma janela de tempo sobre o golpe corpo a corpo de frente (decisão de
    14/11). Projétil e área não são aparados.
  - Aparo bem-sucedido gira o atacante e faz ele perder o Duelista de vista.
  - Fontes de Sentença conforme a Leitura do Oponente.
  - Riposte Fatal é a execução de C3; se matar, o próximo Aparo é automático.
  - Finta, Guarda Paciente, Recuo em Guarda e Duelo conforme a ficha.
- **K4 Lâmina Arcana.**
  - Marca Refratada é a vítima de C3.
  - Lâmina Encantada troca o ataque básico por um golpe corpo a corpo de cristal, que alterna
    fogo, gelo e raio. Os três na vítima dão +2 e uma reação. É efeito, não arma (decisão de
    14/11).
  - Refração é ocultação própria.
  - Salto Prismático só funciona oculto: teleporte às costas validado pela geometria do mundo,
    que conta como golpe pelas costas.
  - Fratura de Luz: abate devolve a Refração e SP.
  - Sentença Prismática é a execução de C3.
  - Espectro de Prisma cria três reflexos temporários, cada um saltando numa vítima diferente.
  - Teleporte da base é a saída.

## 6. C5 — pipeline de arte neutro (tarefa T2)

O pipeline independe do gerador. Codex, ComfyUI local, Hugging Face, fal, uma página web ou um
desenho à mão entram pelo mesmo contrato. Ferramentas em `tools/art_pipeline/`, guia em
`docs/art/pipeline.md`.

- **Folha-fonte `ragrpg_source_sheet_v1`.** Tipos:
  - `character_view` e `creature_view`: grade 4×4. Linha 1 parado (4), linha 2 andando (4),
    linha 3 ação (4), linha 4 dano (2) e morte (2). Uma direção por folha: `south`, `east`,
    `west`, `north`;
  - `equipment_row`: N objetos numa fileira, separados;
  - `vfx_source`: grade 4×4;
  - `icon_source`: quadrado com lado ≥ 128.
  - O fundo pode ser alfa real ou cor chapada declarada (por exemplo `#FF00FF` ou `#00FF00`).
    A remoção é feita pela ferramenta, com os parâmetros registrados. O tamanho é livre; o
    empacotador recorta.
- **Validador.**
  - PNG RGBA (depois da remoção do fundo).
  - Faixas transparentes que separam as células, com a contagem certa e nenhuma vazia.
  - Nada encostado na borda da célula.
  - Objetos de equipamento sem se tocar.
  - Altura do corpo parado em cada vista em relação à vista de referência, com tolerância
    definida pelo guia. As diferenças de até 30% vistas na 1120 precisam ser apontadas.
  - Saída em JSON com o motivo de cada falha.
- **Normalizador.** Iguala a altura das vistas à de referência, sem filtro de suavização na
  pixel art, e registra o passo.
- **Proveniência `ragrpg_art_provenance_v2`.** Um registro por arquivo, com:
  - `path`, `sha256`, `width`, `height` e `kind`;
  - `generator` {`name`, `model`, `host` local/nuvem, `version`};
  - `request` e o `prompt` exato, mais o prompt negativo, a seed e os parâmetros quando
    existirem;
  - `refs` [{`path`, `sha256`}];
  - `post` [{`tool`, `version`, `params`, `input_sha256`, `output_sha256`}];
  - `selected` e `review` {`status`, `date`, `notes`};
  - nota de termos de uso.
  - Um leitor aceita os registros v1 das rodadas Codex 1114–1123, inclusive a 1116, que não
    tinha `selected`, sem reescrever os originais.
- **Seleção.** `selection.json` por lote ou classe aponta a versão escolhida de cada vista ou
  folha, por SHA256. O empacotador só lê a seleção.
- **Arquivo.** A ferramenta copia um lote de staging para o arquivo durável fora do Git e
  confere os hashes. Ela escreve um índice versionado com caminho, SHA256, tamanho, seleção e
  local arquivado. Nunca apaga a origem e recusa sobrescrever bytes diferentes.
- **Registro de geração.** `record_generation.py` é a CLI que qualquer script gerador chama
  para acrescentar um registro v2. Os scripts em `D:\ComfyUI\ragrpg\` são arquivos do usuário
  e não são editados; o guia mostra como chamá-la.
- **Substituição por ID.** Um ícone pintado em `assets/art/skills/painted/<skill_id>.png`
  substitui o SVG, e um flipbook em `assets/art/e08_vfx/<id>/flipbook.json` substitui o efeito
  em código. Nenhum consumidor muda.
- **Fila de geração.** `docs/art/generation_queue.md`: 1124 (Tempestário e Magister),
  conjuntos de classe das quatro híbridas (elmo e ícones), ícones pintados das 28 skills,
  efeitos pintados reservados pelos kits, trajes das híbridas restantes, variantes de
  criatura. Nenhuma tarefa do E09 espera por ela.

## 7. C6 — arte do épico (tarefas T4 e T7)

Fonte: staging em
`C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5/assets/art/`.
Versionar só as versões marcadas `selected` (decisão de 16/11), no mesmo caminho relativo,
com a `provenance.json` completa. As entradas não escolhidas continuam listadas e apontam para
o arquivo. ~23,6 MB.

| Pasta | Arquivos escolhidos |
|---|---|
| `e08_codex_1123/characters/sp_ac/` | `south.png`, `east_v2.png`, `west.png`, `north_v3.png` |
| `e08_codex_1123/characters/mg_ac/` | `south.png`, `east.png`, `west_v2.png`, `north.png` |
| `e08_codex_1123/characters/sp_la/` | `south.png`, `east.png`, `west.png`, `north_v2.png` |
| `e08_codex_1123/characters/mg_la/` | `south.png`, `east_v3.png`, `west_v4.png`, `north_v2.png` |
| `e08_codex_1120/equipment/` | `weapons_h1_v2.png`, `weapons_h2.png` |
| `e08_codex_1123/equipment/` | `weapons_e1_v3.png` |

T4 confere cada SHA256 completo contra a `provenance.json` antes de copiar. Arte-fonte entra
sem `.import`, pela regra do `db7f9252`. Todos os lotes 1119–1123 e `e08_nb_1124` vão para o
arquivo `C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/art_archive/e08/`, com o índice
versionado em `docs/art/archive/e08_staging_1119_1124.json`. A origem em staging não é
apagada.

T7 deriva os atlas V2 das quatro classes em
`assets/art/e08_characters/directional/<pasta>/`, no padrão das classes atuais:
- `body.png` e `weaponless.png`;
- `bare_head.png` se o elmo pedir;
- `calibration.json` e `presentation.json`;
- `provenance.json`, `recipe.md`, `source_recipe.json` e `delivery.md`.

Também cria as entradas de encaixe da cabeça. A calibração de mãos e dedos é conferida com
espada, escudo e cajado nas quatro vistas, por captura nativa.

## 8. C7 — armas novas como itens (tarefa T8)

Decisão de 16/11: itens normais das categorias existentes, no loot atual e nas faixas de poder
atuais, sem conjunto. Ícone recortado da própria arte.

| ID de arte | Folha e posição | Categoria | Usada por |
|---|---|---|---|
| `halo_shield` | H1 v2, objeto 5 | escudo | Paladino |
| `buckler` | H1 v2, objeto 4 | escudo | Duelista |
| `rapier` | E1 v3, objeto 1 | espada | Duelista |
| `prism_staff` | H2, objeto 1 | cajado | Taumaturgo |

IDs de definição e nomes pt-BR seguem a convenção de equipamentos
(`$ragrpg-equipmentdelivery`) e ficam no recibo. A elegibilidade segue a categoria, então as
classes atuais também podem usar os itens. A Lâmina Arcana usa o cajado da origem.

## 9. C8 — integração e candidato (tarefas T10 e T11)

- **Composição.** Branch `claude/e09-candidato`, a partir do commit de arquitetura. Merge na
  ordem do DAG, resolvendo só conflitos mecânicos. Conflito de conteúdo volta à tarefa dona.
- **Verificação.**
  - Suíte completa de `tools/verify.ps1` (sem `-Test`, com `editor_import` em worktree limpo).
    O executável é `C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/godot/Godot_v4.7.2-stable_win64_console.exe`,
    passado em `-GodotPath` ([TESTING](../TESTING.md)).
  - Supervisão Luna (T11): conclusão, ausência de SCRIPT ERROR, timeouts e hashes dos logs.
- **Release.**
  - Exportação com as ferramentas de release vigentes para
    `C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/playtest_e09/<sha>/`.
  - Sondas no PCK exato: os quatro corpos, os 28 ícones, os quatro itens e as entradas de
    efeito.
  - Perfis de revisão de T9, atalhos e smoke, como no E08.
- **Medição.** Sonda de multidão contra `db7f9252`, registrada sem alegar FPS.
- **Roteiro de playtest** em `docs/epics/e09/playtest_guide.md`.
- **Playtest habitual.** Depois da aprovação técnica, avanço do playtest habitual pelo
  procedimento do WORKFLOW, preservando alterações locais e o save pessoal. Sem `master`, sem
  push.

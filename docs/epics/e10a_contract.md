# E10a — contrato de arquitetura

Índice, decisões e tarefas: [e10a.md](e10a.md). Fonte do design:
[EXTENDED_CLASS_SPECS.md](../EXTENDED_CLASS_SPECS.md), §"Família Acólito", e as decisões do
usuário de 14/11 registradas ali. Precedência: [WORKFLOW](../WORKFLOW.md) para o fluxo; este
contrato para o E10a; o [contrato do E09](e09_contract.md) nas regras de costura, Santuário,
arte e integração que este não substitui; E00 e as autoridades de
[ARCHITECTURE](../ARCHITECTURE.md) nos demais pontos.

Números (raios, durações, multiplicadores, limiares, custos) não estão aqui, salvo os limites
decididos pelo usuário. Cada tarefa de sistema ou de módulo fecha os seus num contrato curto
(`docs/epics/e10a/<tarefa>_contract.md`) antes de implementar, a partir da ficha. São ajuste de
playtest e não exigem nova decisão de arquitetura. Mudança no núcleo da ficha volta ao usuário
pela sessão de arquitetura.

## 1. Identidades e IDs

| Identidade | ID | Papel | Origem | Ramo | Pasta de corpo | Prefixo das skills |
|---|---|---|---|---|---|---|
| Acólito | `acolyte` | base | — | — | `acolyte` | `acolyte_` |
| Sacerdote | `priest` | pura | `acolyte` | 2-1 | `priest` | `priest_` |
| Cultista | `cultist` | pura | `acolyte` | 2-2 | `cultist` | `cultist_` |

`acolyte` deixa de ser base reservada: `IdentityIds.reserved_base_ids()` passa a ter só `rogue`.
O rótulo de afinidade de `sp_ac` e `mg_ac` continua `acolyte` e mostra o mesmo texto.

**Biblioteca da base** (ID estável; nome pt-BR provisório, da ficha):

| ID | Nome | Tipo | Função |
|---|---|---|---|
| `acolyte_punishing_light` | Luz Punitiva | ativa, inicial | Projétil de luz em linha que fere o primeiro inimigo |
| `acolyte_prayer` | Prece | ativa, inicial | Cura o próprio Acólito ao longo de alguns segundos |
| `acolyte_votive_shield` | Escudo Votivo | ativa | Barreira curta que absorve dano |
| `acolyte_shadow_seal` | Selo Sombrio | ativa | Marca: DoT de sombra, menos precisão e Loucura |
| `acolyte_disturbing_whisper` | Sussurro Perturbador | ativa | Cone curto: Loucura e afasta os comuns por um instante |
| `acolyte_eldritch_vision` | Visão Eldritch | ativa | Reforço curto: mais alcance, e o próximo Selo ou Sussurro dá o dobro de Loucura |
| `acolyte_devotion` | Devoção | passiva | Skill de luz seguida de uma de sombra (ou o contrário) fortalece a seguinte |
| `acolyte_protective_faith` | Fé Protetora | passiva | Cura e escudo recebidos rendem mais |

Pré-requisitos propostos (fechados pela T5 nos dados do módulo): Escudo Votivo pede Prece;
Selo Sombrio pede Luz Punitiva; Sussurro pede Selo Sombrio; Visão Eldritch pede Sussurro;
Devoção pede Luz Punitiva e Selo Sombrio; Fé Protetora pede Escudo Votivo.

**Skills das puras** (níveis de job 20 entrada, 23, 25, 28, 31, 34, 37):

| Job | Sacerdote | Cultista |
|---|---|---|
| 20 ativa, entrada | `priest_sanctuary` Santuário | `cultist_abyss_gaze` Olhar do Abismo |
| 23 passiva | `priest_grace` Graça | `cultist_ecstasy` Êxtase |
| 25 ativa | `priest_aegis` Égide | `cultist_impossible_idol` Ídolo Impossível |
| 28 ativa | `priest_judgment` Juízo | `cultist_shared_delirium` Delírio Compartilhado |
| 31 passiva | `priest_exorcist` Exorcista | `cultist_open_pupil` Pupila Aberta |
| 34 ativa | `priest_light_seal` Selo de Luz | `cultist_impossible_geometry` Geometria Impossível |
| 37 ativa | `priest_holy_hour` Hora Santa | `cultist_revelation` Revelação |

As regras de aprendizado são as vigentes ([MVP](../MVP.md)): entrada grátis no job 20; ranks
1–5 nas ativas e 1–3 nas passivas; 19 pontos de base e 20 de evolução; 24 atalhos; passivas
legais automáticas. A biblioteca da origem continua disponível depois da evolução.

**Elementos.** `shadow` entra nos elementos aceitos de skill, ao lado de `light`. Os dois são
dano mágico com a etiqueta, sem eixo de resistência; nenhum inimigo resiste ou é fraco a eles
(A2 do E09).

## 2. C1 — costura de base e primitivas de alvo (tarefa T1)

**Regra.** A T1 é a única tarefa do E10a que edita os arquivos compartilhados (C1.10). As três
bases atuais e as 14 identidades atuais não mudam de comportamento. Assinaturas a cargo de Sol,
publicadas em `docs/epics/e10a/t1_base_seam_api.md`.

1. **Registro de bases.** `scripts/classes/class_base_registry.gd` lista `acolyte` →
   `scripts/classes/bases/acolyte/acolyte_base.gd`. A T1 entrega o módulo como esqueleto vazio,
   e só a T5 o edita. As três bases atuais continuam fora do registro.
2. **Dados do módulo de base.** O módulo fornece:
   - nome pt-BR e atributos iniciais (D2, soma 30);
   - ataque básico: tipo (`magic`, `precision` ou `direct`), alcance e poder. O tipo deixa de
     depender de `is_mage()`/`is_archer()` para as bases registradas;
   - definições e ranks das skills da biblioteca, com carteira de base, pré-requisitos e as
     skills iniciais;
   - efeitos de build, receitas de feedback, textos pt-BR e desenhadores de efeito, como um
     kit;
   - pasta de corpo e o corpo de reserva, usado enquanto não houver arte (o do Mago).
   `IdentityIds`, `ClassCatalog`, `ProfileCatalog`, `SkillDependencyRules`, `BuildEffectCatalog`,
   `FeedbackRecipeCatalog` e `SkillCopy` agregam esses dados, como fazem com os kits. Preview e
   execução usam a mesma composição.
3. **Disponibilidade.** O módulo declara `ready_for_play`. Enquanto for falso, a base não
   aparece na criação (`base_class_is_available` falso) e suas evoluções não são oferecidas.
   Perfis de fixture podem forçá-la para teste.
4. **Dois módulos por jogador.** Um objeto de origem quando a base é registrada, ativo antes e
   depois da evolução, e o objeto de kit da evolução. Os ganchos de `ClassKit` (C1.4 do E09,
   T1.1, T1.2 e os do E12 quando compostos) valem para os dois, nesta composição:
   - ganchos de evento (tick, casts, golpe recebido, cura, dano, abate, morte, retorno, troca de
     build): origem primeiro, depois evolução;
   - `can_cast`: recusa se qualquer um recusar, com o código do primeiro;
   - `resolve_cast`: só o módulo dono da skill;
   - `skill_cost`: encadeado, origem e depois evolução, com piso 0;
   - perfil e composição do ataque básico: a evolução substitui a origem quando declara;
   - `before_hit_mitigation`: `cancel` se qualquer um cancelar; `damage_multiplier`
     multiplicado;
   - `temporary_stat_sources`: concatenadas;
   - `on_base_skill_committed`: a evolução recebe os commits pagos das skills da origem
     (inclusive as do módulo de base);
   - bloqueio do corte compacto: qualquer um bloqueia.
5. **Kits puros.** `ClassKitRegistry` ganha `priest` e `cultist` com a origem `acolyte` e o ramo
   (2-1, 2-2; as híbridas do E09 continuam 2-3). `IdentityIds.evolution_origin` e o registro de
   evoluções do `ProfileCatalog` leem a origem e o ramo do registro, sem `match` fixo para os
   IDs novos. A T1 entrega `scripts/classes/{priest,cultist}/<id>_kit.gd` como esqueletos.
6. **Alvo inimigo (A3).**
   - `EnemyActor` passa a ter um alvo de combate, que por padrão é o jogador. Uma sobrescrita
     temporária aponta para outro `CombatActor` vivo (inimigo ou Ídolo), com dono, prazo e
     motivo. Ela expira no relógio de gameplay, congela na pausa e cai quando o alvo morre ou
     sai do mundo. Vale nos dois caminhos (mapa plano e mundo da expedição): perseguição,
     alcance e ataque.
   - Chefe recusa a sobrescrita, com código de erro.
   - **Desvio no commit.** Um provedor registrado pode trocar o alvo de um golpe inimigo no
     instante do commit por outro inimigo ao alcance, com sorteio pelo RNG do inimigo. É o que
     faz o chefe acertar os lacaios. O provedor não cria golpe novo.
   - **Dano entre inimigos.** Passa por `DamageRequest`, com a autoria do jogador dono do efeito
     para claims, `EffectProcLedger`, callbacks de morte, XP e loot. A ameaça do alvo não
     muda por esse dano.
   - **Isca.** Primitiva para criar e remover um ator temporário com HP, sem IA, que os
     inimigos podem mirar e o jogador não. Tem dono, ponto, HP, prazo e um desenhador
     registrado pelo sistema. Presença de isca torna o corte compacto inelegível.
7. **Modificadores no inimigo.** Fontes genéricas em `CombatActor`, compostas uma única vez em
   `CombatMath`, sem fórmula duplicada:
   - multiplicador de dano recebido, com filtro opcional de dono e de etiqueta de elemento;
   - redução de acerto (precisão) dos ataques do próprio ator.
   Movimento na direção errada: primitiva curta de desorientação de movimento para não-chefes,
   no padrão do medo; o chefe a recusa. Raiz e lentidão já existem (`apply_root`,
   `apply_slow`).
8. **Elementos e apresentação.**
   - `shadow` entra em `ClassKitRegistry.KIT_ELEMENTS` e nos elementos aceitos de skill de base.
   - `light` e `shadow` ganham cor e efeito próprios na camada de feedback e nas receitas, sem
     mudar o desenho dos outros elementos. O Paladino e o Taumaturgo passam a usar a cor de
     `light`.
   - Áudio: sem deixa nova. A lista exata de lacunas família × elemento vai para o recibo e para
     o teste de receitas (regra da nota de Sol de 17/11 no contrato do E09).
   - Base e evolução → `actor_kind` pela pasta de corpo; sem arte, o corpo de reserva.
9. **Snapshot.** O módulo de base traz um fragmento de manifesto, como os kits. Regras de A4.
10. **Arquivos compartilhados da T1.** `scripts/core/{identity_ids,profile_catalog,character_progression,character_state,run_state,build_effect_catalog,build_presentation,equipment_eligibility_rules,content_authoring,item_skill_adapters,mob_catalog,skill_dependency_rules,combat_math,actor_marks}.gd`,
    `scripts/data/{class_catalog,class_definition,skill_definition,equipment_definition}.gd`,
    `scripts/actors/{player_actor,combat_actor,enemy_actor,character_animation,equipment_hand_rig}.gd`,
    `scripts/main.gd`, `scripts/core/expedition/combat/threat_service.gd`,
    `scripts/core/expedition/campaign/expedition_campaign_runtime.gd`,
    `scripts/core/expedition/snapshot/{runtime_manifest.json,snapshot_registry.gd}`,
    `scripts/presentation/{feedback_recipe_catalog,feedback_vfx_layer,directional_animation_set,audio_event_catalog,world_projectile_art}.gd`,
    `scripts/ui/{skill_copy,skill_presentation,run_inventory_panel}.gd`,
    `scripts/map_authoring/preview/gameplay_tools.gd`,
    `scripts/map_authoring/patrol/patrol_preview.gd`,
    `scripts/diagnostics/e01_profile_diagnostic.gd`. Outro arquivo compartilhado que a T1
    precise tocar vai ao recibo com o motivo; se pertencer a outra tarefa do E10a, a T1 pede a
    transferência à arquitetura.
11. **Testes legados.** Um teste que enumera ou conta bases, identidades ou elementos e cresce
    por este contrato é atualizado pela T1, só nesses checks, com a lista ou a contagem exata
    nova (nunca `>=`), e cada ajuste vai ao recibo (regra A15 do E09). As listas de destinos de
    evolução e de bases oferecidas na criação ficam com a T10, que parte da ponta da T1.
12. **Verificador.** `tools/verify.ps1` descobre `tests/e10a/**/*_test.gd` e as pastas novas de
    `tests/classes/**` e `tests/systems/**`.
13. **Prova.**
    - Um módulo de base de fixture e um kit puro de fixture, fora do catálogo de produção,
      exercitam cada gancho, a composição de C1.4 e as primitivas de C1.6 e C1.7.
    - `tests/e10a/base_seam_test.gd` e `tests/e10a/enemy_target_test.gd`, com o redirecionamento
      testado nos dois caminhos, a recusa do chefe, o desvio no commit, a isca e o abate entre
      inimigos creditado uma única vez, inclusive em retry.
    - Suíte completa (`tools/verify.ps1` sem `-Test`), porque a T1 toca o código de todas as
      classes. Nenhuma expectativa muda fora de C1.11.

## 3. C2 — Loucura, Êxtase e Ídolo (tarefa T4)

Autoridade de família do Cultista (D4), usada agora pela base Acólito e pelo Cultista e depois
pelo Flagelante, Oráculo, Observador, Arauto da Peste, Aberração, Lunático e Abissal
([HYBRIDS_56_V3.md](../HYBRIDS_56_V3.md)). Pasta `scripts/systems/madness/`.

- **Loucura.**
  - Valor por inimigo, de 0 até o limiar, em `ActorMarks`, com dono. Decai depois de um tempo
    sem ganho.
  - `add(enemy, amount, event_id, owner)` é deduplicado por evento pelo `EffectProcLedger`.
  - No limiar: comum, raro, elite ou raro-elite entra em **Delírio**; o chefe entra em
    **Desorientação**. A Loucura volta a 0.
- **Delírio.**
  - Por alguns segundos, o inimigo ataca o inimigo não-chefe mais próximo, com o próprio
    ataque, pela sobrescrita de alvo de C1.6. Escolhe outro alvo se o atual morrer. Sem alvo,
    fica parado e não ataca o jogador.
  - **No máximo 3 delirantes por dono ao mesmo tempo** (D4). Com o teto cheio, a Loucura fica
    no limiar até abrir uma vaga.
  - Delirantes nunca miram o chefe. Abate por Delírio é do dono (C1.6) e não gera Loucura.
- **Desorientação (chefe).**
  - Por alguns segundos, o chefe erra mais e recebe mais dano (C1.7). Ele nunca troca de alvo.
  - Na janela, cada golpe do chefe tem uma chance de cair num lacaio ao lado dele, pelo desvio
    no commit (C1.6). Sem lacaio ao alcance, o golpe segue normal.
  - Depois, imunidade à Loucura por um tempo.
- **Êxtase** (estado do jogador, por dono).
  - Cargas de 0 a 5. Cada inimigo que entra em Delírio ou Desorientação dá uma, deduplicada por
    evento.
  - Cada carga dá mais MATK e menos custo de SP, pelos ajudantes do sistema para
    `temporary_stat_sources` e `skill_cost`.
  - **A partir de 3 cargas**, o dono recebe mais dano, por `before_hit_mitigation`
    (`damage_multiplier`).
  - Cai uma carga por intervalo sem ganho. Trocar a build não recarrega nem zera.
- **Ídolo.** Isca de C1.6, **uma por dono**, com prazo e HP proporcional ao HP máximo do dono.
  Comuns e elites ao alcance o miram (o Delírio tem prioridade). Todos os inimigos ao alcance
  do olhar, inclusive o chefe, ganham Loucura por tick; o chefe não troca de alvo. O Ídolo não
  ataca nem cura. Desenho em código, com ID de flipbook reservado.
- **Contágio.** Uma marca de contágio num inimigo copia uma fração da Loucura que ele recebe
  para os vizinhos; a cópia não é copiada de novo. Se o marcado entra em Delírio, os vizinhos
  recebem um pulso único. Um salto por evento (D4).
- **Limites de controle** (reserva do E10: "invocações e CC com limites"): Ídolo 1; Delírio 3;
  chefe sem troca de alvo, sem Delírio e sem desorientação de movimento; imunidade depois da
  Desorientação; nenhuma propagação recursiva.
- **Leitura para o HUD.** `describe()` puro com Loucura e estado por inimigo, Êxtase, Ídolo
  (HP e prazo) e contágio, para a T12.
- **Invariantes mínimas:**
  - a pausa congela Loucura, Delírio, Desorientação, imunidade, Êxtase e Ídolo;
  - teto de 3 delirantes;
  - chefe nunca em Delírio e nunca redirecionado;
  - imunidade depois da Desorientação;
  - nenhum evento dá Loucura ou Êxtase duas vezes;
  - contágio de um salto;
  - abate por Delírio creditado uma vez, inclusive em retry;
  - snapshot exato preserva Êxtase e Ídolo; o compacto preserva o Êxtase e é inelegível com
    Ídolo ativo; a Loucura segue a restauração do inimigo.

## 4. C3 — requisitos comuns dos módulos (tarefas T5, T6 e T7)

1. Antes do código, contrato curto em `docs/epics/e10a/<tarefa>_contract.md`, com os números e
   as respostas às cinco perguntas, a partir da ficha, sem mudar o núcleo.
2. O módulo funciona sozinho contra um chefe sem adds, sem augment. Cada pura tem as duas
   builds nomeadas de D6, legais, com os 19 pontos de base e os 20 de evolução, em
   `scripts/classes/<id>/review_builds.json` (esquema `ragrpg_review_builds_v1`, A11 do E09).
3. As interações com a base citadas na ficha estão cobertas.
4. Efeitos em código pelo desenhador do módulo, cada um com ID de flipbook reservado
   (`<prefixo><efeito>`) e listado no recibo.
5. Textos pt-BR de nome, descrição e tooltip por rank.
6. Testes em `tests/classes/<id>/`, com invariantes das regras novas e um combate integrado
   curto. `ready_for_play = true` só depois que esses testes passam.
7. A tarefa não edita arquivo de outra pasta. Faltou API? Sol da T1 ou da T4 a acrescenta na
   própria tarefa, ou a necessidade volta à sessão de arquitetura.

### 4.1 T5 — base Acólito

- Atributos, ataque básico (mágico, alcance ~220, com o livro) e skills iniciais de D2:
  Luz Punitiva e Prece. Passiva de partida: Fé Protetora.
- Luz Punitiva tem etiqueta `light`; Selo Sombrio e Sussurro, `shadow`.
- O Selo Sombrio reduz a precisão (C1.7) e dá Loucura; o Sussurro dá Loucura e afasta os
  comuns, sem afastar o chefe. A Loucura vem da autoridade da T4: o Delírio pode acontecer na
  base, só mais devagar.
- A Devoção lê a alternância luz ↔ sombra pelos elementos das skills, sem lista fixa.
- Combate integrado nos jobs 1 a 19 contra o Mestre das Feras do roteiro do E06.

### 4.2 T6 — Sacerdote

Sobre o Santuário e a Graça do E09 (C2 do E09, API da T5 do E09), sem mudar `scripts/systems/sanctuary/`.
- O Santuário é o círculo ancorado no ponto escolhido, um por dono. Dentro: menos dano
  recebido, cura que rende mais e queimadura nos inimigos.
- Graça liga as cargas; a cura excedente é a fonte do sistema. Entrar no Santuário com a Graça
  cheia dá um pulso de cura.
- Égide e Juízo pelos ajudantes do sistema. Dentro do Santuário, o Juízo atinge todos os
  inimigos no círculo.
- **Exorcista (D3):** a luz remove um buff ou escudo do inimigo atingido, onde houver; sem o que
  remover, deixa-o Exposto (mais dano de luz do dono por alguns segundos, por C1.7). O bônus
  contra mortos-vivos e fantasmas fica registrado e sem efeito.
- **Selo de Luz (D3):** imobiliza (raiz) e marca; no chefe, lentidão. Dano de luz no marcado dá
  Graça.
- **Hora Santa:** o Santuário cresce e fica dourado; a cura dobra, a Graça fica sem limite e o
  Juízo não custa SP.
- Da base: Prece e Escudo Votivo alimentam a Graça; Luz Punitiva é o dano fora do Santuário.

### 4.3 T7 — Cultista

Sobre a autoridade da T4.
- O Olhar do Abismo é uma canalização em cone, com dano mágico contínuo e Loucura.
- Êxtase liga as cargas e o ônus da T4.
- Ídolo, contágio (Delírio Compartilhado) e Desorientação pelos ajudantes da T4.
- **Pupila Aberta:** inimigos em Delírio ou Desorientação recebem mais dano do Cultista (C1.7,
  filtro de dono).
- **Geometria Impossível:** desorientação de movimento nos comuns; lentidão no chefe.
- **Revelação:** por alguns segundos, Loucura rápida em todos os inimigos à vista; delirantes
  causam mais dano entre si; o chefe entra numa Desorientação forte, que vale uma vez por
  Revelação mesmo sob imunidade e é seguida da imunidade mais longa.
- Da base: Sussurro e Selo Sombrio somam Loucura; Escudo Votivo e Prece compensam o Êxtase.
- Combate integrado também contra o Guardião Antigo da fase da floresta, que invoca companheiro,
  para provar o golpe nos lacaios.

## 5. C4 — arte (tarefas T2 e T8)

### 5.1 T2 — arquivo e versionamento

Fonte: staging em
`C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5/assets/art/`. Versionar só os
13 arquivos escolhidos (D8), no mesmo caminho relativo, com a `provenance.json` completa:

| Pasta | Arquivos escolhidos |
|---|---|
| `e08_codex_1116/characters/acolyte/` | `south_v5.png`, `east_v3.png`, `west_v3.png`, `north.png` |
| `e08_codex_1118/characters/priest/` | `south.png`, `east.png`, `west_v2.png`, `north.png` |
| `e08_codex_1118/characters/cultist/` | `south.png`, `east.png`, `west.png`, `north.png` |
| `e08_codex_1118/equipment/` | `weapons_b1.png` (objetos 1 a 3) |

- O lote 1116 não tem `selected`. A escolha do Acólito é a desta tabela (D8, com a tabela
  "Entrega — 14/11/2026" de [e08_codex_art_1116_brief.md](e08_codex_art_1116_brief.md)) e vai
  na seleção (`selection.json`) e no recibo, sem reescrever o registro v1 original (leitor v1 da
  T2 do E09).
- SHA256 completo conferido contra a `provenance.json` antes de copiar. Arte-fonte entra sem
  `.import` (regra do `db7f9252`).
- Os lotes 1116 e 1118 inteiros vão para
  `C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/art_archive/e08/`, pela ferramenta de
  arquivo do pipeline, com índice versionado em `docs/art/archive/e08_staging_1116_1118.json`.
  A staging não é apagada.

### 5.2 T8 — corpos

Atlas V2 das três classes em `assets/art/e08_characters/directional/<pasta>/`, no padrão das
classes atuais (C6 do E09): `body.png`, `weaponless.png`, `bare_head.png` se o elmo pedir,
`calibration.json`, `presentation.json`, `provenance.json`, `recipe.md`, `source_recipe.json` e
`delivery.md`. Validação e normalização de escala pelo pipeline neutro
([pipeline.md](../art/pipeline.md)). Entradas de encaixe da cabeça. Calibração de mãos
conferida com livro, cetro e relicário nas quatro vistas, por captura nativa.

## 6. C5 — ícones SVG (tarefa T3)

Os 22 IDs de §1, no estilo dos SVG atuais de `assets/art/skills/`. Luz em marfim e dourado,
sombra e olho em preto-azulado, magenta e turquesa ([CLASS_IDENTITY_REVIEW.md](../CLASS_IDENTITY_REVIEW.md)).
Base com o símbolo "que ainda não escolheu lado". Manifesto com SHA256; `--check` cobre os 28
do E09 e os 22 novos por lista de IDs. Um PNG pintado em `assets/art/skills/painted/<id>.png`
substitui o SVG depois, sem mudar consumidor.

## 7. C6 — itens (tarefa T9)

| ID de arte | Folha e posição | Encaixe | Origem | Uso |
|---|---|---|---|---|
| `prayer_book` | B1, objeto 1 | `main_hand` | `acolyte` | item inicial do Acólito |
| `halo_scepter` | B1, objeto 2 | `main_hand` | `acolyte` | típico do Sacerdote |
| `eye_reliquary` | B1, objeto 3 | `main_hand` | `acolyte` | típico do Cultista |

- Itens normais no loot atual e nas faixas de poder atuais, sem conjunto; ícone recortado da
  arte. IDs de definição e nomes pt-BR pela convenção de equipamentos
  (`$ragrpg-equipmentdelivery`), registrados no recibo.
- **Armaduras (D9):** as peças de tecido de origem `mage` e as 6 gerais acrescentam `acolyte` a
  `allowed_origins` e as três identidades a `allowed_identities` quando a lista existir. Nenhuma
  outra propriedade muda.
- `equipment_attachment_visual.gd`: só as três chaves novas em `SUPPORTED` e `PROFILES`.

## 8. C7 — criação, evolução, onboarding e perfis (tarefa T10)

- A criação lista o Acólito quando o módulo está pronto (C1.3), com descrição pt-BR.
- A escolha de evolução do Acólito mostra Sacerdote e Cultista.
- Onboarding em `scripts/ui/classes/<id>_onboarding.gd` para `acolyte`, `priest` e `cultist`,
  pela convenção do E09.
- `tools/e10a_review_profiles.gd`: um perfil isolado por build, no job 40 (A18 do E09). Base
  sem `review_builds.json` ou sem `ready_for_play` aparece como pendente, sem erro.
- Listas de destinos e de bases em `tests/e05_evolution_catalog_test.gd` e
  `tests/e09/kit_seam_test.gd`: as atuais mais as identidades do E10a prontas (A9 do E09).

## 9. C8 — augments (tarefa T11)

Seis augments pelo `$ragrpg-augmentdelivery`, no padrão atual:
`pilot_acolyte_pressure`, `pilot_acolyte_reserve`, `pilot_priest_a`, `pilot_priest_b`,
`pilot_cultist_a` e `pilot_cultist_b`. Elegibilidade pela identidade. Receitas sobre handlers
que já existem. Se um augment precisar de handler novo ou de gancho de kit, a necessidade volta
à arquitetura antes de qualquer arquivo.

## 10. C9 — HUD da família (tarefa T12)

Pelo gancho `ClassKit.hud_state` do E12 (`ragrpg_kit_hud_v1`), sem componente visual novo:
- `KitHudState`: prefixo de sistema `madness_` e elemento `shadow` acrescentados às listas
  fechadas; nada mais muda no validador;
- Sacerdote: Graça em pips (∞ com prazo na Hora Santa) e a zona do Santuário;
- Cultista: Êxtase em pips e Loucura em `target_marks` sobre cada inimigo com Loucura, em
  degraus legíveis;
- base: Loucura em `target_marks` quando houver.

Os métodos `hud_state` passam da T5, T6 e T7 para a T12 por transferência registrada no índice,
depois que essas tarefas estiverem ENTREGUES. Os valores vêm das autoridades (`describe()` da T4
e do Santuário); a UI não calcula nada.

## 11. C10 — integração e candidato (tarefas T13 e T14)

- **Composição contínua.** Branch `claude/e10a-candidato`, a partir do commit de arquitetura.
  Cada entrega entra na ordem do DAG assim que fica ENTREGUE, com testes de impacto, resolvendo
  só conflitos mecânicos; conflito de conteúdo volta à tarefa dona. Depois do merge e da cópia
  das evidências ignoradas, a worktree da tarefa é removida e a branch fica.
- **E12.** Quando o E12 estiver em `master`, a T13 faz merge de `master` no candidato. Conflito
  de conteúdo nos arquivos da T1 volta à T1.
- **Verificação.** Suíte completa de `tools/verify.ps1` (sem `-Test`, com `editor_import` em
  worktree limpo) e supervisão da T14: conclusão, ausência de SCRIPT ERROR, timeouts e hashes.
- **Release.** Exportação para
  `C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/playtest_e10a/<sha>/`, com sondas no PCK
  exato: os três corpos, os 22 ícones, os três itens e as entradas de efeito. Perfis de revisão
  da T10, atalhos e smoke. Os `snapshot_manifest.json` novos no `include_filter` (A10 do E09).
- **Medição.** Sonda de multidão contra `db7f9252`, com Delírio ativo, registrada sem alegar FPS.
- **Roteiro de playtest** em `docs/epics/e10a/playtest_guide.md`, com a fase da floresta, o
  Guardião Antigo e o Mestre das Feras (D10).
- **Playtest habitual.** Depois da aprovação técnica, avanço por fast-forward conforme o
  WORKFLOW, preservando alterações locais e o save pessoal. Sem `master`, sem push.

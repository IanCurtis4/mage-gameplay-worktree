# Contratos de implementação — versão 1

Este arquivo descreve o piloto executado. O contrato candidato da expansão está
em [E00_CONTRACT.md](E00_CONTRACT.md), incluindo migração de stats/save. Não
implementar fórmulas novas parcialmente nem tratar exemplos futuros como runtime atual.

## Organização e limites

`scenes/` contém composição visual; `scripts/core/` regras independentes de cenas;
`scripts/data/` tipos Resource de catálogo; `tests/` testes headless.
A tela atual é uma verificação de inicialização e será substituída pela entrada do jogo.
Godot 4.7.2 standard, Compatibility, viewport lógico 1280×720 escalável.

Cena futura: RunController controla fase/encontro/pendências; atores recebem
componentes de movimento/saúde/skills; UI observa sinais e não calcula dano.
Um catálogo carrega Resources por ID. Catálogos nunca recebem HP, cooldown ou stacks.
Não criar EventBus global genérico: usar sinais locais nos donos do estado.

Mundo e colisões usam coordenadas 2D de tela, chão em losangos com proporção 2:1.
Pés são a origem de atores/obstáculos e a referência de Y-sort. Direções não devem
ser projetadas duas vezes. Navegação deve usar regiões caminháveis considerando o
raio do ator; mouse converte para coordenadas globais via câmera. Cada aresta do
caminho e cada passo efetivamente aplicado revalidam o segmento completo contra a
geometria inflada; pontos finais válidos precisam ser alcançados sem cortar quinas.
Cliques fora da região ou dentro de obstáculo resolvem para um ponto caminhável,
sem mover o ator através de área bloqueada.

Em área aberta, a navegação retorna o destino real como único waypoint. Rotas que
contornam obstáculos são simplificadas escolhendo o waypoint visível mais distante,
sempre revalidando o segmento contra a geometria inflada. Inimigos consomem o
orçamento planejado de deslocamento ao atravessar waypoints, com saída sem progresso
para evitar travas por resíduos subpixel.

Parede de Gelo registra um segmento sólido temporário na mesma navegação usada por
atores e projéteis. Colocação revalida toda a faixa contra bordas, obstáculos e
atores vivos antes de cobrar recursos. Registro/retirada reconstruídos mudam a
revisão da malha; atores descartam rotas antigas e replanejam. Expiração, fim do
encontro e morte retiram o segmento sincronicamente, inclusive com a árvore
pausada. Detalhes e tuning estão em E04_MG7_ICE_WALL_HANDOFF.md.

Parede de Escudos é postura defensiva do Espadachim, sem obstáculo de navegação
ou penalidade de movimento. Sua frente é capturada na ativação e não gira com
deslocamento/Investida. Projéteis inimigos frontais consultam o arco antes do
corpo; dano direto frontal usa cópia do pedido e a mitigação passa pelo resolver
canônico. Ações têm classificação explícita ofensiva/mobilidade/defensiva;
somente ação ofensiva validada cancela a postura antes de emitir dano.
Tuning, toggle e limpeza estão em E04_SW1_SHIELD_WALL_HANDOFF.md.

Provocar usa alvo único e não encerra Parede de Escudos. Enquanto provocado,
o inimigo persegue/ataca o jogador; arqueiros não executam a fuga habitual.
Fear/stun/root ainda têm prioridade e projéteis já emitidos não são cancelados.
Debuffs temporários de DEF física/mágica, FLEE, movimento, ASPD, dano causado
e dano recebido são instâncias separadas por atributo e fonte. Em cada canal
vale apenas a maior fração, limitada por atributo; durações não são fundidas.
Reaplicação renova a instância da mesma fonte e uma fonte fraca reaparece após
expiração da forte. DEF/FLEE passam pelo resolver canônico via HealthState;
o valor base continua em StatBreakdown. Detalhes em E04_SW2_PROVOKE_HANDOFF.md.

Perseverança mantém duração no jogador e capacidade de escudo em HealthState.
O resolver calcula o dano uma vez; HealthState consome o escudo antes do HP e
informa as parcelas absorvida/real, sem afetar o snapshot do pedido. Capacidade
usa VIT/INT efetivas via StatCalculator e reaplicação não soma cargas; ver
E04_SW3_PERSEVERANCE_HANDOFF.md.

Grito Perfurante emite um pulso físico baixo e aplica slow e redução de ASPD
somente após dano positivo. Os canais independentes usam o mesmo estado por
fonte do SW2; rank escala duração limitada. Ver E04_SW4_PIERCING_SHOUT_HANDOFF.md.

Fúria injeta uma fonte temporária identificada no `StatCalculator` enquanto
ativa. Recalcular a build mantém exatamente uma fonte; expiração, morte e
limpeza retiram bônus e penalidades sem trocar HP/SP ou cooldown. Ver
E04_SW5_FURY_HANDOFF.md.

Golpe Brutal revalida alvo corpo a corpo/linha de visão após preparo por DES.
O impacto resolve contra a defesa atual anterior ao efeito; só depois de dano
positivo aplica redução temporária de DEF pela fonte da skill. Ver
E04_SW6_BRUTAL_STRIKE_HANDOFF.md.

Raiva Concentrada usa faixa direcional estreita de `SkillGeometry`, compartilhada
entre mira e hit-test, e emite um pedido de dano por alvo na faixa. O jogador
zera caminho, impulso e perseguição no golpe, sem deslocamento tipo Investida;
ver E04_SW7_CONCENTRATED_RAGE_HANDOFF.md.

Grito Aterrorizante aplica fear do `HardControlState` e, independentemente de
imunidade a controle, aumento temporário de dano recebido por fonte. Não causa
dano direto nem cancela projéteis emitidos; ver E04_SW8_TERRIFYING_SHOUT_HANDOFF.md.

Vigor é fonte passiva de `hp_regen` em `StatCalculator`; o runtime continua
aplicando HP regen exclusivamente fora de encontros, sem timer ou fórmula nova
no ator. Ver E04_SW9_VIGOR_HANDOFF.md.

Sede de Sangue usa a alocação de VIT da build como fonte identificada de
ATQ corpo a corpo, sem modificar a VIT efetiva. `RunController` credita uma
única cura por alvo morto com `source_id` do jogador, inclusive DoT, e ignora
notificações duplicadas. Ver E04_SW10_BLOOD_THIRST_HANDOFF.md.

Jogador mantém `velocity` no runtime: aceleração 1100 unidades/s² e frenagem/atrito
1600 unidades/s², velocidade máxima derivada em `StatCalculator` (base 220). Acelera em cerca
de 0,20 s, freia em cerca de 0,14 s e percorre aproximadamente 15 unidades ao parar
em velocidade máxima. Novos cliques conservam o impulso e mudam a velocidade
gradualmente. Chegada reduz velocidade por distância de frenagem, tolerância 0,05.
Integração por passos de até 1/120 s, consumindo todo o delta e revalidando cada
segmento; contato bloqueado remove impulso e recalcula a rota do ponto seguro.
Pause congela posição e velocidade; morte limpa ambas intenção/velocidade; dash
limpa impulso/caminho anterior e permite recalcular perseguição imediatamente.

Seleção assistida de inimigos usa raio total de 68 unidades a partir do centro do
corpo visual (pés + (0,-18)). Um acerto direto (raio do ator + 4) tem prioridade sobre qualquer
alvo apenas assistido. Hover e seleção persistente têm anéis distintos; clicar no chão
cancela a perseguição e a seleção. O ataque básico inicial alcança a soma dos raios dos
corpos + 50 unidades, com banda de retenção adicional de 16 após engajar. Alcance e
linha de visão são revalidados antes do golpe, portanto obstáculos continuam bloqueando.

Perseguição busca a posição real do alvo a cada 0,22 s ou quando a rota termina,
sem parar no ponto de alcance de uma posição antiga. Contato é verificado antes e
depois do deslocamento. Em alcance, jogador firma os pés e emite auto se pronto;
cada emissão apresenta um arco curto e inicia recuperação de 0,14 s, durante a qual
o inimigo pode escapar. Fora do alcance, após essa recuperação, a perseguição retoma
mesmo com cooldown ainda ativo. Clique no chão cancela perseguição/recuperação,
mantendo o cooldown. Ataque emitido ainda passa pela precisão normal de CombatMath.

<!-- Os controles usam a geometria 2D atual, sem mudar projeção/fórmulas de combate. -->

## Mira, input e controles de batalha

`CastIntent` guarda somente modo e skill selecionada. Padrão CONFIRM: Q/W seleciona,
clique esquerdo consome intenção uma vez. RELEASE: key-up correspondente consome;
clique também confirma sem duplicar no key-up posterior. INSTANT: key-down sem echo
lança. Cartões da barra sempre selecionam para confirmar no mundo.

Direito/Esc, foco perdido, morte, menu de controles e escolha de augment cancelam
intenção. Soltar sobre UI interativa cancela; UI recebe cliques antes do mundo.
SP/cooldown são revalidados no commit; selecionar/mirar não consome recursos.
Configurações pausam a arena e não podem empilhar o menu de recompensa.

`BattleTargeting.pick` prioriza corpo direto, depois mantém hover a até 80 unidades
do mouse, depois adquire alvo a até 68. Mortos/objetos inválidos são descartados.
Clique usa o mesmo resolver do realce. Com assistência desligada, somente corpo
direto é elegível. Este é o contrato também para skills single-target futuras;
as duas skills atuais continuam direcionais, sem autoajuste para inimigos.

`SkillGeometry` compartilha raio/ângulo do cone entre teste de acerto e preview.
`PlayerActor.dash_destination` é usado pela mira e pela execução da investida.
`BattleIndicators` desenha cone, corredor/círculo de chegada e pulsos de clique;
verde-água significa disponível, coral indica SP/recarga bloqueada, ouro marca
alvo selecionado. A mira usa coordenadas de combate da arena 2D atual; anéis elípticos
nos pés são decorativos. Este bloco não altera a colisão do corte com obstáculos.

`ControlPreferences` persiste somente modo de cast e smart lock em `user://controls.cfg`.
Valores inválidos retornam ao padrão; falha de gravação mantém a preferência da
sessão com aviso. Testes usam arquivos próprios em `.godot/verification`, nunca o
arquivo do usuário. Este arquivo não persiste run, classe, equips ou cartas.

## Atributos

`StatCalculator.calculate(...) -> StatBreakdown` é a única autoridade dos atributos
e stats derivados. Entrada usa `str`, `agi`, `vit`, `int`, `dex`, `luk`; consumidores
leem `StatBreakdown.value(...)` e não repetem fórmulas. As fórmulas, limites e ordem
de aplicação normativos estão em `E00_02_STATS_CONTRACT.md` e
`E03_A_CORE_STATS.md`.

O vocabulário runtime é canônico: `max_hp`, `max_sp`, `hp_regen`, `sp_regen`,
`melee_attack`, `precision_attack`, `magic_attack`, `physical_defense`,
`magic_defense`, `hit_rating`, `flee_rating`, crítico, velocidade e tempos.
`physical_attack`, defesa única, chance de acerto pronta e mana não existem como
fontes paralelas. `BuildSnapshot` incorpora passivas equipadas como fontes
identificadas; augments entram como fontes adicionais da run. Preview, snapshot,
ator e HUD consomem o mesmo cálculo.

Ao recalcular máximos, preservar HP/SP faltantes (clamp aos novos limites), sem
curar nem reiniciar cooldowns. Recursos atuais pertencem ao ator. SP regenera pelo
stat derivado apenas enquanto o ator está vivo e a simulação não está pausada,
sempre limitado ao máximo. HP regenera por `hp_regen` somente enquanto o jogador
está vivo, fora de encontro e sem pausa, também limitado ao máximo. O HUD prioriza
`RECARGA`, `SEM SP` e `PRONTO`.

Preparações usam `StatCalculator.effective_cast_time`; recargas capturadas no commit
usam `effective_cooldown`. Movimento, morte, menus, perda de foco e reset cancelam
preparação sem custo. SP, cooldown, alvo e alcance são revalidados uma vez no fim;
Teleporte continua instantâneo.

## Dano e efeitos

`DamageRequest` captura IDs runtime, skill, componentes brutos físico/mágico,
multiplicador de dano, modo de acerto, HIT e crítico do emissor. Não contém Node ou
Resource mutável. `CONTESTED` resolve HIT contra FLEE atual do alvo; `GEOMETRY`
representa colisão já confirmada e acerta sem um segundo teste probabilístico.

`CombatMath.resolve(...)` recebe as duas defesas, FLEE e resistência crítica atuais
do alvo, além dos rolls injetados. Mitiga cada componente pela defesa correspondente,
soma, aplica multiplicadores e arredonda uma única vez. A chance crítica efetiva
subtrai a resistência do alvo e o dano usa o multiplicador crítico capturado.
O resolver permanece puro; acerto positivo causa no mínimo 1 e poder zero causa 0.

Aplicador de combate verifica alvo vivo/válido, resolve, limita perda à vida atual,
emite `damage_applied(result)` e, se cruzar HP>0 para 0, `actor_died(actor_id)` uma vez.
Resultado da aplicação acrescenta actual_damage e killed para efeitos de roubo de
vida/eliminação. Eventos não são responsáveis por subtrair HP novamente.
Filhos de efeitos (DoT/explosão etc.) usam is_secondary=true; o runtime respeita
can_trigger_effects antes de acionar qualquer efeito secundário. Danos básicos e
skills diretas podem disparar efeitos. Não usar recursão ilimitada de sinais.

Projéteis direcionais de inimigos fixam a direção quando emitidos: não perseguem o
alvo depois do disparo. O runtime testa a passagem contínua pelo alvo e pela geometria,
destrói o projétil ao atingir obstáculo e limita sua vida por distância. Assim, mover-se
para fora da trajetória é uma esquiva válida e obstáculos oferecem cobertura.

## Augments

`AugmentDefinition` é Resource imutável: id, display_name, description, class_id
(vazio = geral), max_stacks, effect_id, magnitude_per_stack.
`is_eligible(selected_class, current_stacks)` verifica classe e limite.
Run mantém `Dictionary[StringName, int]` de stacks e contador de escolhas pendentes.
Oferta sorteia sem reposição entre elegíveis e fica estável até confirmar.
Confirmar revalida elegibilidade, incrementa um stack e consome uma pendência uma vez.
Resource descreve o efeito; handler por effect_id o executa. Nada de código em strings.

Fluxo: encontro ativo → todos os inimigos eliminados → objeto de recompensa → coleta
→ pendência → jogador abre menu → pausa → confirma → retoma. Não usar cronômetro de
ausência de dano para decidir fim do encontro. UI de pausa processa com árvore pausada.
Pausar menu também pausa projéteis, timers, IA e cooldowns.

## Apresentação do piloto visual

`CombatActor` desenha texturas importadas em 64×64 com nearest, alinhadas pela última
linha opaca aos pés e ajustadas para 52 unidades de altura aparente. A imagem não
define a colisão, a precisão ou o alcance. Sombras, barras e anéis usam a posição
lógica existente. `attack_missed(actor)` só comunica um erro de precisão; flash e
número de dano exigem `actual_damage > 0`. `HealthState` guarda HP e o recorte
defensivo canônico do ator; uma troca de `StatBreakdown` preserva HP faltante.

O efeito do cone guarda origem e direção no lançamento, separadas da orientação de
movimento/auto. O arco do auto representa a distância ao alvo quando o dano é aplicado.

`ArenaView` mistura três texturas 128×128 em shader CanvasItem; o Control do piso
ignora mouse. `BattleIndicators` é o único dono dos marcadores de clique e skill.
`ArenaObstacleView` desenha plataformas baixas ordenadas por Y junto aos atores,
sem mudar os retângulos de navegação. A arena permanece 2D com profundidade simulada.
Fontes raster e parâmetros de importação ficam em `assets/art/pilot/`; nenhum asset
do jogo depende do diretório externo de geração. Texturas são recursos compartilhados
somente de leitura. A prancha em `docs/art/` é documentação, excluída da importação.

## Estado futuro e save

### Apresentação animada (substitui poses estáticas do piloto)

CombatActor usa CharacterAnimation para atlas 256×512 com células 64×64 e pivô
(32,58). CombatAnimationState é estado exclusivamente visual: idle por tempo,
caminhada por distância, direção fixada durante ação, hurt só após dano positivo.
presentation_action conecta gameplay à pose; cast_cancel encerra preparo visual.
Frente/costas são desenhadas; esquerda/direita usam espelhamento. Os contratos de
colisão e combate não dependem do frame. Catálogos e texturas não recebem estado.
Ao morrer, o ator é removido da contagem imediatamente e cria cópia cosmética
ActorDeathVisual de 0,7 s. A cópia terminal do jogador pode avançar durante a pausa
do resultado; ela não causa dano nem processa input. Demais animações pausam.
Scripts de preparação, fontes e prompts ficam no repositório; ver
PLAYTEST_MAGE_ANIMATION.md e ANIMATION_PROMPTS_01.md.

CLASS_ROSTER_BRAINSTORM.md preserva o brainstorm; HYBRIDS_56_EXPLORATION.md descreve
o alvo de oito bases, 16 puras e 56 híbridas. E00_MVP_CLASS_CONTRACT.md fecha o demo
em três bases/seis puras/seis híbridas. Só Espadachim e Mago são jogáveis hoje.

Estado de run: classe, nível, XP, pontos, atributos, HP/SP, cartas, stacks,
fase/encontro, pendências e seed. Não persistir essa estrutura no MVP.
Save v1: schema_version, equipment_collection por classe, equipped por classe/slot,
settings e lifetime_stats. IDs estáveis; desconhecidos ignorados com aviso.
Gravar em `user://profile.json` por temporário + backup antes da substituição;
validar leitura, tentar backup antes de defaults. Sem save implementado nesta fundação.

## Validação

### Geômetra G4 — execução isolada, catálogo parcial indisponível

`GeometerCasting` adapta comandos/vínculos e observa `EnemyActor.ground_walked`
somente após caminhada aplicada pela navegação. `GeometerWallField` consome
travessias reais/contato contínuo da faixa finita; não registra barreira física.
`GeometerInteractionLedger` pertence à instância da construção, preservando janelas
e flags por vítima/projétil durante edição, suspensão e parede→triângulo.
Snapshots de parede são criados no jogador a partir de `StatBreakdown` e ranks
do catálogo, capturados no lançamento pago e consumidos em ordem por ticket.
Catálogos permanecem imutáveis; HP/SP/relógios continuam exclusivamente na run.

O gancho opcional em `PlayerProjectile` concorre com colisões contínuas existentes:
contato posterior a vítima/terreno não transforma. Condução percorre contato→B
com orçamento físico original e retomada da direção, sem renovar alcance/piercing;
desvio muda direção uma vez com alvo/LoS limitados. `ArrowProjectile` consulta
interceptação antes do alvo, respeitando terreno/escudo/Barreira Fantasma.
Adicionais usam `DamageRequest` secundário e resolver central, sem cascatas.
Parede inativa não concede efeitos nem resolve carga pendente; condução ativa
é interrompida sem teleportar o projétil base. Sem mudança no schema/save.
Figuras são underlay; reações curtas de interação usam filho visual acima dos
corpos. Regras completas, tuning e evidências: `E05_GEOMETER_CHECKPOINT.md`.

### Geômetra G5 — campos compostos, sem herança de aresta

`GeometerTriangleField` é estado runtime separado do catálogo, associado à identidade da
construção. Compõe A/B/C a partir dos elementos e tuning imutável do catálogo;
o jogador captura pedidos secundários GEOMETRY de MAG/rank no lançamento pago
de Triangulação. O adaptador retém esse snapshot por ticket até fecharC.
Defesa e aplicação de dano continuam exclusivamente no resolver central.

A/B usam agenda compartilhada1s, com poderF somado em um pedido por ocupante,
sem catch-up nem tick inicial. Slow usa o maior10/20% e residual0,6s. C é
reivindicado antes de emitir dano e resolve uma vez por identidade; gelo usa
controle mágico existente e raio limita três alvos únicos/elos110 com LoS.
Área móvel atua na posição atual, sem varredura. Edição/suspensão/retomada não
recapturam atributos, renovam agenda ou repetemC; pausa congela os relógios.

O gancho opcional `GeometerWallField` delega contato/impacto próprios quando
a figura é triangular, preservando o pipeline de colisão contínua existente.
`GeometerGeometry.triangle_contact` usa círculo versus área sem espessura extra
de parede. Flags de raio usam o mesmo ledger por projétil/instância. A-R entrega
um adicional no próximo impacto elegível na área; B-R entrega um arco a outro
ocupante<=110, sem cascata. Inatividade/outra identidade/impacto fora da área
descartam payloads, não o projétil base. Não há condução/desvio/interceptação ou
Teorema herdados da parede. Figura, preenchimento e hit-test usam o mesmo triângulo.
Sem alteração de save, disponibilidade da classe ou candidato de playtest emG5.

### Geômetra G6 — edição atômica, Colapso e progressão fechada

`GeometerCastCommand` distingue disparos, edições e Colapso. O adaptador atualiza
âncoras móveis antes de validar; `GeometerConstructionState.preview_edit` monta
e valida a figura candidata inteira sem mutar o estado. Translação substitui o
último vértice conservando seu elemento; Reescrita remove o primeiro e acrescenta
o elemento/vínculo congelado no comando. Somente uma edição válida é aplicada
e cobrada. Preservam-se identidade, prazo da figura, agenda, snapshots e ledger;
apenas o vértice substituído recebe novo prazo. Observadores de caminhada são
ressincronizados sem reaproveitar o segmento anterior como uma nova travessia.

Memória Vetorial equipada altera apenas durações capturadas no lançamento pago
ou na edição: +1/+2/+4 s por vértice e +1/+2/+3 s por figura, teto12 s. Equipar,
desequipar ou editar não prolonga o prazo de uma figura já formada.

Colapso é SELF instantâneo: exige figura válida/ativa e nenhuma reserva pendente,
consome a construção antes de callbacks, e captura MAG atual/rank próprio em um
pedido secundário GEOMETRY, sem crítico. O adaptador limpa campos/payloads antes
de resolver dano. Parede usa uma única faixa finita12+raio com LoS, sem travessia,
interceptação ou Teorema; triângulo reutiliza a resoluçãoC sobre pontos/elemento
capturados, com coeficiente próprio, sem manutenção ou repetição da formação.
O ledger é inicializado ao capturar uma nova construção, inclusive antes do
primeiro avanço de um projétil que já nasceu dentro da figura.

`ProfileCatalog` registra as sete skills exclusivas de origem Mago, gates de job
20/23/25/28/31/34/37, TraçadoR1 grátis e os caps5/3/5/5/3/5/5. O codec existente
persiste ranks/presets sem mudança de schema; a construção continua efêmera.
`content_ready=false` permanece até o fechamentoG7, apesar dos metadados completos.
Fixtures habilitam somente esse gate para testar duas builds com compras legais,
19 pontos base/20 evolução, cinco slots ativos e dois passivos.
Tooltips explicam edição, prazos e consumo; nomes longos na barra não expandem
a linha para fora da tela, conservando texto completo no hover/HUD.

### Geômetra G7 — candidato integrado e apresentação

O atlas próprio `geometer.png` usa o contrato de 32 células 64×64 de
`CharacterAnimation`, incluindo frente/costas, caminhada, ação, hurt e morte,
com alinhamento por pés e nearest. Fonte gerada e prompt ficam preservados em
`assets/art/animation_sources`; `prepare_geometer_atlas.gd` reproduz o packing.
Origem Mago, colisão, dano e relógios de combate independem desse asset.

`GeometerOnboarding` é observador somente-leitura: mostra figura/ordem/vínculo,
menor prazo restante, fila/suspensão e próximo comando; ajuda recolhível explica
gates e a distinção Esc/limpeza/Colapso. Informações deixam cliques passarem;
somente o botão do guia captura mouse. O antigo painel genérico é ocultado
nessa identidade. Elementos/Desfazer e slots de skill permanecem nos controles
existentes. Nenhuma preferência/save novo foi criado.

Figuras mantêm área física real: paredes com faixa/direção, triângulos com seis
motivos interiores pequenos por fundação, regras B e reações C limitadas. Vértices
distinguem chama/cristal/raio e chão/vínculo; suspensão usa contorno tracejado
acinzentado sem preenchimento ou manutenção ativa. Um relógio estritamente
visual avança somente pela simulação não pausada. Nas runs Geômetra, inimigos
recebem `compact_control_visuals`: slow/root indicados por pequenas marcas junto
aos pés, preservando todas as regras de CC. Demais identidades mantêm o visual
anterior. Não há dedução de dano ou aplicação de efeito no desenho.

O candidato G7 habilita `content_ready=true` exclusivamente para `mg_ar`; outras
identidades incompletas permanecem bloqueadas. Isso habilita o fluxo real de
evolução/build no código candidato, não atualiza o diretório de playtest nem
dispensa revisão técnica ou aceite humano. Sem mudança de schema/matemática.
Probe denso compara 240 intervalos reais de frame por fase em janela 1080p, com
20 inimigos e APIs de combate, mas delta de simulação explícito 1/60 e comparação
sequencial observacional. Não substitui qualificação de FPS/gameplay pelo usuário.

### Sentinela

Sentinela (`archer` → `sentinel`) mantém biblioteca 7 ativas/2 passivas e slots
5+2, sem schema novo. Contrato completo/tuning: E05_SENTINEL_PLAN.md; fechamento:
E05_SENTINEL_CHECKPOINT.md. `SentinelFocusState` pertence à run e observa o
`encounter_active` canônico; deslocamento real reinicia estabilidade, não Foco.
Fora de combate, após 3s, Foco decai até zero; uma reserva de munição que perde
cobertura é liberada sem gastar SP/iniciar CD, nunca cria piso de Foco. Durante
combate, a munição não expira por relógio. Pausa congela estado; morte/fim limpa.
Cabeça/Perfurante/Concussão validam e emitem um reset imediato, com recuperação
normal e guard contra auto comum no mesmo frame. Explosivo reserva e substitui
somente o próximo auto comum; recursos são consumidos no lançamento validado.
`SentinelMath` usa primários efetivos: INT isolada para Rede/Explosivo, INT+DES
aditiva para Perfurante; CD DES local/limitado nesses três, depois recarga
canônica uma vez. Snapshots ficam no pedido/payload; controles só após dano
positivo, procs leem CC anterior e deduplicam por emissão. Postura usa fonte
`primary_flat` única. VFX têm orçamento cosmético 12, sem suprimir dano/controle.
S7 habilita apenas esta biblioteca completa no candidato isolado; publicar em
playtest/revisão e aceite humano continuam separados. Atlas original preserva
fonte/prompt; provas de renderer não qualificam diversão, balanceamento ou FPS.

### Procedimento

Import headless detecta scripts/recursos inválidos; testes headless validam fórmulas,
limites, dano, elegibilidade, fluxo da arena, layout e invariantes de movimento.
Smoke da cena detecta falhas de inicialização. Movimento automatizado é exercitado
em 30/60/144 Hz, inclusive cruzando patamares de precisão; sensação do combate,
legibilidade e performance percebida ainda exigem partida real do usuário.

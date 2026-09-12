# Contratos de implementação — versão 1

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

Jogador mantém `velocity` no runtime: aceleração 1100 unidades/s² e frenagem/atrito
1600 unidades/s², velocidade máxima derivada em RpgStats (base 220). Acelera em cerca
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

## Atributos

`RpgStats.derive(attributes, flat, increased) -> Dictionary` é a única fonte dos
stats derivados. Entrada usa `str`, `agi`, `vit`, `int`, `dex`, `luk`, não traduções.
Stats base do Espadachim: 8/5/8/2/5/2; Mago: 2/5/5/9/7/2, nessa ordem.
Nível não aumenta stats automaticamente: concede três pontos livres, até nível 5.
Custos de XP por nível seguinte: 100, 150, 200, 250. Conteúdo calibrará XP dos inimigos.

| Stat derivado | Fórmula base |
|---|---|
| max_hp | 100 + 10×VIT |
| max_mana | 40 + 5×INT |
| physical_attack | 10 + 2×FOR |
| magic_attack | 10 + 2×INT |
| defense | VIT |
| attacks_per_second | 1 + 0,02×AGI; limite 0,2–4 |
| hit_chance | 0,90 + 0,005×DES; limite 0,05–1 |
| cast_multiplier | 1 − 0,01×DES; limite 0,25–2 |
| crit_chance | 0,05 + 0,005×SOR; limite 0–0,75 |
| move_speed | 220 unidades/s |
| mana_regen_per_second | 6 mana/s |

Primeiro aplicar `(base + soma_flat) × (1 + soma_increased)`, depois os limites.
`increased=0.20` significa +20%; fontes percentuais somam, não multiplicam entre si.
IDs não reconhecidos não criam stats. Stats não ficam negativos; HP máximo mínimo 1.
Passivas/equips/cartas/augments fornecem modificadores nessa mesma etapa.
Ao recalcular máximos, preservar HP/mana faltantes (clamp aos novos limites),
sem curar ao reequipar repetidamente. Recursos atuais pertencem ao ator.
Mana regenera pelo stat derivado apenas enquanto o ator está vivo e a simulação não
está pausada, sempre limitada ao máximo. No Espadachim, corte custa 15 e investida
20; o HUD exibe os custos e prioriza os estados `RECARGA`, `SEM MANA` e `PRONTO`.

## Dano e efeitos

`DamageRequest`: source_id, target_id (IDs runtime), skill_id, kind PHYSICAL/MAGIC,
base_damage (poder da skill × stat apropriado), hit_chance, crit_chance, can_crit,
is_secondary. Não contém Node ou Resource mutável.

`CombatMath.resolve(request, defense, hit_roll, crit_roll) -> Dictionary` retorna
identidade, tipo, landed, critical, damage e can_trigger_effects. RNG da run fornece
rolls em [0,1); resolver é puro. Tipo mágico/físico seleciona poder no emissor;
ambos usam a mesma defesa no MVP. Skills de área já usam colisão: hit_chance=1;
precisão aplica a ataques básicos que alcançaram o alvo.

Dano = round(base × 100/(100+defesa) × crítico). Crítico = 1,5; defesa mínima zero.
Acerto positivo causa no mínimo 1; erro ou poder zero causa 0. Atributo crítico é
limitado a 75%. Não há resistência elemental ou evasão adicional no MVP.

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

## Estado futuro e save

Estado de run: classe, nível, XP, pontos, atributos, HP/mana, cartas, stacks,
fase/encontro, pendências e seed. Não persistir essa estrutura no MVP.
Save v1: schema_version, equipment_collection por classe, equipped por classe/slot,
settings e lifetime_stats. IDs estáveis; desconhecidos ignorados com aviso.
Gravar em `user://profile.json` por temporário + backup antes da substituição;
validar leitura, tentar backup antes de defaults. Sem save implementado nesta fundação.

## Validação

Import headless detecta scripts/recursos inválidos; testes headless validam fórmulas,
limites, dano, elegibilidade, fluxo da arena, layout e invariantes de movimento.
Smoke da cena detecta falhas de inicialização. Movimento automatizado é exercitado
em 30/60/144 Hz, inclusive cruzando patamares de precisão; sensação do combate,
legibilidade e performance percebida ainda exigem partida real do usuário.

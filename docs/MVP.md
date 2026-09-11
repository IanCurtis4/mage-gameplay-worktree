# Escopo aprovado

## Produto

Windows single-player offline, perspectiva 2D isométrica, câmera fixa seguindo
o personagem, três fases normais e uma arena de boss, runs de 15–25 minutos.
Arte provisória original ou gratuita com licença compatível. Sem backend ou IA no jogo.

Clique no chão navega contornando obstáculos. Clique num inimigo aproxima e
autoataca em alcance; clicar no chão cancela a perseguição. Q/W ativam skills;
alvos direcionais usam o cursor. Mana e cooldowns impedem spam.

## Classes e atributos

- Espadachim: ataque corpo a corpo, corte em cone, investida, passiva de resistência.
- Mago: projétil básico, explosão em área, nova congelante, passiva de regeneração de mana.
- Kits fixos disponíveis desde o início; não se perdem entre runs.
- FOR, AGI, VIT, INT, DES e SOR; níveis 1–5 com três pontos distribuíveis por nível ganho.
- Nível/pontos reiniciam por run. Fórmulas simplificadas próprias, descritas na arquitetura.

## Encontros e boss

Dois encontros delimitados por fase normal. Mapas fixos; combinações predefinidas
variam posições e composição. Máximo de 20 inimigos simultâneos.
Arquétipos: perseguidor, tanque, arqueiro, conjurador de área, atacante com investida,
suporte. Fase 1 introduz o combate; fase 2 pressiona à distância; fase 3 mistura papéis.
Boss anuncia cone, áreas no chão e investida; abaixo de 50% HP combina ataques com
maior frequência. Transição de fase recupera HP/mana. Resumo e reinício após morte/vitória.

## Augments

Cada um dos seis encontros normais gera um objeto coletável. Coleta enfileira uma
escolha; o jogador abre manualmente o menu ao eliminar todos os inimigos do encontro.
Menu pausa o jogo; cada escolha oferece três opções distintas elegíveis. Resolver
pendências antes de avançar de fase. Se houver menos de três elegíveis, mostrar
somente as restantes; se não houver nenhuma, consumir a pendência com aviso.

Catálogo de 12: gerais (HP, crítico, velocidade de ataque, recuperação pós-encontro),
Espadachim (sangramento, corte ampliado, escudo após investida, explosão ao eliminar),
Mago (projétil adicional, queimadura, expansão da nova, redução de recarga ao eliminar).
Numéricos acumulam até três; transformações são únicas. UI mostra efeito atual e
próximo. Dano secundário não pode gerar cascatas de outros efeitos secundários.
Todos desaparecem ao encerrar a run.

## Equipamentos, cartas e persistência

Três slots: arma, armadura e acessório. Doze equipamentos incluindo iniciais;
um prêmio de equipamento por fase normal. Toda aquisição é salva imediatamente,
mesmo que a run termine em morte. Coleção sem duplicatas; respeitar restrições de classe.
Equipamento alterável fora de encontros; duplicata sorteada não cria cópia adicional.

Seis cartas simples, uma recebida por fase normal; um encaixe por equipamento.
Trocar cartas fora de encontros. Cartas, inclusive encaixadas, desaparecem ao fim da run.
Coleção persistente de equipamentos, seleção por classe, preferências e estatísticas
ficam em save local versionado, com gravação segura e backup.
Fechar o aplicativo encerra a run; não há retomada, mas aquisições já salvas permanecem.
Skills fixas são dados da classe, não exigem salvar um sistema de aprendizado.

## Fora do MVP

Multiplayer, mobile, gamepad, geração procedural de mapas, loja de distribuição,
crafting, lojas internas, raridades, subclasses, aquisição de novas skills e
desbloqueios de novos pools de augments. A coleção de equips aprovada está incluída.

## Marcos e aceite

1. Núcleo: arena, Espadachim, perseguidor e arqueiro, navegação/dano, três augments.
2. Build: Mago, seis stats distribuíveis, equipamentos, cartas, save e 12 augments.
3. MVP: três fases, boss, menus/áudio básico, balanceamento e exportação Windows.

Critérios: completar com ambas as classes; seis escolhas fora de combate;
duas builds distinguíveis por classe; persistência correta após morte e reinício;
valores da UI consistentes com combate; navegação sem bloqueios recorrentes;
teste manual de padrões do boss e efeitos simultâneos. Meta 60 FPS/1080p na máquina
do usuário, a medir na arena do primeiro marco. Não afirmar desempenho sem medição.

## Controle de custo

Validar o marco 1 com o usuário antes de expandir. Evitar frameworks, dependências e
releituras grandes. Registrar verificações por bloco. Tokens totais ainda não têm
estimativa medida; usar consumo observável do marco 1 para projetar o restante,
sem confundir créditos do plano com contagem de tokens.

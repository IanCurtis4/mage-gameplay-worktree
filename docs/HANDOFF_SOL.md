# Bloco do Marco 1 — implementado, aguardando revisão

O usuário autorizou a execução deste bloco sobre `41ff198`. A implementação local
foi concluída na branch `codex/m1-arena-combat`; integração, expansão de escopo e
marcos seguintes continuam dependendo de aceite separado.

Título: RagRPG | Sol — Arena e combate do marco 1
Modelo: gpt-5.6-sol, raciocínio high.
Executado em tarefa do projeto RagRPG, em worktree isolada, sobre a fundação commitada.

## Prompt preparado

Implemente somente o núcleo jogável do marco 1 de RagRPG. Leia AGENTS.md,
docs/MVP.md e docs/ARCHITECTURE.md. Preserve os contratos centrais; documente
qualquer ajuste necessário para revisão de Astra. Não crie outras tarefas/agentes.

Entregue uma arena isométrica provisória com obstáculos, câmera seguindo o jogador,
clique para mover com pathfinding e clique em inimigo para aproximar/autoatacar.
Inclua Espadachim com corte em cone, investida, passiva de resistência; inimigos
perseguidor e arqueiro. Use seis atributos-base previstos, sem tela de distribuição
neste bloco. HP/mana/cooldowns visíveis, morte e reinício da arena.

Implemente dois encontros sequenciais. Cada um gera objeto coletável que enfileira
escolha, abrível manualmente fora do encontro com pausa total. Três augments gerais
numéricos (HP +20%, crítico +5 pontos percentuais, velocidade de ataque +15%), cada
um até três stacks. Mostre efeito atual/próximo. A arena é validação técnica; não
implemente três fases, Mago, cartas, equipamentos, save ou boss neste bloco.

Reutilize CombatMath e AugmentDefinition. Teste acúmulo, confirmação única, impossibilidade
de escolher em encontro ativo, morte única e reset sem vazamento de estado.
Execute tools/verify.ps1 e faça validação visual se houver ferramenta disponível;
não afirme que a sensação do combate foi aprovada sem playtest do usuário.

Entregue resumo, comandos/resultados, como jogar e limitações. Faça um commit local
com o trabalho da tarefa para integração posterior por Astra; sem push/publicação.
Pare ao completar esse bloco e aguarde revisão. Integração e próximos blocos serão
liberados separadamente pelo usuário.

## Divisão posterior (não autorizada ainda)

Astra revisa a arena e coordena o playtest. Sol recebe sistemas de build/save após
aceite; Terra recebe catálogos/UI/fases depois dos contratos correspondentes prontos.
Arte provisória e decisões visuais críticas ficam sob direção de Astra. Não criar
todas as tarefas antecipadamente: dependências não prontas geram custo de retrabalho.

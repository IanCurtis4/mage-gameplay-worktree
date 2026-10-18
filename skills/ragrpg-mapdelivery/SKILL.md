---
name: ragrpg-mapdelivery
description: Preparar contratos ou entregar mapas e partes conectáveis autorizados do RagRPG, incluindo montagem por seed, navegação, elevação e portais. Não usar para mapas geográficos ou arte isolada sem integração no jogo.
---

# Entregar mapas do RagRPG

Resolva a raiz com `git -C <checkout informado ou cwd> rev-parse --show-toplevel`
e confirme `project.godot`. Leia AGENTS.md, docs/WORKFLOW.md, docs/MVP.md,
docs/ARCHITECTURE.md, docs/PRODUCT_DIRECTION.md e o contrato/checkpoint do pacote.
Esses caminhos são relativos à raiz do projeto, não à instalação desta skill.
Leia só os contratos detalhados necessários; históricos não autorizam escopo.

## Delimitar a entrega

Distinga pedido de arquitetura, autoria de partes, gerador, navegação ou integração
de campanha. Na ausência de liberação de implementação, produza contrato/delta e
perguntas de produto, não código de E07. Invocar a skill não cria chats ou autoriza
novo épico. Registre base/SHA, resultado, exclusões, APIs e dono dos arquivos.

A direção atual é lobby com seleção de fases e estágios montados de partes;
mapas grandes/labirínticos com elevação funcional e portais de avanço em pontos
específicos. O roteiro `PlaytestGameplay` é predefinido: não chamar sorteio de
spawns de geração modular. Elevação deve afetar acesso/rotas, não só desenho.
Quantidade de estágios, dimensões e densidade precisam do contrato do pacote.
Para cenário 3D/locais memoráveis, ler docs/gates/low_poly_environments.md.
Não presumir conversão integral para 3D. Inimigo memorável conta para limpeza;
acesso ao seu local não pode depender de portal que exija a morte dele.

Antes dos consumidores, fechar interfaces de partes/conectores, superfícies e
alturas, entrada/saída/objetivos, seed e versão de receita, restrições de bioma e
condição de portal. Não presumir APIs prontas de gerador ou linha de visão entre
alturas; audite `ArenaNavigation`, `PlaytestGameplay` e `scripts/main.gd` no checkout.
Contrato técnico deve cobrir clique/superfície, rampas/ponte, colisão, projéteis,
AoE, dash/teleporte e AI, com geometria única. Não criar remendo visual que deixe
atores em superfícies fisicamente desconectadas.

## Construir e integrar

Comece por uma montagem representativa com conexão/altura reais e interfaces
estáveis antes de preencher variantes. Dados de partes são imutáveis; instância
do mapa e estado de encontro pertencem à run. Seed e revisão reproduzem saída;
se houver migração de algoritmo/receita, registrar a mudança de reprodutibilidade.
Falha de geração tem tentativas limitadas e diagnóstico, nunca loop infinito.

Compartilhe geometria entre navegação, spawn, mira e portal. Verifique conectores
por posição/orientação/nível/raio, entrada segura e rota até todos os objetivos
obrigatórios. Rotas alternativas e becos podem existir sem isolar a saída.
Não corrigir desconexão teleportando silenciosamente jogador/inimigos.

Portais permitem avanço e retorno conforme grafo e preservam estado dos mapas;
revalidam sessão, estado e pendências. Revisita/retry não repetem loot/XP/augment.
Limpeza de atores/efeitos mantém progresso permanente e regras de run/augments.
Decisão humana de 18/10: derrotar todos os inimigos abre portais. Respawn tardio
em massa só após limpeza, sem fechar portais; timer único da fase, não por estágio.
Memoráveis contam na limpeza; fechar contabilização de invocações no contrato.
Não substituir limpeza por objetivo parcial. Fase maculada conserva redução de
rendimento entre tentativas até conclusão; detalhe segue PRODUCT_DIRECTION.
Portais podem ramificar; quests devem ter objetivo ou rota garantidos conforme
docs/PRODUCT_DIRECTION.md. Respawn não duplica conclusão ou entrada de estágio.

População total e limite de atores ativos são distintos. Para ecologia/espécies,
use o contrato de população e ragrpg-enemydelivery quando pertinente; dados só
paralelizam com APIs estáveis e dono único. Arquitetura de ativação/carregamento
deve ser explicitada antes de prometer mapas grandes ou FPS.

## Provar a entrega

Selecione invariantes e regressões reais pelo impacto em `tools/verify.ps1`,
conforme docs/TESTING.md; inspecione a lista com `-List` antes de escolher IDs.
Prove seed/revisão reproduzíveis, caminho testemunha, conectores incompatíveis,
falha limitada, seeds adversas e retomada/transição sem duplicação. Exercite
travessia real de rampas/ponte, combate/LoS, entrada/saída e cancelamentos.
Inspecione o renderer; grafo conectado não prova navegação/legibilidade no jogo.
Meça desempenho no cenário real, separando população total de simulação ativa.

Consolide contrato, hash, seleção/logs, seeds, capturas, limitações e próximo
passo em checkpoint. Luna acompanha testes; Sol corrige/valida; Astra somente
arquitetura/exceção justificada por WORKFLOW. Não criar gate por módulo.
Documento apenas: conferir referências/coerência e declarar gameplay não executado.
Playtest/merge/arquivamento seguem WORKFLOW e a autorização concreta da tarefa.

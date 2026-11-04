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
Decisões humanas de 31/10 e 2/11 substituem a regra geral de 18/10: a primeira
jogada de cada fase por personagem exige limpeza; nas repetições vale o objetivo
do estágio, com o guardião resolvido antes quando existir. Confira
`docs/map_editor/contracts/f10_phase_rules.md` e o contrato do mapa. Respawn tardio
em massa só após limpeza, sem fechar portais; timer único da fase, não por estágio.
Memoráveis contam na limpeza; fechar contabilização de invocações no contrato.
Não trocar essa política por uma condição improvisada. Fase maculada conserva redução de
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


## Intercâmbio no editor de mapas F9

Use piece/map/population/patrol para terreno, materiais existentes, props
autorizados, composição, encontros e rotas. Leia `docs/map_editor/exchange.md` e
`docs/map_editor/contracts/f9_regional_synthesis.md` no checkout autorizado para
schema, CLI, limites e máscara de proteção.

Receba o pedido `.rpx` exportado pela pessoa (bundle v2: `source.json`,
`report.json` e `assets.json`), preserve-o byte a byte e trabalhe numa cópia de
`files[source.json].data`. Não edite ticket, base, permissões, relatório ou
manifesto de assets para ampliar o escopo. Declare o hash do pedido/base e os IDs
que vai alterar. Seções/IDs e caminhos protegidos são autorização local; camadas
travadas, slots fixos e pins ficam inteiros; numa camada com região protegida
ficam guardadas a grade, a lista de proteções, as amostras cuja influência toca a
região (altura e mistura de materiais) e os objetos que a tocam. O resto da
camada pode mudar.

Assets: o pacote só declara (caminho, hash, tipo, base de direitos e registro de
origem), nunca traz arquivos. Use apenas assets e props que o projeto já tem com o
mesmo conteúdo; asset novo entra pelo fluxo de arte/assets com registro de origem
(ragrpg-art), não pelo intercâmbio. Arquivo fora de `assets/art/map_authoring`,
dos catálogos ou dos shaders do editor, ou de formato diferente de PNG,
importação, shader e catálogo, é recusado.

Produza candidate.json estrito e rode a CLI versionada `propose <pedido.rpx>
<candidate.json> <proposta.rpx>` com o Godot contratado. O produtor valida/compila;
falha conserva o original, sem scripts/cenas, paths absolutos/traversal ou
reparo silencioso. Confira `review <pedido.rpx> <proposta.rpx> <fonte_atual.json>
[<escolhas.json>]` e entregue proposta, diff, hashes e limitações.

Se a fonte da pessoa mudou depois do pedido, o editor combina base, atual e
proposta por identidade, campo e amostra. Mudanças disjuntas entram; conflitos
voltam com base/atual/proposta e só a pessoa escolhe ("manter a atual" ou "usar a
proposta"); proteção nova da versão atual prevalece. Não tente contornar um
conflito reescrevendo a base ou o pedido: entregue a proposta e descreva os
conflitos esperados. `merge <pedido> <proposta> <atual> <saída.json> [<escolhas>]`
grava a combinação num arquivo novo, sem tocar a fonte.

Variação regional: para relevo, manchas de material ou espalhamento de objetos
dentro de uma região, prefira o serviço do editor (ferramenta "Variação
regional", AX `<tela>/synthesis/*` ou a CLI
`res://scripts/map_authoring/synthesis/headless.gd`) a editar amostras à mão. O
pedido é fechado (seed, região, receita ou "preservar" por canal) e cada variação
aplicada deixa um recibo reproduzível (`replay`/`bundle` na mesma CLI).

Mapa para o jogo: o jogo e os próximos épicos usam só mapas publicados (pacote
`.rpp` imutável fixado em `data/map_authoring/release_packages.json`), pela API de
`docs/map_editor/consumption.md`. Publicar e atualizar a lista é decisão humana;
a skill não publica nem edita a lista.

Na fase composta, a revisão visual é fixada por estágio e resolvida pela API
`MapRelease.load_reference`, independentemente de uma atualização posterior da
lista. Não inserir o pacote visual no snapshot nem ler fontes de autoria para
retomar a run. Confira a apresentação realmente instalada no lobby, portais e
retomada: métricas de uma vista técnica não certificam o renderer com arte.

A pessoa importa a proposta no editor, compara Antes/Proposta e confirma uma ação
desfazível. Não sobrescreva a fonte humana, não publique nem ative o WFC por
inferência. A mesma autoridade atende GUI/AX/CLI. Esta adaptação da fonte
versionada não sincroniza nem instala cópias da skill.

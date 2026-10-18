# Consolidação documental e skills — 17/10/2026

## Autorização, base e propriedade

Pedido humano neste chat: substituir documentação antiga pelas decisões atuais
e criar ragrpg-mapdelivery, ragrpg-augmentdelivery, ragrpg-equipmentdelivery e
ragrpg-enemydelivery. Respostas adicionais confirmam elevação funcional e poção
com CD longo mais bloqueio até sair do combate.

Base `5beea5cd0c70813fbb85207e18bd249dd89c8384`, `codex/playtest`.
Pacote preparado em `codex/content-delivery-docs`, checkout
`C:/Users/João Pedro/.codex/worktrees/content-delivery-docs/RagRPG`.
Dono: chat solicitante `01a11e1a-5eac-7992-9fd5-76e4cdcced19`, documentação e
quatro skills somente. Nenhuma transferência de runtime, arte, dados de catálogo,
runner ou save. Outros chats não foram acionados ou arquivados.

## Mudanças

Entradas README, MVP, ARCHITECTURE, LONG_TERM_EPICS, EPIC_THREADS,
REVIEW_WORK_PACKAGES, E06 índice/contrato/checkpoint/tarefas e E07 foram
substituídas por textos atuais com fontes delimitadas. Onze cópias anteriores
ficam ao lado dos originais com sufixo `.history_2026_10_17.md`, byte a byte,
preservando caminhos relativos e evidências. Não reescrever recibos de teste.

[PRODUCT_DIRECTION](PRODUCT_DIRECTION.md) separa o runtime do destino futuro:
fases selecionadas no lobby, mapas modulares labirínticos, altura/rotas/portais,
gradiente populacional por bioma e progressão fixa por origem; consumíveis,
trash/misc e vendedores/gold. Escolhas ainda abertas estão explícitas.
E07+ e economia não foram iniciados. Nenhum número ilustrativo virou quota.

Quatro fontes versionadas em `skills/` (com `.gdignore`) e metadata de UI,
para instalação em `C:/Users/João Pedro/.codex/skills/`. Descrições distinguem
domínios e autorização; instruções usam as APIs e contratos atuais, incluindo
cartas permanentes e repetidas, exemplares, planos causais finitos e workflow
Luna/Sol. Descoberta automática preservada, sem configuração global.

## Verificação e limitações

Retomada e conclusão documental em18/10/2026, preservando as decisões e os
snapshots de17/10. Validador oficial quick_validate.py: quatro skills PASS;
metadata de UI conferida;122 links locais válidos;11 cópias históricas byte a
byte idênticas. Cópias instaladas conferidas por SHA-256 contra as fontes.
A instalação é somente das quatro pastas solicitadas, sem alterar outras skills.
O pacote não executa gameplay: nenhuma mudança em runtime, cenas, recursos,
migração ou runner. Evidência233/11 do candidato anterior permanece histórica,
não foi reproduzida nem apresentada como teste desta entrega.

Uma avaliação adicional somente leitura das quatro skills exercitou pedidos
de mapa/ponte, augment sem rank, item/carta repetida e inimigos em mapas vizinhos.
Encontrou uma instrução indevida de limpar efeitos na pausa; corrigida para
congelar e preservar estados/snapshots/recargas. Sem outros achados reportados.
Essa avaliação documental não é auditoria semântica de runtime nem teste jogável.

Não houve merge em master/push ou aceite de produto. Próximos contratos deverão
fechar linha de visão entre alturas, condição de portal/respawn, propriedade de
gold/estoque, preços, regras de missão e grupos/duração das poções antes do código.

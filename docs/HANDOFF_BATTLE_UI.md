# UI de batalha — bloco autorizado em 12/09/2026

Base `e70e4d4`, aceita pelo usuário e integrada em master. Trabalho atual em
`codex/m1-battle-ui`, worktree `.tools/battle-ui-worktree`; Astra implementa/revisa.

## Passos de entrega

1. Em andamento: intenção de lançamento (confirmação, soltar, instantâneo), geometria
   compartilhada entre mira/skill e smart lock estável pelo mouse. Testar contratos.
2. Pendente: indicadores no chão, seleção, botões de skills, configuração persistente,
   cancelamento e proteção contra cliques sobre UI/pausa. Validar visualmente.
3. Pendente: suíte completa e candidato no caminho fixo. Aceite da nova UI antes de
   merge. Escrever plano de arte futura, sem produzir assets ou migrar o renderer.

Padrão escolhido explicitamente: Q/W seleciona, clique esquerdo confirma. Botão
direito/Esc cancela. Alternativas: segurar/soltar e smart cast instantâneo. Tecla
solta após um clique de confirmação não pode lançar duas vezes. Mirar não gasta mana.
Mouse determina direção das skills atuais; smart lock aplica a alvos individuais.
Corte e investida continuam direcionais. Resolver de alvo será reutilizável por
skills single-target futuras, que não serão inventadas neste bloco.

Geometria da mira deve corresponder à regra real. Círculo de chegada da investida,
cone do corte e anéis de alvo/clique; skills novas circulares pertencem ao marco de
builds. Preferências são locais, separadas de estado da run e do futuro save de equips.

## Arte futura

Plano em `docs/ART_DIRECTION_NEXT.md`. Produção e migração para chão 3D são passos
futuros sujeitos a aceite. O protótipo atual usa Node2D e profundidade desenhada.

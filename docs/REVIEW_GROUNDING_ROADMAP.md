# Polimento de contato e reservas do roadmap

13/09/2026. Base 5a1251c, branch codex/grounding-roadmap. Única implementação
autorizada nesta rodada: reduzir a sensação de flutuação. Demais mudanças são
documentação/reservas; nenhum épico de expansão foi iniciado.

Sombra antiga em losango 44×20 centrada abaixo dos pés substituída por elipse de
contato 30×9 centrada na origem, com núcleo mais escuro. CharacterAnimation alinha
a última linha opaca ao plano do chão por frame, sem editar atlas/hitbox.
Caminhada usa 16 unidades por frame (ciclo de 64) em vez de 22 (ciclo de 88),
acompanhando distância efetiva durante aceleração/frenagem. Velocidade, atrito,
navegação, dano e input preservados.

313 verificações de verify.ps1 passaram, com import/smoke Godot 4.7.2. Captura
Compatibility 1280×720 revisada em docs/art/mage_runtime.png. Testes 30/60/144 Hz
mantêm fase de caminhada independente do frame rate. A sensação final pede F5
pelo usuário: quatro poses são um limite concreto de fluidez; animações mais
detalhadas estão no E08, não foram geradas nesta correção.

Planejamento vigente: LONG_TERM_EPICS.md, 12 handoffs em docs/epics/,
HYBRIDS_56_EXPLORATION.md e DERVISH_READINESS.md. Roster anterior marcado como
histórico onde contradizia 56 pares direcionais/personagens permanentes.
Reservas de conversa serão registradas em EPIC_THREADS.md. Novos turnos dessas
conversas devem somente reconhecer a reserva, sem ferramentas ou implementação.
Master continua aguardando aceite de produto. Arquivos locais do usuário preservados.

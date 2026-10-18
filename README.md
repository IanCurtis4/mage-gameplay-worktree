# RagRPG

RPG de ação 2D isométrico, Windows offline, em Godot 4.7.2 standard e GDScript tipado.

## Onde começar

- [Produto atual](docs/MVP.md): o que existe, o que é futuro e o que está autorizado.
- [Direção de mapas, inimigos e economia](docs/PRODUCT_DIRECTION.md): decisões humanas de 17/10/2026.
- [Arquitetura vigente](docs/ARCHITECTURE.md): autoridades de regras e contratos por domínio.
- [E06 e candidato de playtest](docs/epics/e06.md): estado, recibos e próximos passos.
- [Roadmap](docs/LONG_TERM_EPICS.md), [fluxo](docs/WORKFLOW.md) e [skills de entrega](docs/DELIVERY_SKILLS.md).

## Jogar e validar

O projeto habitual permanece em `codex/playtest`. Abra `project.godot`, pare a
partida antiga, aceite o reload se solicitado e use F5. A entrada é o menu de
personagens; controles e atalhos são configuráveis na interface.

O candidato inclui dez identidades jogáveis, progressão persistente, equipamentos,
cartas permanentes e augments da run. O roteiro atual tem seis etapas em três
áreas predefinidas; ainda não é a geração modular de mapas planejada.

Validação técnica registrada não substitui o aceite humano do candidato.
Merge em `master` exige esse aceite; não há push automático. Para verificações
por impacto, consulte [TESTING](docs/TESTING.md) e `tools/verify.ps1`.

O texto anterior desta entrada está em [histórico](README.history_2026_10_17.md).

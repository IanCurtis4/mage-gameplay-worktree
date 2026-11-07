# E08 P4 — retomada técnica Sol

6/11/2026. Pedido humano no chat P0: conferir entrega parcial e assumir a parte
complexa possível. Base 6389edcdb7d145e4721b9504ba2876173d4d6a68,
checkout .tools/map-editor-m5, branch codex/e08. Terra P4 está idle; seu commit
é checkpoint parcial, não entrega aceita. P0/Sol assume posse exclusiva nesta
rodada de tools/e08_p4_ui_probe.gd, tools/run_e08_p4_sol_probe.ps1,
docs/epics/e08_p4_sol_delivery.md, e08_p4_directional_contract.md,
e08_p4_sol_contract.md, docs/EPIC_THREADS.md (índice de coordenação), e08_dispatch.md, e08_checkpoint.md e
pasta de evidência docs/epics/e08_evidence/p4_sol/.

Escopo: diagnosticar falhas históricas de sondas, produzir prova nativa atual
com fixture legal/persistida, barra/menu/inventário a UI120%, analisar bloqueio
do rig da candidata e publicar contrato delimitado de quatro direções.
Não alterar sondas antigas/oráculos/runtime nem promover a candidata sem mãos
válidas. O estudo não é atlas aprovado. Sem master/push/playtest/save pessoal.
Somente UMA fixture F1, sincronizada pelo bootstrap existente com manifestos
anteriores preservados; APPDATA/LOCALAPPDATA isolados, timeout externo.

A verificação nova deve falhar em erro real de preparação/captura/assertiva,
encerrar explicitamente e conservar logs por tentativa. Distinguir chamada do
protocolo de drop, input nativo e arrasto físico. Não alegar cobertura de P4
inteiro nem quatro direções implementadas. O contrato direcional delimita uma
próxima implementação de produtor Sol e dependência artística Terra.

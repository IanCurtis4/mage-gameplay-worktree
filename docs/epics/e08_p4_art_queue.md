# Fila operacional de arte P4 — coordenação Root

7/11/2026. Pedido humano ativo: produzir sprites definitivos; ragrpg-resume
retoma esta mesma execução. Este arquivo de coordenação pertence só a Root;
Sol possui os globals/fixture conforme seu contrato. Não é novo épico/gate.

| Unidade | Estado / dono |
|---|---|
| Espiritualista | V2 integrada a195c8de,21/17.440 e Luna; correção de itens mortos sob nova validação Sol |
| Elementalista | Staging completo Terra; Sol integrou harness e corrigiu head W/morte;3.459checks e661/15PNGs de staging PASS |
| Mago | Staging completo,32células S/N byte-idênticas; Sol importou e está inspecionando |
| Espadachim | Staging completo,32S/N byte-idênticas; posse Sol para integração |
| Defendente | Contrato/preparação Terra em arquivos próprios |
| Berserker | Contrato/preparação Terra em arquivos próprios |
| Caçadora / Sentinela / Geômetra / Arqueiro | Pendentes, sem declarar4vistas; próximo contrato antes da escrita |
| Corpos/overrides de inimigos | Pendentes; inventário em p4_sol/baseline_inventory.json; não iniciar novo kit/AI |

Sol delimitado: docs/epics/e08_p4_units_sol_contract.md e files.json. Root não
edita seus arquivos ou fixture até handback. Artistas só suas listas por unidade,
sem engine/importação/commit. P4 aberto, P5 bloqueado; sem master/push/save pessoal.

## Retomada operacional e novo pedido de equipamentos

Na rodada atual, Sol e Terra Berserker interromperam com erro de limite de uso
do provedor. Root interrompeu explicitamente os executores antes de assumir
posse de índice, fixture e arquivos delegados; preserva todas as saídas/parciais,
sem declarar entrega/validação concluída. Defendente retornou integralmente;
seu diagnóstico concreto de2células segue contrato corrigido. A tentativa de
nova tarefa Defendente foi interrompida ainda em pending_init sem nova escrita.
Root assume temporariamente esses arquivos e a consolidação. Uma nova delegação
exige mensagem/posse delimitada, sem alteração de expectativas.

Pedido humano adicional: capacete menor/encaixado, equipamento mais desenhado
e drops temáticos usando a referência Spriters Resource. Contrato independente
[e08_p4_gear_art_contract.md](e08_p4_gear_art_contract.md), estágio novo, sem
conflito com corpos/renderer. Novo agente pedido explicitamente pelo usuário.

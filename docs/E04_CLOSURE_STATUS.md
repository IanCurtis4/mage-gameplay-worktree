# E04 — aceite do candidato e pendência de fechamento

Usuário aprovou o candidato de playtest em 23/09/2026, com a ressalva de
ter testado apenas parte das possibilidades. Aceite cobre o candidato
2ac631d (runtime Espadachim cac2299 e entregas anteriores do Mago/Arqueiro).
Integrado em master sem incorporar alterações locais do editor/exportação.

## Estado

- Arqueiro: biblioteca e fechamento integrado entregues e aceitos.
- Espadachim: SW1–SW10/SWI revisados e candidato aceito em playtest.
- Mago: MG1–MG7 e sprite/animação provisórios implementados e testados;
  fechamento integrado MGI com duas builds entregue para revisão técnica
  ([handoff](E04_MAGE_INTEGRATED_HANDOFF.md)).
- E04 permanece aberto até o gate técnico de Astra para MGI e a auditoria
  final do contrato. E05 foi autorizado condicionalmente ao fechamento de E04;
  não iniciar implementação de evoluções antes desse gate.

## Pacote submetido: MGI

Sol executou somente o fechamento integrado do Mago na tarefa E04
existente. O cenário usa duas builds distintas de até cinco ativas e duas passivas,
compradas dentro da carteira real de 19 pontos, sem augments obrigatórios:
uma elemental e outra espiritual/defensiva. Usar as passivas já implementadas;
não inventar skills para preencher slots opcionais.

Cobrir perfil isolado, compra/equipagem, nomes no menu, presets, save/reload,
snapshot, HUD, encontro melee/ranged, recompensa e encerramento. Conferir
combinação Eletrizado/Descarga, controles, barreiras, limpeza de colisão
temporária e estados; repetir regressões de Espadachim/Arqueiro. Fixtures
de XP/dano final devem ser explicitadas, não apresentadas como balanceamento.

Implementar apenas correções necessárias para esses contratos. Não criar
novas habilidades, evoluções, arte final nem alterar saves do usuário.
Executar tools/verify.ps1, entregar commit e handoff com limitações reais e
parar para revisão Astra. Auditar também eventuais lacunas do aceite E04;
não declarar o épico completo apenas porque testes individuais passam.

Após MGI aprovado, registrar fechamento E04. Se houver mudança jogável,
preparar novo candidato e obter aceite do usuário antes de merge dessa mudança.
E05 começa por contrato/seletor de evolução e origem persistente, em pacote
delimitado; não disparar seis puras e seis híbridas simultaneamente.

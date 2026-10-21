# E07-F6 — ameaça e participação

21/10/2026. EM_EXECUÇÃO. Executor Sol/Alto, chat 01a150a6-ba84-7691-a248-2c63911c12d4.
Aval: “F5 foi concluída. Podemos começar F6.” D06 aprovada em seguida:
“Aprovar essas regras de D06”, referente à pergunta completa registrada neste chat.

Base real a93ea74f41e95fe11174e390b651c0ce1fe41c95 (fechamento F5), runtime
8911d81d0857143f36daea824f3b64fb75d8d5c3. F0–F5 são ancestrais deste candidato.
Branch codex/e07-f6; checkout C:/Users/João Pedro/.codex/worktrees/e07-f6/RagRPG.
Integração operacional/playtest separada; save pessoal preservado. CLI de workflow
e WORKFLOW_TOOLING ausentes nesta base; diagnóstico por Git/contratos, como F2–F5.

## Contrato aprovado

Lista individual por inimigo. Dano efetivo 1x; cura efetiva 0,5x dividida entre
inimigos engajados do grupo; overheal zero. Troca normal estritamente acima de
110% do atual, empate conserva atual; sem atual, identidade estável desempata.
Provocar iguala o maior valor e fixa pela duração/imunidades já existentes.
Atribuição explícita de fonte/owner para DoT/pets. Redução por parâmetro, sem nova
habilidade. Cinco segundos sem vínculo hostil real para sair do combate, já F5.
Snapshots preservam valores, fixação, claims e participação; UI consome ThreatView.
Sem multiplayer, UI nova, habilidades novas ou avanço F7/E08+.

## Manifesto exclusivo e transferência sequencial

F5 entregue/validada e declarada concluída pelo usuário. Transferência sequencial
para este executor, sem outro escritor nestes arquivos:
- scripts/actors/enemy_actor.gd; scripts/main.gd;
- scripts/core/health_state.gd (eventos de aplicação/cura efetivos; sem mudar fórmula);
- scripts/core/expedition/combat/combat_participation.gd;
- scripts/core/expedition/snapshot/runtime_manifest.json e snapshot_registry.gd;
- tools/verify.ps1, somente registro de testes F6/seleção, exclusivo até entrega.
Novos: scripts/core/expedition/combat/threat_service.gd, threat_view.gd e .uid;
tests/e07_f6_threat_test.gd, e07_f6_runtime_test.gd, e07_f6_snapshot_test.gd e .uid.
Documentos: este despacho, f6_api.md, f6_checkpoint.md, delivery/f6.md;
seções F6 de docs/epics/e07.md e docs/epics/e07_tasks.md. Contratos arquiteturais
permanecem históricos; este delta registra o aval posterior D06.
Outros arquivos exigem adendo nominal antes da edição.

## Critérios e evidência prevista

Replay/conflito sem dupla geração, limiar/empate, cura real/overheal/divisão,
DoT e pet sintéticos com owner, provocar/expiração/imunidade existente,
redução sem apagar vínculo, ocultação/LoS/leash/morte, fontes múltiplas,
participação congelada e snapshot/durabilidade pelo writer F4, sem reset.
Testes por impacto via tools/verify.ps1, Godot4.7.2 standard; Luna supervisiona
execução/saídas/erros/hashes do lote, Sol corrige e consolida. Não é auditoria
semântica independente. Sem push, master, avanço do playtest ou arquivamento.

Adendo21/10 antes da correção: scripts/core/expedition/snapshot/snapshot_identity_roles.gd
transferido exclusivamente a F6. Declarar enemy_id e recibos outgoing de participação
nas gramáticas fechadas de remapagem trial/demo já usadas pelo snapshot legado;
provar identidade reconstruída/replay em tests/e07_f6_snapshot_test.gd. Nenhuma
mudança de ID de produção F5, fórmulas ou expectativas históricas. O lote Luna
foi interrompido pelo autor após seis PASS, sem falha de teste; retomar somente
com novo SHA/importação. Os seis consumidores sem snapshot podem ser reaproveitados
por impacto porque seus inputs/rotinas não mudam neste adendo.

# E07-F8 — despacho e propriedade operacional

23/10/2026. Autorização humana neste chat: “F7 terminou, podemos começar F8.”
Executor Sol/Alto; Luna/Médio supervisiona o lote automatizado, sem auditoria
semântica independente. Resultado: composição F0–F7, medição da amostra,
prova nativa/release e candidato técnico com roteiro humano.

Base real: `5ee16ebdce1888c84f15b29f286e956db7b55d42` (F7 entregue/validada),
cumulativa sobre `9e457f222b0bc7dbbc67078ec7712eecee1bb353` (F1–F6 integradas).
Runtime F7: `6a7a31b1303eaa57e6868e4453fc682aee59cea7`.
Checkout exclusivo `C:/Users/João Pedro/.codex/worktrees/e07-f8/RagRPG`,
branch `codex/e07-f8`. Árvore inicial limpa; nenhuma mudança de base/rebase.
D01–D07 aprovadas conforme e07_decisions.md e recibos dos produtores.

F8 recebe exclusivamente, sequencialmente de F7, `tools/verify.ps1`.
Novos arquivos exclusivos: `tools/e07_f8_candidate_probe.gd` e .uid, `tools/e07_f8_candidate_probe.tscn`,
`tools/e07_f8_validation.ps1`, `docs/epics/e07/f8_dispatch.md`,
`f8_checkpoint.md`, `f8_playtest.md`, `delivery/f8.md`.
Coordenação deste pacote possui atualizações de estado em `docs/epics/e07.md`,
`docs/epics/e07_tasks.md`, `docs/MVP.md` e `docs/ARCHITECTURE.md`.
Config de export somente na cópia isolada: nunca sobrescrever export local.
Demais fontes são leitura/execução. Correções externas exigem transferência
nominal antes da edição; este despacho não transfere todo o runtime.
Luna não escreve fontes versionadas: possui somente .godot/verification/e07_f8
para execução/logs, em sequência com os probes nativos/release de Sol.

Cobertura: bootstrap real byte-idêntico (único delta VCS desligado), regressão
composta de F0–F7 e perfil/UI/combate afetados pelo fechamento, inspeção nativa
das seeds42/43, probe explícito sem assert para template Windows release,
reentrada durável em processo novo, catálogo/partes/adaptadores e cenário completo.
Registrar matriz I01–I15, limites concretos de área/população, máquina/renderer/
resolução/seed e p50/p95/p99 de frame time, montagem/carga/save. Operações
síncronas continuam materiais; checks não provam60FPS ou balanceamento.

CLI de workflow e docs/WORKFLOW_TOOLING.md ausentes nesta base; diagnóstico por
Git/contratos/runner existentes, sem instalar ou inventar CLI.
Master/push e migração pessoal não autorizados. Após aprovação técnica, preparar
playtest conforme WORKFLOW preservando alterações e save. Aceite de produto é humano.

## Transferência nominal autorizada23/10 — correção de snapshot

Usuário escolheu “Autorizar Sol a corrigir aqui, com transferência nominal e
regressão”. F8/Sol recebe exclusivamente `scripts/main.gd` (e .uid somente se
necessário) para drenar exclusões adiadas após congelar o tick, antes da captura.
Nenhum campo persistente/API/política novo. Produtores encerraram a escrita.
Reprodução no probe prepare, nível1 real: projétil mata entry_guard; captura
no callback adiado retorna checkpoint_incomplete, enquanto a mesma captura no
frame seguinte funciona (dev_03/dev_04). Não é PASS e não será mascarada com
retry automático do probe. Correção e regressão permanecem neste chat por aval.

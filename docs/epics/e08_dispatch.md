# E08 — propriedade e dispatch

Contrato: [P0–P7](e08_p0_contract.md); autorização [plano](e08_approved_plan.md).
Checkout único de escrita: `C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5`;
branch `codex/e08`; base P0 `c8b80b13d29c468afb7f2ad7ba75eec838e7df32`.

## Donos

P0 possui docs/epics/e08.md, e08_approved_plan.md (documento humano preservado),
e08_p0_contract.md, e08_inventory.md, e08_dispatch.md, e08_p0_receipt.md,
docs/WORKFLOW.md, docs/ARCHITECTURE.md, docs/EPIC_THREADS.md;
runner/embalagem E08 sob coordenação. Nenhuma alteração ao runtime em P0.

P1 Sol 6.1 high recebe EXCLUSIVAMENTE:
- scripts/presentation/presentation_event_bridge.gd e seu .uid novo;
- scripts/actors/combat_actor.gd, player_actor.gd, enemy_actor.gd;
- scripts/actors/character_animation.gd; scripts/core/combat_animation_state.gd;
- scripts/main.gd;
- scripts/actors/player_projectile.gd, mage_projectile.gd;
- scripts/world/world_field_view.gd, battle_indicators.gd;
- tests/e08_presentation_test.gd e .uid;
- tools/verify.ps1 (transferência P0→P1 apenas para registro do teste E08);
- docs/epics/e08_p1_delivery.md;
- docs/epics/e08_evidence/p1/ (somente recibos/logs/hashes/capturas mínimos).

Não precisa editar todos os arquivos permitidos. Arquivo adicional requer
transferência delimitada registrada por P0; diagnóstico pode ser feito sem editar.
P1 não altera schema/save/fórmulas/geometria nem assets. Publica API executável,
integração e testes positivos/negativos/lifecycle, roda verify por impacto,
commit apenas próprios e devolve posse. P0 revisa; Luna supervisiona inputs congelados.

P2 Sol 6.1 high, AINDA NÃO DESPACHADO: propriedade prevista de
scripts/presentation/audio_service.gd, audio_event_catalog.gd,
audio_preferences.gd e .uid; scripts/ui/audio_settings_panel.gd e .uid;
tests/e08_audio_test.gd e .uid; docs/epics/e08_p2_delivery.md e e08_evidence/p2/.
scripts/main.gd e tools/verify.ps1 transferidos sequencialmente de P1/P0.
UI hospedeira concreta, base e APIs P1 serão resolvidas antes do dispatch P2.

P3 Terra 6.1 high, AINDA NÃO DESPACHADO: assets/fontes/receitas do piloto,
consumidores visuais sobre API estável, tests/e08_pilot_test.gd,
docs/epics/e08_p3_delivery.md e e08_evidence/p3/. Lista exata após P2/inventário
visual, antes do dispatch; isso é planejamento, não autorização para escrever
qualquer pasta. Mudança contratual retorna a Sol Apresentação.

Luna low: somente docs/epics/e08_evidence/luna_<checkpoint>/supervision.md e
hashes.json. Runners/logs gerados na fixture sequencial, inputs congelados,
sem mudar runtime/tests/expectativas. Criação de chat condicionada ao checkpoint.

P4–P6 e P7: BLOQUEADOS_ACEITE_HUMANO_P3. Sem chats reservados nem bases fictícias.
Cada dispatch futuro registra SHA completo, arquivos e transferência efetiva.

## Registro

P0: documentação e índices em fechamento; próximo SHA será resolvido pelo commit,
nunca substituir SHA executável por nome simbólico. P1 só inicia após esse registro.

### P1 entregue / checkpoint Luna

P0 documental integrado `f1f53693823ce5a97518a25fa7bd831874161261`.
Dispatch P1 efetivo nessa base, chat `01a1aea0-d67a-7023-9fcf-dbecfe5cef85`,
host local, Sol 6.1 high. Runtime recebido
`04c77c9c36f5ee86a89a266b0d3a3a07e74fccac`; recibo candidato
`d84991e52bf724284f0bf8310de525104f563b81`. Posse devolvida e árvore rastreada
limpa; quatro backups intactos. [APIs/evidência autoral](e08_p1_delivery.md).
12/12 etapas autorais, sem erros/timeouts; não é suíte completa nem aceite visual.

P0 conferiu o diff: hooks de apresentação sem nova fórmula/query/timer de dano;
ponte excluída pela fronteira Control existente, sem schema novo. Corrupção UTF-8
intermediária corrigida pelo próprio P1 antes da rodada final. Engine standard
pareada autorizada em substituição ao wrapper console local que falhou ao iniciar.

Checkpoint Luna P1, pacote fechado: base/candidato
`d84991e52bf724284f0bf8310de525104f563b81`, branch/checkout acima. Inputs congelados
em e08_evidence/p1/inputs.json; seleção final, logs brutos e hashes em hashes.json
e raw_logs.zip. Conferir 12 conclusões, nomes/seleção, exit/erros/timeouts, bytes
dos logs, fontes/fixture/engine/runner/backups e blobs Git. Não repetir suíte
compatível por efeito da supervisão. Se evidência incompleta, reportar falha a P0.
Dono exclusivo Luna low: docs/epics/e08_evidence/luna_p1/supervision.md e hashes.json;
nenhuma edição de runtime/testes/oráculos/manifesto. P0 permanece somente leitura
enquanto Luna escreve. Não é auditoria semântica independente. P2 ainda bloqueado
pela consolidação deste checkpoint.

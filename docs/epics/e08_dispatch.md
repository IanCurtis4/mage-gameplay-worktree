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

### P1 validado e integrado / P2 pronto

P0 consolidou o contrato e a conferência Luna em
[supervisão P1](e08_evidence/luna_p1/supervision.md). 20 inputs de checkout,
9 blobs explicitamente registrados, 19 membros do ZIP, 2.255 arquivos da fixture
contra origem/manifesto, engine/config/runner e quatro backups conferidos;
12/12 conclusões finais sem erro/timeout. P1 VALIDADO/INTEGRADO na composição,
sem aceite artístico ou áudio e sem master/playtest. Chat mantido para correções.

P2: base de código `d84991e52bf724284f0bf8310de525104f563b81`, base documental
`971a7cf693c9c858e8c5fc7683cac88bbffb105f`; commit deste registro apenas documental.
Modelo Sol 6.1 high, checkout/branch acima. Dependência P1 satisfeita. P0 transfere
scripts/main.gd e tools/verify.ps1 a P2; P1 está parado. P2 é único escritor.
Lista EXATA autorizada:

- scripts/presentation/audio_service.gd e .uid;
- scripts/presentation/audio_event_catalog.gd e .uid;
- scripts/presentation/audio_preferences.gd e .uid;
- scripts/ui/audio_settings_panel.gd e .uid;
- scripts/ui/battle_controls.gd (host rolável de configurações existente);
- scripts/main.gd;
- tools/verify.ps1 (apenas registrar o teste e suporte necessário E08);
- tests/e08_audio_test.gd e .uid;
- docs/epics/e08_p2_delivery.md;
- docs/epics/e08_evidence/p2/ (logs/hashes/recibos mínimos, sem fixture inteira).

APIs: contrato P0 e tabela executável do recibo P1, inclusive token de época e
pausa. UI visible em pt-BR com Geral/Efeitos/Interface/Ambiente. Catálogo inicial
com IDs estáveis/paths definidos para P3, sem sons de produção neste pacote;
fixture usa AudioStream sintético. Serviço participa da fronteira Control
descartável existente, sem ampliar snapshot. Sem plugins, música ou save novo.
Volume/mute independentes persistem em audio.cfg separado. Eventos de UI confirmam
ações reais; não converter input tentado/recusado em impacto. Instalação/rebind
não acumula assinaturas/vozes/buses e retomada só reinicia ambiente atual.

Testes P2: e08_audio_test (mute/volume/config inválida e erro de gravação,
dedup/rebind/época, 32 vozes e prioridades, pausa mundo/UI, limpeza/retomada),
e08_presentation_test, combat_animation_test, e07_f1_presentation_test,
e07_f3_lifecycle_test, e07_f3_action_matrix_test e e07_f7_presentation_test;
acrescentar UI por impacto e inspeção nativa do painel em UI120%.
tools/verify.ps1, mesma fixture e standard 4.7.2 pareado já validado (wrapper
console tem falha local193). APPDATA isolado. Sem repetir fronteiras sem delta.
Luna low supervisionará outputs/inputs congelados; Sol P0 consolida antes de P3.
Aceite: API e serviço funcionais com fixture sintética, controles acessíveis,
sem mutação de gameplay/save nem alegação de sound design final. Commit próprios,
recibo autossuficiente com APIs/IDs/paths, hashes e limitações; devolver posse.

### P2 recebido / checkpoint Luna

Dispatch efetivo P2 na base `61d91a65d6673f12bfc8915061668d1d56b6c770`, chat
`01a1aebf-dbc4-7701-8b17-1441618fb9c6`, host local, Sol 6.1 high.
Runtime/evidência `2f72322a3b419eb04eef92a83cbba15ba40214d3`; recibo/handback
`66209511813628b1b78d21426824cee5bbedcf22`. Escrita encerrada, árvore rastreada
limpa e quatro backups intactos. [Recibo P2](e08_p2_delivery.md).
P0 conferiu API, snapshot/staging e captura nativa UI120%; sem schema novo.
Proteção de staging e loop WAV foram corrigidos no mesmo P2. A comparação da
ajuda em1280×720 falha1/30 também na base: limitação herdada, sem falso PASS.

Luna low recebe candidato `66209511813628b1b78d21426824cee5bbedcf22`, mesma
branch/checkout, seleção composta explícita no recibo: 9 etapas pré-loop,
delta final áudio82 checks e nativo83. Mudança entre as rodadas é somente
loop WAV privado e teste correspondente; oito regressões não entram nesse ramo
sem samples e conservam inputs pertinentes. P0 aceita essa compatibilidade
delimitada; não somar repetições como cobertura nova.
Inputs/evidência: docs/epics/e08_evidence/p2/{inputs.json,hashes.json,raw_logs.zip,
audio_settings_ui120.png}. Conferir 23 inputs, 13 blobs, 63 membros do ZIP,
2.265 fontes da fixture, engine/config/manifesto/runner/backups, conclusões reais
e outputs das rodadas finais. Verificar FAIL herdado e seu controle na base.
Sem rerun rotineiro; falha/incompletude retorna a P0. Dono exclusivo Luna:
docs/epics/e08_evidence/luna_p2/supervision.md e hashes.json. Não editar outros
arquivos, runtime/tests/oráculos, fixture ou recibos P1/P2. P0 fica somente leitura.
P3 continua não despachado até esta consolidação.

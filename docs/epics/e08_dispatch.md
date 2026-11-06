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

### P2 validado / P3 pronto

P0 consolidou P2 com [Luna](e08_evidence/luna_p2/supervision.md): integridade de
23 inputs/13 blobs/63 membros ZIP/2.265 fontes de fixture, engine/config/captura
e quatro backups; seleção composta conferida. P2 VALIDADO/INTEGRADO na composição
para seu escopo de áudio, com FAIL herdado de ajuda1/30 explícito e não bloqueante
do painel áudio inspecionado. Não é certificado de toda UI nem aceite sonoro.
P2 está parado para correções. P0/P7: chat01a1ae9c-2471-74d2-84ad-9805a14dc543.

P3 Terra6.1 high: base executável `66209511813628b1b78d21426824cee5bbedcf22`,
base documental `38cfb7c3790e5283555fcb26b507d72dedff8ffb`; este registro e
[contrato P3](e08_p3_contract.md) são documentais. Branch/checkout únicos acima.
Depois do commit documental P0 fornecerá o HEAD completo efetivo no dispatch.
Posse sequencial transferida P0→P3, sem outro escritor. Arquivos EXATOS permitidos:

- scripts/actors/combat_actor.gd (somente desenho/helper visual estático; sem campos);
- scripts/actors/mage_projectile.gd (somente _draw, sem colisão/modificadores);
- scripts/world/world_field_view.gd (somente desenho, sem geometria canônica);
- scripts/main.gd (somente instalação/limpeza do consumidor visual Control);
- scripts/presentation/e08_pilot_visual.gd e .uid;
- scripts/presentation/e08_pilot_feedback.gd e .uid;
- tools/verify.ps1 (registro e08_pilot_test);
- tests/e08_pilot_test.gd e .uid;
- tools/e08_pilot_probe.gd e .uid;
- tools/prepare_e08_pilot_audio.py;
- tools/prepare_e08_pilot_art.py;
- assets/art/animations/mage.png, mage.png.import, mage_weaponless.png,
  mage_weaponless.png.import, preparation_report.json;
- assets/art/e08_pilot/mage_source.png, mage_extra_source.png,
  mage_weaponless_source.png, mage_weaponless_extra_source.png, grass_source.png,
  os cinco .png.import correspondentes, provenance.json e recipes.md;
- assets/art/map_authoring/grass_tile.png e .import, materials_provenance.json,
  materials.md;
- assets/audio/e08/world_cast_start.wav, world_cast_cancel.wav,
  world_projectile_launch.wav, world_impact.wav, world_area_start.wav,
  world_area_end.wav, world_teleport.wav, world_death.wav, world_revive.wav,
  ui_confirm.wav, ui_cancel.wav, ambience_stage.wav, os12 .wav.import
  correspondentes, provenance.json e recipes.md;
- docs/epics/e08_p3_delivery.md;
- docs/epics/e08_evidence/p3/ (evidência mínima do piloto, incluindo antes/depois).

Lista permitida não obriga editar tudo. Não editar ponte/serviço/catálogo áudio,
CharacterAnimation/CombatAnimationState, fórmulas, schema, mapas/populações/RPP,
outros atlas/classes ou docs P0. Necessidade adicional requer pedido delimitado
com pausa de escrita para P0 registrar transferência; correção usa o mesmo chat.
Dependências/API/aceites/testes completos no contrato P3 e recibos P1/P2.
P0 possui export_presets/runner de embalagem e release, não delegados a Terra.
Luna supervisionará checkpoint congelado após entrega; P0 consolida contrato e
release/playtest. P4–P7 continuam BLOQUEADOS_ACEITE_HUMANO_P3, sem chats criados.

### P3 em execução / devolução temporária para correção P2

Dispatch P3 efetivo `cdf34b6c6292716722069ff49cd9eac49323551b`, chat Terra
`01a1aede-5799-76f2-835d-5418b5e395d9`, host local, high. Interrupção por limite
de uso preservou o trabalho; usuário retomou o mesmo chat com ragrpg-resume em6/11.
Não houve substituição do executor. Baselines nativos e manifests de parâmetros
estão no pacote P3; não constituem entrega nem aprovação técnica do piloto.

P3 reproduziu saturação: 24 world.impact confirmados no mesmo quadro, canais100%,
WASAPI, captura no bus effects, pico7,8327608 e7.943/20.992 quadros acima de1,0.
[JSON](e08_evidence/p3/audio_mix.json) e log mantidos no pacote P3. Isso é uma
medida antes da correção, não de ganho/limitação da futura saída corrigida.
P3 parou de escrever e testar explicitamente; P0 assumiu somente registro.
[Manifesto de preservação](e08_evidence/p0/p3_mix_handoff_inputs.json) fixa hashes
de todos os arquivos modificados/não rastreados, incluindo backups e arte parcial.
Não commitar ou sobrescrever esses arquivos por efeito da correção P2.

P2 recebe correção no MESMO chat01a1aebf-dbc4-7701-8b17-1441618fb9c6, Sol6.1 high.
Base integral `cdf34b6c6292716722069ff49cd9eac49323551b` mais WIP P3 congelado
no manifesto; HEAD documental do handoff será passado na mensagem. Branch/checkout
acima. Dono exclusivo de escrita P2 durante correção, arquivos EXATOS:
scripts/presentation/audio_service.gd, tests/e08_audio_test.gd,
docs/epics/e08_p2_mix_delivery.md e docs/epics/e08_evidence/p2_mix/.
P0/P3 ficam somente leitura. Sem alterar WAVs/catálogo/ponte/probeP3/runner/mapas,
expectativas existentes, limite de32vozes, prioridades, eventos, mute/volume,
pausa/staging ou gameplay/save. Usar recursos nativos Godot, sem plugin externo.

Resultado: impedir saturação na saída privada somada do serviço com as vozes
contratadas; preservar timbres/níveis úteis e mutabilidade somente por instância.
Capturar sinal APÓS proteção e soma no bus Geral privado; o raw bus Effects pode
continuar excedendo1 antes dessa proteção. Provar 24impactos reais e mistura de
canais/limites, configurações100%, com captura nativa e relatório de pico/quadros
acima da escala, sem esconder falha baixando o perfil ou descartando vozes.
Reexecutar e08_audio_test (inclui staging/loop/mute/caps/config), regressões de
apresentação e lifecycle por impacto. Mesma fixture/engine, inputs WIP explícitos.
Recibo e hashes mínimos próprios; commit somente quatro caminhos próprios acima,
sem stage-all. Devolver posse P0 para conferir preservação, validação/Luna por
impacto e devolver P3 ao mesmo Terra. Correção contratual automática; sem Astra
ou nova decisão de produto. P3 segue incompleto e gates P4–P7 continuam fechados.

### Correção P2 recebida / checkpoint Luna mix

Runtime/evidência `05acf494b6acc50b3ee793635a8191809c296770`, recibo/handback
`310fef0c93cfa9a957f965b0e838eec4f8093833`. P2 parou de escrever. P0 confirmou
80/80 hashes do WIP Terra intactos; índice sem arquivos P3. [Recibo](e08_p2_mix_delivery.md).
Proteção nativa única no Geral privado, API intacta. Pico real24impactos
7,8327608→0,8902556; mix32slots8,0291433→0,8902561; zero quadros>1 na saída
protegida. BusEffects bruto permanece alto antes da proteção e não é sua saída.
Impacto isolado conserva waveform após atraso de áudio2,042ms; nenhum tempo de
simulação mudou. Autor: verify3/3 (áudio132, apresentação2122, lifecycle90),
nativo268checks; tudoPASS no escopo. P0 conferiu diff pequeno do serviço e prova.

Luna low recebe candidato `310fef0c93cfa9a957f965b0e838eec4f8093833`, mesmo checkout/
branch, base do handoff `a0f09771a0d5928b81c6ad0b5c08788fb284517c` + WIP congelado.
Conferir docs/epics/e08_evidence/p2_mix/{inputs.json,hashes.json,raw_evidence.zip,
comparison.json,native_before_metrics.json,native_after_metrics.json,wip_before.json,
wip_after.json}: 44membros/14blobs únicos noZIP,24capturasfloat, conclusões/erros/
timeouts/inputs reais e2.299fontes da fixture, engine/config/runner e80hashesP3.
Recalcular picos/quadros acima da escala dos buffers conforme o recibo e comparar
antes/depois, pontos de captura e32vozes, sem rerodar suíte por rotina. Histórico
de falhas e rawEffects não são PASS da saída nem falha da saída protegida.
Dono exclusivo Luna: docs/epics/e08_evidence/luna_p2_mix/supervision.md e hashes.json.
P0/P2/P3 somente leitura; nenhum outro arquivo/fixture editado. Não certificaP3.
Após consolidação P0 devolverá escrita ao mesmo Terra com novoHEAD e WIP preservado.

### Mix validado / posse devolvida P3

6/11. [Supervisão Luna mix](e08_evidence/luna_p2_mix/supervision.md) confirmou
44/44membrosZIP,24capturas em14blobs,9inputs,2.299fontes,engine/config e80/80WIP
idênticos; recalculou métricas e alinhamento98frames sem divergência. Verify3/3 e
nativo268PASS no escopo, falhas anteriores preservadas. P0 consolida correção
VALIDADA/INTEGRADA `05acf494b6acc50b3ee793635a8191809c296770`, recibo
`310fef0c93cfa9a957f965b0e838eec4f8093833`; nenhum carimbo de aprovação deP3.

Após este commit documental, P0 devolve a posse EXCLUSIVA ao mesmo Terra P3,
chat01a1aede-5799-76f2-835d-5418b5e395d9. Base efetiva do código atualizado é
310fef0c93cfa9a957f965b0e838eec4f8093833 mais80WIPpreservados; HEADdocumental
completo passado na mensagem de retomada. Propriedade EXATA originalP3 continua;
P2estáparado e seus arquivos serviço/teste não foram transferidos aTerra.
Continuar de onde parou: depois nativo comparável, regressões, roteiro/recibo e
commitP3, sem refazerP0/P1/P2 ou abrirP4–P7. Conservar prova antiga audio_mix.json/
log como rawEffects ANTES da proteção; captura posterior usa novo diretório/nome,
medindo Geral DEPOIS da proteção. Não sobrescrever a evidência histórica.
P0 fica somente leitura até handbackP3. Candidato jogável/release ainda pendente.

### P3 WIP preservado / correções de atlas e UI voltam P1

Terra parou e criou checkpoint explicitamente INCOMPLETO/EM_CORREÇÃO
`7f04830e01db0f49acefd47899c271b45b65adaf`, sem novos testes nessa transferência.
Índice/árvore rastreada limpos, quatro backups fora do commit. P0 inspecionou imagens:
recoloração não resolve identidade do javali; UI120% real preenchida sobrepõe
painel de estágio e barra. Não aceitar essas duas lacunas como fechamento deP3.
P0 não implementa arte nem substitui Terra; producerAPI/UI com mesmoSolP1 precede
consumidor. [Contrato fechado](e08_p1_pilot_corrections_contract.md).

Base integral acima, branch/checkout únicos, chat P1
01a1aea0-d67a-7023-9fcf-dbecfe5cef85, Sol6.1 high. Lista EXATA, API, testes e
aceites no contrato. P0 transfere main.gd, gui_metrics.gd, battle_controls.gd,
expedition_status_panel.gd, character_animation.gd, runner e testes listados
sequencialmente aP1; P2/P3 parados. P1 único escritor, P0 somente leitura após
dispatch. HEADdocumental efetivo será informado na mensagem. Commit do WIP
permite P1 tocar main.gd sem incorporar mudanças de Terra como autoria própria.

Expansão de arte P3 PREPARADA, AINDA NÃO DESPACHADA: fontes
assets/art/e08_pilot/forest_wolf_source.png, forest_wolf_extra_source.png,
forest_boar_source.png, forest_boar_extra_source.png e seus quatro .png.import;
runtime assets/art/animations/e08_forest_wolf.png e e08_forest_boar.png e seus
dois .png.import; receitas/proveniência e tools/prepare_e08_pilot_art.py já previstos.
Depois de validar P1, P0 resolve novoHEAD/API, amplia ligação em main.gd/helper
P3 e devolve posse explicitamente. Não alterar MobDefinition/animation_kind,
arquivos compartilhados de outras identidades, comportamento ou mapas. São
variantes cosméticas por instância no renderer existente, não arquitetura nova.
P4–P7 continuam fechados pelo aceite humano do piloto completo.

### P1 atlas/UI recebido / checkpoint Luna

Código/evidência `3c405e9903ae930b719020b402afe65fc62caa22`, recibo/handback
`55960be86ffe9e4b7ddec4570cd84abd1c184a15`. P1 parou de escrever. Base
`b105dbc6884395edac9f7478b0afe200a4a0940d`, WIP P3 preservado nos114caminhos
fora dos arquivos transferidos. [Recibo](e08_p1_pilot_corrections_delivery.md).
P0 conferiu diff/API e PNG nativo preenchido com painel separado da barra.
set_body_atlas é restrito a kind fora de WEAPONLESS_KINDS e equipamento vazio;
Texture2D persistível256×512, mesmos campos e CombatAnimationState. death_copy
copia orientação exata sem renormalização; nenhum clock/schema novo.

Autor:9/9 etapas, apresentação2204, UI55headless/61nativo, áudio132, animação39,
battleUI47, layout30, actionbar80, F7presentação27, lifecycle90. Zero erros/timeouts.
Falha histórica de help1280 agora resolvida pelo código, sem mudar ui_layout_test.
Capturas nativas mostram UI120% real, rolagem/foco/roda/Escape e resize sem acúmulo.

Luna low recebe candidato55960be86ffe9e4b7ddec4570cd84abd1c184a15, mesma branch/
checkout e base acima. Dono exclusivo: docs/epics/e08_evidence/luna_p1_pilot_corrections/
supervision.md e hashes.json. Conferir inputs.json/hashes.json/raw_evidence.zip,
29membros brutos,6PNGs e native_ui.json,2.301fontes da fixture, engine/config,
backups e114caminhosWIP preservados; conclusões reais de9etapas e61nativas.
Sem rerun rotineiro, mudança de expectativa, edição de código/fixture ou recibo
alheio. P0/P1/P2/P3 somente leitura. Não certificaP3 nem aceite artístico.
P0 consolida e despacha retomada de Terra depois desse checkpoint.

### P1 atlas/UI validado / retomada final da arte P3

Luna confirmou17inputs,29membrosZIP,6PNGs/native_ui,114WIPpreservados,4backups,
dependências P2mix e2.301fontes;9/9logs e61checks nativos sem divergência.
[Supervisão](e08_evidence/luna_p1_pilot_corrections/supervision.md). Sol P0 consolidou
contrato/diff e inspeção nativa: P1correções VALIDADO/INTEGRADO em3c405e9903ae930b719020b402afe65fc62caa22,
recibo55960be86ffe9e4b7ddec4570cd84abd1c184a15. UI120% e help1280 agora corrigidos;
não reescrever recibos históricos como se a falha nunca tivesse existido.

P1 parou. Após este commit P0 devolve escrita ao mesmo Terra P3, chat
01a1aede-5799-76f2-835d-5418b5e395d9, high. Base executável55960be86ffe9e4b7ddec4570cd84abd1c184a15,
WIP7f04830e já ancestral; HEADdocumental efetivo na mensagem. Propriedade original
P3 mais12paths de fontes/atlas no delta de e08_p3_contract.md. main.gd e runner
voltam P1→P0→P3 somente no escopo consumidor/registro de teste; preservar layout,
API e todos arquivos P1/P2. CharacterAnimation/testeP1/UI não foram transferidos.
P3 único escritor, P0 somente leitura até handback. Não houve aceite de produto.

### P3 entregue / checkpoint Luna piloto

Terra devolveu posse no commit3ea5e9086da11c51d81d5a85b8f29d464b04c3d8,
pai22f5788882622d733ab822c4caa08692ceb7226d. Índice/árvore rastreada limpos,
quatro backups intactos. [Recibo final do executor](e08_p3_delivery.md).
P0 inspecionou os dois atlas32frames e capturas da floresta: lobo/javali distintos,
HUDespaçado e preenchido, sem troca dos atlas compartilhados. API/código preserva
estado/clock/morte/snapshot; sem dados de gameplay/RPP alterados. Desempenho,
release e aceite visual/sonoro ainda pendentes. Não declarar candidato final pronto.

Luna low recebe candidato3ea5e9086da11c51d81d5a85b8f29d464b04c3d8, mesma
branch/checkout, base22f5788882622d733ab822c4caa08692ceb7226d. Conferir inputs/
hashes/ZIP no pacote e08_evidence/p3 e provenance de arte/áudio,2316fontes da
fixture/engine/config/backups,14/14etapas concluídas, piloto125headless e126nativo.
Único delta posterior aos testes foi recipes.md com prompts literais; versão
testada/manifesto brutos noZIP permitem compatibilidade documental. Não ocultar
diferença de bytes nem rerodar gameplay por receita documental.
Dono exclusivo Luna: docs/epics/e08_evidence/luna_p3/supervision.md e hashes.json.
P0/P1/P2/P3 somente leitura; sem alteração de código/fixture/expectativas ou
certificação artística. Após conferência P0 prepara comparação F10 e release,
preservando habitual/save, antes de oferecer o piloto ao usuário.

### P3 validado / posse P0 para entrega do piloto

Luna devolveu posse em6/11:35membros ZIP,14/14etapas e126checks nativos,
19inputs,2316fontes,4backups,atlas32/32 e12WAVs conferidos; exceção documental
recipes.md testada/atual identificada sem reclassificar bytes. P0 consolidou
contrato e inspeção já registrada: P3 TECNICAMENTE VALIDADO/INTEGRADO em
3ea5e9086da11c51d81d5a85b8f29d464b04c3d8. Não é aceite de produto.

P0 único escritor para embalagem/comparação: tools/build_e08_pilot.ps1,
e08_release_probe.gd, compare_e08_pilot.ps1, e08_{crowd,terrain,preparation}_compare.gd,
docs/epics/e08_pilot_release.md, checkpoint/índices e evidência p0_release.
Usa a fixture existente e release separado .tools/playtest_e08; nenhuma mudança
de runtime ou save pessoal. P1–P3 parados; falha de produtor retorna ao mesmo chat.
Provas de embalagem executam o binário release real, menu/Mago,12sons/2atlas,
UI120%,floresta publicada, suspensão/retomada e ausência de replay.
Comparação reaproveita sondas F10, mesmo engine/PCK/protocolo sequencial, três
janelas, frio/quente de processo sem esvaziar cache do sistema. Ferramentas
versionadas não iniciam P4–P7 nem substituem o aceite humano.

# E08 P2 — correção da soma de áudio

6/11/2026. Sol Áudio, validação autoral. Correção contratual recebida de P0 no mesmo
chat P2, conforme [dispatch: devolução temporária P3→P2](e08_dispatch.md).
Contrato original: [P0](e08_p0_contract.md) e [recibo P2](e08_p2_delivery.md).

## Candidato, contexto e posse

- Base/HEAD do handoff: `a0f09771a0d5928b81c6ad0b5c08788fb284517c`.
- Base de código anterior à documentação P0: `cdf34b6c6292716722069ff49cd9eac49323551b`.
- Correção, teste e evidência: `05acf494b6acc50b3ee793635a8191809c296770`.
- Branch: `codex/e08`.
- Checkout: `C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5`.
- Este recibo recebe commit documental posterior, sem delta executável. SHA final
  informado na resposta de entrega; resolvível com `git log -1 -- docs/epics/e08_p2_mix_delivery.md`.

A árvore inclui **WIP P3 não entregue**, congelado no
[manifesto P0 de 80 arquivos](e08_evidence/p0/p3_mix_handoff_inputs.json).
Todos os 80 hashes conferidos antes e depois: **80/80 idênticos**, incluindo WAVs,
imports, ferramentas/runner P3, main e backups. Nenhum desses arquivos foi editado,
sobrescrito, incluído no índice ou commitado por esta correção. P3 continua incompleto;
esta validação não certifica seu conteúdo, arte ou piloto.

Estado: ENTREGUE com validação autoral; conferência P0 e supervisão Luna por impacto
pendentes. Após o commit deste recibo, P2 para de escrever e devolve posse a P0,
que devolverá P3 ao mesmo Terra. Sem arquivamento, master/push/playtest ou nova
aprovação de produto por efeito desta correção.

## Correção e APIs

O bus Geral privado de cada PresentationAudioService recebe **uma instância nova de
AudioEffectHardLimiter**, depois da soma de Efeitos/Interface/Ambiente. Recurso nativo
refletido na engine instalada: classes e propriedades estão no ZIP de evidência.
Não há plugin ou alteração no bus compartilhado Master.

- Pré-ganho: **0 dB**; nenhum ganho fixo negativo no serviço, nos samples ou no perfil.
- Teto de saída verificado: **−1 dBFS**, amplitude linear 0,8912509381.
- Teto interno do efeito: **−1,01 dB**, com margem de 0,01 dB para a pequena ultrapassagem nominal observada no efeito nativo.
- Release: **0,1 s**.
- Efeito por instância: estado de ganho/release não é compartilhado entre serviços.
- Configure repetido não empilha efeitos; dispose remove os buses e seus efeitos.

O primeiro ensaio com teto interno exatamente −1 dB ficou abaixo de 1,0, mas o
controle sintético chegou a 0,8913462162, ligeiramente acima do teto nominal.
A falha foi preservada. A margem interna corrige essa aproximação sem relaxar a
assertiva sobre a saída capturada. Somente a expectativa da nova configuração
interna mudou de −1 para −1,01; os **82 checks anteriores permanecem byte a byte**
e o oráculo de saída (zero quadros acima de 1 e abaixo de −1 dB com tolerância
numérica 0,00001) permaneceu igual.

APIs públicas, catálogo/IDs/paths, mute/volumes, roteamento, loop, staging/pausa,
dedup e eventos permanecem os do recibo P2. Os 32 slots continuam **24+4+4**, com
as mesmas prioridades e política de substituição. A correção atua no sinal somado;
nenhuma voz é descartada para resolver saturação. Não altera waveform de catálogo,
RNG, gameplay, schema, dano, alcance, cooldown, recompensa ou relógio de simulação.

## Captura nativa antes/depois

Driver **WASAPI**, mix nativo **48.000 Hz**, samples P3 reais nos 12 paths existentes.
Todos os canais em **100% e sem mute**. Há três taps registrados separadamente:

1. Effects bruto, antes do envio a General; pode exceder 1.
2. General bruto, primeiro efeito de captura, soma de todos os canais antes do limitador.
3. Saída de General, último efeito de captura, **depois da soma e proteção**; fader
   General em 1. Nenhum resultado bruto é apresentado como saída protegida.

O registro original P3 em `e08_evidence/p3/audio_mix.json` mediu Effects bruto:
pico7,8327608109, 7.943/20.992 quadros acima de1. A prova abaixo repete essa carga
e acrescenta a medição no Geral privado.

Na baseline ainda não havia limitador: o campo `protected_general` identifica o
mesmo ponto de saída prospectivo, portanto mede a soma **sem proteção**. Essa
condição está explícita em [comparison.json](e08_evidence/p2_mix/comparison.json).

| Caso / saída General | Pico antes | Quadros >1 antes | Pico depois | Quadros >1 depois |
|---|---:|---:|---:|---:|
| 24 impactos reais no mesmo quadro | 7,8327608109 | 7.943 / 35.840 | 0,8902555704 | **0 / 38.400** |
| 24 impactos + 4 UI + 4 ambientes reais | 8,0291433334 | 7.979 / 35.328 | 0,8902561069 | **0 / 38.400** |
| 32 slots sintéticos coerentes | 29,2982101440 | 33.850 / 38.912 | 0,8903052211 | **0 / 38.400** |

Quadro significa frame estéreo: conta quando qualquer canal ultrapassa amplitude1.
Janelas de captura têm pequenas diferenças de tamanho por agendamento; não são
medidas de desempenho. O bruto Effects depois da correção ainda alcança
**7,8327608109 e 7.943 quadros >1** nos impactos reais, comprovando que a carga
não foi escondida. No mix completo após correção, General bruto alcança
7,9651217461; a diferença da baseline depende da fase dos loops/UI na mixagem,
com as mesmas contagens/volumes/samples.

Diagnóstico imediatamente após disparar confirma todos os slots pedidos ativos,
**zero dropped e zero missing_samples**, antes de terminarem naturalmente. A
contagem `played` inclui o único ambiente de entrada, explicitamente encerrado
antes de cada rajada; não representa voz extra na captura. Controle sintético
exercita o teto mesmo sem samples P3 disponíveis.

Controle de nível/timbre: um impacto real isolado abaixo do limiar tem pico
**0,3263650835** e RMS **0,0600526292** tanto antes como depois. As amostras de
saída são **idênticas** após alinhar 98 quadros de áudio (2,042 ms a48kHz), sem
redução constante de nível. Nos grupos limitados o RMS de saída é 0,20473/0,20696,
com sinal útil não nulo; a envoltória é limitada dinamicamente. Isso não promete
identidade de waveform sob sobrecarga nem substitui audição/aceite sonoro P3.

As 24 capturas estéreo float32 foram reconferidas independentemente em Python:
SHA256, contagem, finitude, pico, quadros acima da escala e RMS coincidem com o
relatório Godot. O controle isolado também foi alinhado e comparado amostra por
amostra, erro absoluto máximo0. Não houve conversão PCM16 que ocultasse os picos.

## Testes, inputs e evidência

Engine standard pareada autorizada:
`C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/godot/Godot_v4.7.2-stable_win64.exe`,
`4.7.2.stable.official.ed1daf0bf`, SHA256
`ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424`.
Mesma fixture `.godot/verification/e07_f1/fixture_project`; APPDATA isolado em
`fixture_project/.godot/e08_user`. Nenhum save pessoal ou projeto/cache novo.

Foram sincronizados somente os dois deltas próprios: audio_service e e08_audio_test.
A fixture tinha uma entrada antiga no manifesto para tools/e08_pilot_probe.gd;
**source e fixture já eram byte-idênticos ao handoff**. Corrigido somente esse hash
no manifesto, sem copiar/editar probe P3. O confronto final verifica **2.299 fontes**
nos dois lados. Manifesto/config/engine e contexto WIP são registrados em
[inputs.json](e08_evidence/p2_mix/inputs.json); plano do runner registra HEAD de
handoff com árvore suja, não uma entrega fictícia de P3.

`tools/verify.ps1 -F1Fixture`, rodada `e08_p2_mix_final`, **3/3 etapas PASS** entre
310 disponíveis, exit0, zero erros/timeouts, limite300s por etapa:

| Teste | Checks | Resultado |
|---|---:|---|
| e08_presentation_test | 2.122 | PASS |
| e08_audio_test | 132 | PASS, incluindo 32 slots sintéticos e checks P2 anteriores |
| e07_f3_lifecycle_test | 90 | PASS |

Execução nativa adicional com samples reais: **268 checks PASS**, exit0, zero
falhas/timeouts. Cobre rajada de 24, todos os pools, controle abaixo do limiar,
limpeza de buses/efeitos, idempotência e independência de estado do limitador.
Checks originais de configuração inválida/gravação falha, mute/volume, dedup,
prioridades, pausa, staging/abort, loop e painel permanecem. Não se repetiu suíte
completa, UI antiga, performance, export ou piloto por efeito desta correção.

Desenvolvimento preservado no ZIP:

- Baseline nativa sem proteção: **7 falhas esperadas** nos checks novos de efeito/
  teto, incluindo confirmação da saturação no Geral. Não foi apresentada como PASS.
- Primeira proteção a−1dB: uma falha no controle sintético por ultrapassar levemente
  esse teto nominal; saída já não excedia1. A margem de0,01dB resolveu o limite
  mantendo as assertivas de saída. Fontes mínimas dessa etapa também preservadas.
- Rodadas finais headless e WASAPI acima passam; mesmas fontes finais nas duas.

[hashes.json](e08_evidence/p2_mix/hashes.json) confere os resumos e
[raw_evidence.zip](e08_evidence/p2_mix/raw_evidence.zip): **44 membros**, incluindo
logs/planos/checks brutos, reflexão nativa, fontes mínimas anteriores, manifesto e
24 capturas (14 blobs únicos, deduplicação somente de bytes idênticos por SHA256).
`capture_index.json` no ZIP mapeia cada nome lógico `.f32le` ao blob exato; formato
estéreo intercalado float32 little-endian, sem normalização. ZIP evita core.autocrlf
sobre logs/capturas. SHA256:
`c3bef59854b09b86a846375146a1cd2bf6c8b34494819a7073f1d8abdd733aee`.
Aproximadamente1,4MiB de evidência durável; sem samples/WIP P3 ou fixture inteira
copiados para o commit. Cópias soltas geradas das capturas foram removidas somente
após conferir o ZIP; fixture/cache existentes permanecem para Luna/P3 sequenciais.

## Reprodução e devolução

PowerShell7, no checkout acima, após conferir os hashes congelados do contexto WIP:

```powershell
$fixture = Join-Path $PWD '.godot/verification/e07_f1/fixture_project'
$env:APPDATA = Join-Path $fixture '.godot/e08_user'
$engine = 'C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/godot/Godot_v4.7.2-stable_win64.exe'
./tools/verify.ps1 -F1Fixture -GodotPath $engine -Test e08_audio_test,e08_presentation_test,e07_f3_lifecycle_test -CheckTimeoutSeconds 300 -VerificationDirectory (Join-Path $PWD '.godot/verification/e08_p2_mix_luna')
& $engine --path $fixture --script res://tests/e08_audio_test.gd -- --audio-mix-native "--audio-mix-output=$PWD/.godot/verification/e08_p2_mix_native_recheck"
```

A parte nativa exige os 12 WAVs P3 e driver real; verifica ausência de samples como
falha. O teste normal headless usa stream sintético e funciona sem assets P3.
Luna confere evidência compatível antes de repetir testes. Não tocar em WIP/testes/
expectativas durante supervisão. [wip_before.json](e08_evidence/p2_mix/wip_before.json)
e [wip_after.json](e08_evidence/p2_mix/wip_after.json) registram preservação dos80.

Propriedade respeitada: somente `scripts/presentation/audio_service.gd`,
`tests/e08_audio_test.gd`, este recibo e `docs/epics/e08_evidence/p2_mix/`.
Não editaram catálogo, ponte, WAVs, runner, main, arte, mapa ou persistência.
Os cinco arquivos rastreados modificados por Terra e seus arquivos não rastreados
permanecem deliberadamente fora dos commits P2. Árvore global **não está limpa**
por causa desse WIP autorizado; não confundir com pendência própria de P2.

Limites: saída medida é o Geral privado após soma/proteção, antes do Master/hardware;
nenhuma alegação de true peak no DAC, resposta de caixas ou preferência sonora.
Não houve benchmark de CPU/memória, certificado do piloto P3 ou mudança no gate
humano de P4–P7. A falha herdada de help/HUD do recibo P2 não foi alterada/retestada.
Dois checkouts e uma fixture mantidos; sem troca do habitual, backup/save pessoal,
master, push, playtest, novo chat ou escalada de arquitetura.

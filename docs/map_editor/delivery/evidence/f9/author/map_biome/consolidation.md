# Bioma de runtime e bordas atômicas — incremento F9

Código `4e3a3788878c7520552c7815d0c2915301857f5f`, de 29/10/2026,
branch `codex/map-editor-f9`, checkout `.tools/map-editor-m5`. Godot 4.7.2
standard, SHA256 `ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424`.
Fixture exclusiva `.godot/verification/e07_f1/fixture_project`.
Este recibo aprova uma integração delimitada; F9 integral permanece aberto.
Conteúdo integrado em `86359e3ddc33ff3dd5ef5a9f009dd7bc0ca306f2`; provas
executadas em 4e com os mesmos bytes de conteúdo, antes desse commit.

## Mudança e revisão de contrato

Sol corrigiu a propagação do bioma explícito de autoria ao único estágio do
manifesto. Contexto vazio ou ausente conserva `ruin`. O validador confere forma,
referências e coerência entre contexto e estágio; refazer o digest de um pacote
incoerente não o torna válido. O leitor recusa o pacote sem regravar seus bytes.
Formato 5 e revisão v5 foram mantidos por ser correção do valor de um campo
existente, sem alteração de schema ou fórmula. O hash compilado muda.

Bordas em lote compartilham os produtores existentes: `BorderOperations`,
`MapSession`, painel GUI/AX e CLI. O limite 529 deriva de 32 instâncias, 496 pares
e uma flag de decoração. Propostas, diff e fonte não compartilham estado mutável.
Um comando inválido recusa o lote inteiro; hash esperado, no-op, nome pendente e
um único undo/redo pertencem à mesma transação. Não foi criado setter genérico
de fonte. O inspector ganhou rolagem e o botão “Aplicar borda a todas as peças”.

Sol leu o delta e os consumidores; Luna escreveu os dois testes dirigidos,
acompanhou as execuções e conferiu contagens, erros e hashes. Correções de fixture
ocorreram na revisão anterior à execução: captura do nome antes de redo, apoio
real da peça e viewport de janela embutida também no modo headless. Os oráculos
de rollback, coerência, bytes preservados e independência do diff foram mantidos
ou fortalecidos. Não se apresenta essa supervisão como auditoria semântica
independente. UIDs foram produzidos pelo engine na fixture antes do congelamento.

## Evidência do produtor

| Etapa | Checks aprovados |
|---|---:|
| MapBiome / MapBiomeNative | 15 / 13 |
| Borders / BordersNative | 93 / 32 |
| GameplayNative | 52 |
| Candidate / Population / Patrol / Exchange | 53 / 91 / 58 / 113 |
| `tools/verify.ps1`, somente `editor_import` | 1 de 299 selecionado |

[Relatório de execução Luna](../../luna/map_biome/report.md) e recibos brutos
na mesma pasta. As regressões de gameplay usam amostras existentes; não são prova
de caminhada, combate ou FPS do Bosque. Sol inspecionou a captura nativa de
1600×1000: canvas 1269×632, 44 malhas, 19 cores, oito spans florestais e controles
finais acessíveis por rolagem. Não é aceite humano da UX completa.

[Auditoria Sol](producer_audit.json), repetível no congelamento do produtor por `audit_producer.py`,
conferiu seis recibos, HEAD antes/depois, engine e todos os hashes enumerados.
Os cinco completion runs têm 2045 entradas cada; Context tem 2039, pois exclui
os seis imports de props presentes no primeiro conjunto. Não são conjuntos
idênticos. Os dez imports de props/terreno foram conferidos adicionalmente.
Zero divergências source/fixture/manifest. As duas fontes de peça e o mapa
anterior continuaram intactos durante a validação do produtor. Logs sem
SCRIPT ERROR, Parse Error ou ERROR; apenas warning conhecido de projeto
aninhado ignorado. APPDATA/LOCALAPPDATA privados; nenhum perfil pessoal usado.

A tentativa inicial Context recebeu `literalF1` como caminho relativo: concluiu
a importação e chegou a emitir checks parciais de Candidate, mas foi interrompida
sem recibo terminal da suíte. Não conta como PASS. Context02 usou o caminho
absoluto correto e terminou. A cópia auxiliar foi preservada
em `.godot/verification/f9_invalid_literalF1_20261029`, sem excluir arquivos;
[recibo do movimento](invalid_fixture_archive.json). Nenhum engine remanescente
foi encontrado antes de liberar a fixture para Terra.

## Conteúdo e consumidor

Terra aplicou `forest_rootbank_v1` às duas instâncias pela janela real AX: 4/4
ações, compile antes de save e reabertura 2/2 em outro processo. Ambos terminaram
com exit 0, logs limpos e hashes coincidentes. [Recibo e captura](../../terra/area_forest_borders/README.md).
Sol inspecionou a captura 1440×1000: moldura florestal visível, cenário preservado;
os controles AX ocupam a faixa superior do canvas, parte da UX ainda a finalizar.

Mapa final `data/map_authoring/sanctuary_woods.map.json`, 45.615 bytes:

- SHA256 do arquivo `8e3f1c3c47709d204eeaf3061e3d98beabb0dfa987ed09ff24ad2ec79e6a631f`.
- Fonte semântica `8a9051f8a416a58890365e1b262cea309053ff52c5ce20725d0598ef7875ed55`.
- Pacote `098aa6b630015504ec47abfa45257fb0c7b571efabad590016dcc34acfc71fdc`.

[Auditoria de conteúdo](content_audit.json) comparou com o blob do mapa em 4e:
somente `borders` mudou. Os dois snapshots, poses, um vínculo e 47 props são
idênticos; as fontes das peças conservaram seus bytes. O backup novo do mapa
contém exatamente a fonte anterior e fica local, junto aos dois backups de peça.
O hash de pacote 68bd do checkpoint 25 é histórico, não um oráculo deste produtor.

Após Terra liberar a fixture, Import01 sincronizou todo o projeto: 2040 entradas
sem os seis imports de props. Luna executou uma única prova do arquivo final:
[ForestConsumer12 PASS](../../luna/map_biome/forest_consumer/report.md), exit 0,
77,321 s, sem timeout/erros. Conferiu arquivo/fonte/pacote, snapshots, poses,
vínculo, contexto sem exceções, bioma efetivo florestal, perfis nas duas instâncias
e 35 spans florestais sem legado. Candidato imutável com corpo canônico 20×32,
84 apoios e 131 conexões preparou acesso a todos os apoios. O marcador autorado
[160,0,640] foi preservado e comporta esse corpo; o preview de mapa usa entrada
provisória e esta prova não registrou sua posição efetiva nem a escolheu a partir
desse marcador.

O [recibo de consolidação](consumer_audit.json) confere 2046 entradas atuais
source/fixture/manifest e dez imports: zero divergências. A entrada adicional é
o backup local do mapa criado pela Store, sem alteração de código/testes/tools.
HEAD ficou 4e antes/depois de todas as provas; nenhum engine ativo no fechamento.

Uma amostra canônica: mapa 28,516 s (navegação 26,275 s), preparo 30,441 s
(navegação 24,581 s). Pico contabilizado de navegação 98.774.456 bytes no mapa e
93.295.064 no preparo, dentro do limite original; não é RSS/heap medido. Autoria
AX teve compilação de 39,375 s. Não são percentis ou FPS; são custos reais dos
produtores/preparo que continuam pendência de responsividade em F9-10. Não
atribuir essa demora apenas à suíte nem mudar geometria/corpo/caps para ocultá-la.

## Limites preservados

Sem App, caminhada, combate, oclusão, continuidade ou FPS do Bosque nesta prova.
Entrada do preview somente de mapa continua provisória até a população escolher
a entrada autorada. População/patrulha parametrizadas, síntese regional,
reconciliação, transporte de assets, ambiente limpo, release, recuperação,
latências de runtime e UX integral continuam na matriz F9. A fixture histórica
M3Native24 ainda requer migração ou retirada com cobertura atual preservada;
sua falha anterior não conta como PASS. F10, aceite de produto, master e push
continuam separados.

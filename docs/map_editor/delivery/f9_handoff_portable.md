# RagRPG — handoff portátil de F9

<!-- f9-current-ax -->
## Checkpoint vigente —29/10: composição AX e mapa do Bosque integrados

Código2248ee724c7cec6b13396eaa99f56e6cfa3e5203; dados `1bdc7301cd46ee40180b5c943f3fcfa10410dc5a`.
Branch codex/map-editor-f9; checkout
`C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5`.
Meta integral F9 ativa. Este incremento está validado; o editor e a área final
não estão concluídos. Não aplicar ao playtest nem marcar aceite humano/F10.

MapOperations/MapPanel compartilham GUI/AX/MapSession/Store para snapshots,
instâncias, transformações, vínculos, contexto/exceções, modos, histórico e IO.
Cliente real aceita screen=map, abre a janela existente, aguarda worker e retorna
map_snapshot com fonte/hash/estado. Top snapshot/source_hash continuam da peça;
hashes por ação correspondem à sessão usada. Sem setter de fonte arbitrária.
Nome pendente e histórico são preservados em falha de arquivo/rascunho/conflito.

Terra montou o arquivo `data/map_authoring/sanctuary_woods.map.json`,45.355B,
por7ações AX; reabertura/recompile2ações em outro processo, ambos exit0/log limpo.
Duas peças,47props, clearing@[0,0,0], overpass@[1280,0,0], woods_seam, forest sem
exceções. Snapshots e fontes originais intactos. Arquivo SHA256
6b8d52095b0d98ba4a436fd5b192ff732b98a8f5da02855646e7e21b9792bb4f;
fonte2407588712870e8bd1b4820e2f82638fe29fb1ce955ae5541b14320e9a2cbe20;
compilação68bd0caa6a9865067bc9a6b025aa34202ba63f4f003642f027b72d2ffded0ed6.
Captura real e recibos em delivery/evidence/f9/terra/area_composition/.
Fontes e evidências desta família preservam LF/bytes via .gitattributes.

Provas: CompositionAX31 PASS em6e; Native13 PASS em2248; CLI10/10 por modo,
reabertura2/2 e negativo que interrompe lote PASS; BordersNative32 e GameplayNative52
PASS. Regressões Composition63/CLI2/Document70 PASS; verify.ps1 editor_import1/299
PASS. As52 verificações de gameplay são de amostras existentes (ator/ponte/combate/
retomada), não do Bosque. Fonte/compilação/bytes do cliente headless e nativo iguais.

Luna escreveu rascunhos e foi interrompida por quota antes de executar. Sol recebeu
os testes por transferência, completou fixtures/oráculos e executou as provas.
Rascunhos preservados; não alegar supervisão independente Luna. Mapas só por Terra
no editor AX. UID3 novas geradas pelo engine e versionadas antes do congelamento.

Consumidor10/10 PASS do mapa real: bytes/hashes/snapshots/poses/emenda, compilação,
candidato imutável, corpo20x32, acesso a um ponto de cada apoio e marcador exato
[160,0,640] com espaço para o corpo. A prévia map-only usa início provisório até
configurar população. Não houve App/caminhada/combate/FPS do Bosque nesta entrega.
Uma execução: mapa27,846s/nav25,924s; preparo24,354s/nav22,454s; total63,547s com
hashes/IO. Custos canônicos continuam pendência real10, sem otimizar duração de suíte.

Limitações concretas antes do uso final: bordas ainda legadas; authoring_context
forest não é propagado por MapCompiler ao stage.biome (ainda ruin). Sol precisa
corrigir metadado com invariantes/compatibilidade e aplicar bordas florestais em
transação AX revisável, sem estado intermediário inválido ou hash inventado.
Layout do inspector precisa rolagem/acabamento em janela1000px. M3Native24 histórico
falha por canvas.motion/testing e2malhas retirados antes desta fatia; falha/timeout
preservados, baseline auditada. Atualizar/retirar fixture no tooling final, sem
contá-la como PASS ou perder cobertura atual. Native13/Gameplay52 cobrem os contratos
atuais escolhidos. O atalho órfão two_rooms da fixture foi arquivado após verificar
0processos desse engine; sessões/perfis preservados, sem mexer em save pessoal.

Fixture ÚNICA para --path:
`C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5/.godot/verification/e07_f1/fixture_project`.
Engine `C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/godot/Godot_v4.7.2-stable_win64.exe`,
SHA256 AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424.
Python C:/Python314/python.exe; PowerShell7.6.5. APPDATA/LOCALAPPDATA descartáveis
na fixture. Source/tests/tools/HEAD congelados em cada prova. Import07 sincronizou
mapa;2041 primários iguais source/fixture antes/depois,6imports de props incluídos
mais4imports de terreno auditados. Testes do produtor tinham2040, sem o mapa novo.
Não confundir conjuntos. Todos os processos/handles próprios terminaram.

Estado esperado após commit documental: só2backups de terreno .source.json.bak
locais não versionados; preservar. CLI de workflow/WORKFLOW_TOOLING continuam ausentes;
não copiar/adivinhar tooling externo. Antes de nova prova, Import normal em pasta
de evidência nova; -SkipImport não sincroniza o projeto inteiro. Nunca usar checkout
como --path nem sobrescrever recibos existentes. Logs com Script/Parse/ERROR falham,
mesmo com exit0. Perfil pessoal, codex/playtest, master e push ficaram intocados.

Próximo: Sol corrige metadado/bordas e expõe população/patrulha/objetivo existentes
para Terra completar o mapa viaAX. Depois prova real de jogo e latências. Síntese/
regeneração regional, reconciliação, assets passivos/ambiente limpo, recuperação,
layout/release e toda matriz F9 permanecem exigidos; nada foi transferido aF10.
Consolidação e pendências reproduzíveis:
`docs/map_editor/delivery/evidence/f9/author/ax_composition/consolidation.md` e
`open_findings.md` na mesma pasta. Receita/argv de Terra em area_composition;
consumer/run_consumer.py lê o arquivo real sem persistir fonte, usar cópia em nova
pasta para não sobrescrever o recibo. Blocos abaixo são históricos.
<!-- /f9-current-ax -->


## Vigente28/10 — emenda corrigida e retomada13 PASS

Código58350cab28da7053eba9151d448911abd5b32a5c; tudo executado na fixture única.
SurfacePick24, Geometry46, Ports92, Native20, Resume13 e2 oficiais isolados PASS.
Sol conferiu2016inputs por etapa, zero diferenças source/fixture/manifest, e viu
captura real. Não há processo/handle ativo. Nova sessão d82baa96dfdc98bcf7e74806
andou no alvo original780/780 após processo novo e re-suspendeu em3.589.468B<4MiB.
Os bloqueios anteriores de snapshot e pick foram corrigidos; seus recibos abaixo
são históricos. [Consolidação](evidence/f9/author/surface_pick/consolidation.md).

App.open/início/retomada ainda custam cerca de49s/31s/30s nesta peça e permanecem
pendência10. Uma rotaNative:46ms para pedido,120frames mediana19,2ms/p9529,4ms,
máximo115,9ms; na retomada só2frames, sem percentis úteis ou FPS geral.
RestanteF9 continua integralmente exigido. Próximo é implementar
[AX parametrizado](../contracts/f9_ax_authoring.md), depois Terra criar o Bosque
pelo editorAX. Síntese/reconciliação/assets/intercâmbio/release/recuperação e área
final não estão fechados. F10 separado; nenhum main/playtest/push/aceite implícito.

Luna executou todas as etapas antes de falhar por limite de uso, sem relatório
final; Sol consolidou a evidência. Terra também foi limitado ao tentar refinar
seu desenho, sem nova alteração ou mapa criado. Não reiniciar testes finalizados.
Código pode avançar porSol; próximos pacotesLuna/Terra retomam quando disponíveis.


## Vigente28/10 — snapshot resolvido; clique de emenda em correção

Código44a0b36439de030ab48a64aff2a26adc856fbadd, testes fac5db2f228d1f5bf11cf31a17e0b89709e730d8.
Encoding exato: checkpoint real3.594.152B dentro dos4MiB préDEFLATE, sem reduzir
colina/corpo/estado. Density33, Native20 e4oficiais(2923checks) PASS. Colina iniciou
no jogo e personagem subiu com corpo20x32. Uma rota: pedido44,128ms;120frames
mediana17,421/p9527,479/máximo136,137ms; nenhuma garantia geral deFPS.

Novo processo restaurou candidato/536apoios/828conexões/posição elevada salva,
mas o alvo seguinteXZ780/780 retorna ambiguous_surface. ResumeFAIL7/9emitidos,
13esperados; não declarar continuidade completa. Próximo: coletarhits e corrigir
WorldGeometry.resolve_surface na emenda, preservando ambiguidades legítimas,
oclusão e pisos. Não deslocar teste nem relaxartolerância. Novo runtime exige
recriar sessãoNative antesdeResume; não adulterar sourcehash do checkpoint antigo.

[Conferência Sol](evidence/f9/author/snapshot_encoding/consolidation.md) e
[relatório Luna](evidence/f9/luna/snapshot_encoding/report.md). Engine/fixture única
preservados;2014inputs atuais source=fixture, sem processos/handles ativos.
Playtest/save pessoal intactos. RestanteF9 ainda exigido: AX parametrizado,
síntese/regeneração/reconciliação, intercâmbio/asset/release/recuperação/fluidez,
mapaTerra noeditorAX e área final. F10 continua separado. Os blocos de snapshot
falho anteriores são históricos e substituídos por este estado vigente.


## Vigente28/10 — T01 integrado, gameplay bloqueado

Meta continua TODO F9 e mapa para testar. Sol código; Terra mapas via editorAX;
Luna testes. [Desenho do Bosque](f9_area_design.md) está pronto, ainda não autorado.
Código diagnóstico82cc23d17eb472f1bc21bdab0591678d4a2c2f4a, branchcodex/map-editor-f9 no mesmo
checkout .tools/map-editor-m5. Aplicação T01 de5e6f6cc; modelo19 PASS em57ffdc2;
provaGUI/menu/AX/undo/relevo nativo passou em82cc23d, mas a etapaNative FALHA:
App.start snapshot_too_large,13/14 checks PASS (20 esperados). Sem caminhada,
picking ou captura gameplay; não declarar T01 jogável nem F9-02/12 concluídos.
Diagnóstico: snapshot10.308.936B >4.194.304B,22.405 containers,634 objetos;
estágio geométrico bruto1.024.396B/536 apoios/828 conexões. Detalhes e próxima
correção no [contrato de densidade](../contracts/f9_snapshot_density.md).
Engine4.7.2 e fixture única preservadas; logs completos rounded_hill/. Não elevar
caps, reduzir33x33/220/420 ou corpo20/32. AX parametrizado ainda falta;
[próxima fatia](../contracts/f9_ax_authoring.md) prepara sua autoridade real.
Luna concluiu biblioteca/oficiais no congelamento0b2d57a; fixture liberada.
Consultar a consolidação no fim deste documento para resultados e hashes. TesteSnapshotDensity ainda rascunho
ignorado, sem UID/import/teste. Não reaplicar propostaTerra antiga nem iniciarF10.


Atualização27/10/2026. Este documento permite continuar em outro modelo/provedor,
sem depender do histórico do chat ou das ferramentas internas do Codex.
Estado: F9 EM EXECUÇÃO; não entregue integralmente e sem aceite de produto.

## O que o usuário autorizou e prioriza

“F8 terminou. Podemos começar F9.” F9 deve fechar todos os pendentes do editor,
conforme seu contrato, sem empurrá-los para F10. Adendo: sombras e acabamento que
melhorem a imersão, aproveitando a engine existente. Nenhum épico E08+ foi aberto.

Em27/10 o usuário esclareceu: duração dos testes não importa por si só. Importam
performance durante o jogo, modo AX que facilite o desenvolvimento agêntico e
mapas robustos consumidos pelo jogo. Não otimizar cronômetro de suíte como meta,
reduzir cobertura ou alterar amostra/corpo/oráculo para aparentar velocidade.
Se a rotina medida também roda no jogo, registrar perfil/escala/fase e comprovar
impacto em gameplay representativo; o tempo de um teste não é FPS.

O usuário prefere incrementos e resumos portáteis para poder trocar de modelo.
Não presumir nem aguardar um reset de cota. Os papéis podem ser assumidos pelos
executores que ele escolher: Terra6.1 implementa fatias pequenas/médias completas;
Sol decompõe, analisa, integra e trata complexidade transversal; Luna pode criar
os testes e gerenciar execução/triagem separadamente. Revisão ampla com Astra só
após terminar o editor, por iniciativa humana. Não criar chats/experimentos por
inferência. O anexo de workflow é referência, não uma ordem para abrir benchmarks.

## Localização, base e preservação

- Checkout de trabalho: `C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5`.
- Branch: `codex/map-editor-f9`.
- Runtime testado neste incremento: `4642dbf878fab4004f98141c7e2437ee11e22bd5`.
- Principal/playtest: `C:/Users/João Pedro/Documents/ChatGPT/RagRPG`.
  Possui trabalho/imports/exports/save pessoais; NÃO usar como cwd de implementação.
- Engine: `C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/godot/Godot_v4.7.2-stable_win64.exe`.
- Engine SHA256: `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`.
- Única fixture: `<checkout>/.godot/verification/e07_f1/fixture_project`.
  Reutilizar sequencialmente; sem terceiro checkout/projeto.

Usar SEMPRE o checkout explícito. Não resetar/limpar arquivos do usuário. Não
commitar .godot/.tools/builds. Sem push automático. Merge em master depende de
aceite humano explícito do candidato testado. Um PASS técnico não autoriza produto.
Não encerrar F9 ou iniciar F10 por ter terminado uma fatia.

Este checkpoint documental consolida as mudanças feitas enquanto o runtime estava
congelado; o congelamento foi LIBERADO após conclusão Luna. Seu commit é posterior
ao runtime4642dbf e não representa outra execução de testes. Inclui:
`docs/WORKFLOW.md`, `docs/map_editor/contracts/f9_ownership.json`,
`docs/map_editor/contracts/f9_terra_work_packages.md`,
`docs/map_editor/delivery/f9_resume.md` e este handoff; além do empacotamento da
proposta Terra e recibos novos de Luna. Conferir Git de novo para identificar o commit documental e deltas posteriores. Não tratar essas mudanças como lixo do worktree.

## Fontes contratuais antes de editar

Na raiz do checkout: AGENTS.md, docs/WORKFLOW.md (norma única atualizada),
docs/REVIEW_WORK_PACKAGES.md, docs/MVP.md e docs/ARCHITECTURE.md.
Depois: docs/map_editor/contracts/f9_completion.md, f9_ownership.json,
docs/map_editor/f9_requirements.md e docs/map_editor/delivery/f9.md.
Para a próxima fatia: f9_terra_work_packages.md e terrain_piece_semantics.md.
Para síntese futura: f9_regional_synthesis.md. Para a correção atual de navegação:
f9_navigation_performance.md. Todos os nomes de contratos acima ficam em
`docs/map_editor/contracts/`.

CLI de workflow e WORKFLOW_TOOLING estavam ausentes nesta base. Não adivinhar
instalação nem copiar tooling externo. A retomada foi diagnosticada com Git,
project.godot, contratos e recibos. Godot4.7.2 standard, GDScript tipado, UI pt-BR,
IDs/código inglês; sem plugin externo. Catálogo imutável, estado separado da run.

## O que existe e foi comprovado por componente

Sombras suaves de contato para atores/props; oclusão/ordem por cotas; materiais,
biomas/bordas; biblioteca/presets/favoritos; minimapa/overlays; prévia jogável real
em perfil descartável com restart/continuidade e comandos GUI/AX/CLI. Renderer
compartilhado entre editor e runtime. Campos Fire/Lightning/Phantom/Ice seguem
apoios e ordenação reais. Não generalizar isso para “toda a apresentação pronta”.
O recibo F9 distingue autoria, supervisão e pendência de cada componente.

Último código, checkpoint19: lote ALL_DIRECT compartilha prova privada de rotas
já aceitas pela autoridade, mantendo endpoints exatos, ida/volta independentes,
orçamentos e validação pública. Gauss17/512 original passou publicação no orçamento
original, corpo20/32 e1024 testemunhas públicas/movimento autorais. Pico105254480
unidades contabilizadas contra268435456; não é medição de heap/RSS. Publicação33,8s
e preparo do corpo43,5s são fases de preparação, não tempos por frame.

Consulta individual conserva Dijkstra/heap/relaxaçãoEPS/custos/desempate, completa
superfícies sob demanda, usa preparação privada e seleção conservadora de sólidos.
No cenário denso HISTÓRICO de perfil2/12: eager160389ms, preparado100731ms, mesmo
resultado integral/digest nas duas rotas, mesmos8683 estados expandidos/524360
testes no desvio. Não é o perfil do jogador20/32, nem prova de FPS ou mapa final.
Essa API também é usada pelo runtime: verificar o impacto real em jogo antes de
considerar a prioridade de performance cumprida. Não ignorar um travamento só
porque foi descoberto por teste; não otimizar a suíte por si só.

Provas autorais finais: Context11, Lazy24, Geometry46, Ports92, Batch36, Dense5
preparado e Dense5 eager. Sete recibos com2002 inputs cada,14014 sem divergência;
fixture igual, project.godot somente com VCS desativado. Organic15 é anterior:
4 inputs mudaram e7 testes/UIDs foram adicionados; compatibilidade foi documentada,
sem fingir nova execução de1024 testemunhas no hash atual.
Auditoria: `docs/map_editor/delivery/evidence/f9/author/navigation_audit.json`.
Falhas e tentativas anteriores permanecem; não apagá-las nem atribuir-lhes PASS.

## Validação concluída e reprodução

Caminho: `docs/map_editor/delivery/evidence/f9/luna/navigation_and_fields/`.
Luna concluiu no runtime4642dbf: Core8/639; FieldsNative73; GameplayNative52;
GameplayControls29;12/12 etapas oficiais/3649 checks. Tudo PASS, sem falha, timeout,
parse/script error ou exit não zero. HEAD antes/depois igual. Fonte/fixture:
14014 hashes autorais de cada lado e9998 referências atuais sem divergência.

Relatório `report.md`, SHA256
`EEB082D4CFDF3AF23A86009049773A07F5294DC797DCC7D81C01C0F68A2FF8F5`.
Os recibos autorais preservam seu HEAD f21709ae e inputs; não foram reatribuídos.
Não repetir etapas concluídas com os mesmos inputs apenas por trocar de modelo.
A supervisão não é auditoria semântica independente, FPS ou aceite de produto.

Fixture LIBERADA para a próxima tarefa autorizada. Em nova retomada, conferir se
outro trabalho começou depois deste arquivo. Nunca executar dois runners na mesma
fixture nem encerrar PID opaco/jogo pessoal. Não tocar o principal/playtest.
Os comandos abaixo são referência de reprodução; rodar novamente só por impacto
de novo delta, falha ou evidência insuficiente. Nenhuma dependência de Codex é
necessária para executá-los em PowerShell comum.

Roteiro reproduzível em PowerShell comum (substituir só nomes de evidência por
pastas novas ausentes; não reutilizar/sobrescrever recibos):

```powershell
$f9Root = 'C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5'
$f9Engine = 'C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/godot/Godot_v4.7.2-stable_win64.exe'
Set-Location -LiteralPath $f9Root
 git rev-parse --show-toplevel
 git rev-parse HEAD
 git status --short
```

Para uma reprodução justificada dos nativos, sem execução concorrente, usar
`tools/map_editor_completion/run.ps1 -GodotPath $f9Engine -Stage FieldsNative
-EvidenceDirectory <nova pasta absoluta>` com importação normal; depois
GameplayNative e GameplayControls, cada qual com sua pasta nova. `-SkipImport`
só quando source/fixture já importadas e conferidas idênticas. Não é sync geral:
esse modo copia apenas quatro arquivos legados.

A seleção oficial concluída usou `tools/verify.ps1 -GodotPath $f9Engine -F1Fixture
-SkipEditorImport -CheckTimeoutSeconds 300 -VerificationDirectory <nova pasta>
-Test @(...)`, com estes12 IDs exatos:

```text
e07_f1_geometry_test
e07_f1_actor_integration_test
e07_f1_adversarial_test
e07_f1_consumer_test
e07_f1_guard_travel_test
e07_f1_fields_test
e07_f1_ice_test
e07_f1_geometer_trace_test
e07_f1_geometer_full_test
e07_f1_non_planar_test
e07_f1_composition_test
e07_f1_presentation_test
```

Durante verificação, APPDATA e LOCALAPPDATA devem apontar para o perfil descartável
`<fixture>/.godot/discardable_profile`, restaurados por try/finally. Não usar save
pessoal. Ignorar somente linhas vazias em checks.jsonl. SCRIPT ERROR, Parse Error,
ERROR, timeout, contagem incompleta ou input divergente impedem PASS mesmo com exit0.
Se falhar, preservar logs e corrigir causa; não mudar expectativa para escondê-la.
Registrar hashes/HEAD antes/depois e escopo realmente executado. A etapa de teste
pode demorar: não é motivo para enfraquecer a validação.

## Integração atual — F9-T01

Atualização posterior ao checkpoint91dfa48: usuário autorizou a integração.
Terra já aplicou os cinco arquivos reais permitidos, preservando a ordem dos três
presets antigos e acrescentando o quarto. Código ainda não importado/compilado/
testado nesta fatia. Luna prepara dois testes novos e atualização legítima da
biblioteca. Existem mudanças de aplicação e documentos na árvore; conferir Git
antes de aplicar novamente o patch (NÃO reaplicar cegamente). Ownership/contrato
foram atualizados. Aguardar testes prontos, importação/UIDs e congelamento para a
execução coordenada na fixture única. Não há teste em execução até esse ponto.

### Proveniência da proposta inicial (agora aplicada, sem validação ainda)

Terra6.1 entregou rascunho de cinco arquivos; NÃO integrado, compilado, testado ou
aprovado visualmente. A revisão inicial de Sol conferiu localização, preservação
do candidato e que o patch se aplica sem conflito, sem aplicá-lo.

Cópia portátil em
`docs/map_editor/delivery/evidence/f9/author/terra_organic_proposal_01/`:
`manifest.json` com SHA-base/proposto; `delivery.md`; cinco cópias `.gd.txt`; e
`proposal.patch`. Esse pacote não depende da pasta ignorada original
`.godot/f9_shadow_draft/terra_organic/`. Não importar/executar esses textos como
código antes de revisar, conferir que a fixture continua livre e transferir propriedade.

Alvos: terrain/brush.gd, terrain/terrain_panel.gd, terrain/organic_example.gd novo,
library/editor_preferences.gd e library/library_model.gd, sob scripts/map_authoring.
Novo modo rounded_hill com peso(1-u²)^3 e preset; exemplo uma camada33x33/passo50,
domínio1600, centro800/800, raio420, altura220 em DOIS traços110 sem aumentar força
máxima128. Pinta caminho curvo pelo Brush existente. GUI/AX compartilham operação;
aplica uma vez pela Session/undo e recusa documento ocupado. Sem novo shader,
asset obrigatório, schema/compilador/física ou construção manual de polígonos.

Congelamento liberado: conferir SHA-base no manifesto, registrar dono
nominal das fontes/novo .uid, revisar o patch e integrar sem sobrepor mudanças
concorrentes. Gerar/copiar somente UID autorizado pela fixture. Luna cria testes
fechados da fatia, Terra corrige falhas locais e Sol confere cobertura/integração.
A especificação está em delivery.md: perfil/centro/proteções/stroke/preset, conteúdo
ocupado, undo, equivalência GUI/AX, compilação real, apoio/clique/navegação e inspeção
nativa. Não chamar proposta de entrega runtime nem encerrar F9-02/12 só por isso.

## Restante obrigatório e limitações concretas

A matriz F9-01–12 e o contrato continuam íntegros. Ainda falta acabamento orgânico
integrado/humano; síntese regional por seed com máscaras e conservação de entidades;
AX/CLI e UX completos; encontros/reconciliação; bundle/dependências em ambiente
limpo; recuperação/cancelamento; responsividade de gameplay/preparação acionável;
apresentação restante, export release/continuidade e área temática final completa.

Não esquecer: algumas mortes/VFX vinculados ao mundo ainda usam caminhos legados
ou suprimidos; sync de atores pode tornar morto visível de novo. Transações de
checkpoint medidas em8–15s e preparação corporal43s precisam ser avaliadas por
seu efeito perceptível, com feedback/cancelamento e sem travar a partida. São
pendências, não prova de defeito em todo mapa ou autorização de nova mecânica.

Geração regional tem contrato em f9_regional_synthesis.md: proposta sobre a raiz
inteira piece/map/population/patrol, máscara compartilhada, preservação por
influência geométrica/footprint/segmento e clone de peça por instância. Reconciliar
referências sem escolher piso global mais próximo. Receita passiva não executa
na importação. Contrato ainda não entrega consumidores; particionar antes de delegar.

## Próximo incremento e regra de encerramento

1. Conferir o relatório Luna concluído e o Git atual, sem repetir testes sem motivo.
2. Preservar o checkpoint documental e a referência ao runtime4642dbf testado.
3. Transferir propriedade, integrar/verificar F9-T01 e medir o resultado no jogo.
4. Continuar a matriz com fatias delimitadas, sem redefinir falta como opcional.
5. A cada incremento atualizar resumo, base/hash, arquivos, verificações e pendências.

Nenhuma autodeclaração de modelo substitui aceitação verificável. Se um item não
foi implementado ou não foi validado, registrar precisamente e continuar quando
possível. Não inventar PASS, completude, benchmark ou cronograma de reset.


## Meta ativa28/10 e congelamento T01

A meta humana agora é entregar todo o restante de F9 e um mapa para testar.
Sol assume código; Terra cria mapas exclusivamente via editor AX; Luna cria e
supervisiona testes. O limite anterior de mais uma integração foi substituído
pela meta explícita. F10 e aceite/merge humano continuam separados.
T01 importado com Godot4.7.2, sem Script/Parse/ERROR. UID do módulo gerado pela
engine; sidecars dos testes preparados por Luna e aceitos na importação.
Inputs serão congelados no commit desta integração, antes dos testes dirigidos.
Ainda não declarar PASS de modelo/nativo nem conclusão de F9-02/12.


### Consolidação vigente28/10 — lote encerrado, correção estrutural pendente

Último código congelado0b2d57a39a55c84ae2b3380714830f41440c6ce5; o SHA atual de
Git pode ser checkpoint documental posterior. Model19, Library50 e LibraryNative53
PASS; tools/verify selecionou snapshotF3(50), geometriaF1(33) e atorF1(193), todos
PASS, sem erro/timeout. [Relatório Luna](evidence/f9/luna/rounded_hill/report.md)
e [conferência Sol](evidence/f9/author/rounded_hill_consolidation.md). Rehash Sol
confirma fonte/fixture atuais sem divergência nos2008 inputs de cada manifesto;
reuso histórico tem deltas explícitos na conferência. Nenhum processo ativo;
fixture liberada. Não repetir este lote por hábito antes de uma mudança nova.

Runtime T01 ainda não jogável: NativeFAIL snapshot10.308.936B >4MiB antes de
picking/caminhada. Resolver encoding exato do grafo com caps/identidade/ciclos/tipos,
provar roundtrip/continuidade e a mesma App33x33/20x32 antes de consumidores.
Rascunho de17 testes preservado como texto inerte em
[evidência portátil](evidence/f9/author/snapshot_density_draft_01.gd.txt); não rodado.
Depois completar AX parametrizado, autoria Terra do Bosque e TODOS os pendentes
F9-01–12. F10 depende de conclusão e autorização própria; não transferir faltas.

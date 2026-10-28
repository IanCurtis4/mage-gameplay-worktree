# RagRPG — handoff portátil de F9

<!-- f9-current-ax -->
## Checkpoint vigente — 28/10: autoria AX integrada e dois terrenos criados

Candidato de código: `17516a20f959fabdecf0af76777824d379d98f42`.
Candidato com os dados Terra: `0acc94ef6530d560eb1695de699b40b53dd8cdb2`.
Branch `codex/map-editor-f9`; checkout
`C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5`.
A meta é TODO F9, ainda em execução. F10 permanece separado.

Sol implementou comandos AX de peça/grade/camada/ponte/conector com os mesmos
operadores da GUI, histórico, proteção, confirmação e Store. O cliente real
`res://scripts/map_authoring/agent/ax_session.gd` aceita ações passivas, aguarda
compilação e retorna estado/hashes/diagnósticos. Não recebe fonte pronta.
Objetos, contexto, composição, população e patrulha ainda precisam dos seus
comandos parametrizados para Terra completar o conteúdo.

Luna: Authoring30 PASS, Native15 PASS, CLI nativo10/10, headless/novo processo/
negativos PASS; `verify.ps1 editor_import` PASS, inclusive após integrar os dados.
Sol conferiu hashes e imagens. Os dois terrenos foram criados por Terra via AX
(8/27 ações), salvos, reabertos e recompilados sem erros; replay byte a byte igual.
Fonte A: `data/map_authoring/sanctuary_woods_clearing.source.json` (15.116B).
Fonte B: `data/map_authoring/sanctuary_woods_overpass.source.json` (8.142B).
Receitas, hashes completos e imagens: `docs/map_editor/delivery/evidence/f9/terra/area_terrain/clean_replay/`.

Prova dirigida do consumidor: os dois dados ligados pela emenda prevista passaram
Maps.compile, Candidate.create e Candidate.prepare, com raio20/altura32 e gate
de todos os apoios acessíveis. Foi composição efêmera de TESTE; não é composição
de produto criada por AX. Não houve App, caminhada, combate ou medição de FPS.
Custo de uma execução: terrenos229/97ms, mapa15,518s e preparo18,914s (navegação
14,715/17,324s). São fases canônicas de preparação, não fluidez durante o jogo.
Continuam pendência de responsividade/cancelamento; não otimizar duração de suíte.

Fixture ÚNICA e obrigatória em qualquer --path:
`C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5/.godot/verification/e07_f1/fixture_project`.
Engine `C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/godot/Godot_v4.7.2-stable_win64.exe`.
NÃO executar o cliente contra o checkout não importado: a primeira autoria Terra
fez isso e emitiu erros de classe; foi preservada e substituída por replays limpos.
Logs com Script/Parse/ERROR não aprovam nada, mesmo com exit0/ok no JSON.
UIDs já versionadas foram geradas pelo engine. Nenhum processo segue ativo.

A política LF em `.gitattributes` uniformiza os quatro *.png.import de terreno.
Os bytes deste checkout agora são iguais aos blobs Git e à fixture testada, sem
alterar configurações de textura. Antes, CRLF/LF mudava o digest do pacote.
Em checkout antigo, conferir/normalizar somente esses quatro metadados antes de
comparar pacotes; não adulterar hash de pacote/perfil antigo. Ainda faltam bundle
de assets/ambiente limpo/export e os demais requisitos F9-09/11.

Próximo: expor ObjectOperations/contexto e composição/população/patrulha por AX;
Terra coloca conteúdo e monta área pelo editor; Luna prova ida/volta e gameplay.
Síntese/regeneração regional, reconciliação, recuperação, fluidez e release seguem
obrigatórios em F9. Não fechar a meta por esta fatia nem mover requisitos a F10.
Source/fixture estão sincronizados pelo Import09; há2020 inputs primários nesse
manifesto (imports têm recibos próprios). Sem mudanças no playtest/save pessoal,
master, push ou aceite humano. Resumos/documentação posteriores não alteram dados.

Detalhes: `docs/map_editor/delivery/evidence/f9/author/ax_authoring/consolidation.md`;
consumidor: `docs/map_editor/delivery/evidence/f9/luna/ax_authoring/verify_sources/consumer_02/source_consumer_report.md`.
Os blocos abaixo são históricos e não substituem este estado vigente.
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

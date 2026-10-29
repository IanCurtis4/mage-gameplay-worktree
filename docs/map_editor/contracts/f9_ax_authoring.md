# F9 — autoria semântica pelo editor AX

Escopo autorizado F9-01/07/09/12, meta humana28/10. Código Sol; Terra cria
mapas somente por comandos AX do editor, sem escrever fontes prontas. Luna
prepara provas e acompanha execuções congeladas. Primeiro consumidor é o
[Bosque do Santuário](../delivery/f9_area_design.md), com dois terrenos criados.
Base do produtor validado17516a20f959fabdecf0af76777824d379d98f42. Primeira fatia
implementada:30 checks de autoria e15 nativos, cliente/roundtrip/negativos e
importação aprovados por impacto. Terra criou duas fontes pelo editor AX; demais
produtores continuam pendentes. Ver delivery/evidence/f9/author/ax_authoring/consolidation.md.

## Resultado e autoridade

Completar comandos parametrizados nos providers existentes, com IDs estáveis,
forma fechada e resultados com IDs/hashes/diagnósticos. A apresentação AX exige
modo AX; alternância é editorial. GUI e AX usam os mesmos métodos de operação,
DocumentSession/MapSession/etc e Stores existentes, incluindo validação, locks,
proteções, conflito externo, undo e confirmação explícita. Não oferecer comando
de substituir a fonte ou aplicar JSON arbitrário como atalho para criar mapas.
Compilar continua na autoridade canônica. Nenhuma fórmula/física duplicada.

## Primeira fatia completa: peça e terreno

TerrainOperations propõe sobre snapshot: criar grade (ID, nome, origem XZ,
colunas/linhas, passo e altura), adicionar ponte (ID, layer, retângulo e cota),
upsert/remove de conector e proteção editorial da camada. GUI add_grid,
add_bridge e save/remove_connector devem chamar a mesma operação que AX.
Parâmetros desconhecidos/NaN/ID duplicado/camada travada/proteção violada
falham sem modificar fonte/histórico. Limites iguais aos controles existentes;
conectores continuam sujeitos à prova geométrica na compilação.

IDs terrain/grid/create, terrain/layer/select, terrain/bridge/create,
terrain/connector/upsert, terrain/connector/remove, terrain/brush/stroke.
Brush mantém contrato e presets T01; seleção explícita não modifica fonte.
Piece provider: piece/document/new, piece/document/name, piece/document/open,
piece/document/save, piece/history/undo e piece/history/redo. Novo/abrir com
alterações exige confirm_discard=true e preservação de rascunho bem sucedida;
salvar usa Store e hash esperado da leitura, nunca sobrescreve destino novo
já existente. Não substituir preservação por parâmetro force.

## Transporte para agentes e CLI

Um cliente SceneTree monta o shell real e sua apresentação AX, recebe ações
passivas limitadas, roteia para provider da tela, chama ax_invoke e retorna
resultado por ação, snapshot final, hashes e diagnósticos. Não transforma
receita diretamente em fonte, não chama operações fora de AX, não executa
scripts recebidos. Abrir/salvar são comandos normais do editor. Esse cliente
permite operação reproduzível pelo agente em ambiente gráfico ou headless;
a prova nativa deve também mostrar a apresentação real e o mesmo hash.
Erros interrompem lote subsequente; alterações já aplicadas têm histórico.
Falha de comando individual nunca aplica documento parcial.

Depois: objetos parametrizados sobre ObjectOperations; mapa sobre snapshots
imutáveis e links; população e patrulha nos respectivos produtores, propostas
com revisão/confirm e reconciliação explícita. Nenhum desses itens é fechado
por esta primeira fatia. Geração regional/intercâmbio seguem seu contrato.

## Provas exigidas

Criar duas grades, seleção/traço, ponte/conectores, locks, conflito/erro sem
histórico extra, undo/redo, nome/save/open e descarte confirmado; comparação
GUI/AX/CLI de mesma fonte (IDs explícitos), nativo/roundtrip, consumidor Terra
sem edição de JSON. Cobertura/regressões escolhidas por impacto. Medir ações
no jogo separadamente da preparação. Atualizar matriz sem fechar F9 inteiro
até comprovar seus demais requisitos.

## Especificação executável da fatia AX01 —28/10

Produtores Sol sobre0b80ca6, checkout/branch preservados. Ownership em
f9_ownership.json; testes novos Luna. Comandos terrain recebem exatamente:

- grid/create: layer_id, name, origin_xz[2], columns, rows, sample_spacing, height.
- layer/select: layer_id; layer/lock: layer_id, locked (destravar é explícito).
- layer/protection: layer_id, region_ids de regiões já existentes nessa camada.
- bridge/create: surface_id, layer_id, origin_xz[2], width, length, height.
- connector/upsert: todos os campos de SourceSchema.FIELDS.connectors.
- connector/remove: connector_id.

Propostas são puras e fechadas. Grade usa limites dos controles2..257, passo4..256,
origem±8192 e altura±512. Ponte4..1024 em largura/comprimento/cota, folga100.
Conector tem normal cardinal e kind walk do formulário atual; largura4..8192,
folga12..8192, posição±8192. IDs de camada/piso não podem colidir. No-op não
acrescenta undo. Conector verifica locks de destino e origem ao ser transferido.
Proteção usa as regiões existentes e o mesmo pincel; ponte recusa interseção com
região protegida. Máscaras por canal e criação/reconciliação regional continuam
nos escopos05/09; não afirmar que este setter as implementa.

Piece/document/new exige document_id,name,confirm_discard; name exige name;
open exige path,confirm_discard; save exige path; undo/redo não têm argumentos.
Campo desconhecido/ID inválido falha antes da preservação. Gravação do nome ainda
em edição é persistida antes de entrar no histórico; falha de gravação preserva
fonte/histórico. Open lê candidato antes de substituir e não descarta por erro.
Fontes semanticamente inválidas continuam abríveis para diagnóstico/reparo na
mesma autoridade; compilação continua obrigatória para publicação.

Transporte: scripts/map_authoring/agent/ax_session.gd é SceneTree e monta Shell
real. Godot --path FIXTURE --headless --script res://scripts/map_authoring/agent/ax_session.gd
-- --ax-request=RECEITA --ax-result=RESULTADO. Para captura nativa, omitir headless,
usar gl_compatibility e --ax-capture=PNG. Resultados/capturas exigem destino novo.
Receita passiva fechada: {"ax_version":1,"actions":[{"screen":"piece" ou "terrain",
"id":"ID do comando","parameters":{...}}]}; no máximo4096ações e teto StrictJSON.
Nenhuma execução de script recebida ou substituição genérica da fonte.
Resposta contém resultado/hashes por ação, snapshot real e diagnósticos; primeiro
erro encerra o lote. Alterações anteriores seguem no histórico; atomicidade é por
comando, não pelo lote inteiro. Objetos/composição/populações não estão expostos
por este cliente ainda. Esta descrição é contrato, não alegação de testes PASS.

O cliente também aceita a ação existente terrain/compile_piece com parâmetros
vazios. Aguarda o worker normal do painel e retorna seu resultado canônico antes
de continuar (proteção300s), mantendo cancelamento/stale/diagnóstico do produtor.
Não retorna uma compilação iniciada como se já tivesse sido concluída. Resultados
por ação omitem cópias integrais data/package; o snapshot final contém a fonte.


## Segunda fatia — objetos, contexto e marcadores (base8601af84)

Sol código; Luna testes; Terra acrescentará conteúdo após a validação. Objetos
parametrizados chamam ObjectPanel.apply_operation/ObjectOperations.propose. IDs:
objects/place, move, translate, rotate, duplicate, remove, group, ungroup, lock,
hide e group/state; parâmetros e defaults do produtor, agora com forma fechada.
objects/select {ids} e objects/surface/select {surface_id} são estado editorial.
objects/scatter/preview recebe parâmetros de scatter; objects/scatter/apply exige
proposal_hash, confere base atual e recalcula pela mesma autoridade; discard {}.
GUI mantém o mesmo fluxo de prévia/confirm e operações. IDs novos retornados em
added_ids/removed_ids; dados completos continuam nos snapshots, sem copiar fonte
por ação. Nenhum comando aplica fonte JSON genérica.

ContextOperations propõe sobre snapshot validado. piece/context/rules/set recebe
biome_ids,allowed_species,allow_rare; preserva áreas. piece/context/area/upsert
recebe region_id,layer_id,min_xz,max_xz,allowed_species,allow_rare,reserved (0/1
record completo de PieceContext.RESERVED). Retângulo positivo no intervalo±8192,
sem sobrescrever região de outro propósito; locks da camada origem/destino.
area/remove {region_id} limpa as referências de proteção da região removida.
Seleções de espécies/reservas usam catálogo existente. piece/context/options {}
expõe as opções passivas para o agente. piece/socket/upsert usa os campos atuais
SourceSchema.FIELDS.sockets e valida a geometria pelo compilador existente;
piece/socket/remove {socket_id}. Formulários GUI chamam os mesmos produtores.
O contexto global pode mudar sem alterar geometria; áreas/marcadores obedecem locks.

Shell anuncia/roteia o contexto de sua peça. O cliente AX amplia screen para
objects, abrindo a janela real pela ação existente piece/open_objects e roteando
pela Presentation correspondente; nenhuma instanciação paralela de sessão nem
bypass de AX. A captura mostra a tela de objetos quando usada por último.

Provas: equivalência GUI/AX com IDs e revisão iguais; catálogo/seleção explícita;
assentamento em rampa/piso superior; place/move/rotate/duplicate/remove/groups;
lock/proteção/IDs/argumentos ruins sem histórico parcial; scatter preview/hash/
stale/discard/undo; regras/áreas/reservas/marcadores/locks, arquivo e reabertura;
cliente headless/nativo sobre o editor real; regressões de objetos/contexto por
impacto. Sem encerrar composição/população/patrulha ou F9 por esta fatia.


## Terceira fatia — composição e contexto de mapa (basebbd3597b)

Sol código/integração; Luna novos testes de dono exclusivo; Terra só consome após
liberação. MapOperations.propose(source,operation,parameters,piece_source={}) é puro,
valida MapDocument e retorna data/output_hash/IDs sem modificar fonte. GUI e AX
aplicam pela mesma MapSession. Snapshot de peça vem somente do PieceStore no painel;
o argumento interno piece_source não é um setter público AX.

IDs públicos/forma fechada:
- map/document/new {document_id,name,confirm_discard}; document/name {name};
  document/open {path,confirm_discard}; document/save {path}; history/undo|redo {}.
- map/piece/add {path,instance_id,position_xz,rotation_quarters}. Snapshot lido e
  validado, deduplicado pelo hash; identidade de instância explícita. Operação
  interna instance/add omite path e recebe a peça já lida como quarto argumento.
- map/instance/select {instance_id} é editorial; map/instance/transform recebe
  {instance_id,position_xz,rotation_quarters}; map/instance/remove exige
  {instance_id,confirm_remove}. Remove referências de vínculos/bordas/exceções,
  preserva snapshots de biblioteca e permite undo completo.
- map/link/upsert recebe todos os campos de MapDocument.LINK; map/link/remove
  {link_id}. Ambas as instâncias e conectores devem existir. Compilação continua
  autoridade de geometria/compatibilidade e vínculos conflitantes.
- map/mode/set {mode} manual/recipe; map/context/set
  {biome_id,instance_id,rules,reason}. instance_id vazio só muda bioma e exige
  rules/reason vazios; caso contrário substitui exceção dessa instância ou remove
  com rules vazias. Context.validate_map mantém regras/motivo/manual e warnings.
- map/compile_map {} usa o worker real existente; cliente aguarda conclusão/stale.
  map/borders/apply mantém seu contrato atual de hash esperado e comando fechado.

IDs/source/fields desconhecidos, coordenada não finita/fora±16000, rotação não
inteira0..3, referência ausente e confirmação falsa recusam sem histórico parcial.
Posições usam o mesmo intervalo da GUI, preservando frações sem arredondamento de
seleção. Forma interna de operação coincide com sufixo público, salvo piece/add
→ instance/add e document/name → name. File/save usa hash esperado da abertura;
novo destino AX existente falha, GUI só sobrescreve após FileDialog e hash lido.
Novo/abrir AX alterados exigem confirm_discard e preservar rascunho com sucesso.
Nome pendente deve sobreviver a falha de arquivo sem mutar histórico parcial.

Cliente aceita screen=map, abre a janela existente por piece/compose_map, usa sua
Presentation/MapSession real e retorna map_snapshot com fonte, source_hash e estado
(caminho/dirty/histórico/seleção); cada ação recebe hashes da sessão correspondente.
source_hash/snapshot/estado de topo continuam identificando a peça por compatibilidade;
map_snapshot identifica a composição. Captura final escolhe o último viewer usado.
Não substituir o documento do mapa com JSON arbitrário nem compilar fora do worker.

Provar GUI/AX/CLI/roundtrip com IDs/hash iguais; duplicação de snapshot, transformação,
vínculos/remoção/referências/undo, modos/contexto/exceções/warnings; campos inválidos,
NaN/range/ID/ref/confirm/stale/conflicto de disco preservando fonte; fluxo nativo e
captura; regressão de composição/contexto/bordas pertinente e verify.ps1. Terra
montará o Bosque no passo seguinte, com forest e entrada de população ainda pendente.
Não fechar AX global, geração/regeneração, intercâmbio, desempenho ou F9 nesta fatia.


## Bioma de runtime e bordas em lote — base0eb9b5c5,29/10

Correção de contrato existente: MapCompiler propaga authoring_context.biome_id
não vazio ao único stage do manifesto. Contexto ausente/vazio mantém ruin legado;
não deduz bioma de arte/perfil nem restringe os IDs adicionais já permitidos.
O validador de pacote confere shape/referências do contexto e coerência de biome.
Pacotes anteriores com contexto forest e stage ruin são recusados como inválidos,
sem apagar ou regravar bytes. Legados sem contexto continuam aceitos. Formato5 e
compiler_revision v5 permanecem: corrige valor de um campo existente, sem mudar
schema, geometria ou fórmula. Documentar o novo hash de pacote, fonte inalterada.

BorderOperations.apply_batch(source,commands) propõe alterações fechadas pela
mesma apply existente; lote1..529 (=32perfis+496transições+decoração) e entries
Dictionary. Inválido em qualquer passo retorna falha sem mutar o source. Session
apply_borders(commands,expected_source_hash,pending_name=null) valida base/nome e
aplica uma vez; apply_border é wrapper de1. Diff before/after e command_count
retornados. Undo/redo integral, no-op sem novo histórico, proposta e source separados.

MapPanel.apply_borders(commands,expected_source_hash) compartilha Session e nome
pendente com GUI/AX. Novo comando map/borders/apply_batch recebe exatamente
{expected_source_hash:hash,commands:array}; singles preservam contrato anterior.
GUI oferece Aplicar borda a todas as peças sobre o mesmo produtor; respeita a
seleção Herdar por clear_instance_profile para cada instância. O inspector passa
a ter rolagem própria para que os controles finais não fiquem cortados. Nenhum
setter genérico de fonte, preview importado, novo perfil/asset ou colisão alternativa.

Provar bioma explícito/fallback, tamper rehashed/legado incoerente rejeitado sem
mutação, propagação ao consumidor de população; lote puro/diff/hash/invalid-last/
shape/cap/stale/no-op/undo/redo/nome pendente e equivalência GUI/AX/CLI; nativo com
controles/rolagem e mapa/bordas reais. Depois Terra aplica forest_rootbank_v1 às
duas instâncias do Bosque em um lote AX, compila/salva/reabre e entrega hashes.
Corpo real, apresentação e latências ainda exigem suas provas; sem fecharF9.

CLI legado mantém --border-command e acrescenta --border-batch com os mesmos
5argumentos (flag, fonte, pedido, destino, hash anterior ou -). Pedido de lote
contém expected_source_hash/commands e usa Session.apply_borders; leitura do
pedido reutiliza o limite StrictJSON de SourceStore antes de alocar o arquivo.
O cliente AX via CLI continua outra superfície equivalente sobre o mesmo painel.

## Quarta fatia — encontros e patrulhas (base ff61b57b, 29/10)

Sol implementa; Luna escreve testes de dono exclusivo. Terra consome somente
após liberação técnica e sempre pelo AX real. Sem nova espécie, fórmula, quest,
limite maior ou nova geometria. Os compiladores canônicos continuam a validar
contexto, corpo, rota, origem/recompensa, plano aplicado e leash.

PopulationOperations.propose e PatrolOperations.propose são propostas puras,
fechadas por operação, seguidas de Document.validate e Session.apply uma vez.
Invalid-last/nested/NaN/ref/confirm não podem alterar fonte ou histórico; no-op
não cria undo. Retornam output_hash, entity_id e added_ids/removed_ids. GUI usa
os mesmos produtores. Não existe comando para substituir o documento completo.

População expõe os sufixos abaixo sob population/:

- document/new {document_id,name,confirm_discard}, document/name {name},
  document/open {path,confirm_discard}, document/save {path}, history/undo|redo {};
- map/import {path}: snapshot validado pela MapStore/MapCompiler, apenas quando
  ainda não há mapa. map/query {} devolve hash de mapa/pacote, bioma, apoios com
  vertices_xyz e sockets com position_xyz, a partir do pacote real do canvas;
  catalog/options {} devolve o catálogo existente;
- entrance/set com PopulationDocument.ANCHOR;
- brush/upsert, exclusion/upsert, interaction/upsert com os respectivos records
  BRUSH/EXCLUSION/INTERACTION completos, IDs explícitos e nested fields fechados;
- brush/remove {brush_id,confirm_remove} remove também seus slots, como a GUI;
  exclusion/remove e interaction/remove usam o ID correspondente e confirmação.
  Referências de portal/site após remover interação ficam para diagnóstico no
  compilador, sem reparo inferido;
- slot/upsert com SLOT completo exige fixed=true; criação/edição manual é fixa.
  Slots gerados só vêm da prévia canônica. slot/pin {slot_id,fixed} e
  slot/remove {slot_id,confirm_remove};
- brush/select {brush_id}, slot/select {slot_id}, surface/select {surface_id}
  são editoriais; surface_id vazio seleciona todos. IDs de apoio vêm da consulta;
- plan/preview {}, plan/apply {expected_source_hash,proposal_hash,confirm_apply},
  plan/discard {}, compile {}, cancel {}. Preview/compile iniciam os workers
  existentes e recusam um segundo job. A assinatura privada da proposta liga
  base_hash, hash da data e diff; apply confere assinatura fornecida, base atual,
  confirmação e assinatura recalculada antes de um único Session.apply.
  Resultado/snapshot expõe proposal_hash e diff, sem setter de proposta AX.

Patrulha expõe sob patrol/: document/new/name/open/save e history/undo|redo com
os mesmos campos; population/import {path,confirm_discard}, map/query {},
route/upsert com PatrolDocument.ROUTE completo e waypoint arrays fechados,
route/remove {patrol_id,confirm_remove}; waypoint/upsert com patrol_id mais
WAYPOINT completo, waypoint/remove {patrol_id,point_id,confirm_remove},
waypoint/move {patrol_id,point_id,direction} com direction inteiro -1 ou 1.
Upsert de ponto novo acrescenta ao fim; edição preserva posição; move no limite
é no-op. route/select {patrol_id}, surface/select {surface_id} são editoriais;
compile {} e cancel {} usam a thread real e o hash de revisão já existentes.
Modo, espera, ordem e atribuição de slots da GUI passam pelo mesmo produtor.

Novos/abrir/importar substitutivo validam o candidato antes de descartar e
exigem confirmação AX quando dirty; falha de preservação de rascunho interrompe
substituição. Save usa o hash dos bytes realmente lidos pela Store; novo destino
AX existente é recusado. GUI FileDialog pode confirmar sobrescrita pela mesma
save_document com hash observado. Falhas não mudam caminho/saved_hash/histórico.
Nome explícito aparece nos dois painéis. Sessões expõem can_undo/can_redo.

O cliente AX aceita screen population/patrol, abre as janelas existentes por
map/open_population e population/open_patrols e usa suas apresentações/sessões.
Não instancia outro painel nem injeta fonte. Workers preview/compile são
aguardados e o resultado final é retornado, com cancel/stale. Cada ação usa o
hash da sessão correspondente; snapshots population_snapshot/patrol_snapshot
incluem fonte, estado, diagnóstico e assinatura da proposta quando houver.
Campos de topo continuam identificando a peça por compatibilidade. Captura
mostra a última tela real e esconde janelas auxiliares acima dela.

Provar modelo puro, GUI/AX, documentos/conflitos/rascunho, IDs/nested/refs,
manual fixo/remoção de brush, undo integral, proposta stale/adulterada/confirm,
rotas/espera/ordem/slots exclusivos, workers e consumidor. CLI nativo/headless e
roundtrip devem ter os mesmos hashes. Luna é dona dos testes novos
map_editor_encounter_authoring_test.gd e map_editor_encounter_authoring_ui_test.gd;
UIDs somente geradas pelo engine. Regressão Population/Patrol/Context e
verify.ps1 por impacto. Ainda não fecha reconciliação entre revisões, geração
regional, performance, área final ou F9 integral.

Campos concretos de map/query: map_source_hash, map_package_hash, biome,
surfaces[{surface_id,vertices_xyz}] e sockets[{socket_id,kind,surface_id,position_xyz}].
Na importação de mapa para encontros, o pacote recém-validado é repassado somente
durante o Session.apply síncrono, com source_hash exato; refresh evita recompilar
esse mesmo snapshot. Não é cache persistente ou fechamento de F9-10.

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

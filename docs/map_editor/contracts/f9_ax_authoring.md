# F9 — autoria semântica pelo editor AX

Escopo autorizado F9-01/07/09/12, meta humana28/10. Código Sol; Terra cria
mapas somente por comandos AX do editor, sem escrever fontes prontas. Luna
prepara provas e acompanha execuções congeladas. Primeiro consumidor é o
[Bosque do Santuário](../delivery/f9_area_design.md), ainda não construído.
Base atual58350cab28da7053eba9151d448911abd5b32a5c, T01econtinuidade validados
porimpacto; fixture liberada. Esta nota não declaraAXnovo implementado/validado.

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

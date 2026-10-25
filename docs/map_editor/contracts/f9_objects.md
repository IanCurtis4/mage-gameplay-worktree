# F9-01 — engenharia de objetos dentro do contrato aprovado

25/10/2026. Especificação de implementação Sol, não certificado de entrega.
[Produto autorizado](f9_completion.md), [dono nominal](f9_ownership.json).
Consumidores só entram após a correção compartilhada F9-04 passar na regressão.
Não altera renderer/projeção, fórmulas, recompensas ou propriedade do catálogo.

## Fonte e autoridade

Usar placements/dependencies já existentes na fonte1. Cada placement conserva
placement_id, definition_id, revision, position_xyz, rotation_y e surface_id.
Rotação de autoria será expressa em graus e validada pelo catálogo. Definições
bloqueantes só aceitam quartos de volta; decoração pode admitir outras rotações
somente com apresentação correspondente. Instâncias não editam a definição.

Metadados editoriais opcionais versionados guardam grupos, travas e ocultação;
fontes antigas sem extensão não ganham campos/hash ao abrir. Grupos identificam
placements sem propriedade compartilhada mutável. Duplicar remapeia identidade;
uma operação de grupo é uma ação de histórico. Ocultar na autoria não apaga o
objeto publicado nem permite publicar bloqueio invisível. Trava protege também
AX/CLI/scatter/transformações em grupo. IDs/grupos não dependem da ordem do array.

Catálogo passivo local com revisão/hash, origem/licença, categoria/biomas,
sprite/dependências, pivô, dimensões e envelope. Entradas devolvidas por cópia.
Ausência/adulteração de definição/asset falha explicitamente. Objeto não contém
script, cena, callback ou outra execução remetida. O catálogo publicado continua
confiável localmente; transporte de imagens/bytes precisa das validações F9-09.

Assentamento resolve a camada/superfície escolhida pelo kernel canônico, inclusive
ponte sobre passagem inferior. Compilação confere altura, inclinação admitida,
footprint, revisões e proteção de passagem; não troca de piso silenciosamente.
Snap é parametrizado e visível. Decoração não recebe collider por folha.

## Capacidades e apresentação

Cada definição declara separadamente decoração, corpo, ataque/LoS e oclusão
visual. As combinações entregues precisam corresponder às capacidades reais do
runtime; não anunciar máscara independente usando um volume que bloqueia tudo.
Rochas/troncos sólidos usam o envelope geométrico compartilhado; arbustos e
acabamento vegetal são decoração. Copa visual não amplia o collider do tronco.
Ocultar/fazer fade por câmera nunca remove bloqueio de gameplay.

Compilação emite volumes e descritores visuais vinculados ao mesmo source_hash,
com dependências por bytes. Composição transforma ambos uma única vez e mantém
IDs por instância. Peça, mapa, prévia de atores e export consomem os mesmos dados.
Sprites mantêm pivô no contato com o chão, escala de mundo, profundidade e leitura
em terreno claro/escuro; inspeção nativa comprova asset e envelope no jogo.

## Operações/provas

APIs comuns de colocar, selecionar/inspecionar, mover, girar, duplicar, agrupar,
remover e scatter recebem parâmetros e retornam proposta/diagnóstico/hash.
GUI, AX e CLI aplicam essa proposta pela sessão existente. Nenhum erro deixa
histórico ou fonte parcialmente modificados. Scatter tem seed/stream próprios,
quantidade, espaçamento, regiões/exclusões e budget; conserva pins, entradas,
conectores e rotas protegidas. Quota impossível mostra déficit, sem reduzir
silenciosamente o pedido. A proposta é revisável antes do commit.

Provar roundtrip/save/undo/redo/import/export, catálogo alterado/asset ausente,
camada/trava/grupo, snap/suporte/inclinação, rocha impedindo movimento/ataque,
vegetação sem collider, passageiro sob ponte e objeto no piso superior, seed e
ordem estáveis, exclusões e quota impossível. Verificar witness de navegação
livre quando o centro geométrico de uma superfície foi ocupado por um objeto.
Este contrato não elimina as demais linhas da matriz F9 nem abre F10.

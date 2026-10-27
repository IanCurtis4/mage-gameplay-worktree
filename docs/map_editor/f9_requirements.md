# F9 — matriz de completude em execução

Autorização25/10/2026 e base/propriedade no [dispatch](contracts/f9_dispatch.md).
Piso obrigatório [F9-01–12](contracts/f9_completion.md); confrontar fontes e código.
Estados iniciais são diagnóstico, não declaração de que a implementação já passou.
Recibos F0–F8 ficam históricos e intactos. Provas novas devem identificar SHA,
engine, inputs, resultado, logs e limitações. Esta matriz será expandida ao
encontrar requisitos adicionais nos consumidores; nenhuma linha pode ser removida
para ocultar uma falta. Fonte primária comum: [arquitetura](architecture.md),
[validação](validation.md), [autoria](authoring_modes.md).

| Requisito | Origem adicional | Estado comprovado na base / ação necessária | Implementação/prova F9 |
|---|---|---|---|
| 01/11/12 sombras e profundidade visual | adendo humano26/10 | personagens já têm elipse de contato; props/prévia precisam acabamento coerente e prova em pisos/cotas reais | [contrato e opções da engine](contracts/f9_contact_shadows.md); contato e ordem de desenho validados04a7dfc:242 verificações e3 etapas oficiais Luna; desempenho em escala e preview integral continuam em10/11 |
| 01 catálogo/origem/licença/dependências | arquitetura, recibo F8 | catálogo passivo de6 definições, PNGs/proveniência e hashes; três originais imutáveis e cacto/pilar/arenito integrados |expansão validada a44cfb1:30/23/53/25 e2 oficiais Luna; transporte limpo pendente |
| 01 colocar/mover/rotacionar/duplicar/remover | arquitetura | API comum e GUI implementadas; AX/CLI parametrizados faltam | checkpoint18fa57f:53 checks,25 nativos e supervisão |
| 01 seleção/inspector/grupo/camadas/travas | arquitetura | seleção alpha, inspector e grupos editoriais com travas e cópia de IDs | comprovado no checkpoint de objetos; restante da biblioteca em06 |
| 01 snap/assentamento/inclinação | arquitetura | snap numérico, inclinação por catálogo e escolha explícita do piso superior |53 checks de objetos, incluindo ponte e piso travado |
| 01 decoração/corpo/ataque/LoS/oclusão | arquitetura, emendas | rocha/tronco sólidos e arbusto decorativo usam capacidades explícitas; combinação não suportada falha | movimento/ataque comprovados; prova final de oclusão/apresentação pendente |
| 01 scatter/exclusões/undo/roundtrip/export | arquitetura, validação | scatter determinístico revisável, quota/exclusões/undo/roundtrip comprovados |53+25 checks; export e pipeline final pendentes |
| 02 relevo suave/silhueta | terrain_piece_semantics | grade e smooth existem; planos de amostra não demonstram orgânico | pendente |
| 02 caminho/cobertura/encosta e pintura | terrain_piece_semantics | quatro materiais, pesos normalizados, mistura gradual de Pedra por declive e UV mundial/triplanar integrados | fundação validada ef88996:35/20/46, objetos nativos25, Core639 e2 oficiais Luna; acabamento orgânico/lados e área final ainda exigidos |
| 02 penhasco/faces não caminháveis | F2 closure | terrain v5/composição v4 preservam todas as faces/massas, suportes só até45°, pele exposta e faixa inferior junto da ponte | fundação validada7073d38: Cliff61, Ports92, Core639 e30 oficiais Luna; Native17/Mesh34/Relief58 e Objects53/Scale46 reaproveitados com deltas; relevo orgânico/área final ainda exigidos |
| 03 floresta/deserto/planície/ruína | map_composition_and_seams | quatro perfis ricos, canal/água sem collider, ruína legada preservada | fundação validada d3c0e25: Borders93/Native32/Ports92/Cliff61/Relief58/Core639 e30 oficiais Luna; integração visual/área orgânica final continua obrigatória |
| 03 transições/dono/abertura/frestas | emendas, F3 | normalização/dono/miter/união em T e transição explícita; corpo atravessa abertura80/N:M12 | validado d3c0e25; prova temática/UX integrado e export final pendentes |
| 03 ausência de perfil/asset | emendas | catálogo/dependências fechadas, ausência retorna diagnóstico | regressão d3c0e25, Borders93 e Core639; ambiente limpo em09/11 permanece exigido |
| 04 largura útil M3-NAV-01 | recibo F3, F8 | corrigida em WorldGeometry, inclusive desvio com centro bloqueado e curva entre aberturas | validado tecnicamente ce7bd59;46 checks + Core639 +25 IDs F1, recibo F9 |
| 04 abertura larga sobre malha refinada | fronteira encontrada ao completar02 | terrain v4/composição v3/assembler v2, receptor, emenda inclinada e ator integrados | fundação validada e6fdf43: Ports92, Core639,30 oficiais Luna; lote34 e dirigidos reaproveitados com hashes; GUI/AX/bundle/export/visual final ainda exigidos |
| 04 rampa400/160 e400/200 | recibo F8 | corrigidos plano escalar e precisão do envelope da laje; amostra conserva escala original | validado tecnicamente ce7bd59, movimento real sobre rampa/ponte e oráculo de altura |
| 04 precisão/altura/escala/corpo/folga/sentido | F2, F3, E07 | EPS preservado; half-ULPs de x/y/z projetados no plano/borda e transição física local | checkpoints270ff3a/e6fdf43 com supervisão por impacto; sem garantia universal de escala |
| 04 suporte contínuo e massa do relevo | F9-02/11, física compartilhada | união local e massa convexa/índice/desvios, transporte ao assembler e contato direcional implementados | validado tecnicamente270ff3a: malha34, massa56, geometria46, objetos53 e30 etapas oficiais Luna; Core639 autoral com proveniência no recibo |
| 05 mesma peça/manual/seed/contexto | autoria F8 | entregue; preservar APIs/revisões e hash | pendente de regressão |
| 05 síntese/regeneração interna real | arquitetura, F6 | troca de slots não esculpe; entregar operação regional | pendente |
| 05 proteção terreno/props/encontros/patrulhas/pins | arquitetura, F6 | pins de instância apenas; entregar máscaras e seleção real | pendente |
| 05 diff/contradição antes do commit | F6, validação | existe para slots; ampliar às regiões internas | pendente |
| 06 biblioteca/busca/miniaturas/categorias | arquitetura, F8 | paleta de objetos e biblioteca de fontes com busca/categorias/miniaturas locais; componente em validação | [biblioteca e navegação](contracts/f9_library_navigation.md), integração em execução |
| 06 presets/favoritos | arquitetura, F8 | preferências por projeto, presets reais de brush, favoritos e recuperação implementados |50 verificações de dados e53 nativas autorais; supervisão pendente |
| 06 minimap/árvore de objetos/camadas | arquitetura, F8 | árvore de camadas existe; completar | pendente |
| 06 overlays/foco/atalhos/diagnóstico localizado | arquitetura | overlays parciais; entregar conjunto acionável | pendente |
| 07 UX coerente/guiada | autoria F8 | menus e seletores existem; fechar fluxo humano inteiro | pendente |
| 07 AX IDs/ações parametrizadas/estado/diagnóstico | autoria F8 | ax_invoke só botão; entregar operações com parâmetros | pendente |
| 07 histórico/hash/confirmação/modos | F8 | entregue; preservar invariantes | pendente de regressão |
| 08 biomas/espécies/chances/pesos/reservas | autoria F8 | contexto/reservas e pesos existem; conferir chances e fluxos | pendente |
| 08 raro manual sem palco/sorteio | decisão F8 | entregue com53 checks; preservar | pendente de regressão |
| 08 exceção instância/regra/motivo/aviso | decisão F8 | entregue; preservar em novos consumidores | pendente de regressão |
| 08 quest passiva/origem/recompensa canônica | F8, PRODUCT_DIRECTION | entregue; nenhuma engine inferida | pendente de regressão |
| 08 stale/revisão/reconciliação sem perda | F6, F8 | snapshots separados, reimportação explícita limitada | pendente |
| 09 GUI/AX/CLI equivalentes | F7, F8 | GUI/headless parcial; AX sem parâmetros | pendente |
| 09 diff/preview/undo/proteção espacial/rebase | F7 | camada protegida inteira e base divergente; completar região/reconciliação | pendente |
| 09 assets passivos/ambiente limpo/segurança | F7 | referências locais apenas; transporte faltante | pendente |
| 09 fontes de skills/guias | F7 | três fontes versionadas existentes; atualizar sem instalar | pendente |
| 10 autosave/backup/pending/conflito | F1, F3, validação | entregue em documentos; conferir novos estados | pendente de regressão |
| 10 cancelamento/progresso/stale/atomicidade | F2, F6, F7 | worker parcial; commit e prévia síncronos F7 | pendente |
| 10 cache/invalidação regional | arquitetura, F2 | ausência registrada de cache/bake incremental | pendente |
| 10 medição pequeno/representativo/estresse | validação, F2 | lote canônico permite composição densa antes excedida300s; busca individual densa ainda174671,384ms |34 checks autorais do lote, com direção/testemunhas, snapshot, orçamento/cache local e união de grafos; responsividade final e medições amplas pendentes |
| 11 pacote imutável/revisão/consumo sem código | arquitetura, F3–F8 | publicação existe; ponto de consumo integrado incompleto | pendente |
| 11 preview real/apresentação de jogo | F8 | pacote real, atores técnicos; completar apresentação e fluxo | pendente |
| 11 restart/continuidade/compatibilidade | F5, validação | snapshot estrito; preservar revisão ou erro sem destruição | pendente |
| 11 export limpo/dependências/API | F8 | release técnico existe; ampliar aos consumidores F9 | pendente |
| 12 área temática/fluxo humano sem código | validação, F8 | amostra técnica; caminho curvo/bifurcação/vegetação/rocha/arte faltantes | pendente |
| 12 clareira/rampa/platô/ponte/rota inferior/santuário/emenda | validação, F8 | amostra técnica existente; demonstrar produto final | pendente |
| 12 disperso/grupo/patrulha/interação | validação, F8 | amostra sete atores; preservar e apresentar no jogo | pendente |

Medições antigas não certificam mudanças F9. Limites defensivos medidos não são
requisitos adiados; exclusões explícitas continuam as do contrato (campanha,
quests/economia nova, multiplayer, renderer novo e execução de conteúdo remetido).

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
| 01 catálogo/origem/licença/dependências | arquitetura, recibo F8 | placements existem no schema, compiler recusa; entregar catálogo real | pendente |
| 01 colocar/mover/rotacionar/duplicar/remover | arquitetura | nenhum consumidor de placement; entregar sessão/GUI/AX | pendente |
| 01 seleção/inspector/grupo/camadas/travas | arquitetura | camadas de terreno existem; objetos ausentes | pendente |
| 01 snap/assentamento/inclinação | arquitetura | entregar suporte e limites por definição | pendente |
| 01 decoração/corpo/ataque/LoS/oclusão | arquitetura, emendas | capacidades explícitas e único envelope; folhas sem collider | pendente |
| 01 scatter/exclusões/undo/roundtrip/export | arquitetura, validação | entregar determinismo, proteção e pipeline inteiro | pendente |
| 02 relevo suave/silhueta | terrain_piece_semantics | grade e smooth existem; planos de amostra não demonstram orgânico | pendente |
| 02 caminho/cobertura/encosta e pintura | terrain_piece_semantics | duas texturas com máscaras; fechar mistura gradual por inclinação | pendente |
| 02 penhasco/faces não caminháveis | F2 closure | compiler recusa >45°; fechar suporte/sólido/visual | pendente |
| 03 floresta/deserto/planície/ruína | map_composition_and_seams | só ruin_envelope_v1; perfis/arte/envelopes faltantes | pendente |
| 03 transições/dono/abertura/frestas | emendas, F3 | fechamento ruína existe; ampliar sem estreitar passagem | pendente |
| 03 ausência de perfil/asset | emendas | preservar erro explícito sem barreira invisível | pendente de regressão |
| 04 largura útil M3-NAV-01 | recibo F3, F8 | path ancora centro; corrigir autoridade WorldGeometry | reprodução/correção em curso |
| 04 rampa400/160 e400/200 | recibo F8 | falhas de plano e rota registradas; reproduzir sem alterar amostra | reprodução/correção em curso |
| 04 precisão/altura/escala/corpo/folga/sentido | F2, F3, E07 | justificar limite numérico e regressões compartilhadas | pendente |
| 05 mesma peça/manual/seed/contexto | autoria F8 | entregue; preservar APIs/revisões e hash | pendente de regressão |
| 05 síntese/regeneração interna real | arquitetura, F6 | troca de slots não esculpe; entregar operação regional | pendente |
| 05 proteção terreno/props/encontros/patrulhas/pins | arquitetura, F6 | pins de instância apenas; entregar máscaras e seleção real | pendente |
| 05 diff/contradição antes do commit | F6, validação | existe para slots; ampliar às regiões internas | pendente |
| 06 biblioteca/busca/miniaturas/categorias | arquitetura, F8 | ausente | pendente |
| 06 presets/favoritos | arquitetura, F8 | ausente | pendente |
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
| 10 medição pequeno/representativo/estresse | validação, F2 | medições parciais históricas; completar frio/quente/custos relevantes | pendente |
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

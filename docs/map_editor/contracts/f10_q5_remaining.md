# F10 Q5 — pendências técnicas após as provas de preparação

5/11/2026. Pedido humano: “Vamos resolver as pendências de Q5 então”.
Base `954341d5721ea6959fb89b1458ce17242e3ce6f6`, código `06abdd917`.
Mesmo checkout, branch e fixture. Não abre outro marco nem concede aceite.

## Escopo e propriedade

- Sol: `expedition_service.gd`, `snapshot/snapshot_registry.gd`, testes de
  retomada/densidade, runners, UIDs, integração, documentação e evidência.
  Caminhos do núcleo relativos a `scripts/core/expedition`.
- Tarefa delimitada de navegação: exclusivamente
  `scripts/core/expedition/spatial/world_geometry.gd` e
  `tests/map_editor_far_navigation_test.gd`. Guarda exata para evitar cálculo
  descartado; preservar custos, candidatos, sentido dos conectores, obstáculos,
  temporários, perfil, revisão e leash. Comparação com referência obrigatória.
- Terra: os dois arquivos `scripts/ui/expedition/expedition_{presentation,status_panel}.gd`
  e `tests/e07_f7_presentation_test.gd`; entrega concluída e propriedade
  transferida a Sol para integração, acessibilidade e ajuste à largura real.
  Sol recebe também `scripts/world/expedition_portal.gd` para usar a mesma
  legenda neutra no mundo, inclusive nas repetições da fase.
- Luna: supervisão dos testes somente após congelamento e transferência da
  engine. Sem escrita de fontes durante execução; uma única fixture.

## Retomada com uma reconstrução passiva

Delta explícito ao contrato de desempenho: somente `resume` conserva a
reconstrução completa que já validou antes da gravação. O grafo permanece
destacado e passivo; não é instalado nem avança ticks enquanto o writer não
confirmar o resultado. Confirmação religa apenas autoridade externa
(perfil/revisão/sessão) e lifecycle ao estado confirmado, como já ocorre no
caminho de campanha. Falha definitiva libera o grafo; resultado incerto o
retém passivo até reconciliação. Replay de pedido confirmado reconstrói
normalmente a partir do checkpoint. Nenhum formato, recibo, journal, RNG,
recompensa ou regra de dono muda. As duas reconstruções das transações de
portal/coleta que alteram o mundo continuam preservadas.

A medida do tamanho lógico de snapshot torna-se diagnóstico opt-in: a
validação semântica e a codificação compacta continuam obrigatórias, com os
mesmos limites. Erro de tamanho mantém diagnóstico completo, calculado sob
demanda. Não reutilizar encoding após alteração de autoridade.

## Portais e prova

Destino e estado aparecem em linhas próprias, com quebra conforme a largura
real. Tooltip contém o texto completo e orientação sem inventar a causa do
bloqueio. Elegibilidade vem da autoridade existente; apresentação não muda
limpeza, objetivo ou regras de repetição.

Provar sucesso, falha definitiva, confirmação perdida, não gravação incerta,
reconciliação, replay, dono/revisão e recuperação; densidade e excesso de
tamanho; navegação diferencial e percurso real; apresentação, continuidade,
release limpo e `tools/verify.ps1` dirigido. Medir entrada, portal, retomada e
rota extrema sobre os mesmos pacotes e perfil. Registros automatizados não
substituem as nove tarefas sem código ou aceite humano de Q5.

Conferência adicional: Sol recebe `tests/e07_f1_presentation_test.gd`. A
expectativa histórica que recusa uma emenda contínua deve ser confrontada com
`f9_surface_picking.md`, sem regressão de runtime. Reproduzir primeiro; só
depois atualizar a prova para o dono determinístico da abertura bidirecional
e acrescentar recusa quando o mesmo vínculo for desativado. Sobreposições e
pisos independentes continuam recusados, incluindo a suíte SurfacePick.

## Segunda rodada após medição (mesma autorização)

A primeira guarda manteve a rota completa idêntica, mas mediu apenas
103,807→94,411 s no extremo real. Não resolve a pendência. Fonte e fixture
voltam a implementação depois de ForestPlay/GameInterface; nenhum writer
trabalha durante a engine.

Sol assume `world_geometry.gd`, `world_support_patch.gd` e o teste
`map_editor_far_navigation_test.gd`. Memo limitado existente pode guardar
`Kernel.contains(cell, point, 0)` para superfície e Vector3 exatos; mesma
configuração/revisão/perfil/candidato, mesma invalidação e saturação com
fallback integral. Só uma preparação privada de segmento, ligada ao objeto
world e aos endpoints/revisões exatos, pode reutilizar esse veredito entre
sweep e fração. DTOs, witnesses e certificados externos não podem transportar
essa autoridade; nenhum flag externo dispensa validação. Corpo, headroom,
união de apoios, declive, massas, temporários e candidato continuam integrais.
Não mudar heap, heurística, candidatos, ordem, sentidos, custos ou EPS.

Tarefa delimitada de grade recebe exclusivamente `world_height_grid.gd` e o
novo `tests/map_editor_grid_attachment_test.gd`. `_attach` pode testar o
mesmo disco da origem uma vez; cada node `usable` já provou o outro disco
com a mesma view/radius/inside. Extrair só a varredura privada da cápsula
entre discos já provados, preservando todos os predicados, ordem e distâncias.
Comparar a lista completa com a implementação anterior em corpos, bordas,
declives, falhas, `inside` e coordenadas distintas. Não criar cache novo ou
mudar grafo. Sol integra UID/runner; engine continua exclusiva e sequencial.

A reprodução posterior deve medir o extremo real novamente contra a rota
arquivada, com fontes congeladas. Referência de navegação conserva as versões
anteriores dos wrappers de sweep/fração, separando o cache novo do oráculo.

O extremo seguinte manteve a rota em 76,181 s (14.844 testes canônicos de
membership e 374.002 hits), ainda lento. A mesma fatia Sol pode conservar
até 32.768 resultados de `_candidate_point` que chegarem depois da saturação
do memo de pares, sem retirar as provas anteriores, mudar EPS ou aumentar o
limite do memo de pares. Só bools, mesma chave/invalidação/candidato.

As pernas de um desvio podem usar um scope conservador da célula inteira:
contorno XZ com a folga de representação já existente, todas as alturas
(sem culling em Y), mesma ordem dos índices e massas; temporários completos
e candidato continuam consultados. Até 128 scopes derivados por memo, sem
atores ou estado de run; fallback calcula normalmente se atingir o limite.
O envelope estreito dos endpoints continua restrito às retas originais.

Controle dessa tentativa: 75,168 s contra 76,181 s, sem ganho confirmado;
cache de overflow e scopes foram descartados, preservando a evidência. A
fonte final pode ainda contar a máscara canônica do índice: se TODOS os
triângulos forem transitáveis, consultas de triângulos íngremes devolvem vazio
sem percorrer linhas. Sem contador disponível, continuam as varreduras antigas.
O teste diferencial retira o contador da referência para forçar essas
varreduras, inclusive nos 72 casos de grade. Nenhum veredito é inferido de
outro perfil nem de uma máscara carregada de fonte externa.

Esse segundo ensaio também ficou sem ganho no extremo (77,037 s); contador e
atalhos de máscara vazia foram descartados. Fonte final conserva somente a
extração dos discos já provados, membership exato limitado e guarda da rota
de dois pontos, além dos deltas de retomada/diagnóstico/portais. As tentativas
descartadas ficam nas evidências, sem consumidor de produto.

Conferência final de UI: título válido de 120 caracteres sem espaços produziu
9 linhas/231 px no Label contra 58 px reservados pelo botão. Reproduzido em
F7 presentation (27/1) antes da correção. Sol religa a medida à mesma quebra
adaptativa do Label e ao mínimo real após layout. Repetir F7/GameInterface e
release; provas de core/navegação permanecem compatíveis, com os dois inputs
de UI explicitados no vínculo. Referência: [Font 4.7](https://docs.godotengine.org/en/4.7/classes/class_font.html),
[Label](https://github.com/godotengine/godot/blob/master/scene/gui/label.cpp).

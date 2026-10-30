# F9 — navegação em tempo de jogo: diagnóstico e opções (checkpoint31)

30/10/2026. Sol/Astra (Claude Opus). Base 7452c2fc, mesma branch/checkout/fixture.
Análise e medições apenas; nenhuma mudança em `world_geometry.gd` nesta rodada.
Decisão humana 30/10: opção 1 (grafo reutilizável). Implementação em fatias
próprias, com contrato antes de código.

## Medições no Bosque real (Godot 4.7.2, fixture única, perfil do slot)

| Consulta | Distância | Tempo |
|---|---|---|
| `WorldGeometry.path` home do beco/grupo oeste → entrada (4 slots) | 1395–1514 | 55,3–64,7 s cada, frio ≈ quente |
| mesma consulta, 2ª chamada no mesmo mundo | — | 58,2 s (sem reuso entre consultas) |
| home da clareira → entrada (3 slots) | 197–293 | 2,6–3,3 ms (caminho direto) |
| salto local de 10% rumo à entrada | — | 0,4–2,4 ms |
| validação da rota de patrulha (6 trechos locais) | — | 10,6 ms |

Trace de uma consulta longa (58,3 s): construção 3,25 s; testes de folga
(`_navigation_clear`) 38,9 s; suporte (`_navigation_fraction`) 14,2 s; 3.761 estados,
3.220 expansões, 282.535 testes de aresta locais (~138 µs por folga), 53 apoios
preparados, memo 549.209 misses/14.290 hits. O custo é o grafo de visibilidade
local avaliado do zero a cada consulta.

Release × debug: o mesmo `core_probe.gd` exportado com o template
`windows_release_x86_64` consumiu 84 s de CPU sem concluir as duas consultas que o
build debug fez em ~114 s. Ganho máximo ≈1,3×: não é efeito do modo debug.
(O template headless em segundo plano ficou limitado a ~15% de CPU pelo Windows;
por isso comparar CPU, não relógio.)

Carregamento do teste (debug): leitura/validação do candidato 18,1 s (inclui
`Patrols.validate_package` 17,4 s), `prepare` 77,8 s — lote de superfícies 22,6 s,
Planner 12,4 s e nova validação do candidato dentro do `prepare` (~18 s); montagem
do mundo ~30 s. A janela agora prepara em thread separada e não congela.

## Por que o jogo trava

Inimigos replanejam com `WorldActorMotion.plan → WorldGeometry.path` a cada
0,45 s (perseguição) ou 1 s (retorno de patrulha). Qualquer rota não direta que
atravesse a emenda custa ~1 min na thread principal: o quadro fica parado e o jogo
parece "carregando". Rotas curtas e diretas são baratas, por isso parte dos testes
pequenos não mostrava o problema.

## Opções (decisão humana: opção 1)

1. **Grafo de navegação reutilizável (correção estrutural, recomendado).** Guardar
   por mundo + revisão de geometria + perfil o grafo de visibilidade/portais já
   provado, ligando só os terminais de cada consulta; ocupantes/obstáculos
   temporários verificados à parte. A* com heurística euclidiana consistente
   mantém custo ótimo. Meta medível: consulta longa < 20 ms no Bosque. Exige
   contrato de invalidação (insert_obstacle/temporários/revisões), diferenciais
   contra o Dijkstra atual e regressões de navegação completas. Vários pacotes.
2. **Planejamento fora da thread principal.** Rota em worker com resultado
   descartado se a revisão mudar; inimigo espera/segue rota anterior. Remove o
   travamento visível, mas a consulta continua lenta (inimigo "pensa" 1 min) e
   exige snapshot imutável do mundo para não competir com ocupantes.
3. **Orçamento por consulta de IA.** Limite de expansões por replanejamento; se
   estourar, o inimigo desiste/aguarda. Rápido de fazer, muda comportamento de
   perseguição longa e não resolve rotas legítimas longas.
4. **Contorno só de conteúdo para testar já.** Espécies com aggro/leash
   (`pilot_*`) em vez de `demo_chaser`, para perseguições ficarem locais. Não
   corrige o motor; guarda voltando de longe ainda pode travar.

Otimização exata já contratada (`f9_navigation_relaxation.md`, pular predicados
de arestas que não relaxam) cortaria parte dos 53 s de testes, mas sozinha não
leva a milissegundos; pode compor a opção 1.

## Medição complementar (checkpoint32)

Probe dinâmico no Bosque real (jogador espadachim em [160,0,640]): `path` até os
4 inimigos do beco/viaduto 84,1–86,9 s cada; até os 3 da clareira 2,7–3,4 ms.
Perseguição do jogador replaneja a cada 0,22 s para o ponto do alvo; com alvo
local, clique→primeiro dano 25 ms. Quadro pior em combate local 81–93 ms.

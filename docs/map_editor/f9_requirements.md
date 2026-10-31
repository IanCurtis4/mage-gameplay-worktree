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
| 01 colocar/mover/rotacionar/duplicar/remover | arquitetura | API comum, GUI e AX/CLI parametrizados implementados | checkpoint24: Content28/Native30, Objects53, cliente12/12+reabertura; Sol temporariamente executou após quota Luna |
| 01 seleção/inspector/grupo/camadas/travas | arquitetura | seleção alpha, inspector e grupos editoriais com travas e cópia de IDs | comprovado no checkpoint de objetos; restante da biblioteca em06 |
| 01 snap/assentamento/inclinação | arquitetura | snap numérico, inclinação por catálogo e escolha explícita do piso superior |53 checks de objetos, incluindo ponte e piso travado |
| 01 decoração/corpo/ataque/LoS/oclusão | arquitetura, emendas | rocha/tronco sólidos e arbusto decorativo usam capacidades explícitas; combinação não suportada falha | movimento/ataque comprovados; prova final de oclusão/apresentação pendente |
| 01 scatter/exclusões/undo/roundtrip/export | arquitetura, validação | scatter determinístico revisável, quota/exclusões/undo/roundtrip comprovados |53+25 checks; export e pipeline final pendentes |
| 02 relevo suave/silhueta | terrain_piece_semantics | grade/smooth e Gauss17 com512 apoios reais, corpo20/32, publicação e1024 testemunhas/movimento comprovados por Sol; acabamento humano/nativo continua exigido | checkpoint19 e contrato de desempenho; Organic15, não fecha visual orgânico |
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
| 05 síntese/regeneração interna real | arquitetura, F6 | troca de slots não esculpe; contrato regional preparado com consulta Astra, consumidores ainda pendentes | [síntese regional](contracts/f9_regional_synthesis.md), sem conclusão antecipada |
| 05 proteção terreno/props/encontros/patrulhas/pins | arquitetura, F6 | pins de instância apenas; entregar máscaras e seleção real | pendente |
| 05 diff/contradição antes do commit | F6, validação | existe para slots; ampliar às regiões internas | pendente |
| 06 biblioteca/busca/miniaturas/categorias | arquitetura, F8 | paleta de objetos e biblioteca de fontes com busca/categorias/miniaturas locais; componente em validação | [biblioteca e navegação](contracts/f9_library_navigation.md), integração em execução |
| 06 presets/favoritos | arquitetura, F8 | preferências por projeto, presets reais de brush, favoritos e recuperação implementados |Luna50 no73b6ee8; browser53 e recuperação/correção de suspensão validados6d72972, conforme recibo |
| 06 minimap/árvore de objetos/camadas | arquitetura, F8 | minimapaXZ/câmera e busca/foco por camada/objeto/apoio/rota integrados às5 telas; árvore/listas dos produtores preservadas | validado6d72972: Luna20/52/53/28,Core639 e5 oficiais;9799 inputs conferidos; custos e fluxo final seguem em10/12 |
| 06 overlays/foco/atalhos/diagnóstico localizado | arquitetura | altura/cotas, apoio, corpo, aberturas, encontros e rotas com flags; folga/LoS/ocupação reais, foco e atalhos no quadro; apoio explícito para seção editorial entre andares | validado6d72972: Native52 e5 oficiais Luna; diagnóstico/custos/UX integrada/área final ainda exigidos no conjunto12 |
| 07 UX coerente/guiada | autoria F8 | menus e seletores existem; fechar fluxo humano inteiro | pendente |
| 07 AX IDs/ações parametrizadas/estado/diagnóstico | autoria F8 | peça/terreno/objetos/contexto/marcadores/composição e população/patrulha parametrizados sobre telas reais; geração/intercâmbio e fluxo integral ainda faltam | checkpoint27: encontros27/25, cliente12/12+reabertura4/negativo; conteúdo real do Bosque e fechamento global pendentes |
| 07 histórico/hash/confirmação/modos | F8 | entregue; preservar invariantes | pendente de regressão |
| 08 biomas/espécies/chances/pesos/reservas | autoria F8 | contexto de peça/reservas/marcadores agora parametrizados; pesos existem; conferir chances e fluxos integrados | Content28/Native30 e floresta/áreas Terra comprovados; não fecha população/exceções/reconciliação |
| 08 raro manual sem palco/sorteio | decisão F8 | entregue com53 checks; preservar | pendente de regressão |
| 08 exceção instância/regra/motivo/aviso | decisão F8 | entregue; preservar em novos consumidores | pendente de regressão |
| 08 quest passiva/origem/recompensa canônica | F8, PRODUCT_DIRECTION | entregue; nenhuma engine inferida | pendente de regressão |
| 08 bioma de autoria no manifesto final | descoberta checkpoint25 | corrigido em4e3a3788: bioma explícito propagado, fallback ruin e pacote incoerente recusado sem regravar | checkpoint26: MapBiome15/Native13, consumidor de população e BosqueForest12 PASS; App/gameplay final do Bosque ainda exigido |
| 08 stale/revisão/reconciliação sem perda | F6, F8 | snapshots separados, reimportação explícita limitada | pendente |
| 09 GUI/AX/CLI equivalentes | F7, F8 | equivalência comprovada para composição/contexto e encontros/patrulhas, compilação e Store; geração/intercâmbio/bundles finais faltam | checkpoint27:27/25, cliente12/12/reabertura4 com fonte/pacote/bytes iguais e erro que interrompe antes de save; restante pendente |
| 09 diff/preview/undo/proteção espacial/rebase | F7 | camada protegida inteira e base divergente; completar região/reconciliação | pendente |
| 09 assets passivos/ambiente limpo/segurança | F7 | referências locais apenas; transporte faltante | pendente |
| 09 fontes de skills/guias | F7 | três fontes versionadas existentes; atualizar sem instalar | pendente |
| 10 autosave/backup/pending/conflito | F1, F3, validação | entregue em documentos; conferir novos estados | pendente de regressão |
| 10 cancelamento/progresso/stale/atomicidade | F2, F6, F7 | worker parcial; commit e prévia síncronos F7 | pendente |
| 10 cache/invalidação regional | arquitetura, F2 | ausência registrada de cache/bake incremental | pendente |
| 10 medição pequeno/representativo/estresse | validação, F2 | lote canônico permite composição densa antes excedida300s; busca individual densa ainda174671,384ms |34 checks autorais do lote, com direção/testemunhas, snapshot, orçamento/cache local e união de grafos; responsividade final e medições amplas pendentes |
| 11 pacote imutável/revisão/consumo sem código | arquitetura, F3–F8 | candidato passivo, janela/perfil descartável e clientes GUI/AX/CLI integrados | clientes consolidados7f723ac:22/18/52/33/49,Core639 e6 oficiais; [papéis/evidência](delivery/evidence/f9/author/gameplay_clients_consolidation.md); release/fluxo final pendentes |
| 11 preview real/apresentação de jogo | F8 | pacote rico compartilhado e Player/Enemy/Campaign/HUD reais; quatro campos com apoio/cota/ordem em validação | pele81e2f42 e app/janela/controles581dae4 supervisionados; campos73 autorais e regressão52/29 PASS, demais VFX/área/release pendentes |
| 11 restart/continuidade/compatibilidade | F5, validação | janela estável, RUN nova no restart, revisão antiga preservada, stop tokenizado sem kill e corte canônico | fonte581dae4 supervisionada52/33/29 e clientes7f723ac; revisão/export/recuperação/área final continuam no conjunto |
| 11 export limpo/dependências/API | F8 | release técnico existe; ampliar aos consumidores F9 | pendente |
| 12 área temática/fluxo humano sem código | validação, F8 | mapa Terra viaAX com2peças/trilha/colina/ponte/47props/emenda e bordas/contexto runtime florestais; fluxo humano/área final faltam | checkpoint26: fonte45.615B, lote AX4/2 e consumidor12 corpo20x32/84apoios PASS; sem App/caminhada/combate/FPS do Bosque |
| 12 clareira/rampa/platô/ponte/rota inferior/santuário/emenda | validação, F8 | amostra técnica existente; demonstrar produto final | pendente |
| 12 disperso/grupo/patrulha/interação | validação, F8 | Bosque: 3 dispersos, grupo de 3, guarda fixo com patrulha `alley_watch` e `shrine_completion`, todos via AX; App abre e patrulha anda no jogo | checkpoint30: patrol AX 211s PASS, janela ativa 138s, guarda chegou ao 1º ponto; checkpoint31 portão "Iniciar teste" (GameplayGate24); checkpoint32 mira por corpo desenhado + trava inteligente (WorldTargeting16); lag de rota longa (55–87 s) aguarda grafo reutilizável; checkpoint33 gravação por morte adiada ao fim do combate (11,2 s em vez de 17–19 s por morte); aceite humano pendente |

Medições antigas não certificam mudanças F9. Limites defensivos medidos não são
requisitos adiados; exclusões explícitas continuam as do contrato (campanha,
quests/economia nova, multiplayer, renderer novo e execução de conteúdo remetido).

Checkpoint19 acrescenta publicação de Gauss17/512 dentro do orçamento original,
consulta individual preparada e provas Context11/Lazy24/Geometry46/Ports92/Batch36.
A comparação densa atual preserva resultado integral e reduz160389ms para100731ms;
continua limitação concreta de10 e não certifica fluidez. Core/oficiais/supervisão
integrada ainda pendentes no congelamento, conforme recibo. Nenhuma linha é removida.

Atualização27/10 posterior: Luna navigation_and_fields concluiu Core639,
FieldsNative73/GameplayNative52/Controls29 e12 oficiais/3649 checks no4642dbf,
sem erros/timeouts; supervisão integrada pendente acima foi satisfeita. Fixture
liberada. Performance in-game, autoria AX útil e robustez são prioridades humanas;
cronômetro de suíte não é meta. Restante F9 continua exigido; T01 é só proposta.


Checkpoint20 parcial28/10: T01 integrado, novo brush/preset/exemplo e modelo19
PASS. GUI/AX/menu/undo e captura orgânica comprovados, mas Native falha no início
da App por snapshot10.308.936B >4MiB. Ainda sem caminhada real, frames ou conclusão
de02/11/12. [Diagnóstico](contracts/f9_snapshot_density.md); limites/corpo/amostra
preservados. Bosque do Santuário é desenho Terra, não mapa entregue. Meta humana
renovada cobre TODO F9; Sol código/Terra autoria AX/Luna testes. Permanecem todos
os pendentes; próxima autoridadeAX em contrato próprio, sem empurrar paraF10.


Checkpoint21: snapshot denso dentro dos4MiB préDEFLATE(3.594.152B), Density33 e
Native20 +4oficiais PASS. Colina real foi percorrida com corpo20x32; não fecha área
final nem todos os itens02/11/12. Novo aberto04/11: pick emXZ780/780 retorna
ambiguous_surface após restauração correta do estado. Resolver emenda de faces
sem deslocar o alvo ou enfraquecer múltiplos pisos/oclusão. App.open50s/início30s
continuam pendência10, apesar de pedido44ms/frames mediana17,4ms nesta única rota.
Matriz completa permanece exigida; ver conferência de snapshot_encoding no recibo.


Checkpoint22: pick de emenda corrigido semmoveralvo780/780 ouaumentarEPS/caps.
SurfacePick24,Geometry46,Ports92,Native20,Resume13 e2oficiais isolados PASS.
Processo novo restaura estado e aceita nova caminhada/re-suspend3.589.468B<4MiB.
Fecha o bloqueio concreto04/11 do checkpoint21; não remove demais requisitos.
Carregamento≈49s/início31s continuam pendência10. PróximoAXparametrizado e
criaçãoTerra noeditorAX; mapa/áreafinal/síntese/intercâmbio/release ainda exigidos.


Checkpoint23: peça/terreno AX e cliente aprovados17516a20; duas fontes Terra
integradas0acc94ef, replay8/27 e abertura/compilação iguais. Consumidor ligado
PASS para20x32 e acesso a todos os apoios, sem App/caminhada ou composição AX
persistida.30/15 checks, CLI e importação documentados no recibo. Arte/props,
contexto, composição/população/patrulha AX e prova de gameplay continuam exigidos.
Política LF elimina divergência de bytes dos imports de terreno deste candidato;
assets em bundle/ambiente limpo/export não foram fechados. Custos15,5s/18,9s de
mapa/preparo são canônicos, ainda pendência10, sem inferência de FPS.


Checkpoint24: código52798508, conteúdo Terra b14ea3dc. Content28/Native30,
Objects53, cliente12/12/reabertura e editor_import PASS; Sol executou após quota
interromper Luna.24+23props/contexto/áreas/entrada por AX; consumidor decorado
20x32, apoios e marcador exato com ida/volta PASS. Composição foi efêmera de teste,
map-only preview com início provisório; não há App/caminhada/combate/FPS. Custos
canônicos mapa26,056s/preparo23,557s e consultas adicionais mantêm10 aberto.
[Recibo](delivery/evidence/f9/author/ax_content/consolidation.md); restante integral
mantido, próximo composição/contexto de mapa AX, depois população/patrulha e
perfil das buscas antes do uso real. Sem fecharF9 ou mover lacunas aF10.


Checkpoint25: produtor2248ee72 e mapa1bdc7301.31/13, cliente10/10/reabertura,
Borders32/Gameplay52, Composition63/Document70/CLI2 e editor_import PASS. M3Native24
histórico falhou por preview retirado, baseline auditada; migração do tooling
pendente e sem contagem como PASS. Terra montou2peças/47props viaAX7/2 e consumidor10
PASS corpo20x32; não houve gameplay do Bosque. Contextoforest ainda não se propaga
para stage.biome e bordas são legadas; custos canônicos≈28/24s e UX/fluxo final
mantidos pendentes. [Consolidação](delivery/evidence/f9/author/ax_composition/consolidation.md).
Nenhuma linha anterior removida; meta completaF9 permanece ativa.

Checkpoint26: código4e3a3788 e conteúdo86359e3d corrigem bioma de runtime,
adicionam lote atômico de bordas GUI/AX/CLI e rolagem no inspector. Luna15/13,
Borders93/Native32, Gameplay52, Candidate53/Population91/Patrol58/Exchange113
e verify editor_import PASS. Terra aplicou ambos perfis forest_rootbank_v1 por
AX4/2; somente borders mudou, com47props/snapshots/vínculo preservados.
ForestConsumer12 PASS do arquivo final: stage/context forest,35spans sem legado,
corpo20x32 com acesso aos84apoios/131conexões e marcador autorado exato válido.
Sem App/jogabilidade/FPS do Bosque; mapa28,516s/preparo30,441s são custos canônicos
e mantêm10aberto. [Consolidação](delivery/evidence/f9/author/map_biome/consolidation.md).
Próximo: população/patrulha parametrizadas e conteúdoAX; restante integral de
F9 preservado, incluindo desempenho real, síntese/reconciliação/assets/release,
UX final e migração do teste M3Native24 histórico. Sem transferência aF10.

Checkpoint27: runtime5a97f7d7, fixture corrigida/validação3a5bff35. Produtores
de encontros/patrulhas, documentos/Stores, proposta assinada e cliente AX real
passaram27/25, Gameplay52, Context53/91/58/113 e verify editor_import1/299.
CLI em5processos: preview2,headless12,nativo12,reopen4,negativo2/3esperado;
fontes/pacotes/bytes iguais. Primeira falha24/25 foi fixture de espera1,75 num
controle com passo0,1; diagnóstico preservou todos os oráculos e runtime, mostrou
valor1,8 igual na GUI/AX. Fixture corrigida e precisão1,75 da API coberta em
modelo/CLI. [Consolidação](delivery/evidence/f9/author/encounter_authoring/consolidation.md).
Não cria ainda população/patrulha de produto no Bosque nem prova App/FPS.
Próximo é Terra autorar encontros/objetivo pelo AX; reconciliação, síntese,
assets/release, desempenho real, UX e toda área final permanecem exigidos em F9.


Checkpoint30 (30/10, Sol/Astra Opus, Terra Sonnet, Luna Haiku): conteúdo e5fddf84
e código 01ffd228. Terra autorou pelo AX a troca do guarda para espécie com
engajamento (demo_chaser tem aggro0 e é patrol_unsupported), prévia sem mudança de
slots e a patrulha `alley_watch`; patrol/compile AX PASS 211,333s. GameplayCandidate
prova ida/volta por connectivity_batch por estágio/perfil; CandidateBatch18,
GameplayWindow33, GameplayCli18, GameplayControls29 e GameplayNative52 PASS.
Bosque abriu no jogo por AX nativo: preparo ready107,6s/active138,4s, log limpo,
patrulha real em movimento. Achado: 3 Guerreiros da clareira perseguem desde o
início e mataram o personagem parado em ~2min (conteúdo, decisão pendente).
Worker GUI180s, busca individual, FPS, aceite humano e demais linhas seguem abertos.
[Consolidação](delivery/evidence/f9/author/patrol_gameplay/consolidation.md).

Checkpoint31–32 (30/10, Sol/Astra Opus, Luna Haiku): a pedido humano, a janela
de teste carrega em thread e para em "Iniciar teste" (GameplayGate24 PASS;
prepare 93,5 s fora da principal, `start()` 31,8 s ainda nela). O lag não é do
modo debug: `WorldGeometry.path` de rota longa leva 55–87 s sem reuso; o usuário
escolheu o grafo de navegação reutilizável
([diagnóstico](contracts/f9_runtime_navigation.md)). A mira no mundo autorado
passou a usar o corpo desenhado e a mesma trava inteligente do modo plano
(WorldTargeting16 PASS; `collision_radius` intacto).
[Portão](delivery/evidence/f9/author/gameplay_gate/consolidation.md) ·
[Mira](delivery/evidence/f9/author/world_targeting/consolidation.md).

Checkpoint33 (31/10, Sol/Astra Opus): a pedido humano (cliques perdidos em
inimigos amontoados, Augments a ~0,1 FPS), medido que cada morte de inimigo
gravava a expedição inteira (17–19 s). Decisão humana "Adiar + aliviar": a
gravação durável ocorre uma vez ao fim do combate, reaproveitando a captura e a
pele autorada (11,2 s no Bosque). Pré-filtro exato nas consultas de
recompensa/área e aviso de Augments fora de combate. WorldRewardPoll10 e
GameplayNative53 PASS.
[Consolidação](delivery/evidence/f9/author/deferred_commit/consolidation.md).

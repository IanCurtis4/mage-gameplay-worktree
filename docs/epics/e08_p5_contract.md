# P5 — Mundo da Floresta do Santuário

Autorização humana em 8/11/2026, após o candidato técnico P4 fd32d346 (aceite
visual P4 ainda pendente e registrado como tal). Escopo escolhido pelo usuário:
espécies próprias, ambiente visual + som, materiais do terreno e variantes de
props. Checkout .tools/map-editor-m5, branch codex/e08, base fd32d346.
[Plano](e08_approved_plan.md), [posse](e08_p5_files.json),
[briefing de imagegen](e08_p5_imagegen_briefs.md). Sem master/push/habitual/save.

## Papéis e modelos

Coordenação P0 (sessão principal) mantém contrato, posse, verify.ps1, wrapper
`tools/e08_p5_fixture.ps1` e integração. Subagentes por papel: Sol → Opus,
Terra → Sonnet, Luna → Haiku. Imagegen raster fica com o Codex por pedido do
usuário; itens que dependem dele permanecem WIP com briefing, sem substitutos
procedurais apresentados como arte final.

## Fase A (sem imagegen)

**A1 Sol — catálogo de apresentação por espécie.** Substituir as listas fixas
`[forest_wolf, forest_boar]` por um catálogo tipado em
`scripts/presentation/species_presentation_catalog.gd` (const, imutável):
mob_base_id → visual_id direcional, atlas V1 de fallback (opcional), tinta,
`embedded_weapon` (corpo já traz a arma; sem projeção dinâmica). API pública em
`E08PilotVisual`: `has_species_presentation(id) -> bool` (já consumida por
main.gd:255) e `install_forest_atlas(actor) -> bool` com o mesmo contrato atual.
Lobo/javali mantêm comportamento byte a byte (V2 específico; falha → V1 completo
da espécie). Espreitador/Arqueiro da Copa/Guardião entram com visual_id
reservado `e08_forest_stalker`, `e08_forest_canopy_archer`, `e08_forest_warden`:
enquanto o manifest default não existir, mantêm EXATAMENTE o corpo genérico e a
tinta atuais (warrior/archer npc_body/beast_master). Quando existir, usam o
corpo próprio sem tinta dupla e, se `embedded_weapon`, sem arco projetado.
Trocar de espécie limpa derivações. Sem campo de save/snapshot; restore frio
reconstrói pelo mob_base_id. Testes: e08_species_presentation_test.gd (catálogo
imutável, ids existentes nos 5 MobDefinition, presença/ausência de manifest via
fixture explícita, fallback, switch kind, restore frio) e regressão dos atuais.

**A2 Terra — ambiente da floresta.** Camada procedural de apresentação para o
bioma `forest`: folhas/partículas e luz filtrada/névoa leve, determinística por
seed de estágio, densidade limitada, congelada na pausa, encerrada na troca de
estágio e reconstruída na retomada sem estado salvo. Nunca cobre indicadores de
perigo/alvo/área nem a UI: desenhar abaixo dos indicadores do mundo ou com alfa
baixo fora deles; testar zoom 50/100/160 e UI 120%. Integrar por
`expedition_backdrop.configure(biome)` e/ou main.gd (Terra é dona de main.gd na
fase A, exceto a linha 255 já ajustada pela coordenação). Som: cue
`ambience.forest` sintetizado por `tools/prepare_e08_pilot_audio.py` (vento em
folhas e pássaros esparsos, loop sem clique, sem música), selecionado por
bioma; demais biomas seguem `ambience.stage`. Respeitar canais/limites/mix P2,
pausa, deduplicação e retomada sem replay. Testes: e08_forest_ambience_test.gd e
e08_audio_test.gd. Custo: comparar floresta com/sem camada, mediana/p95.

## Fase B (depende das imagens do Codex)

B1 Terra empacota as três espécies (64 poses/4 vistas) estendendo o produtor de
inimigos para S/N gerados (sem atlas nativo), calibração, nativos e consumidor.
B2 Sol troca materiais (novas revisões de arquivo, mesmos IDs grass/earth/stone/
sand) e variantes de props, republica os três mapas pelo compilador existente
como novas revisões imutáveis, preservando geometria, rotas, populações,
encontros, navproof e corpos físicos. Variantes decorativas só substituem
colocações decorativas; uma nova árvore só substitui carvalhos com corpo/LOS/
oclusão idênticos aos do carvalho. Contratos de B1/B2 são detalhados quando as
imagens chegarem.

## Validação e limites

Cada pacote usa `tools/e08_p5_fixture.ps1` (trava única da fixture; nunca rodar
verify/engine fora do wrapper), nomes de evidência imutáveis, falhas preservadas.
Luna confere execução/hashes ao fim de cada fase. Falha volta ao autor; não
editar expectativa para esconder falha. Sem nova espécie/IA/stats/loot/
população, sem mudança de dano/alcance/colisão/RNG/save/tempo. Aprovação técnica
não é aceite visual; o usuário aceita o candidato P5.

## Resultado da fase A — 8/11

A1 Sol ([recibo](e08_p5_species_delivery.md)) e A2 Terra ([recibo](e08_p5_ambience_delivery.md))
entregues. Correção da coordenação: A2 havia retirado `ambience.forest` de
`Catalog.ids()` para o e08_pilot_test não varrê-lo (191→189 checks), o que
ocultava cobertura. Causa real era o próprio teste ler `wav.data` por amostra
(cópia inteira a cada leitura, O(n²)); o teste agora lê o buffer uma vez, o cue
voltou a EVENTS e nenhuma asserção mudou. Luna (luna_phaseA1): 45 etapas,
115.096 checks, 0 falhas/timeouts/divergência de hash; pilot 191/0 em ~13 s.
Camada de ambiente: 39 partículas, z abaixo dos indicadores; nas capturas é
muito sutil (aceite visual humano decide intensidade). Métrica de script do
probe de custo é inconsistente (mediana maior que o quadro inteiro); vale o
quadro: mediana 2,37 vs 2,18 ms, p95 4,32 vs 3,19 ms numa cena estática.
Fase B aguarda as imagens do Codex. Nota B1: unidade V2 do Arqueiro da Copa
precisa também de textura weaponless (pode ser igual ao corpo, arma embutida).

## Fase B — imagens recebidas e inspeção 8/11

Codex entregou em `assets/art/e08_world/staging/`: 3 espécies × 4 vistas 4×4,
4 materiais 1254² e 5 props. Inspeção da coordenação: Espreitador ok (aljava só
em W); Arqueiro da Copa ok (arco embutido na mão que lidera em E/W); Guardião ok
com ressalvas (ataque E lê como preparo, cabeça do cajado difere por vista);
props coerentes com o carvalho; grama/areia sem emenda visível. Terra está
avermelhada e saturada (RGB médio 114/56/30) e pode competir com indicadores
vermelhos; pedra é calçamento de paralelepípedos e o ID `stone` (cliff_tile)
também veste faces de penhasco — não trocar às cegas. **Falta proveniência**:
nenhum `provenance.json`; empacotamento segue, promoção final aguarda Codex.

B1 Terra/Sonnet: empacotar as três espécies (produtor estendido para S/N
gerados, sem atlas nativo), calibração NPC, unidade default, nativos e teste
real (manifest presente instala corpo próprio; Arqueiro da Copa com weaponless
e arma embutida, sem projeção). Altura alvo: mediana idle do corpo genérico atual
(warrior/archer/beast_master); Guardião até ~1,15× para presença de chefe,
respeitando 58×56 e pivô (32,58). IA/colisão iguais.
B2a Terra/Sonnet: prévia no renderer real, só no probe (sem alterar fontes,
mapas, catálogo ou pacotes): antigo×novo por material e com props trocados,
indicadores de perigo/área sobre terra/pedra, zoom 50/100/160, cintilação.
B2b Sol/Opus (após decisão humana sobre terra/pedra): revisões de material,
catálogo de props, colocações e republicação dos três mapas.

## Fase B — resultados B1/B2a e decisões humanas 8/11

B1 Terra ([recibo](e08_p5_species_art_delivery.md)): três espécies empacotadas
64 poses/4 vistas, unidade estágio e default; b1_verify4 verde (species 172,
npcs 1292, pilot 191, presentation 2204, content 3461, snapshot/continuation/
mob_state/tx/rx). Captura nativa do Arqueiro da Copa b1_native_canopy_archer_1
INVÁLIDA (sonda delegava ao manifesto do arqueiro jogador); sonda corrigida,
b1_native_canopy_archer_2 669/0 mostra a arte nova. Lobo/javali/warrior/gel/
companion reemitidos byte-idênticos (prova de produtor inalterado).
B2a Terra ([prévia](e08_p5_world_preview.md)): slot `stone` (cliff_tile) é único
para faces de penhasco, bordas, topos pintados e topos íngremes; quase toda pedra
visível é parede. Mosaico em .godot/verification/p5/B2a_terra_world_preview_probe_b2a_mosaic3.
Ao retomar após a queda, B2a sobrescreveu sem querer a própria sonda (a coordenação
informou erradamente que nada existia); reescrita e revalidada só em terraços,
números reproduzem; mosaico enviado é da versão anterior da sonda.

Decisões do usuário: grama e areia novas adotadas; **terra nova adotada como está**
(ciente da proximidade de tom com o vermelho de perigo); pedra nova rejeitada,
cliff_tile mantido; samambaia/flores/cogumelos/tronco adotados como variantes
decorativas; bétula substitui ~25% dos carvalhos por mapa de forma determinística,
com o mesmo corpo físico e pivô ajustado (.515/.977, altura ~228,5, a confirmar por
Sol). Próximo: B2b Sol/Opus — revisões de material, catálogo de props, colocações
e republicação dos três mapas, preservando geometria/rotas/populações/navproof.


## Proveniência — decisão do usuário 8/11

O usuário pediu ao Codex que não escrevesse `provenance.json` para economizar
tokens. A coordenação gerou os registros: pastas de staging (materiais, props e
cada espécie), as três unidades de espécie e a política do empacotador. Cada
registro traz gerador, briefing usado como pedido, SHA256, dimensões, base de
direito `project_generated_output` e `prompt: null` com a nota "prompt exato não
registrado". Status `generated_project_art_prompt_unrecorded`. Nenhum prompt foi
inventado; isso deixa de bloquear a promoção.

## Fase B — B2b e integração da coordenação 8/11

B2b Sol ([recibo](e08_p5_world_delivery.md)): grama/terra/areia em arquivos v2
(`terrain_material_v3`, pedra = cliff_tile); catálogo de props revisão 3 com 11
definições; bétula com corpo/regras idênticos ao carvalho e pivô (0,52; 0,94), altura 226,
coerente com o perfil de raízes do carvalho (o pivô .515/.977 da prévia erguia a bétula
~8 unidades). Regra determinística por `sha256(sal + placement_id)`: 25% dos carvalhos →
bétula; 40% dos arbustos → decorações (samambaia 40%, flores 30%, tronco 15%, cogumelos
o resto); tronco e flores só em sítio plano. Nenhuma colocação criada, removida ou movida.
Três mapas republicados como novas revisões; Bosque do Santuário e `representative.rpp`
recompilados das fontes intactas (consequência mecânica dos pinos). Prova de igualdade
`e08_p5_world_republish_test` 63/63. A publicação não usou `map_into_population` porque
ele regravava âncoras em float32 e movia 7 âncoras de borda de célula nos Vales.

Integração da coordenação: teste novo registrado em verify.ps1; 12 pacotes
intermediários (rodadas 1–2 da B2b) apagados da árvore e da fixture, nunca versionados
(evidência P0_coordinator_cleanup_superseded1); pinos de UI do editor atualizados para o
catálogo de 11 itens (paleta de objetos/biblioteca/biome props 6→11, navegador da
biblioteca 17→22, busca "Árvores" retorna carvalho e bétula); fundo da expedição fora do
mapa passa a usar as texturas v2 (tintas inalteradas). Conferência visual da coordenação
nas capturas b2b_visual4: grama/areia/terra novas, bétula assentada como os carvalhos,
tronco em chão plano, penhascos inalterados.

Limites: os testes nativos de UI do editor (`run.ps1` LibraryNative/BiomePropsNative/
ObjectsNative/TerrainNative) exigem fixture espelho completa e não rodam pela fixture P5.
Uma tentativa de LibraryNative (evidência B2b_sol_world_native_p0_library_native1) mostrou
as checagens de catálogo de 11 itens verdes, mas também o erro `lock` em
`_preparation_metrics_mutex` nulo (`world_connectivity_batch.gd:205`) durante compilação
no editor. Esse mutex veio da F10 (2ff1c00f, 5/11), arquivo não tocado na P5;
LibraryNative não era rodado desde a F9. Exportação de release (`map_editor_candidate
-Stage Release`) não repetida.

Luna/Haiku 8/11 (B2b_sol_world_verify_luna_p5_verify1 e sondas luna_p5_*): sincronização
com 0 entradas; 47 testes do verify com código de saída 0 (inclui pilot 191, species 172,
forest_ambience 58, asset_manifest 7/7, world_republish 63/63); 12 testes de mapa pelo
wrapper com as contagens esperadas (terrain 102, terrain_scale 46, biome_props 30, objects
53, cliff 61, forest_species 7, phase_rules 12, phase_release 11, phase_presentation 10,
forest_phase 9; em janela forest_profile 3 e forest_play 20). Nenhum SCRIPT ERROR;
hash do manifesto da fixture igual no início e no fim. P5 tecnicamente validada; aguarda
aceite visual do usuário.

# E08 P5 B1 — arte própria das três espécies (entrega Terra)

Base `fd32d346`, checkout `.tools/map-editor-m5`, branch `codex/e08`. Sem commit/push.
Evidências em `.godot/verification/p5/` (prefixo `B1_terra_species_art_`).

## O que foi empacotado
Três unidades V2 (64 poses, 4 vistas x 16) a partir das folhas 4x4 do Codex em
`assets/art/e08_world/staging/species/<id>/{south,north,east,west}_source_v1.png`
(somente leitura): `e08_forest_stalker` (kind warrior), `e08_forest_canopy_archer`
(archer, arco embutido) e `e08_forest_warden` (beast_master, chefe). Cada uma em
`assets/art/e08_enemies/directional/<id>/` (source_recipe.json, recipe.md,
calibration.json, body.png, presentation.json, provenance.json, delivery.md; arqueiro
também weaponless.png) e unidade padrão em `assets/art/animations/directional/<id>/`
(body.png, presentation.json; arqueiro também weaponless.png) com `.import` copiados
da fixture. Estagiário e padrão têm os mesmos pixels e o mesmo `rgba_sha256`.

## Escalas e alturas
Altura mediana de repouso dos corpos genéricos (warrior/archer/beast_master): 50 px.
Receita: `generated_views`, `per_view_scale` (cada vista usa a própria mediana de
repouso, pois as folhas geradas têm tamanhos diferentes entre vistas; com escala
global as vistas variavam 46–51 px), `target_height` 50/50/55. Resultado (repouso
medido): Espreitador 49–51; Arqueiro da Copa 48–51; Guardião 53–55 (~1,1x; 57,5 exigiria
passar do limite 56). Todos os quadros cabem em 58x56 (máx. medido 58x55 no Guardião),
chão 57 em todas as poses. Escala por vista: Espreitador 0,184/0,189/0,198/0,182;
Arqueiro 0,188/0,184/0,181/0,179; Guardião 0,195/0,199/0,195/0,190.

## Produtor
`tools/prepare_e08_enemy_directional_art.py`: novos ids em `KINDS`; recipe com
`generated_views:true` exige `target_height` explícito (8–56) e só aceita folhas geradas
(sem `native_cells`/`indices`); `per_view_scale` empacota cada vista com o empacotador
existente (`build_unit`, não alterado) e mantém o bloco da vista; arqueiro mede mãos e grava
weaponless; `provenance.json` pendente com SHA256 das entradas. Somente recorte/matte/escala/
empacotamento, sem desenho. **Unidades existentes inalteradas**: o caminho de código nativo
não mudou e as seis receitas (warrior, beast_master, gel, animal_companion, wolf, boar)
foram reexecutadas; `git status` limpo para elas (png, presentation, calibration idênticos ao HEAD).

## Calibração
Espreitador/Guardião: como o NPC warrior (slots neutros, cabeça invisível, `ground_y`
medido do pixel). Arqueiro (kind archer exige `weaponless` e empunhaduras reais fora das
poses de morte): `main_hand`/`off_hand` = centro de componentes de cor de pele fora da zona da
cabeça (47% superior do quadro), `fingers` 3x3 sobre pixels opacos; main_hand = lado do arco
(maior x em S/L, menor em N/O), convenção geométrica, não anatômica. Conferido em sobreposição:
maioria nas mãos/antebraços; em poucos quadros de dano/morte do lado oeste o ponto cai no
capuz ou na barra da capa (pixel válido, sem efeito: NPC não projeta equipamento).

## Testes (wrapper)
`tests/e08_species_presentation_test.gd` ganhou `real_units()` (manifests reais presentes: corpo
próprio V2 via `configure_occurrence`/`install_forest_atlas`, tinta branca, `equipment_visual`
vazio e sem projeção após resync, kind igual ao `MobDefinition`, 64 poses com chão 57, 64 poses
renderizadas não vazias ≤58x56, arqueiro com weaponless próprio); o caso "volta ao genérico do
Arqueiro" agora força manifest ausente (o padrão real existe). Fixtures/seam intactos.
`tests/e08_directional_npcs_test.gd`: o caminho esperado das espécies da floresta agora é o
visual_id do catálogo (sem relaxar asserções). Verify `b1_verify4`, 10 testes, todos 0 falhas:
species 172, directional_npcs 1292, pilot 191, presentation 2204, directional_content 3461,
e07_f3_snapshot 52, continuation 2743 (30 cenários), mob_state 372 (4), e06_tx_mob 27, e06_rx_mob_ai 4.

## Prova nativa
`tools/e08_directional_npc_probe.gd`: `SPECIES_KINDS` mapeia os três visual_ids aos kinds.
Probe (`native <id> --default`): `b1_native_stalker_1` 537 checks, `b1_native_warden_1` 537, `b1_native_canopy_archer_2` 669; 0 falhas, 8 capturas cada (64 poses, calibração por vista, câmera
50/100/160). Olhei as capturas: vistas L/O olham para o lado correto, arco/cajado/adagas no lado
alvo, pés no chão (linha de chão da calibração), sem recorte, escala próxima ao genérico
(Guardião um pouco maior). Ressalvas: o pose de ataque leste do Guardião lê como preparo; a aljava
do Espreitador só aparece de lado/costas; cintilação/tinta em jogo não medidas.

## Correção da captura do Arqueiro da Copa
`b1_native_canopy_archer_1` (405 checks) é **INVÁLIDA**: o probe delegava ao binding do jogador
quando `unit_kind` era `archer` (`F.ORIGINS`) e renderizou o corpo antigo (túnica laranja), não a arte
nova. Correção em `tools/e08_directional_npc_probe.gd`: ids de `SPECIES_KINDS` sempre seguem o caminho
NPC (`bind_animation` e `cost_visual`), ligam exatamente o `manifest` da espécie, checam
`actor_kind==unit_kind`, `equipment_visual` vazio e que o atlas ligado está na pasta da espécie.
Nova captura `b1_native_canopy_archer_2`: 669 checks, 0 falhas; `01_body_64.png` mostra o arqueiro de
capuz/manto de folhas, arco no lado alvo em L/O. Espreitador e Guardião (guerreiro/mestre das feras não
são tipos de jogador) já usavam o caminho da espécie: capturas visualmente confirmadas (capuz com folha,
adagas; galhada/cajado); não reexecutadas (sem o novo check de caminho; b1_sync7 inclui a correção).

## Evidências e falhas
sync `b1_sync2..b1_sync6`; import `b1_import2`; verify `b1_verify1` (falhou:
`directional_npcs` esperava caminho genérico; corrigido), `b1_verify2` (colisão de fonte com a B2a,
repetido), `b1_verify3` (3 falhas do meu teste: deslocamento de chão é 1,0, não 0; corrigido),
`b1_verify4` (verde); nativos `b1_native_{stalker,canopy_archer,warden}_1`. Quedas de energia
interromperam a sessão uma vez; os arquivos foram regenerados e o hash rgba conferido (body e weaponless).

## Limitações
Proveniência do Codex pendente (hashes de entrada registrados, prompts nulos). Aceite visual humano
pendente. Arte de espécie fora da cena de mapa real (sem captura em mapa). Empacotamento descarta
fragmentos soltos (keep_character) e reduz com LANCZOS + alfa 128. Staging do Codex não alterado.


## Proveniência — decisão do usuário 8/11

O usuário pediu ao Codex que não escrevesse `provenance.json` para economizar
tokens. A coordenação gerou os registros: pastas de staging (materiais, props e
cada espécie), as três unidades de espécie e a política do empacotador. Cada
registro traz gerador, briefing usado como pedido, SHA256, dimensões, base de
direito `project_generated_output` e `prompt: null` com a nota "prompt exato não
registrado". Status `generated_project_art_prompt_unrecorded`. Nenhum prompt foi
inventado; isso deixa de bloquear a promoção.

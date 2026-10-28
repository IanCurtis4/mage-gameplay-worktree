# F9 — desenho da área de aceite: Bosque do Santuário

Estado: **terreno das duas peças criado via AX, compilado e reaberto**: [clareira](../../../data/map_authoring/sanctuary_woods_clearing.source.json) e [passagem](../../../data/map_authoring/sanctuary_woods_overpass.source.json), com [recibo do replay limpo](evidence/f9/terra/area_terrain/clean_replay/report.md). Props, contexto e entrada foram adicionados por AX e reabertos; [recibo de conteúdo](evidence/f9/terra/area_content/README.md). Avaliação artística, composição, encontros, travessia com corpo de raio 20 e altura 32 e gameplay permanecem pendentes. O alvo é F9-12 e a [amostra de validação](../validation.md); F10 depende de autorização própria.

## Planta e coordenadas

Unidades do mundo; X/Z locais em cada peça, Y é altura. Ambas ocupam 0–1280 em X e Z; instanciar B em (1280, 0, 0), sem rotação. A entrada está em A (160, 0, 640); a emenda é A (1280, 0, 640) ↔ B (0, 0, 640), com largura 256, normais leste/oeste, sentido `both`, tag `map_editor` e folga declarada 128. Manter plana a vizinhança da emenda. Uma largura ou folga declarada não comprova passagem.

**A — clareira.** Grade `a_ground`, origem (0,0), 21 colunas × 21 linhas, passo 64, Y=0. A trilha curva de terra passa por (160,640), (320,640), (576,512), (832,512), (1088,576), (1280,640); raio de pintura 112, dureza 0,25 e força 0,85, sobre grama. Clareira de combate em (384,640), fora do arvoredo. Uma colina discreta arredondada em (320,224), raio 192, força 24, dureza 0, deixa fora da influência o corredor e a emenda. Fazer a colina antes da pintura; conferir que as faces geradas e seus apoios permanecem acessíveis. A clareira não é uma sala cercada por paredes de árvores.

**B — corte em planta.** As grades abaixo partilham apenas bordas, nunca interiores coplanares. Os IDs são propostos para operações do editor. Cada grade começa com altura uniforme; a rampa é esculpida depois. O solo elevado é massa até sua base: não existe piso baixo sob qualquer platô. A única sobreposição vertical intencional é a ponte fina sobre o piso central.

| ID | Origem X/Z | Colunas × linhas | Passo | Altura | Extensão X/Z |
|---|---:|---:|---:|---:|---|
| `b_west` | (0,0) | 5 × 11 | 128 | 0 | X 0–512, Z 0–1280 |
| `b_low` | (512,384) | 7 × 5 | 128 | 0 | X 512–1280, Z 384–896 |
| `b_north_ramp` | (512,0) | 3 × 4 | 128 | 0 inicial | X 512–768, Z 0–384 |
| `b_north_top` | (768,0) | 5 × 4 | 128 | 128 | X 768–1280, Z 0–384 |
| `b_south_ramp` | (512,896) | 3 × 4 | 128 | 0 inicial | X 512–768, Z 896–1280 |
| `b_south_top` | (768,896) | 5 × 4 | 128 | 128 | X 768–1280, Z 896–1280 |

Em cada rampa aplicar `ramp` com `shape=square`, `radius=512`, `strength=1`, `hardness=1`, `target=0`, `end_height=128`: pontos norte (512,192) → (768,192), sul (512,1088) → (768,1088). Cada seleção limita o pincel à sua grade; a inclinação planejada é 128/256, cerca de 26,6°, abaixo de 45°. O pincel cobre a largura inteira, com bordas coincidentes em Y=0 no oeste e Y=128 no leste. Os lados inclinados para a faixa central são bordas de alturas diferentes, não uma conexão transversal presumida.

Superfície especial `b_bridge`, associada a `b_north_top`, origem (896,384), largura X=256, comprimento Z=512 e altura Y=128: une as bordas norte e sul dos platôs. Seu centro é (1024,128,640). A faixa inferior permanece em `b_low` a Y=0 e passa sob a ponte ao longo de Z=640: (640,0,640) → (1024,0,640) → (1180,0,640), com retorno. O compilador atual representa a ponte como espessura 4, então a distância geométrica nominal da face inferior até o chão é 124, sujeita a comprovação de colisão. A rota superior parte de (256,0,192), sobe até (864,128,192), atravessa (1024,128,448) → (1024,128,832), chega a (864,128,1088) e pode voltar pela rampa sul a (256,0,1088). Santuário no platô norte em torno de (1056,128,192); beco e grupo de combate na parte oeste/sul, em torno de (320,0,1088), com caminho de volta aberto. A faixa central é o corte que justifica a ponte; o chão inferior não precisa atravessar o sólido dos platôs.

O preview usa perfil real raio 20 e altura 32; não são dois raios diferentes. `Candidate.prepare` exige um ponto válido e alcançável em **cada** suporte caminhável, e ida/volta para objetivos e portais. Compilar e testar todas as bordas entre grades, os dois extremos da ponte, o piso sob ela e todas as faces geradas. A massa de terreno e o recorte de suporte podem inviabilizar a transição lateral ou isolar algum fragmento: coordenadas são hipótese construtiva, não prova. Se houver apoio inalcançável, corrigir geometria pela autoridade do editor e repetir a prova, sem omitir suportes nem relaxar perfis.

## Material e objetos

`grass` é o fundo e `earth` marca a trilha. Em B pintar no `b_west` com raio 112 a linha (0,640) → (256,640) → (384,768) → (384,1088), e pintar em `b_low` a linha (512,640) → (1180,640); completar a aproximação das rampas e o caminho ao santuário nas respectivas camadas. O traçado visual deve respeitar seleção por camada. Grama, terra e os seis itens do catálogo são reais; aqui usar somente `oak_tree`, `woodland_shrub`, `moss_boulder`, `broken_pillar`. Copas e suas sombras pertencem à apresentação existente; observar no jogo, sem assumir controle separado ou criar asset.

Pontos iniciais propostos, X/Z locais, `snap=0`; colocar sobre o suporte indicado e ajustar após compilação/inspeção:

| Peça/suporte | Definição | Posições X/Z |
|---|---|---|
| A `a_ground` | `oak_tree` | (128,160), (384,96), (640,128), (896,128), (1120,192), (128,1088), (384,1152), (704,1088), (992,1152), (1184,1024) |
| A `a_ground` | `woodland_shrub` | (192,256), (512,192), (768,256), (1088,320), (192,960), (544,1024), (832,960), (1120,960) |
| A `a_ground` | `moss_boulder` | (96,384), (640,320), (960,320), (128,832), (704,896), (1088,832) |
| B `b_west` | `oak_tree` | (128,128), (320,128), (128,384), (128,896), (128,1184), (384,1184) |
| B `b_west` | `woodland_shrub` | (256,256), (448,320), (160,800), (448,960) |
| B `b_west` | `moss_boulder` | (128,480), (160,1056), (448,1184) |
| B `b_north_top` | `broken_pillar` | (896,96), (1120,96), (1216,256) |
| B `b_south_top` | `broken_pillar` | (896,1184), (1120,1184), (1216,1024) |
| B `b_low` | `woodland_shrub` | (640,448), (768,832), (1184,448), (1184,832) |

Conservar entrada, emenda, rampa e bordas da ponte livres, com largura útil planejada de pelo menos 160 entre obstáculos. As posições são rascunho: raio e caixa reais dos props, declive local, aproximação e corpos podem exigir deslocamento. Verificar especialmente `a_ground` com colina e os pilares no platô. Menos de 30 props por peça fica abaixo do teto 1024; não implica que o pacote cumpra o teto de 4 MiB, nem que toda face esteja acessível.

## Sequência AX e checkpoints

1. Após validação do produtor, criar A vazia e `terrain/grid/create` com os campos da tabela; `terrain/layer/select`, traço `terrain/brush/stroke` `rounded_hill` e depois `material` com os valores acima. Criar conector leste com `terrain/connector/upsert`: `connector_id=a_east`, `surface_id=a_ground`, `position_xyz=[1280,0,640]`, `normal_xyz=[1,0,0]`, `width=256`, `headroom=128`, `kind=walk`, `direction=both`, `tags=[map_editor]`. Compilar e salvar pela sessão AX com caminho e proteção de conflito.
2. Criar B vazia, executar seis `terrain/grid/create` com `layer_id`, `name`, `origin_xz`, `columns`, `rows`, `sample_spacing`, `height` da tabela. Selecionar as rampas uma de cada vez e aplicar os dois traços `terrain/brush/stroke` especificados. Criar `terrain/bridge/create` com `surface_id=b_bridge`, `layer_id=b_north_top`, `origin_xz=[896,384]`, `width=256`, `length=512`, `height=128`. Pintar as camadas; criar conector oeste `b_west_gate`, superfície `b_west`, posição [0,0,640], normal [-1,0,0] e demais campos iguais a A. Compilar antes de objetos; conferir diagnóstico, suportes e alturas.
3. Consultar `objects/library/query`, selecionar definição por `objects/library/select` e usar operação semântica de colocação com `definition_id`, `surface_id`, `position_xz`, `snap`; mover objeto por ID e exercitar desfazer/refazer. Salvar e reabrir ambas as peças. IDs finais de faces compiladas e de objetos são os retornados pela sessão, nunca IDs supostos.
4. Criar composição manual, adicionar as duas fontes, posicionar B e vincular os conectores; compilar e demonstrar ida/volta através da emenda e nas rotas superior e inferior. Inspecionar alcance de todos os apoios, corpo e teto, não apenas os endpoints ilustrativos.
5. Criar entrada em A, população dispersa no entorno da clareira, grupo concentrado no oeste de B e slot fixo em rota ida/volta perto do beco, sem ocupar corredores. Escolher espécie/categoria/origem disponíveis e verificar corpo e leash; incluir `phase_completion` no santuário. Preparar/aplicar prévia, configurar patrulha, compilar, salvar/reabrir e testar pacote real com perfil descartável. Conferir navegação, combate e retorno. A geração com pins exige variantes reais compatíveis; demonstrar também intercâmbio em clone e rejeição sem perda conforme a amostra de validação.

## Estado das operações AX e lacunas

Inspeção estática em andamento: `terrain_panel.gd` anuncia `terrain/grid/create`, `terrain/layer/select`, `terrain/bridge/create`, `terrain/connector/upsert` e `terrain/brush/stroke`; as primeiras operações estão em implementação/validação, não presumir que estejam liberadas ou aprovadas. `objects/library/query` e `objects/library/select` existem, mas consulta e seleção não posicionam um objeto. Faltam verificar na versão integrada operações semânticas com parâmetros de colocação/movimento e seleção de superfície; inserção/posicionamento e ligação de peças; caminhos e confirmações de arquivo; pintura de entrada/pincel/slot/interação; seleção e configuração de rota, pontos e vínculo de slot; geração e intercâmbio. Botões genéricos sem parâmetros dependem de campos, seleções, diálogos ou cliques e não provam essas capacidades. Conferir `ax_snapshot()` e contrato efetivo antes de autoria; nenhuma fonte deve ser alterada diretamente para contornar lacuna.

Conferidos [sólidos](../contracts/f9_terrain_solids.md), [relevo misto](../contracts/f9_mixed_relief.md), implementação de operações de terreno, amostra de rampa/ponte e consumidor `Candidate.prepare`. O exemplo serviu apenas para entender superfícies, nunca como mapa final. Inspeção estática, sem engine/processo, criação de mapa ou suíte de gameplay; travessia, aparência, desempenho e aceite humano permanecem pendentes.

## Estado do terreno — replay limpo

As duas fontes de terreno foram criadas via AX e preservadas em `data/map_authoring/sanctuary_woods_clearing.source.json` e `sanctuary_woods_overpass.source.json`. Replay na fixture importada reproduziu seus bytes; reabertura das fontes originais na mesma fixture reproduziu hashes de fonte e compilação. Detalhes, comandos e ressalvas em [recibo de terreno](evidence/f9/terra/area_terrain/clean_replay/report.md). **Terreno criado**; props e contexto foram acrescentados posteriormente. Permanecem população, composição entre peças, teste jogável de corpo raio 20/altura 32 e aceite visual. As coordenadas acima permanecem intenções sujeitas à comprovação de navegabilidade.

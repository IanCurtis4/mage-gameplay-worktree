# F2 — fechamento com a direção corrigida, revisão técnica2

Autorização humana posterior em24/10/2026: “Faça o que tiver que ser feito agora,
com a documentação nova em mente, para fechar F2.” Base executável
f0a854a39dc6687e2b6a514efa233ec34fd69bfd; mesmo checkout/branch de M2, árvore limpa.
A direção em terrain_piece_semantics.md já fixa produto; esta rodada detalha e
implementa engenharia dentro dessas escolhas. Não escolhe nova campanha/épico,
nem converte atores/renderer do jogo. Sol mantém correções e contrato técnico;
Luna supervisiona o candidato executável por impacto, sem gate Astra rotineiro.

## Resultado e propriedade

Fechar terreno de uma peça/célula, inclusive uma área grande e contígua. Área e
resolução interna são distintas. Autoria por altura/material e pontes; nenhuma
montagem de chão por objetos poligonais pré-desenhados. Representação interna
gerada automaticamente com superfícies de suporte convexas e adjacências reais.
Texturas repetidas, transição por máscara e sombreamento contínuo na projeção
isométrica aprovada. Conector editável com posição/superfície, sentido, largura e
folga; add/update/remove atômicos e preservados em IO/undo.

Sol mantém todos os arquivos nominais M2 do dispatch anterior. Acrescenta:
- scripts/map_authoring/compiler/terrain_partition.gd e .gd.uid
- scripts/map_authoring/terrain/terrain_material.gd e .gd.uid
- scripts/map_authoring/terrain/terrain_material.gdshader e .uid
- assets/art/map_authoring/grass_tile.png e .import
- assets/art/map_authoring/earth_tile.png e .import
- assets/art/map_authoring/materials.md
- tests/map_editor_terrain_scale_test.gd e .gd.uid
- scripts/map_authoring/io/decimal_float.gd e .gd.uid
- scripts/map_authoring/io/strict_json.gd (transferência pontual M1→Sol F2:
  conversão decimal exata; gramática, limites e validação permanecem)
- tests/map_editor_document_ui_test.gd (transferência pontual M1→Sol F2:
  tipo explícito WeakRef, exigido pelo scan nativo; nenhum oráculo alterado)
- docs/map_editor/contracts/m2_closure.md (este registro)
- docs/map_editor/delivery/evidence/m2/closure/ (evidência Sol)
- docs/map_editor/delivery/m2_closure.md (recibo consolidado Sol)

Luna recebe exclusivamente closure/luna.md e closure/luna_run/ após o congelamento
do SHA; não há escritor simultâneo nesses caminhos nem permissão para código.

Nenhum escritor simultâneo; não tomar arquivos do runtime E07/F8. Fonte/schema1,
Session/Store M1 e seus limites de leitura continuam consumidos sem alteração.
O cenário com máscaras fracionárias revelou perda de um ULP no String.to_float
do engine. O leitor estrito recebe conversor decimal corretamente arredondado;
não há quantização de alturas/máscaras nem tolerância no hash para esconder erro.
Sem props/população/composição M3/M4, catálogo completo, solver ou patrulha.
O terreno oferece fronteira para objetos detalhados separados; não achata objetos
em textura nem promete seu catálogo nesta entrega. Materiais novos são ativos
locais desta correção autorizada, com origem/prompts/hash registrados.

## Contrato técnico2 e provas

Particionar automaticamente a grade por regiões coplanares contíguas, com
identidade determinística. Uma região plana pode cobrir milhares de quadrados
visuais com um suporte canônico; relevo preserva amostras/triângulos necessários.
Sem simplificação de altura oculta. Conexões são derivadas de bordas geométricas,
nunca de proximidade projetada. Mapa/peça não se divide por orçamento técnico.
Limite defensivo separado para amostras visuais e suportes lógicos, acompanhado
de medições; não basta elevar256 e repetir trabalho quadrático por grade inteira.
As autoridades espaciais do runtime permanecem inalteradas.

Renderização do terreno usa os mesmos pontos3D projetados, UV em coordenadas de
mundo para repetição sem emenda entre quadrados e máscaras interpoladas. Linhas
de triangulação só em overlay diagnóstico. Suavidade visual não altera suporte.
Textura ausente/dependência alterada deve ser diagnosticada; não publicar
pacote visual sem suas dependências. Pacote revisionado informa materiais e
contagens distintas de peça, amostras, triângulos e suportes.

Grande fixture: uma única peça com grade65×65, área8192×8192 unidades do mundo,
subida/platô contínuos e dois materiais; tamanho é cenário medido, sem equivalência
numérica aprovada com os mapas das referências. Provar também grade129×129 plana,
edição local, roundtrip, determinismo entre processos, conexão e travessia reais,
ponte/passo inferior e erros de folga/LoS. Preservar contraprovas históricas,
atualizando oráculos apenas quando a nova partição altera deliberadamente o DTO.
Inspeção nativa e medição fria/quente separadas; nenhuma promessa de FPS/escala
ilimitada. Publicação/consumo no jogo e encontro ficam nos pacotes seguintes.

## Leitura de declive — complemento humano

O usuário acrescentou a referência de terreno íngreme automaticamente mais
escuro/pedregoso para distinguir passagem. O material do F2 deriva essa mistura
da normal geométrica suavizada, sem sobrescrever as máscaras de pintura. Faixa
inicial de apresentação: gradiente0,7 até1 (aproximadamente35°–45°); é parâmetro
técnico inicial, não uma nova regra aprovada de mobilidade. A rampa leve continua
com o material pintado. Clique e travessia continuam sob geometria canônica.

O compilador F2 ainda recusa suporte acima de45°; não inventa paredes/volumes de
montanha nem declara um talude escuro como bloqueador de projétil. A classificação
de faces não caminháveis com volume de terreno fechado deve entrar no contrato
de bloqueios do consumidor correspondente antes de publicar esse tipo de mapa.
Esta fronteira fica explícita; o contraste de material já pode ser inspecionado
na autoria e não mascara um suporte inválido. Testes exigem mistura derivada do
declive e preservação da pintura original.

Registro documental posterior ao fechamento: Sol conserva o retorno visual do
usuário em terrain_piece_semantics.md e no recibo m2_closure.md, com propriedade
adicional de delivery/evidence/m2/product_references/05_aom_terrain.png e da entrada
correspondente no manifesto de referências. Sem transferência de arquivos
executáveis, produção de asset ou abertura de outro marco por esse registro.

Confirmação humana posterior encerrou F2 com aceite visual e autorizou a sequência
F3. Sol registra a decisão no recibo/índice e possui exclusivamente
docs/map_editor/contracts/m3_preparation.md para a passagem documental. Isso não
transfere arquivos executáveis de M2, cria chat ou registra integração em playtest.

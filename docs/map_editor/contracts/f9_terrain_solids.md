# F9 — relevo, massa e apresentação de biomas

Engenharia Sol no contrato autorizado F9-02/03/10/11. Suporte contínuo já
validado no SHA50ba51ac. Inventário dos chats25/10 confirmou os produtores
Editor F0–F8, E07 catálogo e validação inativos; propriedade nominal transferida
em f9_ownership.json. Não muda renderer/projeção, unidades, regras de combate,
catálogos de espécies/recompensas ou o teto caminhável de45°.

## Geometria e pipeline

O relevo continua altura autorada em grade; refinar/suavizar muda os mesmos
vértices consumidos por suporte, ray pick e navegação. Nada de montar objetos
poligonais de chão ou suavizar só a imagem. Faces acima de45° serão visuais e
massas não caminháveis; uma peça mista pode contê-las. Fonte totalmente sem
suporte caminhável falha claramente. Rampas reais conectam patamares; penhasco
não vira rampa por textura. Máscaras de pintura permanecem autoria independente.

Adicionar volume canônico de prisma de terreno: topo convexo/plano em Vector3,
fundo horizontal abaixo do topo ou capa paralela de espessura vertical positiva,
ID e ID opcional do suporte do topo. Auxiliar
puro valida/transforma e calcula planos escalares f64/contato; não usar AABB como
substituição visual de uma encosta inclinada. Envelope de corpo é conservador,
como as primitivas atuais; raios de raio zero usam as faces reais. Definir e
testar contato/tangência, lados/fundo, altura e revisão, sem aumentar EPS.

Consulta de movimento no chão ignora apenas as massas sob o suporte atual e os
vizinhos realmente conectados no contato local do disco. Isso evita que a própria
encosta caminhável colida com o pé. Não ignora penhascos, massa de outro piso,
obstáculos ou teto. Sweep genérico/projétil/LoS conserva as massas. Regiões de
skills também conferem interseção de massa acima de outro piso. Não duplicar
fórmula espacial em ator/UI; WorldActorMotion consome a consulta canônica.

Fonte → terrain compiler → composição → manifest → prévia/jogo/export conserva
o prisma e seu ID de suporte, transformados uma única vez. PartDefinition e
assembler devem propagar a capacidade ou recusar explicitamente; nunca descartar
um sólido. Campos opcionais ausentes conservam dados/hash legados. Conexões
internas de uma peça rica precisam de representação explícita para seu consumo
no assembler; o comparador F6 não pode fingir capacidade que ainda não tem.
WitnessGraph deve consumir WorldGeometry para evitar voltar a pontos centrais
obrigatórios em uma abertura cuja lateral está livre. Preservar testemunhas,
direção, revisões e identidade. Migração entre builds continua fora do contrato;
snapshots incompatíveis são recusados sem destruir a revisão guardada.

## Materiais e biomas

Materiais Grama/Terra/Areia/Pedra usam albedos locais passivos, origem/prompts e
hashes; declive mistura pedra gradualmente, sem escrever na máscara do autor.
Coordenadas de pedra nas faces íngremes devem incluir altura para evitar esticar
textura de chão em um penhasco. Usar o shader canvas existente e a projeção
compartilhada, com mipmaps e escala de mundo, sem renderer novo.

Perfis floresta/deserto/planície/ruína mantêm dono único por span, abertura real
e passagem livre. Floresta usa mata/raízes densas; deserto, montes/cactos; planície,
córrego com margens/desnível legíveis; ruína, escombros e alvenaria. Água é
apresentação do canal, sem natação/salto. A margem e a ausência de suporte
justificam a restrição; água não recebe muro invisível nem bloqueia ataque por
inferência. Transições têm preset explícito ou autoria local. Perfil/asset ausente
falha. Definições de props continuam imutáveis; copa/folha não amplia tronco.

## Provas necessárias antes do consumidor seguinte

Testes de prisma e de rampas/platôs/penhascos, raio/LoS/corpo, disco sobre encosta,
piso inferior/teto, buraco e emendas. Roundtrip, transformação por rotação/offset,
snapshot e material adulterado/ausente. Corpus orgânico real com caminho curvo,
curvatura de silhueta e mistura de materiais; capturas nativas com actor/props e
envelope visível. Custo frio/quente e amostras representativas/estresse, sem
declarar medições isoladas como FPS. Regressão por impacto com Luna; ambiente e
export limpos. Esta especificação não certifica implementação ainda ausente e
não fecha F9 nem abre F10.

## Estado técnico intermediário — não certificado como entrega F9

Primitiva implementada em world_solid_prism.gd;37 checks autorais iniciais em
`delivery/evidence/f9/author/relief_snapshot_01`. WorldGeometry valida massa ao
configurar, ground_sweep ignora só os suportes locais, teleporte só normaliza a
capa se os extremos ficam acima de seu plano, região confere massa, e snapshot
recusa massa malformada na captura/restauração. Malha23 passou em relief_mesh_02
antes da guarda posterior de snapshot. O delta seguinte implementa emissão por
terreno/composição, transporte por PartDefinition/assembler, ligações internas
opcionais e WitnessGraph canônico;52 checks autorais PASS em relief_witness_01.
Render de lados/materiais e prova oficial de geração ainda estão pendentes.
Arte nova já foi
copiada e importada; catálogo/shader/perfis ainda não a oferecem. Não certificar
essa etapa por esses testes parciais.

Índice espacial derivado e vértices de desvio já implementados e provados no
corpus52; medir a regressão completa antes de congelar. O índice bounded
de sweep evita percorrer todas as massas por passo. O grafo de massa convexa
inclui obstáculo cuja projeção ocupa só parte do suporte. O contorno bloqueante resulta de cortar o polígono do suporte
pelos planos da massa expandida pelo perfil; projetar o plano do suporte em
escalares f64. Não usar só os cantos do AABB de uma encosta. Criar candidatos
ligeiramente fora desse contorno, revalidar corpo/folga/suporte e segmento
inteiro. Mesmas consultas canônicas, sem navegador paralelo.

Região na própria capa deve ignorar a massa correspondente explicitamente;
normal de apresentação em Vector3 pode perder precisão frente ao plano f64,
principalmente160/400 e200/400. Pré-flight valida vínculo dos vértices ao suporte;
não ignorar massa de outro piso. Testar rampas originais com massa, penhasco
bloqueante, desvio real, teleporte que tentaria atravessar a encosta e snapshot.
Broadphase e cache não alteram narrowphase nem substituem estado do estágio.

Retomada26/10: Core parou no timeout de população300s. Diagnóstico encontrou
contatos com identificação de suporte diferente e precisão das emendas, além
de falsos bloqueios nos cantos do envelope de massa. Correção usa half-ULPs
projetados, sem ampliar EPS/raio, e transições locais por conexão real, direção,
kind, folga e validade de ambos os suportes. Sweep do corpo também intersecta
o intervalo do disco horizontal contra o contorno convexo; não alarga a união
de pisos para esconder colisões. Malha31 PASS autoral em relief_precision_mesh_03;
novos oráculos de canto passaram no corpus56. Core639 e seleção oficial F0
56/149/198 concluíram sem erro/timeout. População passou em126,504s com o teto
300s mantido. Rodadas autorais anteriores à guarda final do segmento inteiro
até o destino exato; SHA de consolidação e supervisão serão registrados no
recibo. Nenhuma apresentação/material/bioma é certificada por essas provas.

Depois fechar emissão de terreno misto caminhável/penhasco, materiais e famílias
de borda, além da abertura lógica sobre malha refinada no contrato próprio.
Repetir regressão
por impacto e medições; só então próximo checkpoint de supervisão.

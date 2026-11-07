# P4 — revisão artística de equipamentos

7/11/2026. Autorização humana atual: diminuir e encaixar o capacete; revisar
armas e escudos com aparência mais desenhada; produzir drops temáticos, usando
https://www.spriters-resource.com/pc_computer/ragnarokonline/asset/127576/
como referência de estilo/tamanho. Criar um agente paralelo foi pedido expresso.
Não muda a produção direcional dos personagens. Base de API/checkout:
`dd68005cb416a764863550b44c290b65613550c6`, branch codex/e08,
`C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5`.
O SHA documental entregue antes da escrita identifica esta lista versionada.

Dono Terra6.1 médio em [lista exata](e08_p4_gear_art_files.json); Root coordena,
Sol mantém renderer/fixture de outras três unidades. Não editar runtime, catálogo,
testes, fontes legadas, imports externos, saves, globals ou arquivos de outros.
Sem Godot/importação/commit; staging fora da descoberta automática. Fontes
originais e prompts preservados. Usar ragrpg-art/imagegen integrado, sem CLI API.
Este pacote artístico não toma posse da integração/renderer.

## Entrega observável

Inventariar os14 equipamentos de cabeça reais (ID,nome,qualidade,origem,consumidor)
e as7chaves de arma/acessório atuais, confrontando o loot real; não assumir
que nome de classe define mob de origem. Criar mapa cosmético explícito por ID,
sem nova elegibilidade/raridade/taxa/drop/slot ou fórmula. Itens cinza/branco
de mobs básicos terão leitura convencional quando realmente existentes; não
reclassificar qualidade ou inventar um drop Guerreiro. Conservar nomes/temas já
explícitos; variações temáticas podem ser desenhadas dentro desses temas.
Os exemplos maçã atravessada por flecha e casca de ovo são estudos autorados
adicionais e identificados como ainda sem novo ID/drop, até vínculo concreto.
Não recolher sprites da referência para incluir no produto: observar proporção,
contorno e materiais e criar arte própria com fontes/proveniência.

Produzir os14visuais de cabeça reais e2estudos em quatro vistas S/N/E/W,
mesma identidade reconhecível, lateral real, encaixe pequeno sobre crânio sem
cobrir olhos/rosto. Meta inicial da cobertura de um elmo comum:18–20px de largura,
14–16px de altura lógica (antes o domo tinha26x20); assimetrias ficam coerentes.
Usar atlas por ID quatro células horizontais96x96, arquivo384x96, equivalente a
24x24 lógicos por vista (4x). Âncora inicial lógica[12,13]; declarar bbox/âncora
real em presentation.json. Escolher adereços proporcionais, sem inflar todo elmo.

Refazer espada,machado,cajado,arco,escudo,foco e contas com desenho fantasy
pintado, contornos finos orgânicos, materiais e volume, sem degraus grossos/crisp
procedural. Preservar tamanhos/grips lógicos atuais para não invalidar mãos:
sword16x32/8,25;axe20x32/10,25;staff16x40/7,30;bow20x34/14,17;
shield20x26/10,13;prismatic_focus14x20/7,16;wooden_beads12x12/6,5.
PNG com resolução4x, alpha real, bbox/logical_size/grip claros. A conversão
posterior deve desenhar em tamanho lógico e filtrar somente anexos; não alterar
filtro/corpo do personagem nem compensar arma maior mudando regra de alcance.

Fonte imagegen pode ser folha em grade; crop/empacotamento mecânico em ferramenta
NOVA própria autorizada, sem sintetizar arte por geometria, apagar props por
código ou editar ferramenta compartilhada. Preservar margem transparente e
RGB invisível normalizado na medição. A ferramenta nova não é consumidor de jogo.

## Provas e handback

Inspecionar saídas e mostrar contact_sheet.png sobre claro/escuro em1x e ampliado;
comparar cabeça nua/cobertura e manter olhos visíveis na proposta. Conferir alpha,
dimensões, fontes/hashes e mapping de todos IDs/chaves. Registrar prompts e uso
imagegen integrado em recipe/provenance, limitações e partes não concluídas.
Se uma geração falhar, corrigir de modo localizado e continuar independentes;
nenhuma expectativa/teste é relaxada. Arte pronta em staging não prova encaixe
nativo: Root/Sol fará no renderer real pós handback, incluindo retrato/mundo,
64poses, quatro direções, morto, UI120/câmera50/100/160 e exportação.
Este é mesmo P4, não abre P5 ou novo kit de gameplay; sem master/push/playtest
pessoal. Devolver posse integral com arquivos/hash/pendências explícitos.

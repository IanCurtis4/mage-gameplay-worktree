# Autoria dual e modos UX / AX — F8

Decisões humanas25/10/2026; implementação/candidato e evidências no [recibo M8](delivery/m8.md).

A **peça é a mesma fonte** para montagem manual e geração por seed. Seu tamanho
é independente da grade técnica; pode representar uma sala ou área extensa.
Uma instância escolhe uma revisão imutável da peça. Alterar a fonte não reescreve
os mapas já montados: reimportar a peça é uma escolha explícita.

## Contexto e encaixes

**Contexto da peça…** configura vários biomas, espécies elegíveis, permissão de
sorteio de raros e áreas internas. Lista vazia de espécies permite o catálogo;
lista vazia de biomas não restringe destino. Os IDs de bioma são classificações
de autoria, não um novo catálogo artístico ou novas políticas de recompensa.
Origens/categorias/espécies continuam passando pelo catálogo e policies canônicos.

**Conexões** edita borda/piso, posição, orientação, largura, folga e sentido.
O compilador confere a abertura e o vínculo real. Declaração de compatibilidade
não dispensa suporte, colisão, altura, passagem do corpo ou rota de retorno.
Biomas compatíveis e encaixes geométricos são restrições distintas.

Áreas internas são regiões da camada, autoradas por retângulos nesta interface;
o formato suporta polígonos. Podem restringir espécies/sorteio de raros ou reservar
um encontro identificado. Uma reserva contém espécie, categoria, origem e uma
referência opcional de quest. Ela não entra no sorteio comum. Preparar a prévia
de encontros realiza um slot fixo, com corpo e rota válidos, ou apresenta falha.
Publicação exige exatamente um slot correspondente à reserva. A referência de
quest fica nos dados; não cria objetivos, grants, progresso ou sistema de quests.

**Contexto do mapa…** define o bioma de destino e exceções por instância: bioma,
espécie, sorteio de raros ou reserva. Escolher regra e informar motivo são
obrigatórios. Avisos acompanham fonte, compilação e export. Exceção não libera
catálogo inválido, conector quebrado, ausência de suporte ou corpo sem rota.
Receitas e geração por seed recusam exceções manuais; não as herdam em silêncio.

Contexto é uma extensão opcional, com `version=1`, da fonte1. Fontes antigas não
ganham campos nem hashes novos só por abrir. Novas fontes carregam o contexto
nos snapshots, no intercâmbio e no pacote compilado. O limite do pacote continua
4MiB. Recompilar uma fonte não reescreve expedições pessoais existentes.

## Tema dos encontros

O usuário esclareceu que palco crível é **diretriz editorial de imersão**, não
gate inexorável. Um raro pode ser colocado manualmente sem palco. Líder de bando,
animal solitário forte e chefe com lacaios orientam composição, doodads, iluminação
e ambientação quando estes recursos estiverem disponíveis. Autor humano e agente
seguem a mesma direção. O compilador não pretende avaliar qualidade narrativa.

Palcos temáticos do F4 permanecem utilizáveis e validam referências quando
declarados. A permissão de sorteio não impede um raro fixo manual; espécies,
reservas, catálogo e corpo continuam sendo conferidos. Sorteio de raros usa a permissão configurada; reserva é intenção de
conteúdo explícita. Nenhum campo temático altera loot, respawn ou fórmula de dano.

## Duas apresentações, mesmas operações

UX é a apresentação inicial. Ações são agrupadas em Arquivo, Editar, Criar,
Visualizar, Validar e testar e Intercâmbio. No terreno, uma seleção de ferramentas
mostra Pincel, Nova grade, Ponte ou Conexões para reduzir ruído. A prévia continua
central; grade técnica é opcional. Diálogos mantêm confirmação, histórico e
proteção de arquivo dos respectivos produtores.

AX expõe ações diretas e uma paleta sobre a prévia, com identificadores estáveis
em inglês por tela/ação, como `piece/apply_name`, `map/toggle_test` e
`population/simulate_death`; rótulos permanecem pt-BR. A tabela explícita de IDs
não depende da tradução de um rótulo. Ferramentas de simulação ficam neste modo. A API local de
inspeção `ax_snapshot()` retorna fonte em cópia, ações, IDs e disponibilidade;
`ax_invoke(id)` exige AX, rejeita ação ausente/desabilitada e chama o controle
original. Não oferece bypass de validação, publicação, histórico ou confirmação.
As CLIs existentes continuam sendo o caminho para operações sem interface.

A seleção UX/AX é compartilhada pelas telas abertas e herdada por telas novas.
Alterná-la não salva, altera fonte, recompila, consome seed ou modifica histórico.
Não é um estado de gameplay e não é gravado no catálogo da peça.

## Revisão das lacunas do plano

F0–F7 entregam autoria de terreno/composição/encontros/patrulhas, WFC opcional e
intercâmbio. As tabelas originais em architecture.md e validation.md descrevem
objetivos, não certificam que toda função lá mencionada exista. Este F8 acrescenta
contexto compartilhado e UX/AX. A evidência deve distinguir funcionalidade,
usabilidade humana, arte e escala.

Limites a apresentar no candidato: publicação local não instala uma fase na
campanha; mapa por seed escolhe variantes em slots, sem esculpir terreno livre;
pins preservam instâncias inteiras; variedade de biomas não cria barreiras de
floresta/deserto; props/doodads/vegetação autoráveis, biblioteca com miniaturas,
favoritos, minimap, máscaras de regeneração internas e editor narrativo de quests
não estão entregues pelos produtores. A área técnica não certifica esses itens
nem representa aceite de ambientação handmade. M3-NAV-01 continua pendente.

O roteiro humano final deve pedir avaliação real da criação manual, leitura dos
encaixes/áreas, quantidade de cliques, menus, tamanho da prévia e alternância AX.
Tests automatizados não aprovam essa experiência em nome do usuário.

## Delta F9 de navegação e inspeção

O inventário F8 acima é histórico. F9 integrou props, materiais/perfis, biblioteca,
presets/favoritos e navegação; estado e pendências atuais estão na
[matriz F9](f9_requirements.md), sem aceite humano implícito. M3-NAV-01 foi
corrigido e validado no checkpoint ce7bd59, conforme o recibo F9.

Nas telas de terreno, objetos, mapa, encontros e patrulhas, use a roda para
zoom e o botão do meio para mover a câmera. F enquadra com o desenho focado.
O minimapa centraliza a câmera na cota indicada. Busque uma entidade e use
“Focar seleção”; duplo clique em camada/objeto também enquadra seu conteúdo.
Essas ações preservam fonte, histórico e posição de personagens.

Em “Overlays”, altura/cotas, apoio e bloqueios ajudam a conferir o relevo;
conexões mostram sua largura, encontros e rotas mantêm os dados dos produtores.
“Inspecionar folga” pede raio/altura do corpo. “Inspecionar linha de visão” pede
dois cliques e consulta o mundo à meia altura escolhida. Compile a fonte atual
antes das consultas; na janela de objetos, “Compilar peça” usa o worker comum.

O clique padrão respeita oclusão. Para conferir outro andar, escolha um apoio
explícito na lista: é uma seção editorial e a colisão completa permanece ativa.
Assim, ocultar a ponte ou selecionar a passagem inferior não faz um corpo alto
caber sob ela. Texto de ocupação diferencia espaço físico válido de posição
ocupada. A inspeção não pinta, move ou teleporta personagens.

Em AX, os oito comandos de navegação usam `<screen>/viewport/` e os mesmos
parâmetros/APIs dos controles. Biblioteca/presets continuam com seus comandos
próprios. Esta integração ainda não certifica todas as ações AX/CLI nem a
responsividade em escala ou a área final de aceite.

# F9 — biblioteca e navegação de autoria

Delta sequencial F9-06/07, dentro da completude já autorizada; sem novo épico,
catálogo/arte, mecânica, renderer ou formato de conteúdo. Paleta de objetos
já tem seis miniaturas, busca e categorias; aproveitar esse consumidor e
corrigir a matriz inicial, que ainda descreve sua ausência na base.

Favoritos e presets de brush são preferências de autoria por projeto na API
nativa EditorSettings.get/set_project_metadata, fora das fontes, saves e
pacotes publicados. Validar estrutura/tipos/limites antes de usar; corrupção
não é substituída silenciosamente. Não usar favoritos globais do sistema de
arquivos do Godot. Testes nativos usam somente metadata da fixture e perfil
descartável. Referência da engine:
[EditorSettings](https://docs.godotengine.org/en/stable/classes/class_editorsettings.html)

Biblioteca de fontes: registrar explicitamente peças/mapas abertos/salvos ou
escolhidos pelo autor, com ID/caminho/tipo/hash/nome; não varrer todo o disco.
Leitura usa schema/IO dos produtores; nunca carregar cena/script do registro.
Miniatura é reconstruída localmente do pacote validado, com chave de conteúdo/
dependências, progresso, cancelamento e descarte de retorno obsoleto. Abrir ou
duplicar preserva rascunho atual e identidade/revisão; cópia inicia outro ID e
outro caminho. Favorito não é pin de gameplay ou regra de geração.

Presets capturam modo/raio/força/dureza/forma/material/alturas já suportados pelo
brush. Aplicar preset só muda ferramenta; o traço usa Brush.stroke e transação
existentes. GUI e AX especializado chamam as mesmas autoridades.

Minimap e foco são câmera, sem teleportar ator nem mudar fonte. Camadas/objetos
e diagnósticos focam a região correspondente. Overlays úteis de suporte/altura,
bloqueio/LoS/folga, conectores, população e rotas respeitam geometria/capacidades
reais; visibilidade editorial não remove corpo publicado. Consulta de LoS/folga
usa WorldGeometry com cota/corpo exatos, sem regra paralela baseada na imagem.
Atalhos não tomam edição de texto nem disparam ações em janela inativa.

Provas dirigidas: preferências fora do hash/histórico; favoritos/presets e
registro roundtrip, estado malformado, catálogo ausente; paridade GUI/AX;
minimap/foco/overlays em rampa/ponte e erro localizado; miniatura cancelada/stale,
abertura/cópia sem perda. Inspeção nativa e supervisão Luna após congelamento.
Nada nesta preparação certifica o fluxo completo ou fecha F9-06 antecipadamente.


## Componente de biblioteca implementado, aguardando supervisão

Backend nativo ligado pelo addon; os módulos de dados não referenciam
EditorInterface no runtime. Headless usa memória explicitamente. Última cópia
válida de preferências é guardada a cada escrita. Recuperação exibe quantidades,
exige o hash da cópia com problema, preserva essa cópia em outra chave nativa
e só então restaura. Orçamento defensivo de16 cópias de recuperação por projeto;
atingir limite preserva o estado e retorna erro, sem apagar cópias anteriores.
Preferências inválidas não são promovidas, descartadas ou sobrescritas em silêncio.

Mudanças entre janelas atualizam paleta/presets; favorito ou preset não reinicia
compilação de miniatura. Registro de fonte alterado invalida a seleção pendente.
Caminhos Windows equivalentes recebem uma identidade; reconciliar alias antigo
preserva favorito. Registros são metadados, nunca apagam a fonte ao ser removidos.

SubViewport512x384 usa TerrainCanvas/MapCanvas reais; cache256x192 com chave
fonte/engine/código/dependências e stamp de hash do PNG/pacote. Alteração da
fonte ou ambiente durante worker/render descarta resultado. Um worker por
painel, progresso/cancelamento e geração do pedido; fonte/catálogo não são mutados.
Gravações derivadas ficam em.godot/map_authoring/library, fora do Git/export.
Miniaturas não são input confiável de física. O custo síncrono de validação de
pacote/montagem dos nodes e limpeza abrangente de cache continuam em F9-10.

A abertura/cópia usa confirmação/rascunho do produtor e nova identidade/caminho
para cópia. Mapas recusam troca se preservar o rascunho falhar. MapStore devolve
o hash dos bytes efetivamente lidos, eliminando a janela em que um hash de uma
leitura posterior poderia autorizar sobrescrever uma edição externa.
Minimap/overlays/foco e paridade CLI integral continuam em execução, sem fechamento
antecipado de F9-06/07/09/10/11.

## Próximo componente: minimapa e inspeção espacial

Ferramentas comuns às telas de terreno, objetos, composição, encontros e
patrulhas. MinimapXZ é projeção editorial: desenha caps, objetos e marcadores
com uma moldura de câmera calculada na cota de foco indicada. Clique centraliza
a câmera nessa cota; nunca move atores. Ajustes de zoom/pan/foco não mudam
fonte, revisão, histórico, compilação ou colisão. TeclaF atua apenas com foco
na área de desenho; busca não intercepta edição de texto nem janela inativa.

Overlays usam faces, massas/AABBs, aberturas, slots e rotas dos produtores.
Preview de relevo ainda não compilado é identificado como prévia; não certifica
folga ou navegação. Inspeção de corpo/LoS exige pacote compilado atual, usa
WorldGeometry.position_query/sweep e informa suporte inválido/ocupação/obstáculo,
com ponto e volume reais. Camadas ocultas deixam de ser alvos visuais, mas
conservam seus corpos nas consultas do pacote. Nenhum sweep por sprite ou
fórmula alternativa de rota/altura. LoS é segmento à meia altura do corpo
escolhido entre pontos de apoio válidos, não visibilidade de toda a silhueta.

Foco por entidade/diagnóstico usa o ID e bounds da geometria correspondente;
alvo ausente ou ambíguo tem erro explícito. GUI e comandos AX parametrizados
delegam às mesmas APIs. Cache do modelo de desenho invalida na mudança de
geometria/fonte/visibilidade; moldura de câmera é desenhada à parte para não
reconstruir toda a geometria a cada pan. Capacidades/custos só serão declarados
após provas de rampa, ponte com piso inferior, corpo grande, obstáculo e clique
do minimapa, sem inferir FPS de testes funcionais.

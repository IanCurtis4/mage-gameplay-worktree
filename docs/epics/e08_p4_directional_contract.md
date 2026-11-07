# E08 P4 — extensão delimitada para quatro direções

6/11/2026. O usuário pediu norte/sul/leste/oeste para personagens e inimigos no
chat P4; retomada técnica solicitada a Sol no P0. [Implementação produtora e
evidências](e08_p4_directional_delivery.md) concluídas por Sol; conteúdo P4 ainda
pendente. Este contrato não declara quatro vistas artísticas prontas no jogo. Substitui o limite
32 células apenas quando o conjunto direcional de uma identidade for produzido,
calibrado e validado como unidade. P4 continua aberto. Não inicia P5.

## Diagnóstico e decisão técnica

CombatAnimationState.face guarda direção contínua, mas seleciona só frente e
costas com flip horizontal; frame_index tem 32 índices. CharacterAnimation,
EquipmentHandRig, fingers, EquipmentAttachmentVisual e EquipmentHeadVisual usam
essa indexação. Alterar apenas o PNG não seleciona vistas laterais. Virar ou
retintar uma vista frontal não produz uma lateral.

A autoridade de movimento/combate fica intacta. A direção visual recebe o vetor
2D já projetado usado por face, sem reinterpretar coordenadas 3D ou pathfinding.
Nova seleção cardinal: eixo de maior módulo; y<0 norte, y>=0 sul, x>0 leste,
x<0 oeste. Zero conserva orientação. No empate, escolher vertical de forma determinística. Refinamento técnico na
implementação autorizada: a direção é derivada do vetor facing já salvo; evitar
um segundo estado direcional que alteraria o schema do snapshot. Zero conserva
o facing existente, inclusive após restauração. O cache visual precisa
incluir direção resolvida, inclusive se a fase de animação for a mesma.
Durante ação a direção continua a do lançamento; dano não gira o ator; morte e
sua cópia congelam direção, retomada mantém regras atuais de reconstrução.

## Formato e consumo único

- V2: atlas RGBA 256×1024, 64 células64×64; pivô-base (32,58), pés calibrados.
- Quatro blocos de16 poses, ordem sul/norte/leste/oeste. Cada bloco tem idle4,
  walk4, action4, hurt2 e death2; índice=16*direção+pose. Durações, deslocamento
  de caminhada e transições são os existentes, sem clock paralelo.
- Frente e costas atuais são mantidas no legado V1. V2 possui arte específica
  para as quatro vistas; sem flip automático do corpo em V2. As assimetrias de
  traje, arma, mão dominante e escudo devem continuar coerentes nas quatro.
- Manifesto imutável por identidade define versão, textura base/sem arma,
  pivô, hashes, calibração de pés/mãos/dedos/cabeça e profundidade. Catálogo
  apenas de apresentação; nenhum campo persistido na definição de gameplay.
- CharacterAnimation resolve um único descritor de desenho para corpo, anexos,
  dedos, cabeça, sombra de contato e cópia de morte. Não deixar cada drawer
  recomputar sua direção/índice/flip. API pública legada permanece compatível.
- V1 aceita exatamente os assets atuais sem mudar seus quadros. V2 é carregado
  só se textura,64poses,rig e metadados forem válidos. Rejeitar conjunto inválido
  de forma observável e manter V1 inteiro; nunca corpoV2 com rigV1 silencioso.
- RigsV2 têm64 calibrações reais por identidade: main/off, crops de dedos,
  orientação do equipamento e profundidade. Âncora em roupa opaca não comprova
  mão. Capacete recebe âncora/profundidade por pose, não a heurística antiga.
- Props de arma e escudo continuam equipamentos separados e imutáveis; nenhuma
  nova restrição de equipamento ou gameplay para acomodar um sprite.

## Abrangência e sequência produtora/consumidora

O inventário Sol [baseline_inventory.json](e08_evidence/p4_sol/baseline_inventory.json)
congela os atlas e mapeia recursos MobDefinition. Dez identidades jogáveis,
corpos warrior/archer/gel/beast_master/animal_companion e overrides wolf/boar
precisam ser avaliados. Archer também tem consumidores inimigos; warrior atende
várias espécies. Preservar os consumidores e os overrides individuais do piloto.
Recurso de teste existente não é promessa de que aparece na fase publicada.

1. Sol publica produtor V2 com suporte legado e fixtures sintéticas identificadas
   como teste, incluindo seleção cardinal, validação de manifesto, desenho e
   equipamentos. Não anunciar arte pronta a partir dessas fixtures.
2. Terra produz primeiro UMA identidade equipada completa, com quatro vistas e
   todas as poses, sobre API fechada; Sol valida rig, cabeça, dedos, orientação,
   transições, morte e ausência de alteração de simulação. Não fabricar todas
   as folhas antes de provar a integração de uma delas.
3. Terra conclui as demais identidades e corpos de inimigos no escopo autorizado,
   com inventário de preservar/corrigir/completar e fontes/prompts. Nenhuma classe
   pode terminar rotulada quatro direções enquanto ainda usa V1.
4. Revisar renderer nativo nos sentidos cardinais, diagonais/empates, chão claro/
   escuro, rampas/pontes/oclusão, zoom de câmera50/100/160 e UI120. Validar todas
   as combinações de equipamento atuais, não só sobreposição de marcadores.

Produtor Sol implementado em6b33dce1, candidato técnico congelado3637f260 e
conferido por Luna. [Recibo e evidência](e08_p4_directional_delivery.md),
[lista exata de propriedade](e08_p4_directional_files.json) e dispatch registram
base, escopo e transferência. A API abaixo está disponível para o próximo pacote
de conteúdo, começando por UMA identidade completa em staging. Terra não edita
APIs compartilhadas por inferência; nenhuma arte V2 foi ativada nesta entrega.

## Invariantes e aceites

Zero mudança a dano/alcance/colisão/LoS/cooldown/RNG/tempo de simulação/save.
Testes V1 atuais continuam intactos. V2 cobre64poses, quatro direções distintas,
limites dos recortes/alpha/pivô, rigs/flip/oclusão corretos, trocar equipamento,
pausa/cancelamento/revive, morte, troca de estágio/suspensão sem replay e export.
Asset inválido não muda estado de animação nem parcialmente ativa V2.
Não trocar só dimensões esperadas dos testes antigos para parecer aprovado.

Medir no renderer real CPU/p95/picos e memória por conjunto: pixelsRGBA brutos
sobem de0,5MiB para1MiB por atlas, mas isso não certifica RAM/VRAM nem custo final.
Reusar controles e limiares E08 (>10% reproduzível ou>16MiB retidos exige triagem).
Promover uma identidade só com arte e rig completos; relatório deve distinguir
produtor disponível, identidade integrada e cobertura total pendente.

## Implementação autorizada — 6/11/2026

Usuário pediu continuar com a implementação após a triagem Sol. Base
e10bf71d91d0e9271d9792ed04e211ab8ca17112, mesmo checkout codex/e08. Terra P4 está idle.
P0/Sol é único escritor da lista e08_p4_directional_files.json e evidência
p4_directional. Essa transferência inclui os produtores antes somente leitura
para Terra. Sem mudanças nos testes legados ou runtime_manifest/schema.

Detalhe de binding: conjunto por identidade em
res://assets/art/animations/directional/<actor_kind>/presentation.json;
substituição por ocorrência usa set_directional_manifest(path) explicitamente.
Texturas e manifesto ficam na mesma pasta, permitindo reconstruir o catálogo
estático a partir da resource_path já salva, sem novo campo persistente.
Hashes RGBA canônicos verificam o conteúdo importado também no PCK, sem exigir
PNG fonte no export. Conjunto deve ser validado por inteiro antes de ativação.
Fixtures geométricas em tests/fixtures/e08_directional são somente provas,
não novas identidades/arte do produto. Não promover a candidata Espiritualista.

Testes: novos unitário/integrado, animação, alinhamento, aparência E06, classes
com provas de atlas, apresentação/piloto/áudio e fronteiras snapshot/lifecycle/
action_matrix/continuation por impacto. Renderer nativo mostra64poses, equipamento,
capacete real no retrato, zoom de câmera e custo comparável V1/V2. Testar PCK.
Luna low supervisionará inputs/execução congelados sem rerun rotineiro.

## API executável e autoria do conjunto V2

CharacterAnimation.set_directional_manifest(path:String)->Dictionary retorna
{ok:true}, invalid_directional_presentation com detail, ou
 directional_kind_mismatch. Falha não muda atlas/rig/clock em uso. Configure(kind)
procura o caminho padrão acima; atlas V1 continua quando o conjunto não existe.
Falha automática gera WARNING uma vez na seleção; não é fallback parcial.
set_body_atlas continua restrito a variantes inimigas V1 e preserva sua API.

O manifesto usa format ragrpg_directional_animation_v2, actor_kind (tipo visual,
por exemplo geometer, não ID de evolução mg_ar), pivot [32,58], body/weaponless
com path res:// e rgba_sha256, e frames com64registros. As texturas PNG ficam
na mesma pasta do presentation.json, inclusive em substituição por ocorrência.
Weaponless é obrigatório para as dez identidades equipáveis. Inimigos sem
contrato de equipamento podem usar weaponless:null; seus rigs não exigem pixels
de mão, pois não empunham itens. Os quatro blocos de imagem devem ser distintos;
a anatomia lateral continua exigindo inspeção humana/técnica, não só hash.

Cada frame possui ground_y inteiro igual ao último pixel opaco do corpo;
slots main_hand/off_hand/arms, cada um com point [x,y], fingers [x,y,w,h],
angle radianos (somado ao ângulo-base do equipamento), depth0/1 e flip booleano.
angle_overrides/depth_overrides opcionais usam chaves de equipamento já suportadas
para ajustes absolutos. Em V2, posições/crops são da célula selecionada e não
sofrem o flip do corpo V1. Flip local espelha somente a peça no seu grip.
Cabeça: head com point,angle,depth,flip,visible; o renderer resolve a vista do
capacete a partir da MESMA direção de corpo/mãos. As poses de morte têm dados
próprios; não são a heurística do V1. Nenhum ajuste em tempo de gameplay lê
pixels ou consulta regras de dano.

rgba_sha256 = SHA256 dos bytesRGBA8 em ordem de linhas, RGB zerado somente onde
alpha é0. Isso torna a conferência compatível com a correção de borda invisível
do importador Godot; pixels visíveis e alpha permanecem integralmente vinculados.
PNG fonte e prompt/proveniência têm hashes próprios no recibo de arte. Não usar
hash do PNG diretamente nesse campo. O loader valida tamanho,64células, pés,
alpha nos grips/crops vivos dos corpos equipáveis e valores finitos/limitados.

render_descriptor()->Dictionary fornece version,frame,direction,atlas,region,
rect/origin,flip,dead,head,equipment,arrow_visible. Seus dados de calibração são
cópias; não modificam catálogo. Actor/inventário/cópia de morte passam pelo
mesmo draw_on, inclusive capacete pilot_head já existente. Outros capacetes
continuam sem arte própria: não recebem o desenho de pilot_head por inferência.

frame_index() continua API V1. Novos consumidores/probes usam render_descriptor,
não inferem a célula de64poses a partir do índice legado. CombatAnimationState
adiciona só métodos direction_index e pose_index sobre os campos existentes;
não há novo campo em ator, relógio ou runtime_manifest. Catálogo derivado é
estático e reconstruído pelo path da textura em processo frio/restore.

Preparar primeiro UMA identidade completa no diretório direcional, com fontes
preservadas fora do atlas de runtime. Calibrar112 grips vivos e os dedos nos dois
corpos,64poses de cabeça e pontos de morte/equipamento, não só encaixar em qualquer
pixel opaco. Fixture geométrica não substitui essa entrega artística.

O caminho sem anexos reutiliza _frame_for_view e a mesma compensação de pés,
mas evita alocar descritor/rig sem comandos de equipamento. Não é renderer de
gameplay paralelo. A regressão medida e sua correção constam do recibo.

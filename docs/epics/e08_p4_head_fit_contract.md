# P4 — cabelo base e chapéu encaixado

7/11/2026. Decisão humana atual: cabelo/rosto formam base no sprite, chapéu
sobrepõe cabelo sem ficar grande/largo. Esta correção cosmética do P4 segue
[runtime produtor existente](e08_p4_directional_contract.md), não inicia P5.
Root mostrou mecanicamente o defeito real no Mago: a ponta do capuz embutido
continua fora do elmo menor, enquanto a âncora antiga fica acima do crânio.
Apenas reduzir o elmo não resolve essa base. Referência local de diagnóstico:
.godot/author_triage/mage_hat_layers.png. Espiritualista tem cabelo exposto e
será controle positivo. Sem remover permanentemente a aparência original aprovada.

## Solução técnica delimitada

Catálogo V2 ganha textura opcional `bare_head` no mesmo diretório de presentation,
com path+rgba_sha256 e dimensões256x1024 iguais às demais. Contém o MESMO corpo
sem adereço fixo na cabeça, com rosto e cabelo neutro próprios. Só é selecionada
quando há equipamento de cabeça visual conhecido. Sem equipamento, usar o corpo
original; remover chapéu restaura exatamente o atlas anterior. V1 continua íntegro.
Opcionais ausentes conservam corpo anterior inteiro; opcional presente inválido
rejeita V2 completo como os demais. Essa variante requer weaponless, nunca muda
arma/luva/ground/clock. Validar64frames e alfa nos grips/crops/ground também nela.
Catálogo mapeia path da terceira textura para mesma unidade; restore frio deriva
pelo path já salvo, sem novo campo em ator/snapshot/DTO/save. Death copy conserva
mesma variante/direção/head; seleção usa equipment_visual existente.

`head.point` é âncora autorada no crânio/cabelo por pose e direção, incluindo mortes,
não na ponta do antigo chapéu. Chapéu tem abertura facial transparente quando
aplicável e visor/copa proporcionais. S/N/E/W são arte própria; W não é espelhado
outra vez se o atlas já tem vistaW. Head.flip é toggle adicional expresso.
Não duplicar seleção corporal em drawer independente: mesmo render_descriptor,
retrato/mundo/morte. Catálogo estático de arte mapeia14IDs reais de cabeça;
maçã/flecha e casca de ovo são estudos adicionais sem ID/drop de gameplay.

Anexos pintados4x mantêm tamanhos/grips lógicos; usar CanvasTexture filtrada
localmente ou equivalente comprovado para não alterar filtro do corpo inteiro.
A API CanvasTexture permite filtro próprio, conferir no engine standard real:
https://docs.godotengine.org/en/4.4/classes/class_canvastexture.html
Bounds/morte são medidos em unidades lógicas e não nos pixels4x da fonte.
Nenhuma mudança de raridade/taxa/loot/origem/eligibilidade é inferida da arte.

## Primeiro consumidor artístico — Mago completo

Base de API01d7eda9ba39af414e55c278c1c0dbade29f4168, codex/e08, checkout
C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5.
[Propriedade exata](e08_p4_mage_head_fit_files.json): Terra6.1 médio, novo staging
assets/art/e08_head_fit/mage, sem escrever corpo/manifesto Mago existente.
Root/Sol é dono de runtime/fixtures/integração. Dispatch entrega SHAversionado.

Entregar64poses de corpo com cabelo/rosto e sem capuz roxo fixo, mantendo o
cabelo castanho e a identidade do Mago. Aplicar ragrpg-art/imagegen integrado;
inspecionar atlas/referências primeiro. Edição em4folhas4x4porvista remove SOMENTE
capuz/chapéu, preserva face/hair, expressão/pose/direção, braços/mãos/roupa/pés.
Fontes preservadas; v2/v3 localizadas por pose, sem redesenho por código.
Preparação mecânica em ferramenta nova própria: copiar pixels do corpo original
fora de regiões de cabeça autoradas; substituir apenas essas regiões com crops
da arte nova normalizada. Regiões e proteções de mãos/roupa são dados autorados
por pose em calibration.json, não heurística global por cor. Original e mão/crops
vivos devem ser byte-id fora da área de cabelo, sem apagar props por algoritmo.
Não usar máscara retangular que apague uma mão levantada; proteger esses pixels
ou autorar recorte adequado. Ficar com um resto de capuz não equivale a conclusão.

Calibração independente contém hash do corpo original,64regiões/proteções e64
âncoras cranianas reais para chapéu. Toda mudança de pixels é confinada às áreas
autoradas, conservando64grounds e112grips/crops, corpo/pivô/ação. Reproduzir
RGBA/hashes, fonte/proveniência/prompts, contact_sheet nu/com pelo menos elmo
piloto, maçã e ovo pequenos,4vistas e poses de morte. Sem Godot/importação/commit,
fixture/runtime/testes/manifestos alheios. Devolver unidade completa e posse.

Sol integra o produtor opcional, catálogo/anexos pintados e primeiroMago após
handback; testa seleção/equipar/remover inválidos/restore frio/morte e gameplay
por impacto, renderer nativo/câmera50/100/160/UI120/retrato/export e custo.
Outras identidades com capuz fixo seguem depois dessa prova, sem fabricar todos
os consumidores antes da primeira. Cabelo exposto existente não precisa terceira
textura se arte/encaixe já funciona. Aprovação técnica não é aceite humano.

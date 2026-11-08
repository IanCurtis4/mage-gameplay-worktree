# P4 — integrar equipamentos desenhados e cabeça do Mago

7/11/2026. Pedido humano atual: capacete menor/encaixado, armas/escudos mais
pintados, temas próprios por drop e cabelo como base para chapéu. Trabalho no
mesmo P4; sem itens/classes/qualidades/taxas novas, P5, master/push ou saves.
Leia [cabelo/base](e08_p4_head_fit_contract.md), [arte](e08_p4_gear_art_contract.md),
[lista exata](e08_p4_gear_integration_files.json). Base API/arte173c8e4d83e803532f7be0850151fda585373ccf,
branch codex/e08, checkout C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5.
Sol6.1 high: fronteira do renderer/catalogo/restore, conforme WORKFLOW. Dispatch
passa SHA e transfere índice/únicafixture; Root não os usa até handback.

## Resultado observável

1. Sete PNGs desenhados4x consomem mesmos perfis/grips, estado/direção/crops e
profundidade existentes; desenhos novos no mundo e retrato. Escala lógica igual,
não confundir pixels4x com comprimento lógico. Filtro linear somente nessas
texturas (CanvasTexture própria por recurso ou prova equivalente), corpo íntegro.
Bounds em unidades lógicas, morte apoia no chão considerando ângulo/flip real.
Manter7SVGs/fontes/histórico e todos4.593oráculos V1; não relaxá-los para aprovar.
Novo oráculo V2 de suporte mede imagem pintada separadamente em unidades lógicas.
2. Quatorze IDs reais de cabeça têm arte própria S/N/E/W, escala menor que antigo
elmo26x20, âncora craniana autorada. W já possui spriteW: não espelhar duas vezes.
Describe usa ID de definição confirmado em snapshot/catálogo, não aparência por
classe/raridade. Desconhecido não recebe pilot_head por inferência. Retrato,
ator e morte usam mesmo descriptor e rotina. Ícones de inventário/drop usam arte
correspondente, preservando APIs/IDs e nomes; sem layout de UI novo. Dois estudos
maçã/ovo podem ser mostrados na prova, sem introduzir ID/drop ou concessão legal.
3. Implementar opcional bare_head exatamente como contrato de cabelo, com
validação integral/atômica, catálogo derivado do path e sem campo persistido.
PrimeiroMago recebe textura real64poses após handback Terra; selecionar SÓ com
headgear conhecido, remover restaura atlas antigo. Face/olhos legíveis; não empilhar
capuz fixo e elmo menor. Anchors64 de Terra vêm no staging separado e precisam
conferência nativa, especialmente morte. Body/hands/grounds fora regiões autoradas
permanecem byte-id. Não redesenhar PNG por código; correção artística volta Terra.

Sem mudar snapshot/runtime_manifest/regras/AI/loot/equip eligibility/clock/duração
ou hitbox. Catálogos de apresentação imutáveis/static cache. Registrar erro/fallback
observável para recurso ausente/inválido. Se optionalbarehead ausente, legado/V2
anteriores inteiros; se presente inválido, rejeição integral como outros campos.
Não criar drawer paralelo com lógica independente de direção ou rosto.

## Fronteiras/posse/dependências

ProduçãoGear completa em staging/read-only: assets/art/e08_equipment_redesign;
fontes/prompts/provenance/crops persistidos. Copiar somente PNGs aprovados para
production headgear/painted e criar catálogo de apresentação novo versionado,
sem promover source sheets. Mago barehead artist possui SÓ assets/art/e08_head_fit/mage
+ ferramenta própria; fontes existentesMage(bodyRGBA2def...) são estáveis/read-only.
API fechada permite preparar produtor/negativos/baseline antes dessa arte, mas
consumir/copy barehead real só após handback Root explícito. Não editar artista.
Defendente/Berserker/Caçadora e Sentinela/outros permanecem fora: não promover ou
editar suas calibrações. Root continua autoria/planejamento em arquivos disjuntos.

## Prova e entrega completa

Capturar baseline de custo nativo do Mago V2 atual/equipamentos antigos ANTES de
editar renderer/fixture; mesma cena96equipados/3janelas3s/perfil e engine standard.
Depois comparar CPU/framep95/picos/cache retido, triagem>10% reproduzível ou>16MiB;
sem claims RSS/VRAM/FPS de mapa por suíte. Preservar controles/deltas/hashes.

Teste novo registra14IDs/7chaves/imagens4x+grips+ícones, unknown/fallback e cache
imutável; transação real equipar/desequipar owned head e elegibilidade; qualquer
key14no mesmo descriptor/retrato. Barehead válido/inválido rejeição atômica,
64poses/4vistas/alpha/fingers/grounds e pathcoldrestore/snapshot/deathcopy reais.
Não fabricar todas as variantes de cabelo antes de provar uma identidade.
Testes relacionadosV1/producer, conteúdoSpirit/trêsdefaults/units/inventory/icon,
aparência, snapshot/continuation/action_matrix/lifecycle/projeção e áudio porimpacto,
usando tools/verify.ps1; manterfalhas/tentativas originais sem somar duplicadas.

Renderer real: Mago com cabelo e com cabeça/7props em64poses e4direções, sem
capacete grande/face apagada. Equipar/removerreal mostraatlasoriginal vsbarehead,
14headgear emgaleria, Spiritcontroleexposto, piso claro/escuro, zoom50/100/160,
UI120, morte/repouso/transições/dedos. Captura nativa não é só marker ou composição
PIL. PCK exato testa corpo/ícones/catalogue/barehead/hash/restore comengine standard,
APPDATA/LOCALAPPDATA isolados. Export não inclui perfis/cache/saves no commit.

Recibo portátil com base/hash entregues/integração, seleção real/erros/timeouts,
engine/input/SHA e ZIP mínimo evidências sem caches/saves/PCK. Dono de arte/validação
Sol explícito, Luna supervisiona freeze depois, não auditoria visual independente.
Commit EXATOS próprios (sem Root/artistas/4bak) e devolver índice/fixture/arquivos.
P4 segue aberto: outras cabeças com capuz fixo e demais identidades/inimigos ainda
aguardam suas entregas; esta fatia não declara aceite humano ou atualizaçãohabitual.

## Estado8/11/2026

Escopo entregue tecnicamente no commit que contém
[e08_p4_gear_integration_delivery.md](e08_p4_gear_integration_delivery.md).
24/318etapas únicas/31.283checks, nativo final2/PCK/movimento PASS; limites e
falhas históricas preservados. Conferência de freeze Luna pendente via Root.
Posse exclusiva do executor encerrada com commit/handback; Root recebe índice,
única fixture e arquivos listados. Outros stages/artes não promovidos.

# E08 P3 — piloto Mago, floresta, VFX e primeiros sons

6/11/2026. Execução Terra 6.1 high, autorizada pelo [plano](e08_approved_plan.md).
Dependências: [P1](e08_p1_delivery.md) e [P2](e08_p2_delivery.md) validados por
Sol P0 e Luna nos recibos. [Contrato base](e08_p0_contract.md),
[inventário corrigido dos consumidores reais](e08_inventory.md),
[propriedade e dispatch](e08_dispatch.md). Sem P4–P6 até aceite humano do piloto.

## Resultado e linguagem

Entregar uma fatia visual/sonora refinada e comparável no renderer jogável atual:
Mago equipado caminhando/conjurando, projétil, área e teleporte; inimigos comuns
e Guardião Ancestral da floresta publicada; cenário e primeiros 12 sons.
Preservar o que já é adequado, corrigir problemas observados e completar lacunas.
Não basta apresentar arquivos existentes como melhoria; registrar intervenção
e resultado observável, ou motivo verificável para preservar cada frente.

Usar ragrpg-art, pipeline/fonte existentes e imagegen quando houver produção
raster nova. Manter linguagem do atlas atual: 32 poses, células64×64,
pivô(32,58), frente/costas e espelhamento, contato com chão e equipamento.
Escala/paleta/cadência partem dessa base; não trocar renderer nem produzir
dez identidades por efeito do piloto. Fontes raster antigas não são sobrescritas;
fontes novas e prompts/receitas/proveniência ficam rastreáveis. Não copiar arte.
VFX vetorial pode ser código próprio sobre a API de eventos confirmados.

Publicação real: `data/expedition/phases/forest_sanctuary.json` compõe
forest_terraces, forest_valleys, forest_lair. Espécies forest_wolf,
forest_boar, forest_stalker, forest_canopy_archer, forest_ancient_warden,
mais companheiro já declarado pelo chefe. sanctuary_woods é fonte antiga e
os quatro backups não são inputs a republicar. MobPrototypeVisual.draw_on
não é o drawer atual: os inimigos usam CharacterAnimation. Atlas compartilhados
não podem mudar classes bloqueadas P4; preferir acabamento por consumidor.

## Fronteira técnica estável

P1/P2 são contratos consumidores, não reimplementações. UI/áudio/VFX não criam
DamageRequest, consulta física, hitstop, timers de gameplay, RNG de gameplay ou
alteração de dano/alcance/LoS/cooldown/recompensa. Eventos confirmados conservam
época e geometria canônica; ausência de ponto exato de impacto é explicitada.
Indicadores essenciais existentes permanecem completos sob qualquer cap cosmético.

Feedback novo fica sob Control descendente da ponte, já descartável/excluído do
snapshot. Reter somente efeitos visuais efêmeros, com limpeza na época/estágio,
pausa e staging passivo/desativado. Retomada reconstrói estado atual sem replay.
Não adicionar campos em atores/controlador/CharacterAnimation nem mudar schema.
Helpers visuais estáticos podem ler o estado atual sem armazenar estado de run.
CombatActor.body_drawer/body_visual_owner são serializados hoje: não colocar
um novo RefCounted/Callable neles e presumir exclusão automática. Mudança real
de API necessária retorna ao Sol P1, com transferência sequencial registrada.

Sons: produzir os 12 WAVs nos paths exatos da tabela de P2. Catálogo/serviço
não precisam ser editados. Ambiente tem loop inteiro garantido em cópia privada;
autor validar costura e nível sonoro. Demais 11 são one-shot sem loop. Receitas
originais sintetizadas são permitidas; fonte externa exige licença/proveniência.
Sem música. Comparar cast/lançamento/impacto/área/teleporte/UI e volume/mute.

Cenário conserva geometria, rotas, populações, encontros, referências/revisões
publicadas e hashes dos RPP/navproof. Material cosmético pode ser refinado;
não editar source/map/population/patrol JSON ou republicar por inferência.
Se republicação visual se mostrar necessária, parar escrita e pedir transferência
delimitada ao coordenador, para usar compilador existente e nova revisão imutável.

## Evidência, testes e entrega

ANTES de editar arte/consumidores, capturar baseline no renderer nativo usando
a fixture atual P2 e perfil descartável; guardar argumentos/seed/posições/câmera.
Comparar depois com os mesmos parâmetros. Nenhuma montagem ilustra como se fosse
gameplay. Inspecionar PNGs reais e registrar a escolha preservar/corrigir/completar.

Matriz: piso claro/escuro, rampa, ponte, vegetação, grupo e chefe, Mago equipado;
caminhada, cast/cancelamento, projétil, área, teleporte, morte/revive, troca de
estágio e suspensão/retomada. Zoom50/100/160%, UI120%, sobreposição de equipamento,
alvo/perigo/área. Amostra nativa reutilizável pode isolar cobertura geométrica;
também mostrar a floresta publicada real, não só um mock de chão plano.
Registrar capacidades não cobertas sem falsos PASS; corrigir lacunas contratuais.

Novo tests/e08_pilot_test.gd verifica invariantes pertinentes: proveniência/paths,
fontes/imports, nenhum dado de gameplay alterado, lifecycle/caps visuais, fontes
e samples válidos sem clipping/NaN, ausência de replay, consumo dos dados canônicos.
tools/verify.ps1 por impacto: combat_animation_test, e08_presentation_test,
e08_audio_test, e08_pilot_test, mage_gameplay_test,
e04_teleport_rank_integration_test, e07_f1_presentation_test,
e07_f3_lifecycle_test, e07_f3_action_matrix_test, e07_f7_presentation_test;
fronteiras adicionais tocadas exigem seleção adequada. Não editar expectativas
para ocultar falhas. O FAIL herdado de ajuda em1280×720 continua identificado.

Uma fixture já existente: .godot/verification/e07_f1/fixture_project, sync só de
deltas, com manifesto e config verificados. Engine standard pareado 4.7.2 do
principal; APPDATA isolado. Sem cópia de projeto/cache/terceiro checkout/export
inteiro pelo executor Terra. P0 possui embalagem/release e comparação F10 após
devolução de posse; Terra entrega probe nativo reproduzível e inputs/evidência
do piloto. Incluir mediana/p95/pico/memória quando medidos, sem inferir FPS de
tempo de suíte. Dívida F10 segue explícita; [orçamento](e08_p0_contract.md).

Commit somente arquivos próprios; recibo e08_p3_delivery.md com SHA/base/branch/
checkout, propriedade, antes/depois, testes/logs/hashes, roteiro visual/sonoro,
fontes/licenças/receitas e limitações concretas. ZIP mínimo conserva bytes brutos
dos logs quando necessário; sem projeto inteiro. Parar de escrever e devolver
posse ao P0 para revisão, Luna e embalagem do candidato jogável. Gate de produto
é o usuário ver/ouvir/testar esse candidato; este dispatch não é seu aceite.

## Correção obrigatória de identidade — retomada após P1

A revisão do WIP7f04830e mostrou que só recolorir animal_companion deixa javali
e lobo com a mesma silhueta de orelhas grandes. Isso não encerra o piloto.
Produzir agora atlas próprios de forest_wolf e forest_boar na linguagem aprovada,
sem modificar os atlases compartilhados dos demais atores. P1 entregou e validou
set_body_atlas(Texture2D)->bool: [API e precondições](e08_p1_pilot_corrections_delivery.md).
Usar uma vez após configure do EnemyActor, fora do desenho, via helper P3/main;
verificar retorno. Os dois animais usam kind animal_companion sem equipamento,
aceito pela API. Não acessar campos privados nem mudar animation_kind/catalog.
Texturas imutáveis e offsets/clock/cópia/snapshot seguem o contrato P1 existente.

Paths adicionais EXATOS de propriedade Terra nesta retomada:

- assets/art/e08_pilot/forest_wolf_source.png e .png.import;
- assets/art/e08_pilot/forest_wolf_extra_source.png e .png.import;
- assets/art/e08_pilot/forest_boar_source.png e .png.import;
- assets/art/e08_pilot/forest_boar_extra_source.png e .png.import;
- assets/art/animations/e08_forest_wolf.png e .png.import;
- assets/art/animations/e08_forest_boar.png e .png.import.

Receitas/proveniência, prepare_e08_pilot_art.py, relatório de preparação,
helper/main e testes/recibo P3 já pertencem à lista original. Mesmos32frames,
256×512,64×64/pivô32,58; fonte/prompts preservados, produção raster por imagegen
e processamento existente. Identidade por forma, não só cor: lobo quadrúpede
canino e javali quadrúpede suíno com corpo/focinho/orelhas/presas reconhecíveis.
Manter escala/contato/direções e poses adequadas; não criar espécie ou habilidade.
Inspecionar todos os frames e leitura nativa, inclusive morte/cópia/revive e
retomada com o recurso próprio. Fontes adequadas dos demais consumidores ficam.

P1 também corrigiu UI120% e help1280: não reeditar layout nem reduzir escala.
Preservar esse diff em main ao ligar variantes. Recapturar depois nativo com HUD
preenchido, rolagem acessível e mesmos parâmetros da comparação; pares antigos
com UI/HUD anteriores permanecem referências de origem identificadas. Qualquer
falha concreta retorna ao mesmo produtor; não falsificar prova ou apagar histórico.
A prévia sonora informa seus ganhos (ambiente/cues) e ordem; não alegar que uma
montagem sequencial é a mixagem ao vivo. P0 embalagem/comparaçãoF10 ainda pendentes.

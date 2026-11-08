# P4 — integração final de corpos direcionais

PRONTA após o commit deste contrato/inputs. Artebase dc5ada5f83e3213cc4857a63c065704eaf51a810;
produtor Gear/bare_head entregue em94dfaf7f97e8faa094d9f9ad7612baf7729d801c,
supervisão Luna PASS e todas4bases restantes entregues. Root despachará o SHAfinal
com índice/fixture/arquivos transferidos explicitamente. Esta reserva não inicia
outro épico ou autoriza arquivos fora lista. Sol6.1high pela fronteiraNPC/restore;
artistas Terra6.1médio sóstaging separado. Contratos já fechados:
e08_p4_directional_contract.md,e08_p4_head_fit_contract.md,
e08_p4_head_fit_remaining_contract.md,e08_p4_enemy_art_contract.md.

## Resultado observável e limites

Completar o P4 autorizado:10identidades jogáveis e6corposNPC/overrides existentes
em64poses/4vistas, catálogo V2/rigs/head e anexos coerentes no renderer comum.
Primeiros4jogadores jápromovidos, últimos6completeStage; todos6NPCs emStage.
Todosos10preservam/autoram conteúdo conforme contratos/recibos. Não basta PNG:
promover só cada unidade completa após rig/head/consumidor/nativo/export/custo.
Sem espécie/classe/skill/kit/loot/equipamento ou elegibilidade nova, sem mudar
AI/dano/alcance/colisão/RNG/save/snapshot/tempo ou espaço de gameplay. MesmoP4,
P5–P7 não despachados, master/push/playtesthabitual fora desta execução.

Fontes/prompts/receipts estão versionados. Root conferiu offline6NPCs:32nativas
byte-id,64grounds,4blocos/hash; isso não aprova arte nativa/anatomia/timing. Player
Geo/Archer64/112pedem análise de luvas próximas no renderer; nunca marcarroupa
como mão para satisfazer alpha. Correções locais seguem mesma unidade/autor.
Fontes históricas e quatrobak/saves/habitual são preservados.

## Consumidores de equipamento/cabelo

Integrar6players restantes por paths padrão e atualizar a enumeração explícita
V2 nos testes atuais, preservando controlos32células/V1 sem relaxar oráculos.
Archer/Hunter/Sentinel/Geometer recebem bare_head somente após arte64poses completa
emstaging próprio/read-only. Usar opcional/API do produtorGear já validado, copiar
PNG e64anchors/angles, sem novo formato. Def/Bers/Spirit/Element/Sword já têm
cabelo exposto; conferir cabeça pequena real e ajustar suas64âncoras cranianas
por evidência se necessário (não ponta de cabelo/capuz/torso). Não introduzir
terceiroPNG se o cabelo existente já funciona. Equipar/remover restaura original.

14IDs de cabeça/7props pintados permanecem mapas cosméticos de itens existentes.
Dois estudos maçã/ovo semID de loot continuam estudos, não concessão de item.
Retrato/mundo/cópia morta compartilham descriptor/direção/escala. Nenhum filtro
novo global no corpo. Mãos/fingers/peça/piso emunidadeslógicas (PNGprops4x).

## ConsumidoresNPC e invariantes

warrior/gel/beast_master/animal_companion usam pathsV2default. Wolf/boar são duas
apresentações independentes por ocorrência; manifest.actor_kind animal_companion
continua igual ao ator. E08PilotVisual tenta set_directional_manifest específico
por mob_base_id; se ausente/inválido, manter seuV1 específico completo, não
raposa/lobo genérico nem fallback parcial. CatalogResource imutável.

ArcherNPC compartilha corpo de jogador sem arco embutido: configure_occurrence
projeta arco pelo equipment_visual existente SOMENTE quando conjuntoV2validado.
FallbackV1 conserva corpoNPC original comarco embutido e visual vazio. Limpar
projeção cosmética derivada ao reconfigurar NPC para outra identidade, evitando
arco herdado num guerreiro/animal. Sem criar item/field ou mudar habilidade/timing.
Snapshots já guardam textura/dicionário existentes; restorefrio deve reconstruir
cada corpo/override e arco, não genericfox nem replay de ataque/loot.

NPCs restantes usam props incorporados e não equipam anexos: weaponless:null,
head invisible/slotsunused não alegam rig, nem podem receber equipamento inferido.
Enumerar os16MobDefinition já inventariados e friendlyanimal_companion consumidor.
Presença de recurso de teste não significa ocorrência publicada. Tintas de
espécies/piloto atuais conservadas. Inimigos do catálogo não viram novos habitantes.

## Validação e entrega

Fixtureúnica/engine4.7.2standard e APPDATA+LOCALAPPDATA isolados. Antes de ativar
defaults, guardar controles de custo96atores V1/V2 por identidade/3janelas3s,
com mesma carga sem loads paralelos (NPCunadorned,playersequipped explicitamente).
Triar >10% reproduzível ou>16MiB retidos; não inferirRSS/VRAM/FPSde campanha.

Testes novos NPC: default/override valid/invalid atomic/fallbackporocorrência,
Archercom/semV2/switchkind, 16MobDefinitions imutáveis,64poses/grounds4direções,
path/resource/hash emcoldrestore real/cópia morta e exportPCK. Player6consume
harness64rigs/112grips/7props e transações reais de cabeça/inventário/restore.
Conferir Source/FixtureSHA eprodutoralfa/resolução2células; não editarlimiares.

Rendererreal: cada16body em4direções e64poses, ação/caminhada/dano/morte, dedos,
headgearprops reais, cabeças pequenas semchapéu empilhado/face apagada; roupa,
chão claro/escuro, rampas/pontes/oclusão do piloto, câmeras50/100/160UI120 e
retrato/mundo. Provas NPC incluem lobo e javali juntos,Warrior/bowvisuais corretos
com tintas, ArcherNPC sem arco ausente/duplicado; headlessnão prova isso.
Captura/movimento não altera relógio/semântica nem é revisão humana de campanha.

Executar tools/verify.ps1 por impacto: conteúdo/defaults/producer/head/equip,
animação/alinhamento/aparência/icon/inventário,presentation/pilot/audio,classes
alteradas/companheiro e snapshot/continuation/action_matrix/lifecycle/F1. Preservar
V1 e executar novas expectativasV2 em testes específicos; tipar GDScript para
não mascarar falha. Reusar evidência compatível de fronteiras inalteradas, sem
somar runs repetidos. Falha vaiSol/autor, não ajustar expectativas para ocultar.

PCK exato com consumidores/hashes/restore e body/defaults/head; snapshot/codec
existente. ZIP mínimo portátil sem caches/saves/PCK e hashes deinputs/engine/
artifacts/capturas/logs/resultados. Seleção e limitações explícitas, autoriaSol
separada da supervisãoLuna (nãoauditoria visualindependente). Consolidar checkpoint
P4 técnico após todo escopo, não declarar produto aceito. Commit somentepróprios
elencados (sourceartistasread-only) e devolveríndice/fixture/arquivosRoot. Root
prepara candidato de playtest em operação separada após técnico; merge só após
aceite explícito do usuário sobre candidato testado. Sem push automático.

## Triagem Root de rigs vivos antes da integração

Inspeção de dados mostrou Hunter/Sentinel/Geometer com main_hand.flip=false nas
poses W e angle_overrides de arco ausentes inclusive na ação E/W; Archer, em
contraste, já tem flipW e overrides de ação. Isto exige correção/conferência do
rig, não é evidência de que armas encaixam só porque112pontos têm alfa.

Antes de promover, comparar os28quadros vivos S/N de cada identidade com a API
V1 EquipmentAttachmentVisual.placement no MESMOkind/slot/key/pose, usando estado
canônico eorigem equivalente. Preservar point/crops,ângulos eprofundidade legados,
incluindo bowHunter1.05/Sentinel0.45 emrepouso, actionphase eprofundidade durante
hurt/back. Usar a API existente para extraircontrole, não copiar fórmula paralela.
Morte V2 segue política nova de suporte/horizontal já aprovada, fora desse controle.

E/Wprecisam autoria própria de orientação/depth/flip: arco disparado paraWnão
pode mostrar seta paraE. Conferir sinal horizontal do arco/seta nos quadros de
lançamentoE/W e geometria nativa, sem presumir que mirror local também espelha
ângulo global (V2 tem flip explícito e ângulo autorado). Revisar espada/machado/
cajado/foco/escudo/contas eoclusão perto/longe; não aplicartemplate genérico que
ignore o braço real. Corrigir metadata no mesmo pacote, preservando pixels/palmas
vivas; se faltar mão de fato, voltar ao artista com prova/célula específica.
Novo teste deve usar controle legado independente paraS/N e invariantes de direção
E/W, além de alpha/fixtures e galeria. Não relaxar4593oráculos antigos nem tratar
comparação da calibração consigo mesma como prova de compatibilidade.

Precisão do controle S/N: as8identidades que preservaram células nativas mantêm
pontos/crops/ângulos/depth conforme APIlegada nas28poses vivas. Spirit/Element
foram redesenhadas integralmente e não devem receber pontos legados de corpos
diferentes; nelas verificar gesto/orientação/oclusão por evidência real e comparar
apenas convenções de fase pertinentes. Nativecompat não exige restaurar PNGold.

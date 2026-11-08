# P4 — integração final de jogadores, NPCs e equipamentos

Candidato técnico final, iniciado por Sol6.1high (Codex) e concluído em8/11 por
continuação autorizada pelo usuário após parada do Codex, codex/e08 no checkout
.tools/map-editor-m5. Base085e1a1aa66bedff11f686eace274444413928ab; candidato é
o commit deste recibo. Índice/fixture F1/lista final devolvidos a Root no commit.
[Contrato](e08_p4_final_integration_contract.md),
[posse](e08_p4_final_integration_files.json). Aceite humano pendente; sem
master/push/habitual/saves pessoais/P5. Contadores vigentes estão na seção
"Validação final do candidato corrigido"; números intermediários são histórico.

## Escopo integrado

Dez identidades jogáveis usam64poses/S/N/E/W. Defendente, Berserker, Caçadora,
Sentinela, Geômetra e Arqueiro promovidos para descoberta automática; quatro
anteriores preservados com ajustes de rig pertinentes. Quatro variantes de
cabelo copiadas de inputs read-only paraArcher/Hunter/Sentinel/Geometer, com
seleção/remoção/coldrestore existentes. Mago mantém variante já validada. As
cinco identidades de cabelo exposto usam só seus corpos existentes.

Seis corposNPC promovidos:warrior,gel,beast_master,animal_companion e dois
corpos específicos e08_forest_wolf/e08_forest_boar. Os dois últimos continuam
actor_kind animal_companion e selecionam apresentação pelo mob_base_id. Falha
no específico conservaV1 completo da própria espécie, sem raposa genérica nem
fallback parcial.16MobDefinitions existentes enumerados, sem espécie/população
nova. Companheiro testado é EnemyActor invocado por beast_master; não existe
consumidor de pet amigável encontrado. Root retirou essa inferência do contrato.

Quatorze cabeças e sete peças pintadas/ícones já aprovados mantidos. Nomes,
elegibilidade, economia, dano, AI, RNG, colisão, snapshot/schema e relógio não
mudaram. Catálogos/resources imutáveis; mudança é de apresentação.

## Calibração e limites de fonte

Novo controle extrai EquipmentAttachmentVisual.placement por API, sem duplicar
fórmula. Nas8identidades nativas,28células vivas S/N e palmas/crops/ângulos/depth
conferidos comV1; Sourcepixels preservados. O primeiro teste detectou966falhas
reais de metadata/orientação, registradas. Correções restauram o controle nativo,
incluindo bowHunter1.05/Sentinel0.45, faseaction/hurt e occlusão. E/W preservam
palmas autoradas e têm flipW explícito/rotação refletida; seta de lançamento
aponta ao alvo. Spirit/Element mantêm palmas dos corpos redesenhados, sem copiar
anatomia legada incompatível. Seus arcos laterais recebem convenção de disparo.

Nativos de10players e6NPCs conferidos por Sol; Root fez leitura suplementar das
sete galeriasNPC(incluiArcherNPC), sem novo achado bloqueante. Isso não é aceite
humano nem auditoria visual independente. Headanchors expostos foram inspecionados
com as peças pequenas; não se criou terceira textura desnecessária. Quatro novas
bases preservam448crops/256grounds e pixels fora das regiões autoradas/proteções;
original/bare e fontes permanecem intactos. promoção.json registra23PNGs byte-id
e64frames idênticos nos12conjuntos copiados, mudando só paths do manifesto.

## NPCArcher e triagem de desempenho

V1 era corpo com arco embutido/visualvazio. Projeção V2 inicial custou4.63–4.71msCPU
por96redraws contra0.43ms do controle. Cache privado de geometria, limitado a128,
reusa draw_key e descriptor autoritativos, sem campo em ator/save; DTO público
continua separado. Reduziu a2.06ms, ainda alto. Passou igualdade de geometria,
invalidação por fase/direção/equipamento, proteção contra mutação e limite.

Solução final usa npc_body.png por composição mecânica das camadas do renderer,
corpo weaponless e dedos originais; não desenha/remove anatomia por código.
Body.png/weaponless/bare_head do jogador seguem byte-id. O manifesto body aponta
o derivado; contratos de jogador selecionam weaponless/bare normalmente. Só
os paths exatos aprovados de staging/produção evitam segunda projeção de bow.
OutroV2válido, inclusive npc_body.png homônimo em outra pasta, recebe arco
dinâmico; V2inválido mantémV1baked. Trocar kind limpa derivação. Sem campo/estado
ou formato novo. NPC não ganha seta extra de nock, comoV1; projétil real e setas
dos jogadores permanecem iguais.

Composição4:64bounds/gutters1px/grounds exatos e corpo byte-id fora do suporte
pintado. Comparação re-renderizada máxima2/255RGBA por quantização, sob3/255.
Os ensaios1/2 expuseram ponta de arco abaixo do pisoW56; corrigido ângulo de
preparo para−0.45rad na MESMA palma. Ensaio de integração expôs borda63 nos três
repousos15/31/47; bow1.4rad manteveX/palmas e corrigiu gutter, sem recorte.
Importação inicial reescreveu RGB de alfa baixo: fix_alpha_border=false SOMENTE
no novo derivado mantém o hashRGBA estrito e o pixel nativo; importer original
preservado. Falhas, metadados anteriores e logs conservados.

17perfis96atores,3janelas3s moving/idle porV1/V2, com inputs/engine/fixture
congelados e APPDATA/LOCALAPPDATA isolados. NPCArcher finalCPU0.485/0.475ms
contra0.415/0.406; framep95+7.34/+4.50%, retido+894860B.10players sem regressão
material; NPCs1quad têm overhead comumV2~0.07–0.1msCPU/96. Percentuais>10,
picos/medianas/memória estão explícitos em performance_summary.json. Root aceitou
triagem do pequeno residual em valores absolutos; não exige zerar porcentagem.
Tentativa posterior de lookup passou41815/4892/1181 mas foi retirada byte-exata
por preferência de escopo; produtor voltou ao94df original, com histórico salvo.
Não certifica FPS de mapa/campanha, RSS/VRAM ou ausência de vazamento.

## Histórico de validação em consolidação

Rig/cache41812PASS; quatro novas bases4892cada, demaisplayers4651cada. NPCstages
1181 e consumers/defaults1292PASS, com16defs/summon/negativeexactpaths/switchkind/
restorefrio e simulação preservada. Tools/verify.ps1 registra os2testes novos;
seleção por impacto está em andamento, com4593oráculosV1 intactos. Contadores
não somam reruns. Nativos de staging compatíveis são reutilizados com prova de
igualdade PNG/metadata; repetir somenteArcher alterado e consumidores/defaults.

Falhas de harness preservadas: extração1 por indentação; novoNPCprobe encoding/
CRduplicado; guard de origem após editar consumer em fila anterior; world_integrated1
passou3capturas de piso/rampa/ponte antes de erro de tipo no helper(point_visible
esperaVector3). Corrigir só probe após seleção congelada, sem modificar runtime
nem expectativas. Não repetir testes já compatíveis por essa correção de helper.

A seleção acima (43 etapas/114.800 checks), mosaico final integrated3 (361/0) e
export_final1 (PCK b8249397…, 7 testes empacotados PASS) certificavam o candidato
ANTERIOR à correção lateral abaixo; ficam como histórico, não como prova final.

## Correção lateral da mão da arma — 8/11

Retomada após parada do Codex (última atividade 07:37, nenhum processo Godot
ativo), por pedido humano de auditar P4 e continuar. Inspeção das capturas
nativas mostrou, no Arqueiro em W, o arco na mão de trás com a seta
atravessando o corpo, no jogador e no ArqueiroNPC derivado. Causa: metadata do
rig, não pixels. Fontes W têm a mão da frente estendida; o slot main_hand seguia
a convenção "mão à direita da tela" nas duas vistas laterais, que em uma delas é
a mão de trás. O teste existente só conferia o sentido da seta, por isso passou.

A mesma inversão existia espelhada: Espadachim/Defendente em W (espada golpeando
para trás), Sentinela/Caçadora em E (arco atrás, seta cruzando o corpo) e o
impacto E do Berserker (punho da frente vazio). Usuário escolheu corrigir todas.
tools/fix_e08_lateral_grip_side.py troca main_hand/off_hand com seus dedos,
profundidade, ângulos e overrides nas 14 poses vivas da vista invertida
(Archer/Swordsman/Defender W48–61; Sentinel/Hunter E32–45) e só o quadro de
impacto E42 do Berserker, espelhando o golpe W já autorado (ergue atrás, acerta
na frente). arms mantém seu deslocamento da palma principal. Pixels, S/N, mortes,
cabeças, ground e a vista correta ficam byte-idênticos; o script recusa vista de
referência que não lidere ou correção repetida. Mago/Elementalista/Espiritualista/
Geômetra mantêm o cajado autorado: a outra palma conjura; não é arma para trás.

ArqueiroNPC recomposto pela ferramenta existente (compose_lateral_grip1: 64/64,
gutters/ground/corpo protegido, máximo 2/255). npc_body RGBA
4527f932c7daccd127173cf4fc2d6df04d9b0b017ad38ac9aa972b12e7c8cd3a substitui
2a942c05…; ângulo −0,45 do preparo W56 (mão de trás) ficou superado e o −0,08
autorado da palma da frente passou. Fixture npc_archer_unarmed recebeu os mesmos
quadros. Novo invariante no teste de rig: a mão da arma lidera em direção ao
alvo nas duas vistas laterais (arcos/espadas poses8–10, Berserker10), staging e
default. Originais pré-correção em .godot/verification/p4_final/lateral_grip_before1;
prova visual antes/depois pela sonda lateral temporária, fora do Git.

## Validação final do candidato corrigido

Mesma seleção de 43 etapas (regression_lateral1): 114.876 checks, 0 falhas/erros/
timeouts; +76 são o novo invariante; 4.593 oráculos V1 de mão intactos. Nativos
das seis unidades corrigidas 6×4.714 checks/36 capturas e ArqueiroNPC 405/8, todos
0 falhas; Mago/Elementalista/Espiritualista/Geômetra e os outros cinco NPCs têm rig/
corpo byte-idênticos e reaproveitam os nativos anteriores. Mosaico mosaic_lateral1
361/0 em 64 quadros e 17 apresentações. PCK export_lateral2 SHA256
ca728669956d43802122eb41c7381256017e0fe1f47cd8ce0cc271db32a78f40, 113.778.756 bytes;
7 testes empacotados 98.888 checks/0. export_lateral1 é falha de harness
preservada: testes passaram, mas o processo partiu fora da worktree e a DLL do
plugin git (só editor) gerou ERROR no log; repetido com CWD na raiz, presets iguais.
Custo 96 atores não repetido (só metadata e npc_body de mesmo tamanho).
Inspeção visual das capturas reais confirmou arco/espada/machado na mão da frente.
Evidência: [README](e08_evidence/p4_final/README.md), evidence.zip 1.158 membros.

P4 técnico completo neste candidato; aceite visual de produto continua humano.
Conferência Luna de integridade e preparação do candidato de playtest ficam com
Root em etapa separada; os três rascunhos de guia/preparo/perfil seguem exclusivos
Root e fora deste commit. Sem master/push/habitual/save pessoal; P5–P7 não iniciados.

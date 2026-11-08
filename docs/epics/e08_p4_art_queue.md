# Fila operacional de arte P4 — coordenação Root

7/11/2026. Pedido humano ativo: produzir sprites definitivos; ragrpg-resume
retoma esta mesma execução. Este arquivo de coordenação pertence só a Root;
Sol possui os globals/fixture conforme seu contrato. Não é novo épico/gate.

| Unidade | Estado / dono |
|---|---|
| Espiritualista | V2 integrada a195c8de,21/17.440 e Luna; correção de itens mortos sob nova validação Sol |
| Elementalista | Staging completo Terra; Sol integrou harness e corrigiu head W/morte;3.459checks e661/15PNGs de staging PASS |
| Mago | Staging completo,32células S/N byte-idênticas; Sol importou e está inspecionando |
| Espadachim | Staging completo,32S/N byte-idênticas; posse Sol para integração |
| Defendente | Contrato/preparação Terra em arquivos próprios |
| Berserker | Contrato/preparação Terra em arquivos próprios |
| Caçadora / Sentinela / Geômetra / Arqueiro | Pendentes, sem declarar4vistas; próximo contrato antes da escrita |
| Corpos/overrides de inimigos | Pendentes; inventário em p4_sol/baseline_inventory.json; não iniciar novo kit/AI |

Sol delimitado: docs/epics/e08_p4_units_sol_contract.md e files.json. Root não
edita seus arquivos ou fixture até handback. Artistas só suas listas por unidade,
sem engine/importação/commit. P4 aberto, P5 bloqueado; sem master/push/save pessoal.

## Retomada operacional e novo pedido de equipamentos

Na rodada atual, Sol e Terra Berserker interromperam com erro de limite de uso
do provedor. Root interrompeu explicitamente os executores antes de assumir
posse de índice, fixture e arquivos delegados; preserva todas as saídas/parciais,
sem declarar entrega/validação concluída. Defendente retornou integralmente;
seu diagnóstico concreto de2células segue contrato corrigido. A tentativa de
nova tarefa Defendente foi interrompida ainda em pending_init sem nova escrita.
Root assume temporariamente esses arquivos e a consolidação. Uma nova delegação
exige mensagem/posse delimitada, sem alteração de expectativas.

Pedido humano adicional: capacete menor/encaixado, equipamento mais desenhado
e drops temáticos usando a referência Spriters Resource. Contrato independente
[e08_p4_gear_art_contract.md](e08_p4_gear_art_contract.md), estágio novo, sem
conflito com corpos/renderer. Novo agente pedido explicitamente pelo usuário.

## Checkpoint após5756f094

Elementalista/Mago/Espadachim default integrados e correção comum mortos validados:
23etapas/28.694checks únicos; Luna integridade em andamento separado. Root tem
índice/fixture após handback Sol; não alterar2431inputs até terminar supervisão.
Defendente/Berserker/Caçadora estão completos emstaging Root; não promovidos.
Defendente: somente2mortes nativas corrigidas imagegen,30outras S/N preservadas.
Caçadora:3mortes com arco residual corrigidas,29outras S/N preservadas.
Berserker:32S/N preservadas. Os3 têm64heads/112grips; prova nativa pendente.
Sentinela em produção Terra; Geômetra/Arqueiro têm contrato, sem dispatch.
Gear:14heads+2estudos+7anexos e fontes entregues emstaging, alfa/encaixe proposta,
integração ainda pendente. Hoods com cavidade opaca corrigidos nas fontes.
Novo pedido cabelo/rosto documentado em e08_p4_head_fit_contract.md. Mago será
primeiro caso completo de corpo com cabelo exposto SOMENTE quandohead equipado;
aparência aprovada sem equipamento permanece original. Novo artista tem posse
só após dispatch do contrato/lista específicos. Corpos inimigos ainda pendentes.

DispatchRootGel: contratoNPC+toolversionadosa23a84c2; RootúnicoescritorstageGel/lista. Solíndice/fixture/exclusivostestados; TerraArcher/Geometeretapaspróprias. SemnovoAI/loot.

## Retomada após limite/primeira cabeça —7/11

Clock retornou22:42UTC(19:42BRT), após reset19:39 informado pelo provedor. Root
retomou Sol e as duasTerras sem sobrescrever parciais. Índice/fixture seguemSol.
Todos10jogadores têm4vistas completas: Spirit/Element/Mage/Sword default validados;
Def/Bers/Hunter/Sentinel/Geometer/Archer completos emstaging, nativo ainda pendente.
Todos6corposNPC agora completos emstaging: gel,warrior,beast_master,animal_companion,
forestwolf/boar. Root conferiu32S/N exatas,64grounds,4blocos eRGBA de todos;
consumidores/overrides/ArcherNPC/renderer/PCK ainda pendentes. Não confundir catálogo
NPC de teste com ocorrência publicada. Hashes em p4_npc_authoring_checks.json.

Sol primeira prova realMago passou: unidade2589,nativo5568/35capturas,14IDs×64,
7props×64,4vistas,UI real,olhos/capuzorigem/equipar-remover preservados. Ajustou
somentehead.pointY +4pxnas64poses apóscomparar; fontebare_headce94intacta. Isso
libera as4bases de cabelo restantes (contrato+wrappernovos), não aceitehumano/P4.
Custo apósrepetiçãoquieta: móvelCPU8,138/9,288→6,840/9,333ms, parado8,193/10,409→
6,874/9,300; retenção -32544B. Tailinicial13,9%nãoreproduzido;ambas medidas ficarão
no reciboSol. Ele segue verify/export/consolidação, sem incluirRootnovosstages.
Root tem UMA janela temporária do índice só para commit de arte/contratosdisjuntos,
e devolverá explicitamente antes de qualquer novoGitSol. Próxima execuçãoartistica
4bareheadunidades depende do contrato/lista versionados neste lote.

## Fronteira validada e inputs finais —8/11

Gear/Mago entregue94dfaf7f97e8faa094d9f9ad7612baf7729d801c eLuna integridadePASS:
ZIP522/37891701B SHA6421f67fd2461ca1771d011a1aba422f776e6fd6803f47933c1c3f3f0b1b5d85;
2468inputs;24etapas únicas31283checks,5568/35nativo,76/64motion, PCKfinal2PASS.
Root removeu APENAS2PCKs temporários após novamente conferirhash/path/bytes:
202155480B; recibo p4_equipment/validation_pack_cleanup.json. Fontes/logs/ZIP/
fixture/saves/pilotoP3 preservados. Renderer eprodutor retornaram à posseRoot.

Todas4bases de cabelo restantes entregues eRoot conferiu independentemente:
256grounds,448crops,256frames fora máscaras intactos ehashes. Originais preservados.
Hunter tinha arco confirmadoS15: quarta correção somenteframe15 no corpo e
headfitdependente. Corpo19f5871b70263bec4ea125be168008e384369f5bf2bd3de9d9b1d6aff8442c5d;
bare04d7e64c81f1d90f8aa53bb5f467d6772c850673edfe297f7d1610ae7d25c7f2.
28nativas originais e3mortes anteriores intactas; antiga divulgação29nativas/c116
é histórica. Sentinelbare2f417e4b...,Geobare6f9b3212...,Archerbare77e45f85....

Root encontrou risco de rig vivo, registrado no contrato final: Hunter/Sentinel/
GeometerWflipfalse/semoverrides de arco deação; não promover semextração do
controleS/Nlegado eorientaçãoE/W/oclusão nativa. Todas16artes de corpo completas
não significam16conjuntos integrados. Integraçãofinal abrangerá6players+6NPCs,
4bareheads,6overrides de consumidores/ArcherNPC evalidará oescopoP4 inteiro.
Contrato/lista final resolvemProducerBase94df; oSHA do próximo commitRoot com
inputs/contrato será a base executável da delegação. Sem P5/master/push.

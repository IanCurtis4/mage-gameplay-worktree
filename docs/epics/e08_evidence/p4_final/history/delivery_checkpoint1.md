# P4 — integração final em execução

Sol6.1high, base085e1a1aa66bedff11f686eace274444413928ab, codex/e08 no checkout
.tools/map-editor-m5. Posse exclusiva de índice/única fixture/lista final continua
Sol até commit/handback explícito. Root não escreve inputs. Sem novos épicos,
master/push/habitual/saves. Este checkpoint parcial NÃO é fechamento técnico.

## Concluído nesta rodada

- Referência via EquipmentAttachmentVisual.placement existente extraída em
.godot/verification/p4_final/legacy_rig_reference2. Primeiro auxiliar falhou por
indentação mista, preservado em legacy_rig_reference1 e corrigido.
- Oráculo independente inicial detectou966falhas de metadata/orientação.
S/N das8identidades nativas corrigidos conforme API legada para todas7peças e
3slots/28poses; palmas nativas preservadas, crops do slotarms retornaram ao
controle legado, sem mudar pixels. E/W mantêm pontos/crops/near-far autorados,
flipW explícito e ângulos refletidos; faseaction/hurt leva overrides pertinentes.
Spirit/Element conservam palmas/redesenhos e só corrigem arco lateral de lançamento.
- rig_pixel_control1 PASS23.882checks: comparação independente da API,28células
vivas exatas de cada8identidades e disparoE/W. TestesV1 antigos serão preservados
por fixture explícita; não reduzir oráculos/4593mãos.
- Quatro bareheads copiados do staging read-only, sem mudar PNGs/fontes:Hunter
04d7e64c...,Sentinel2f417e4b...,Geo6f9b3212...,Archer77e45f85.... Headanchors/angles
consumidos da calibração autorada. Stage unit de cadaum:4892checks PASS, inclusive
14IDs×64, bounds mortos,112crops, máscaras, equipar/remover e coldrestore real.
- NPC consumidor implementado: arco derivado apenasArcherV2válido, limpeza ao
reconfigurar, wolf/boar com overrideV2 específico e fallbackV1 completo. NPCstages
unit_npc_stages1 PASS1176. Consumidores/defaults/snapshot ainda pendentes.
- native_hunter_stage3:15capturas PASS e inspeção4vistas/anexosW. Sentinel/Geo/
Archer stage2:4714checks/36capturas cada,14heads+7props64poses e inventário real.
Bases expostas seguem em fila native_<kind>_stage1 e player_<kind>_stage1;
Def/Bers jáunit4651PASS. Conferir os resultados antes de repetir etapas.

Falhas adicionais de harness preservadas: novoNPCprobe escrito em encodingWindows
(import_hair_cost1 Unicodeerrors), corrigidoUTF8; native_hunter_stage2 encontrou
CRduplicado na conversão, normalizado antes de native_hunter_stage3PASS. Uma
chamada native_hunter_stage1 parou no guard de hash após edição serial de
consumer durante fila jácriada; nenhum engine/prova foi declarado nesse guard.

## Próximo passo autorizado

Concluir conferência nativa/rigs em10players e6NPCs antes defaults. Medir17perfis
96atores V1/V2,3x3s moving/idle, quietas coordenadas Root:16corpos e NPCArcher
matched (V1baked/visualvazio versusV2weaponless+arco pela derivação real).
Ainda NÃO foi iniciado custo final. Promover só com dados/calibração válidos;
depois consumerNPC real/16MobDefs/summon, verify por impacto, nativo de defaults/
piloto/oclusão/PCK, freezeZIP/commit/handback. PCKs novos manter até Luna/Root.

Root confirmou não haver path de pet amigável: exigência era inferência pelo nome
animal_companion e foi retirada do contrato. Testar consumidores reais EnemyActor
invocado por beast_master e test_animal_companion/catalogo, sem inventar consumidor.

## Checkpoint após custos —8/11

17perfis concluídos:cost_all_npc_static1 +cost_all_sixteen1 (32engines
no segundo lote, todos0erro/timeout;2556inputs origem/fixture SHA iguais antes/depois).
10players sem regressão material;6NPCs+NPCArcher têm residual comum de catálogo/
seleçãoV2~0.07–0.1msCPU por96redraws, percentuais>10 preservados com valores
absolutos/picos/memória em performance_summary.json. Root aceitou triagem
técnica do residual; não certifica campanha/FPS. NPCArcher principal regressão
4.7msCPU resolvida por npc_body.png mecânico (0.485moving/0.475idle;controle
0.415/0.406;framep95+7.34/+4.50;retido+894860B). 64bounds/gutters/grounds e
corpo fora do arco byte-id, re-render max2/255RGBA. .import novo fix_alpha_border
false mantém hashRGBAestrito, sem mudar importer dos originais. Três repousos
15/31/47bow1.4rad ewindupW56−0.45, mesmaspalmas/X/crops; falhas preservadas.

Cache privado de geometria bounded128 continua (41812rigPASS). Tentativa lookup1
(objetal aliases no mesmo cache produtor) passou41815/4892/1181, mas foi retirada
byte-exata via sync_lookup1/previous e sync_lookup_revert1 a pedidoRoot; nenhum
novo cache produtor no candidato. Produtor original94df intacto.

Archerstatic3 unit4892,NPCstatic_stage11181 e rigNPCstatic341812PASS. NPCbody
reconhecido SOMENTE pelos2paths aprovados; homônimo fora da pasta validadoV2
projeta bow dinâmico e o limpa ao trocar kind. Originais body/weaponless/bare
Archer preservados. Próximo: conferir6NPCnativos+deltaArcher, promover cópias
idênticas de6players/6NPCs/4bareheads, consumer16MobDefs/summon/coldrestore,
verifyimpact/PCK/world/oclusão e freeze/commit/handback.

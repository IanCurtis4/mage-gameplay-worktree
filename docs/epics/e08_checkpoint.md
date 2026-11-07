# E08 — checkpoint portátil

> Estado vigente em 6/11: [piloto aceito com ressalva sonora](e08_p3_product_acceptance.md); P4 autorizado, [contrato](e08_p4_contract.md). Bloqueios por aceite P3 nos registros abaixo são históricos. P5/P6/P7 ainda dependem das entregas anteriores; não despachados.


6/11/2026. P0/P7:01a1ae9c-2471-74d2-84ad-9805a14dc543.
[Autorização](e08_approved_plan.md),[contrato](e08_p0_contract.md),[donos](e08_dispatch.md).

Checkout C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5,
branch codex/e08. Código P3:3ea5e9086da11c51d81d5a85b8f29d464b04c3d8.
Candidato empacotado:ad09b99d5e70385d4532b478931c85629f5de849.
Commits posteriores de ferramentas/documentos não substituem esse PCK.
Base F10:c8b80b13d29c468afb7f2ad7ba75eec838e7df32.

P1 ponte/atlas/UI120%, P2 áudio/limiter e P3 arte/VFX/12sons tecnicamente
VALIDADOS/INTEGRADOS. [P3 final](e08_p3_delivery.md),[Luna](e08_evidence/luna_p3/supervision.md).
14/14etapas+126checks nativos; ZIP35membros,2316fontes. Receita documental
pós-teste identificada; versão testada preservada. Sem aceite artístico/auditivo.
P4–P7 BLOQUEADOS_ACEITE_P3; não declarar E08 inteiro ou P7 final concluído.

Habitual permanece codex/playtest em fba777b3822356a10e7f6e050971e54ab1a9819b,
216 alterações locais na inspeção. Nenhuma aplicação/rebase/limpeza no habitual,
save pessoal e4backups preservados; sem master/push/terceiro checkout.
P1:01a1aea0-d67a-7023-9fcf-dbecfe5cef85; P2:01a1aebf-dbc4-7701-8b17-1441618fb9c6;
P3:01a1aede-5799-76f2-835d-5418b5e395d9 estão parados, disponíveis para correções.
Usuário autorizou expressamente acompanhamento/mensagens corretivas P1–P3.

Release separado .tools/playtest_e08/pilot_ad09b99d, app RagRPG E08 Piloto1,
save separado. EXE109127680B, SHA256
4a9eaded8955ef789ab02651ed9d2dde80328fbb342bd2a6db4db33e86305668;
PCK125350284B, SHA256
d91bc71373ec370e744b61032b7aed036f4895620241027b29c0b505c81246e2.
Export/inspeção/menu/boot EXE passaram. Engine standard+PCK exato passou20checks:
62inimigos,UI120%,atlas,limiter,suspensão/retomada e ambiente atual sem replay.
Entrada50,810s;suspensão8,908s;retomada26,675s nessa amostra. Asset manifest7/7
PASS via verify.ps1. Teste antigo E06 de exportação falha2/162 por11mobs esperados
contra16atuais; mesma falha no PCK F10. Não alterar expectativa. Primeiro pack
teve .import reescrito; correção de exportação conserva bytes originais e texturas
importadas. Binários obsoletos removidos por caminhos/hashes verificados;
logs/manifestos preservados, não são candidatos jogáveis.

Próximo passo: Sol concluiu consolidação e preparou [recibo](e08_pilot_release.md)
e [roteiro/antes-depois](e08_pilot_route.md). Comparações6+2+2processos válidos,
triagem investigada por ablação v2; desempenho varia entre janelas, sem promessa
universal. Inspeção interativa do EXE não foi executada porque os dois mecanismos
de automação falharam ao criar o kernel; boot normal EXE e20checks standard+PCK
passaram. Processo do teste adicional encerrado deliberadamente, não PASS.
Luna devolveu posse sem divergência:93/93membros,2323fontes atuais/2322export,
21arquivos de jogo/avaliação,5processos de embalagem,20checksPCK,7asset e10processos
comparativos conferidos. [Supervisão final](e08_evidence/luna_pilot_release/supervision.md).
Sol consolida aprovação técnica PARA PLAYTEST COM RESSALVAS. P0 entregou atalho,
roteiro,antes/depois e som. Próximo passo é o usuário testar este candidato e
registrar aceite ou correções. P4–P7 continuam BLOQUEADOS_ACEITE_P3. Não criar
chats bloqueados nem inferir aceite de produto; correções reutilizam P1–P3.
Nunca dois escritores no checkout. Nenhum runtime mudou após o export.
ZIP93membros, SHA256be2adeb28932a001630ec66e17ba8931582c215889f3c45f635ad42b9cafa949.

Engine standard4.7.2.stable.official.ed1daf0bf, SHA256
ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424.
Uma fixture/cache .godot/verification/e07_f1/fixture_project,2322fontes no
preflight de embalagem; perfis de teste isolados. CLI tools/workflow/workflow.py
e docs/WORKFLOW_TOOLING.md ausentes nesta base: retomada Git/contratos sem copiar
tooling adivinhado. Diagnóstico e aprovação técnica não equivalem a aceite humano.
## Limpeza autorizada de disco — 6/11/2026

Após a entrega, o usuário pediu remover testes antigos e deixar o disco C mais
limpo. Foram removidos caches de importação, a fixture descartável em
.godot/verification (incluindo e07_f1/fixture_project), cópias antigas F9,
builds superados e resultados temporários já consolidados. Os arquivos-fonte
dos testes, os dois checkouts Git, quatro backups, saves pessoais e evidência
versionada foram preservados. Os21arquivos do piloto E08 e o PCK F10 de referência
conferiram pelos mesmos hashes após a limpeza. O candidato e seu aceite não mudam.

A fixture/cache já não está instalada: antes de uma nova validação -F1Fixture,
recriar pelo bootstrap existente tools/verify.ps1 -Test e07_f1_import_test,
com o engine standard fixado. A reimportação é esperada; não restaurar cópias
antigas de testes. Registro operacional fora do Git em
C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/cleanup_2026_11_06/.
Nenhuma suíte de gameplay foi repetida por esta limpeza de arquivos gerados.

## Aceite humano e P4 — 6/11/2026

Usuário aceitou o piloto ad09b99d com sons ainda bit-crushed, adequados como
placeholder, e autorizou continuar P4. Contrato/lista exclusiva publicados;
próximo passo é execução Terra Personagens, esforço médio, checkout codex/e08.
P5/P6 aguardam dependências. Nenhum merge/push ou alteração de save.
A preparação documental não repetiu gameplay.

Chat P4: 01a1b369-442b-7f91-82a1-2316a4a0514d, host local, Terra6.1 médio.
O SHA deste registro será informado no dispatch. Depois da transferência,
P4 é único escritor dos arquivos listados; P0 somente leitura até handback.

## P4 parcial retomado por Sol — 6/11/2026

Terra parou no checkpoint6389edcdb7d145e4721b9504ba2876173d4d6a68.
Pedido humano atual autorizou avaliar/assumir a parte complexa. Sol assumiu
triagem conforme e08_p4_sol_contract.md e concluiu prova UI atual, sem alterar
runtime/arte/testes:764checks nativos/10identidades/32capturas; verify4/4,
6.433checks. Aviso2ObjectDB do teste admin conservado. Luna conferiu74/74membros
ZIP,2.332fontes,engine/tools/backups e devolveu posse sem divergência.
[Subentrega e pendências concretas](e08_p4_sol_delivery.md).

P4 continua INCOMPLETO, P5 bloqueado. Próximo pacote técnico possível a Sol é
produtor V2 direcional e integração comum de cabeça/anexos, com lista exata/SHA
antes de editar. [Contrato técnico](e08_p4_directional_contract.md).
Arte candidata Espiritualista24/56grips semalpha não promovida. Preview do
inventário não desenha capacete: pendência real de integração, não resolvida
por captura ou mudança do oráculo. Terra permanece parado para essa fronteira.
Release ad09b99d e habitual/save não mudaram; sem master/push.

## Produtor direcional implementado — 6/11/2026

Autorização humana posterior: continuar a implementação técnica por Sol.
Base e10bf71d91d0e9271d9792ed04e211ab8ca17112. Implementação e evidência em
[e08_p4_directional_delivery.md](e08_p4_directional_delivery.md), API/contrato
em e08_p4_directional_contract.md.64poses/quatro vistas e V1 preservado,
mesmo relógio e campos de snapshot, rig/head compartilhados; capacete aparece
no retrato real. Arte de produto e candidata Espiritualista não foram alteradas.

25/25etapas,13.829checks; nativo82/6capturas; PCK814+84PASS. Regressão de custo
sem anexos foi detectada e corrigida; paridade RGBA exata com o piloto e CPU
de desenho menor. P95 de quadro variou em algumas janelas sintéticas; triagem,
repetição e instrumento CPU preservados, sem promessa de FPS universal.
2.352fontes, uma fixture reutilizada, engine4.7.2standard e backups conferidos.
CLI workflow continua ausente; não foi copiado tooling.

Freeze deste registro entrega apenas dois arquivos de conferência a Luna:
e08_evidence/p4_directional/luna_supervision.md e luna_hashes.json. Demais
arquivos somente leitura até handback. Código/fonte do PCK não mudarão por
conferência. Próximo consumidor é UMA identidade artística V2 em staging,
com corpo/equipamentos completos e testes reais; P4 inteiro/P5 continuam abertos/
bloqueado respectivamente. Habitual, status local e saves preservados.

## Produtor direcional consolidado — 7/11/2026

Implementação6b33dce1, candidato congelado3637f260, na branch codex/e08.
[Luna](e08_evidence/p4_directional/luna_supervision.md) conferiu389/389membros,
2.352fontes, engine/backups/PCKs e execuções25/13.829, nativo82/6, pacote814+84;
devolveu posse a Sol. Corrigido somente o caminho mal codificado da engine no
manifesto externo, com reconciliação antes/depois. ZIP/runtime inalterados.
Três PCKs temporários conferidos foram removidos (~208MiB); fontes/fixture/logs,
piloto aceito, habitual e saves preservados. Detalhes no recibo direcional.
Consolidação documental não repetiu gameplay. Produtor disponível para UMA
identidade artística V2 em staging; P4 continua incompleto, P5 bloqueado.
Sem ativação de arte, transferência de edição de APIs, merge ou push.

## Produção artística P4 autorizada — 7/11/2026

Usuário pediu produzir sprites definitivos. [Contrato do primeiro conjunto](e08_p4_art_contract.md)
e [propriedade exclusiva](e08_p4_art_files.json) delimitam EspiritualistaV2 completa
em staging, Terra6.1médio como subagente de conteúdo, Sol harness/teste e integração.
Base48058190d9a7e12dce7319b6d25020e0befacfd1; mesmo checkout codex/e08.
Produtor pronto e conferido; demais identidades vêm após provar a primeira.
P4 permanece em execução; P5 bloqueado. Habitual/piloto/save preservados.

## Espiritualista V2 — primeira unidade integrada em7/11/2026

[Recibo artístico](e08_p4_art_delivery.md):4vistas/64poses,112grips vivos,
fontes imagegen e calibração Sol, promoção para caminho padrão.21etapas/17.440checks,
nativo447/15PNGs,64frames de movimento; PCK3.293+814PASS. Primeira tentativa de
áudio falhou por APPDATA não isolado, repetição isolada passou sem alterar áudio.
Oráculos V1 preservados por fixture explícita; migração de paths V2 documentada.
ZIP275membros,2.377inputs congelados, sem cache/perfis/builds. Após commit, posse
Luna somente dos dois recibos de conferência p4_art/luna_supervision.md e
luna_hashes.json; inputs desta unidade não mudam até handback. Outros conjuntos
ainda podem ser produzidos em arquivos disjuntos, sem editar esses inputs.

Elementalista entregue em staging por Terra, calibração inicial pronta e inspeção
Sol pendente; [contrato independente](e08_p4_elementalist_contract.md)0ddad09f.
Demais identidades/inimigos ainda pendentes; P4 continua em execução, P5 bloqueado.
Habitual/piloto/saves preservados; sem master/push/arquivamento de chat P4.

## Handback Luna da Espiritualista — 7/11/2026

Candidato a195c8de29ce436520548a44268d412df69f6b49 conferido por Luna:275/275
membros,2.377inputs em origem/fixture, engine/backups/PCK,21/17.440checks,
nativo447/15, pacote3.293+814 e movimento64PNG/GIF6,4s. Devolveu posse, sem
rerun ou aceite artístico/produto. [Conferência](e08_evidence/p4_art/luna_supervision.md).
Removido somente o PCK temporário83.157.672bytes após conferir seu hash/tamanho;
fontes/fixture/evidência/piloto/save preservados. [Consolidação](e08_evidence/p4_art/consolidation.json).
A narrativa de espera por Luna acima é histórica. Espiritualista tecnicamente
consolidada; Elementalista em staging sob inspeção Sol e Mago preparado como
próximo pacote em arquivos disjuntos. P4 continua aberto, P5 bloqueado.

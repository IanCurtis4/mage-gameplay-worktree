# E08 — checkpoint portátil

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

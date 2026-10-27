# Consolidação técnica Sol — clientes de gameplay F9

Código3418303544fada82f3485de1c63a04e847805fbf, primeira supervisão congelada
em8610171e329b2b03b622dd275f13246dbcc225d2; correção somente de setup técnico
em7f723acc0186741abb3f93769d3f01b9065716a8. Humano conserva porta80, negativos
explicitam24. [Falha parcial Luna](../luna/gameplay_clients/report.md) preservada.

Luna executou os cinco estágios Editor22/CLI18/Native52/Window33/CandidateNative49
PASS, incluindo fim efetivo dos dois processos CLI. Na primeira regressão,
composição60/63 falhou e a seleção parou; nenhuma etapa omitida foi alegada PASS.
Após Sol explicitar a porta24 da fixture, Luna executou Core completo: candidato53,
documento70, terreno102, composição63, população91, patrulha58, geração89 e
intercâmbio113, todos PASS. [Manifesto completo](../luna/gameplay_clients/core_corrected/manifest.json).

Luna executou os seis oficiais por tools/verify.ps1: animação39, snapshotF6 40,
faultF5 20, snapshotF3 50, cenaF1 102 e apresentaçãoF1 37. Saídas0, sem erros ou
timeouts; [recibo](../luna/gameplay_clients/official/checks.jsonl). Não são a suíte
oficial completa. Depois das execuções, o subagente atingiu seu limite de uso e
não escreveu report_final.md. Não se atribui a ele relatório/conferência posterior.

Sol conferiu os logs e a auditoria pós-Verify:1984 inputs do manifesto Core
iguais entre fonte/registro/fixture, sem divergência. Quatro manifestos anteriores
1990 cada e CandidateNative1984 conservam somente o delta autorizado de
tests/map_editor_composition_test.gd (setup24 reexecutado no Core); nenhuma
outra diferença. Seus inputs atuais também coincidem com a fixture. A diferença
única de project.godot é VCSautoload true→false, engine SHA256
AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424 e HEAD7f723ac
estáveis. [Auditoria Sol](gameplay_clients_audit.json). As cinco provas anteriores
são reaproveitadas com essa proveniência, sem alegar nova execução posterior.

Resultado: cliente de gameplay tecnicamente consolidado por Sol, com execução
supervisionada acima e limite documental da supervisão explícito. Fixture liberada
após confirmar ausência dos processos descartáveis. Não é auditoria semântica
independente, aceite humano ou entrega integral F9. Campos visuais, export limpo,
responsividade, geração regional e demais linhas do contrato permanecem abertos.
Principal/playtest e save pessoal preservados; sem master/push ou novo marco.

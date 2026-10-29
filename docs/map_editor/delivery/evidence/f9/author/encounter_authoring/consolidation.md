# AX de encontros e patrulhas — validação F9

Runtime `5a97f7d7e095b36d65795140bae82a7178b73d6b`; candidato com fixture
corrigida `3a5bff35a573cce3ac76439d68d59eaed87c7974`. O delta entre ambos
em scripts/addons/tools/data é vazio; somente testes, documentação e evidência
mudaram. Branch `codex/map-editor-f9`, checkout `.tools/map-editor-m5`, Godot
4.7.2 standard SHA256 `ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424`.
Fixture exclusiva `.godot/verification/e07_f1/fixture_project`.
Não é fechamento F9 nem aceite de produto.

## Comportamento entregue pelo candidato

Sol implementou propostas fechadas PopulationOperations/PatrolOperations e
integrou os mesmos produtores aos controles GUI e providers AX existentes.
Entrada, brushes/espécies/pesos, exclusões, interações e slots fixos usam o
Document/Session canônico. Remover brush confirmado inclui seus slots; criação
manual não pode se declarar gerada. Rotas, pontos, espera, ordem e atribuição
exclusiva usam PatrolDocument; a compilação mantém corpo, suporte, origem,
recompensa e leash existentes. Nenhum setter de documento completo foi exposto.

Prévia de população continua no worker real, sem aplicar fonte. A assinatura
privada liga base, fonte proposta e diff; confirmação, hash atual e assinatura
recalculada antecedem uma única ação de histórico. Proposta obsoleta/adulterada
é recusada. Documento novo/abrir e importação substitutiva preservam rascunho;
erro de preservação interrompe a troca. Stores devolvem o hash dos bytes lidos;
save mantém conflito externo e recusa novo destino AX já existente. Nome ainda
em edição é preservado em falhas; sessões expõem undo/redo.

O cliente abre as janelas reais de população/patrulha pelos pais existentes e
aguarda os workers. Snapshots e hashes são específicos da sessão; topo da
resposta continua identificando a peça. Consultas expõem catálogo, apoios e
sockets do pacote real. Captura escolhe a última tela, com seus ancestrais.
Importar mapa repassa o pacote recém-validado apenas no apply síncrono, ligado
ao hash exato, evitando outra compilação/reconstrução idêntica. Não é cache
persistente nem conclusão de desempenho F9-10.

## Execução e diagnóstico

Luna escreveu e executou os testes; Sol revisou contrato, código, oráculos,
recibos, capturas e bytes. Essa supervisão não é auditoria semântica independente.
As correções pré-execução de fixtures e snapshots estão no
[registro Luna](../../luna/encounter_authoring/README.md).

Primeiro lote em 5a: modelo27 PASS; nativo24/25, sem Script/Parse/ERROR. Sol
executou uma cópia instrumentada com os 25 oráculos originais intactos. Todas
as subcondições da rota eram verdadeiras, exceto espera esperada1,75 versus
valor efetivo1,8 com passo0,1 do controle. GUI/AX tinham a mesma rota. [Diagnóstico](native_diagnostic_01/diagnostic.manifest.json).
Produção não mudou. A fixture passou a usar1,8 e igualdade exata; o modelo foi
fortalecido para exigir1,75 exato em ponto novo/editado, preservando a ordem.
Falha original, cópia instrumentada, logs e hashes continuam preservados.

Rerun em 3a5: EncounterAuthoring27, Native25, GameplayNative52,
Candidate53/Population91/Patrol58/Exchange113 PASS. `tools/verify.ps1` selecionou
somente `editor_import`: um ID do catálogo de299 PASS, não a suíte inteira.
Sem Script/Parse/ERROR; warning conhecido do projeto aninhado ignorado.
Source/tests/tools/HEAD ficaram congelados, perfil APPDATA/LOCALAPPDATA privado.

[Consolidação de hashes](validation_audit.json) compara os2054 inputs dos três
completion runs e os2048 de Context com a fonte/fixture atuais. Os seis imports
de props explicam a diferença; dez imports de props/terreno foram conferidos.
Zero divergências. Quatro UIDs foram geradas pelo engine e transportadas sem
edição antes do Import02. Import03 sincronizou os dois testes corrigidos.

## Transporte e conteúdo

A prova do cliente real passou em cinco processos sequenciais: preview2/2,
headless12/12, nativo12/12, reabertura4/4 e negativo2/3 com exit1 esperado.
O negativo recusou slot manual declarado gerado e não executou o save seguinte.
[Manifesto CLI](cli_01/manifest.json) e captura `cli_01/native.png` preservados;
Sol inspecionou a captura da janela real em1440×1000. Inputs2054 e HEAD3a5
permaneceram estáveis, sem erros e sem engine remanescente.

Headless/nativo reproduziram os seis hashes:

- população/fonte `0700db5d8682478a63e53d0c5844fb74fb6fb628c12b4d18e3d356d137726261`;
- patrulha/fonte `c9f485ce973cf00a4df085a6163466c39092b75966e6cbeb7abce64ddfb74758`;
- população/pacote `3d539c31f65a2fc3d2f05d70aca80e00f7cb18f5f756d1f3be47949fd45a9133`;
- patrulha/pacote `3844c99bbd11b68a0c01db693a5dd9286efc81e90c20834c85f1e22ce9bc962f`;
- população/arquivo `eb46c2c669149d58eaefc9d74083c157dfe89a6a24fb7e6d5a25a5e236db3b27`;
- patrulha/arquivo `a749059483c63f5f718bef8fe927c544f7985102e7b77a5e5c1475cbfff5e233`.

A reabertura confirmou fontes/pacotes em processo novo. A espera AX1,75 foi
conferida exatamente no arquivo salvo; o controle atual tem passo0,1 e a lista
mostra uma casa decimal. O dado fracionário não foi arredondado pelo AX/Store.
Não confundir essa prova sobre fixtures descartáveis com autoria do Bosque.

Terra preparou [plano passivo](../../terra/area_encounters/plan.md) e receitas.
Ainda não criou `sanctuary_woods.population.json` ou `.patrol.json`. O Bosque
continua no checkpoint26, sem encontros/rotas/objetivo realizados nem nova prova
de App/caminhada/combate/FPS. Depois da liberação do produtor, Terra fará a
autoria exclusivamente pelo editor AX e os consumidores terão prova própria.

## Limites vigentes

Reconciliação entre revisões, síntese/regeneração regional, transporte de assets,
ambiente limpo, export/release, recuperação/cancelamento/cache/progresso integral,
UX final, performance representativa in-game e área final continuam na matriz
F9. O teste histórico M3Native24 ainda precisa migrar/ser retirado com cobertura
atual preservada. Sem F10, playtest pessoal, master ou push nesta fatia.

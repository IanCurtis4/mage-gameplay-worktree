# E07-F0 — integração operacional

18/10/2026. Usuário informou F0 concluído e autorizou iniciar F1. Coordenação
conferiu a [entrega Sol/Luna](delivery/f0.md) e integrou F0. Estado: **VALIDADA,
INTEGRADA, ARQUIVADA**. Sem aceite de gameplay E07 ou merge em master.

## Proveniência

- Base F0: `e30c49bb6442344ce8d937910ca6170effc70c7a`.
- Código: `0720d5b699cf2d3c5a81917ba1ca8318ea03bd05`.
- Recibo/API finais: `fff0960bad32779bb9041f5748c0ba722fed714d`.
- Coordenação anterior: `9afc24717c018f02ecbcb41e357a4cf38fdca622`.
- Integração: **`42604ef8674a2c28f5aadc633b73cda15178e0b3`**.
- Chat F0: `01a14f91-d0c6-7c20-82c9-a22650fa5199`.

Árvore F0 limpa. Criada codex/e07-f1 a partir da entrega F0 e integrado o commit
de coordenação, sem conflitos. Delta contra F0 contém somente quatro documentos;
scripts, testes, runner, cenas, dados e project.godot permanecem idênticos ao
candidato validado. codex/e07-f0 preserva a entrega original como referência.
Checkout habitual codex/playtest avançou por fast-forward até o hash integrado.
As 214 alterações locais tiveram seus bytes conferidos antes/depois e preservados.
Nenhuma alteração no save pessoal, master, push ou configuração do usuário.

## Conferência e reuso de evidência

Conferidos os 15 hashes publicados (engine, runner e logs), os 43 arquivos de
origem e suas cópias no projeto fixture, as quatro etapas completas com exit0,
failed=false e timed_out=false e ausência de marcadores de erro nos logs finais.
Conferidos os 46 arquivos entregues dentro da propriedade de F0; o runner
acrescenta somente seis linhas e não relaxa checks anteriores. A coordenação
não repetiu os 415 checks de gameplay: reusa a execução supervisionada por Luna
e consolidada por Sol, vinculada ao código e inputs byte a byte compatíveis.
Isso é conferência de evidência e integração, não auditoria semântica independente.

Preservados 107 arquivos de evidência, com verificação de cópia byte a byte, em
`C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.godot/evidence_archive/e07_f0_0720d5b`.
`archive_manifest.json` lista SHA256 de cada arquivo. Originais continuam em
`C:/Users/João Pedro/.codex/worktrees/content-delivery-docs/RagRPG/.godot/verification/e07_f0`.
Não remover esse arquivo de evidências por arquivar o chat ou reutilizar a branch.

O import de F0 certifica somente o projeto fixture puro. O import do projeto
completo encontrou GitPlugin preexistente indisponível; nenhuma importação nativa
completa ou prova visual do produto está certificada. F1 precisa resolver seu
ambiente de execução e produzir prova nativa própria. Não reinterpretar a prova
de F0 como validação de atores, ponte jogável, combate ou renderer multialtura.

## Próximo passo

API [F0](f0_api.md) disponível no hash integrado. F1 recebe checkout e arquivos
por [despacho próprio](f1_dispatch.md). O recibo F0 é histórico; decisões posteriores
e estado de integração são registrados aqui e no índice, sem reescrever sua evidência.

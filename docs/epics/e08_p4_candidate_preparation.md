# Preparação do candidato de revisão P4

Dono Root, operação posterior à aprovação técnica completa e supervisão de
integridade. Não executada por esta reserva. Destino novo e isolado em
.tools/playtest_e08/p4_<hash>, preservando o checkout habitual codex/playtest,
as alterações locais, saves pessoais e o pilotoP3 aceito. Sem master/push.

Arquivos próprios novos: tools/prepare_e08_p4_review_profile.gd e .uid, este
contrato/recibo e docs/epics/e08_p4_playtest_guide.md. O helper não altera runtime
ou definições: usa ProfileFacade/PlaytestProfileAdmin/Inventory/ActionBar reais,
recusa userdata fora da pasta explícita do candidato e recusa perfil não vazio.
Não usar Source save pessoal. Três grupos de revisão (3/4/3personagens) respeitam
MAX_CHARACTERS8; nenhuma expansão de slots. Só itens existentes/permitidos e
habilidades legais no modo de teste, sem criar drops novos.

Depois da entrega técnica final, usar o PCK exato validado (hash/bytes iguais),
engine standard verificada e launcher próprio com APPDATA/LOCALAPPDATA isolados
por grupo. Preferir executar o helper externo diretamente com --main-pack no
PCK exato: assim usa as APIs e o nome de aplicativo do próprio candidato, sem
editar a fixture ou reempacotar o jogo. Se esse mecanismo não for suportado,
confirmar primeiro a correspondência de código e userdata com a fixture.
O helper não é um novo consumidor de apresentação.
Aprovação técnica não é aceite humano. Registrar os10personagens preparados,
revisões/diretórios/hashes, smoke de abertura e roteiro. Não remover ou alterar
perfis não vazios em repetição; novo diretório preserva progresso anterior.

O CLI tools/workflow/workflow.py e WORKFLOW_TOOLING.md não existem nesta worktree;
não copiar tooling de outro checkout. Usar a preparação já existente de pacote
isolado E08 e declarar que isso não aplicou/rebaseou o checkout fixo habitual.

## Execução em P7-C3 (9/11/2026)

Esta preparação foi integrada ao candidato E08 da P7, não a um candidato só-P4: destino
`.tools/playtest_e08/e08_<hash>` (a guarda do helper aceita `p4_` e `e08_`), personagens
nomeados "E08 <classe>", script `tools/e08_p7_package.ps1 -Stage Profiles`. Resultado,
hashes e diretórios em [e08_p7_release.md](e08_p7_release.md); roteiro atualizado para
P4–P6 em [e08_p7_playtest_guide.md](e08_p7_playtest_guide.md).

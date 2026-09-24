# Gate Astra — E05-S1B

Entrega 04922e3 sobre 1a3717b: APROVADA no escopo transacional.
Revisados CharacterProgression, ProfileFacade, ProfileCatalog e testes,
incluindo o writer/resolve_commit reutilizado. Candidata isolada, reembolso
somente da carteira evolução, manutenção dos direitos da base, ranks gratuitos
derivados e limpeza seletiva dos dois presets respeitam S0/S1A. Revisão obsoleta
impede reaplicação; destino atual é no-op. start_run bloqueia conteúdo
indisponível sem apagar identidade ou impedir carregamento do perfil.

Validação independente: tools/verify.ps1 completo em Godot 4.7.2, importação,
67 suítes / 3076 checks e smoke aprovados; 50 checks na suíte S1B.
git diff --check limpo. Nenhum bloqueio identificado. Os kits prontos são
fixtures, não conteúdo de produção. Sem validação visual ou habilitação de
classes evoluídas. Playtest/master não foram atualizados.

## Próximo pacote autorizado: S1C — Terra

Na tarefa E05 existente, implementar apenas o seletor de evolução no menu.
Consumir evolution_options/change_evolution; não duplicar elegibilidade,
carteiras, grants, limpeza de presets ou nomes por mapas locais da UI.
Mostrar origem, evolução atual, níveis/requisitos e disponibilidade de conteúdo.
As 12 evoluções permanecem indisponíveis em produção; nenhuma fixture deve
vazar para o catálogo real. Estado atual não oculta motivos de bloqueio.

Confirmação explícita antes de escolher/trocar, informando perda de compras
exclusivas/reembolso e possível limpeza de slots; cancelamento não escreve.
Após sucesso, atualizar resumo, progressão e ambos os presets; apresentar os
slots efetivamente limpos a partir da resposta. Não equipar a entrada gratuita
automaticamente. Usar personagem em foco e preservar seleção de alts.

Falha definida: conservar intenção, request_id e expected_revision para retry.
Revisão obsoleta/resultado incerto: atualizar estado pela fachada, não repetir
uma troca automaticamente com revisão nova. Tratar run ativa, readonly,
conteúdo indisponível e perfil/personagem ausente em pt-BR. O início de run
bloqueado por content_unavailable precisa de mensagem compreensível.

Arquivos: character_menu e cenas/helpers de UI estritamente necessários,
testes de UI/integração isolados, verify.ps1 e handoff. Sem alterar contratos
core, schema, catálogo, skills ou runtime de combate. Se uma lacuna de API
bloquear o pacote, entregar reprodução para revisão, sem contornar regra na UI.

Validar renderização sem escrita, confirmação/cancelamento, troca com fixtures
isoladas, atualização dos dois presets, falha/retry, personagem em foco,
readonly/run ativa e estados de produção indisponíveis. Executar verify.ps1;
registrar evidência visual quando disponível e declarar limites honestamente.
Entrega: commit e docs/E05_S1C_HANDOFF.md; parar no gate do primeiro padrão UI.
Não iniciar kits/dados de produção nem atualizar playtest/master.

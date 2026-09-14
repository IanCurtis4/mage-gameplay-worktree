# Revisão E01 — personagens persistentes e alts

## E01.1 — separação de estado e IDs estáveis

Data: 13/09/2026. Estado: **ACEITE TÉCNICO ASTRA**.

- Base contratual: `247e304` (encerramento aceito de E00 sobre `73f7a03`).
- Implementação inicial: `82dd8d1`.
- Candidato aprovado: `02262cbe88dc8ef0c162c32c2b9d3c960296ea54`.
- Branch isolada: `codex/e01-persistent-characters`.

O passo introduz `ProfileState`, `CharacterState`, `BuildSnapshot` e o registro
`IdentityIds`. `RunState` recebe uma cópia profunda da build e conserva apenas
estado da run. O caminho legado do piloto continua aceitando troca de classe; uma
run originada de personagem persistente rejeita essa troca sem mutar IDs, build,
skills ou estado transitório.

A primeira revisão encontrou e devolveu dois defeitos: troca de classe permitida
numa run persistente e aceitação do par evolução/base vazio. O commit aprovado
corrige ambos. Regressões cobrem as 12 origens de evolução, pares inválidos,
isolamento entre alts, cópias de presets/equipamentos e separação da run.

### Evidência

Astra executou independentemente `tools/verify.ps1` com Godot 4.7.2 na worktree
do E01: Foundation 20, Animações 30, Marco 1 63, Perseguição 41, UI 47,
Arena 32, Layout 28, Mago 52 e Persistência 33: **346 verificações PASS**.
Importação e smoke concluídos com exit 0; `git diff --check` sem problemas e
worktree limpa no candidato revisado.

### Limites e próximo gate

Este aceite encerra somente E01.1. Escrita atômica, backup, migração e recuperação
pertencem a E01.2; fachada, criação/seleção e XP idempotente pertencem a E01.3.
Nenhum desses passos foi iniciado. `codex/playtest` e `master` não foram alteradas.

## E01.2 — persistência versionada e recuperação

Data: 14/09/2026. Estado: **ACEITE TÉCNICO ASTRA**.

- Implementação inicial: `5717176`.
- Correção de invariantes duráveis: `efb2b48`.
- Candidato aprovado: `deaf37144e7ef78e64b064878e2221ce0e85e6c4`.

O passo introduz o codec do schema 2, um escritor transacional por perfil,
substituição por arquivo pendente validado, backup conservador, recuperação e
migração reconhecida do schema 1. Falhas, revisões obsoletas, regressão dos
contadores monotônicos e artefatos isolados bloqueiam o commit antes de publicar
estado em memória. Schema futuro e catálogo incompatível permanecem intactos e
somente leitura, sem recuo silencioso ao backup.

O catálogo mínimo de persistência passou a validar origem, slot, categoria,
carteira e tetos de rank do contrato E00: rank efetivo máximo 5 para ativas e 3
para passivas. Skills da carteira de evolução declaram `required_evolution_id`;
compras e presets só aceitam a evolução exata, inclusive quando o rank gratuito
já tornaria a skill utilizável. Esta metadata é uma fronteira de validação do
save, não a árvore completa de requisitos que pertence a E03.

### Evidência

Sol executou `tools/verify.ps1` com Godot 4.7.2: **435 verificações PASS**,
incluindo 89 de E01.2, importação/editor e smoke com exit 0 e sem `ERROR`.
Uma reprodução Luna separada aprovou 33 cenários de contadores, artefatos,
schema futuro, catálogo/equipamentos e preservação byte a byte. Astra revisou o
delta e repetiu a suíte completa com os mesmos 435 checks; sondas adicionais
confirmaram rejeição de catálogo superdimensionado e de skill gratuita na
ausência ou na evolução errada. `git diff --check` e a worktree ficaram limpos.

### Limites e próximo gate

Este aceite encerra somente E01.2 e libera E01.3-A: fachada transacional mínima
para criar e selecionar personagem. `start_run` e recompensa idempotente ficam
em E01.3-B após novo gate. Não há aceite de produto nem atualização de
`codex/playtest` ou `master`.

## E01.3-A — candidato da fachada criar/selecionar

Data: 14/09/2026. Estado: **ACEITE TÉCNICO ASTRA**.

- Implementação inicial: `f6d5001`.
- Candidato aprovado: `ec865acf6068324ed92d30b70608cf83f6729736`.

`ProfileFacade` é a dona da cópia publicada do perfil e recebe um único
`ProfileStore`; nenhuma operação instancia um escritor alternativo. As APIs
`create_character(request_id, expected_revision, display_name, base_class_id)` e
`select_character(request_id, expected_revision, character_id)` exigem correlação
e revisão originais. Repetição após commit encontra `stale_revision`, sem reservar
novo ID ou publicar outra seleção.

A criação ocorre sobre cópia: valida limite de oito e base disponível, deriva do
catálogo os dois ranks ativos e o passivo gratuitos, desbloqueia/equipa starters,
reserva o contador monotônico e seleciona o novo alt no mesmo commit. Catálogos
posteriores podem marcar no máximo um equipamento `starter` por origem/slot; na
ausência de conteúdo de equipamentos, o loadout vazio continua estruturalmente
válido. A base só fica disponível quando o catálogo possui exatamente o kit inicial
E00 (duas ativas e uma passiva gratuitas da carteira base), portanto Arqueiro
permanece bloqueado até seu catálogo ser implementado.

Se o writer retorna falha depois de um resultado potencialmente durável, a fachada
relê o perfil. Ela confirma sucesso apenas se o estado inteiro coincide com o
candidato esperado na revisão seguinte; estado antigo confirma falha sem publicação
e qualquer terceiro resultado gera `result_uncertain`, mantendo a fachada somente
leitura até `open_profile()` reconciliar explicitamente o disco. Criação e seleção
também bloqueiam enquanto existir uma sessão de run durável.

Falha ao reabrir ou ao atualizar o snapshot depois de `stale_revision` também
herda o `error_code` e o estado somente leitura do store. O snapshot publicado
anterior pode continuar visível, mas nenhum comando — nem uma seleção no-op — é
certificado até uma reabertura explícita bem-sucedida.

Ficam fora deste candidato: menu E02, aprendizado/progressão E03, escolha de
`legacy_loadout`, `start_run` e concessão idempotente de recompensa E01.3-B.

### Evidência e próximo gate

Sol executou a suíte oficial completa com **482 verificações PASS**, incluindo
47 da fachada. Astra revisou o delta, reproduziu a tentativa de seleção no-op
após schema futuro e confirmou sua rejeição; repetiu os 482 checks com
importação/editor e smoke sem `ERROR`. O aceite libera E01.3-B na mesma fachada:
`start_run`, recompensa sequencial/idempotente, `end_run` e fechamento durável de
sessão abandonada. Ainda não é aceite integrado do épico ou do produto.

## E01.3-B — candidato de sessão e recompensas duráveis

Data: 14/09/2026. Estado: **EM IMPLEMENTAÇÃO / AGUARDANDO REVISÃO ASTRA**.

`start_run(request_id, expected_revision)` valida personagem selecionado, preset
e ausência de transação pendente. O mesmo commit reserva o `run_id`, incrementa o
contador monotônico e `runs_started`, e abre o cursor durável em zero. Somente
depois desse commit a fachada constrói e entrega um `RunState` a partir de
`BuildSnapshot` profundo, com níveis derivados e ranks efetivos centralizados.
Perfil estruturalmente válido mas sem nenhuma ativa no preset selecionado não está
pronto para run.

`grant_reward(request_id, expected_revision, run_id, sequence, reward_id)` recebe
apenas um ID. `ProfileRewardResolver` é uma tabela local copiada e imutável que
resolve XP, equipamentos e incrementos permitidos de estatísticas; a UI nunca
fornece esses valores. Run divergente, sequência menor que 1 ou salto rejeitam;
`sequence <= cursor` é no-op `already_applied`; somente `cursor+1` aplica XP
saturado nos tetos E00, novos itens, estatísticas e cursor no mesmo commit ao
personagem fixado pela sessão. Item ausente do catálogo bloqueia antes da mutação.
Resolver estruturalmente inválido ou com item ausente do catálogo bloqueia o próprio
`start_run` antes de reservar contador/sessão.

`end_run` aceita apenas `completed`, `death` ou `abandoned`, fecha a sessão e grava
o contador correspondente uma vez. Sessão fechada rejeita replay. Ao reabrir um
perfil com sessão salva, `open_profile()` primeiro grava `reward_session=null`,
preserva recompensas confirmadas e avisos de recovery, mas não retoma combate nem
inventa conclusão/morte/recompensa final. Falha nesse fechamento mantém a fachada
somente leitura e impede nova run. Todas as operações reutilizam a reconciliação
de resultados incertos aprovada em E01.3-A.

O resolver padrão ainda não possui conteúdo; encontros e pools reais pertencem a
E07/E06. Esta fachada não adiciona menu E02, compra/progressão E03, combate novo,
arte ou retomada de combate após fechar o aplicativo.

# E07-F3 — captura e restauração em memória

20/10/2026. **EM_EXECUÇÃO**, Sol/Alto, chat `01a150a6-8993-7c72-946a-2a35ca56f4d5`.
Aval humano: “F2 terminou. Podemos começar com F3.”

Base executável `6a64d7ba3846a19a86a63fa25b66fb51e5d6ade7`, fechamento de F2;
runtime F2 `eeb7cab048b9b58577919b9a122ad8fcd1217a25` e F1
`5b54cf4820502b50cc4d9159a01f866ad687b9ad` são ancestrais.
Branch `codex/e07-f3`, checkout exclusivo
`C:/Users/João Pedro/.codex/worktrees/e07-f3/RagRPG`.
A composição sequencial contém ambos os produtores entregues/validados;
não afirma integração operacional ou aprovação de produto/playtest.
CLI de workflow e WORKFLOW_TOOLING ausentes: diagnóstico por Git/contratos,
como registrado em F2. O checkout habitual e o save pessoal são preservados.

## Decisão humana D02 consumida por F3

Resposta “Aprovar congelamento local proposto” à pergunta: “Para F3, aprova que
estágios sem jogador congelem suas ações e efeitos locais, enquanto o relógio
global da expedição ativa continua e registra reposições pendentes? Ao suspender
a expedição inteira, todos os relógios congelam.”

Essa regra complementa o delta de locks D02 aprovado em F2. Quest antecipada
continua pendente para F5; não é necessária à captura passiva F3. F3 não cria
ondas, lifecycle de produção, regras de revive ou consumidores de F4+.

## Dono exclusivo e transferência antes da edição

F1/F2 entregues: a propriedade dos arquivos abaixo passa sequencialmente a F3
somente no escopo de captura/restauração; nenhum escritor paralelo.

- Novos `scripts/core/expedition/snapshot/*.gd`, manifesto versionado do diretório
  e respectivos `.uid`; `tests/e07_f3_*.gd`, `.uid` e `tests/fixtures/e07/f3/**`.
- Existentes `scripts/main.gd`, `scripts/core/run_state.gd`,
  `scripts/core/run_reward_service.gd`, `scripts/core/run_build_service.gd` e
  `scripts/core/expedition/spatial/flat_world_geometry.gd`: somente construção
  passiva e integração da barreira. Estados de kits/atores/world são consumidos
  pelos adaptadores; qualquer edição adicional requer adendo nominal prévio.
- `tools/verify.ps1`: transferência exclusiva de F2 para registrar seleção F3.
- Este despacho, `f3_api.md`, `delivery/f3.md` e seção F3 de `docs/epics/e07.md`.

ProfileStore/Codec/Facade e contratos arquiteturais não são editados. Captura
não cria writer, não altera schema8, não aplica migração pessoal. Sem push,
playtest ou merge master. F4 somente após entrega/validação e nova liberação.

Transferência complementar antes da edição: `scripts/world/spiritualist_halo_underlay.gd`
fica exclusivo de F3 para tornar a ligação visual em `_ready` idempotente;
o grafo restaurado já contém o sinal, sem reaplicar efeitos. Nenhuma regra de kit.

Correção no controlador já transferido: a fila de summon passa a registrar a
intenção antes do callback diferido e consumi-la uma vez; a barreira congela
input/focus-out e mantém a intenção durante pausa. Evita perder ou repetir um
summon no corte, sem ampliar o contrato finito E06.

## Aceite e evidência exigida

SnapshotRegistry capture/validate/restore, StableEntityRegistry e barreira de
tick; manifesto explícito por runtime_kind/revision; referências e claims em
duas passagens, sem configure/reset/start/callbacks de gameplay. Tipos ou
referências desconhecidos falham. Preservar RNG, ofertas, augments, recursos,
ações em voo e causalidade das dez identidades. Comparar próximos resultados
reais com execução contínua em deltas distintos. Registrar tamanho/tempo e
cobertura exata; lacuna de kind bloqueia F4. Luna supervisiona testes e hashes;
Sol corrige e consolida contrato/limites. Não prometer save durável.

# E04 — execução em pacotes curtos

Autorizado pelo usuário em 21/09/2026 após aceitar E03 no candidato `495ee16`.
O candidato foi integrado em master. E04 mantém a tarefa existente e usa uma
worktree isolada; o diretório do Godot permanece em codex/playtest.

## Regra de execução

Uma mensagem libera um único pacote. Entregar e parar; não iniciar o seguinte
nem aguardar em loop. Não há meta garantida de tokens: limitar escopo, contexto
e saída reduz consumo, mas não permite prever a porcentagem de uso necessária.
Nesta rodada está liberado somente S0-A. Os demais são sequência planejada.

- Ler apenas instruções obrigatórias, checkpoint e arquivos relevantes; não
  reanalisar todo o épico a cada turno.
- Um comportamento verificável por pacote, normalmente até três arquivos de
  implementação mais testes e checkpoint. Se exigir mais, propor recorte antes.
- Um commit focado; resposta com hash, resultado, teste e próximo pacote, até
  seis linhas. Checkpoint curto é a fonte de retomada após interrupção.
- Teste dirigido por pacote; verify completo quando tocar integração ou quando
  exigido por AGENTS. Não repetir suíte sem alteração que justifique.
- Sol: contratos, matemática e mecânicas compartilhadas. Terra: consumidores,
  UI e composição sobre contratos aprovados. Luna: tabelas/textos/casos definidos.
  Sem cadeia obrigatória entre modelos nem subagentes nesta primeira rodada.
- Astra revisa contratos críticos e fechamento; correções rotineiras não pedem
  aceite do usuário. Playtest por subépico de classe e no fechamento E04.

## Fundação compartilhada

| Pacote | Entrega | Dono |
|---|---|---|
| S0-A | Mapa mínimo de lacunas e contrato de rank/dispatch, sem código; especificar próximo recorte e casos de aceite | Sol |
| S0-B | Definição/consulta de rank validada, sem migrar todos os consumidores | Sol |
| S0-C | Uma skill piloto consumindo rank, custo/tempo/poder; regressão da emissão | Sol |
| S0-D | Restantes das skills piloto sobre o padrão aprovado, por classe | Terra |
| S0-E | Texto/fixtures dos dados já aprovados; não inventar números | Luna |
| S0-F | Conferência integrada, snapshot e rank efetivo; gate técnico | Sol/Astra |

S0-A deve conferir E00 e contratos de classe. Números ausentes são decisões de
design, não autorização para Luna inventá-los. Evitar abstração universal e
evitar migrar todo o controller no primeiro pacote.

## Classes, uma de cada vez

Ordem: Espadachim → Mago → Arqueiro. Para cada classe, abrir pacotes separados:

1. Especificação curta de kit e ranks faltantes; somente decisões ainda abertas.
2. Uma primitiva nova por vez com Sol (ex.: guarda; parede sólida; armadilha).
3. Uma skill usando a primitiva, com teste de sucesso/cancelamento/limites.
4. Variantes com Terra e dados aprovados com Luna, sem alterar contratos.
5. Passivas e duas builds; teste contra melee/ranged sem augments.
6. Integração, revisão Astra e playtest do usuário antes do próximo subépico.

E04 mantém o escopo das três bases e fundamentos dos ramos, conforme handoff.
Evoluções E05, demais classes, arte final e campanha E07 não são liberadas aqui.

## Checkpoint

- E03: aceito pelo usuário; master em `495ee16`.
- E04-S0-A: liberado para execução na tarefa E04 existente.
- Demais pacotes: planejados, sem execução nesta rodada.

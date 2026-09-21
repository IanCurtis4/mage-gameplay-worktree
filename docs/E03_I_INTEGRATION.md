# E03-I — Fechamento integrado de stats e progressão

Estado: **candidato integrado preparado; aguardando revisão técnica Astra e playtest do usuário**.

Base revisada: `647665b`. Fechamento composto pelos commits:

- `ba9713f` — conecta XP persistente aos dois encontros do piloto;
- `8153ac4` — mantém a lista de personagens visível no menu rolável.

Este handoff fecha somente E03. Não libera E04/E05/E07, não atualiza
`codex/playtest` ou `master` e não faz push/rebase.

## Fluxo entregue

O menu normal agora compõe `ProfileFacade` com uma tabela local imutável para os
dois encontros já existentes. Ao tocar no cristal depois de eliminar todos os
inimigos, `RunController` confirma primeiro a transação persistente e só depois
consome o cristal e libera a escolha de augment:

| Evento atual do piloto | XP base | XP job |
|---|---:|---:|
| `encounter_one` | 100 | 80 |
| `encounter_two` | 150 | 100 |

Esses números reutilizam os casos já exercitados pelo contrato E01 e são valores
de integração do piloto E03. A composição/tabela final de encontros, drops e XP
continua pertencendo a E07 e pode substituir o resolver sem mudar a transação.

O `request_id` de cada coleta é estável por run/encontro e a sequência é a do
encontro. Falha definida de gravação mantém o cristal e o cursor sem alteração,
bloqueia o avanço e informa **E para tentar novamente** ou **Personagem para
sair**. Um sucesso confirmado — inclusive recuperação idempotente — libera o
augment uma única vez.

XP e pontos já aparecem no perfil durante a run, mas o `BuildSnapshot` iniciado
continua por valor. Assim, subir de nível na arena não cura nem muda dano, HIT,
HP/SP ou cooldowns daquela run. Investimentos no menu entram somente no próximo
snapshot.

## Integração numérica e persistência

`tests/e03_integrated_progression_flow_test.gd` percorre as fronteiras públicas e
o controller real, sem repetir a matriz de regras puras de E03-L2:

1. menu cria/seleciona personagem e inicia a arena persistente;
2. duas coletas reais gravam 250 XP base e 180 XP job;
3. os totais derivam base level 3, job level 3, seis pontos de atributo e dois
   pontos de skill base;
4. o snapshot/ator da run original permanece numericamente inalterado;
5. após encerrar, o menu investe um ponto de FOR e compra `slash` rank 2;
6. nova run concorda entre preview, snapshot, ator, HUD e `DamageRequest`;
7. novo carregamento conserva XP, alocação e rank;
8. falha de commit e retry comprovam que o pickup não é consumido nem duplicado.

Caps, carteiras separadas, JL20 sem evolução, ranks gratuitos, falta de pontos,
pré-requisitos, respec e reload continuam cobertos pelas suítes E03-B/C2. O fluxo
novo apenas compõe essas autoridades.

## Conferência visual

Renderização determinística foi inspecionada em 1280×720 e em altura reduzida
(viewport efetivo 995×560 pelo modo de stretch). O menu conserva:

- personagem selecionado legível em uma lista com altura mínima;
- XP, níveis, carteiras e atributos dentro do scroll vertical;
- ações de progressão alcançáveis por rolagem;
- botão **Iniciar run com este personagem** fixo e visível fora do scroll.

A inspeção identificou e corrigiu a lista do roster que antes colapsava dentro do
container rolável. As capturas locais ficam somente sob `.godot/verification` e
não integram o Git.

## Roteiro reproduzível de playtest

1. Abra o projeto no Godot 4.7.2 e execute a cena principal.
2. Crie um Espadachim ou Mago, selecione-o e clique em **Iniciar run com este
   personagem**.
3. Elimine todos os inimigos do primeiro encontro e toque no cristal dourado.
   A mensagem deve informar `+100 base · +80 job`. É assim que se obtêm os
   primeiros três pontos de atributo e um ponto de skill no jogo.
4. Pressione **E**, escolha um augment e inicie o segundo encontro.
5. Elimine todos os inimigos e toque no segundo cristal. A mensagem deve informar
   `+150 base · +100 job`.
6. Escolha o augment final e volte ao menu com **R**. Confira 250 XP base, base
   level 3, 180 XP job, job level 3, `Atributos: 6/6 livres` e
   `Skills base: 2/2 livres`.
7. Invista um ponto em um atributo. Em Espadachim, compre o próximo rank de
   **Corte**: o rank gratuito inicial é 1, então a compra mostra rank 2.
8. Inicie outra run. Confira no resumo/HUD o novo snapshot; a primeira run não
   deve ter mudado retroativamente.
9. Volte ao menu, feche e reabra o jogo. XP, investimento e rank devem permanecer.

Para exercitar manualmente falha de disco é necessário um store instrumentado;
o caso automatizado confirma que o cristal permanece e que o retry aplica o XP
uma vez.

## Validação

Com Godot 4.7.2 standard:

```powershell
./tools/verify.ps1 -GodotPath `
  'C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/review-engine/Godot.exe'
python tools/verify_e00_contract.py
```

Resultado final: importação do editor, todas as 21 suítes e smoke da cena principal
passaram, totalizando **992 checks**. A suíte integrada nova acrescenta 17 checks
aos 975 já aprovados no C2. O verificador numérico independente E00 também passou
**4.630 checks**.

## Limites concretos

- E07 continua dono dos encontros finais, recompensas de eliminação, loot,
  balanceamento e prêmio de vitória; E03 liga somente os dois cristais do piloto.
- Comprar rank já persiste e entra no `RunState.skill_levels`, mas tabelas de
  poder/custo/efeito por rank ainda não existem; isso permanece E04. Portanto,
  **comprar rank não promete hoje uma alteração de efeito de gameplay**.
- Escolher evolução e ranks 21–40 permanecem E05.
- A inspeção visual automatizada não substitui sensação de controle e legibilidade
  em playtest humano.
- Nenhum schema, fórmula de `StatCalculator`, asset, plugin ou dependência externa
  foi alterado.

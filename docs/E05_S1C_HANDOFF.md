# E05-S1C — seletor de evolução no menu

Estado: **implementado; aguarda gate de Astra do primeiro padrão de UI**.

Base: `a98d72a` (gate S1B) na branch `codex/e05-evolutions`. Autoridade:
[gate E05-S1B](REVIEW_E05_S1B_ASTRA.md) e
[handoff transacional S1B](E05_S1B_HANDOFF.md).

## Resultado

O menu de personagens agora contém o painel **Evolução** para o personagem em
foco. Ele consome exclusivamente:

```gdscript
facade.evolution_options(character_id)
facade.change_evolution(request_id, expected_revision, character_id, evolution_id)
```

Não há mapa local de identidades, nomes, afinidades, níveis, carteiras, ranks
ou legalidade de slots. A tela apenas apresenta as opções devolvidas pela
fachada: origem, evolução atual, nível base/job, ramo, requisitos, prontidão do
conteúdo e todos os motivos de bloqueio, inclusive quando a identidade atual
está indisponível.

O botão de uma opção selecionável abre uma confirmação explícita. Ela avisa
sobre reembolso de compras exclusivas e possível limpeza de slots; cancelar
somente fecha a confirmação. Após a confirmação bem-sucedida, o menu se
recarrega do perfil e mostra o reembolso e a contagem de slots esvaziados
informados pela resposta. A entrada gratuita não é equipada pela UI.

## Transação e estados de interface

- A confirmação captura a revisão observada ao abrir. Se houver mudança externa,
  a fachada devolve `stale_revision`; a intenção é descartada e o menu recarrega,
  sem repetir a evolução com uma revisão nova.
- Em `save_failed`, intenção, `request_id` e revisão são preservados para que a
  confirmação seguinte repita exatamente a operação original.
- Cancelar, trocar de alt ou abrir uma nova confirmação descarta o retry ligado
  à intenção anterior. Assim uma confirmação nova sempre captura seu próprio
  contexto e não reutiliza uma revisão cancelada.
- Em sucesso, erro obsoleto ou resultado incerto, o menu não faz retry
  automático. Ele atualiza o estado pela fachada.
- O personagem em foco é sempre o alvo, sem trocar `selected_character_id`.
  Trocar de alt cancela uma confirmação pendente para não aplicar a intenção em
  outro personagem.
- Run ativa e perfil somente leitura deixam as ações indisponíveis e mostram a
  razão em pt-BR. `content_unavailable` de `start_run` agora tem mensagem
  compreensível no menu.

## Arquivos

- `scripts/ui/character_menu.gd`: painel, apresentação de opções, confirmação,
  retry e textos de estado em pt-BR;
- `tests/e05_evolution_menu_integration_test.gd`: integração isolada do menu;
- `tools/verify.ps1`: registra a suíte S1C.

Nenhum arquivo de `scripts/core/`, schema, codec, catálogo de produção, skill,
ator, controlador ou combate foi alterado. As doze evoluções de produção
continuam `content_ready=false`; Defendente/Berserker aparecem somente como
fixture isolada de teste.

## Evidências

A suíte S1C executa 23 checks headless em Godot 4.7.2 standard e cobre:

- evolução atual de produção indisponível, sem escrita, e mensagem do bloqueio
  de run;
- renderização do painel e seus controles dentro do scroll;
- confirmação sem escrita, cancelamento e primeira escolha;
- rank gratuito não equipado automaticamente;
- revisão obsoleta sem retry automático;
- troca Defendente→Berserker, limpeza dos dois presets e feedback retornado pela
  transação;
- falha definida com retry do mesmo `request_id`/revisão;
- falha, cancelamento, avanço de revisão e nova confirmação; inclusive após
  trocar de alt e retornar ao personagem em foco;
- personagem em foco distinto da seleção persistida;
- run ativa e perfil somente leitura.

Comando final:

```powershell
pwsh -NoProfile -File .\tools\verify.ps1 `
  -GodotPath 'C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.tools\review-engine\Godot.exe'
```

Antes da correção localizada, a verificação integral passou com importação,
**68 suítes / 3.095 checks** e smoke. Para esta rodada autorizada por Astra,
passaram a suíte S1C atualizada (**23 checks**) e a regressão
`e02_character_menu` (**23 checks**). O delta não altera core, catálogo,
persistência nem a cena; a repetição integral fica reservada para o próximo
gate integrado.

## Limites e próximo gate

- Não houve playtest visual interativo; a evidência visual automatizada limita-se
  à construção headless e à verificação do painel/layout no teste de integração.
- O painel não habilita conteúdo nem inventa descrição de kit para as doze
  identidades indisponíveis.
- Não houve atualização de `codex/playtest` ou `master`.

Parar para revisão de Astra. Dados e kits de produção continuam fora do escopo.

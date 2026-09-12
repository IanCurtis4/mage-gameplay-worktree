# Revisão e candidato — UI de batalha

Bloco autorizado em 12/09/2026. Base `e70e4d4`: movimento/arqueiros aceitos pelo
usuário e integrados em master. Nova branch `codex/m1-battle-ui`; implementação e
revisão por Astra. Não foi criada outra tarefa/agente.

## Entrega por etapas

- `e3b686b`: contratos de lançamento, resolução de alvo e geometria, preferências,
  testes iniciais e proposta futura de arte.
- `3d99caf`: integração de input, indicadores de chão, anéis/pulsos, barra de skills,
  controles persistentes, proteção de UI/pausa, layout e testes de eventos.

Padrão explicitamente escolhido pelo usuário: Q/W seleciona, clique esquerdo lança.
Direito/Esc cancela. Há lançamento ao soltar e instantâneo nas configurações.
Cartões da barra sempre permitem seleção por mouse. Smart lock retém o realce sob
pequenos deslocamentos do cursor, dá prioridade ao corpo direto e não troca sozinho
o alvo já perseguido. Skills atuais são direcionais; o resolver é reutilizável por
skills single-target futuras. Não foram criadas skills ou classes novas neste bloco.

## Evidências

`tools/verify.ps1`: 208 verificações (12 fundação, 63 M1, 33 perseguição/movimento,
40 UI/input, 32 fluxo, 28 layout), importação e smoke aprovados.
Testes de UI despacham eventos pelo Viewport: pressionar/soltar, clique, echo,
cancelamento, clique em botão, pausa, confirmação única e foco perdido. Arquivos
temporários de preferências são próprios dos testes. Nenhum teste altera controls.cfg
do usuário. Também são verificados endpoint real do dash, custo revalidado, morte,
alvos inválidos, limites do smart lock e impossibilidade de empilhar menus de pausa.

Capturas renderizadas no Godot, inspecionadas em 1280×720: cone, investida contra
obstáculo e janela de controles. Layout medido em 1280×720 e 1920×1080, incluindo
descrições dos três modos. Evidências ignoradas ficam em
`.tools/battle-ui-worktree/.godot/verification/battle_ui_{cone,dash,settings}.png`.

## Limites e próximo aceite

A geometria usa as coordenadas 2D existentes; não é uma migração para chão 3D e não
altera a interação do corte com obstáculos. Círculos indicam cliques/alvos e chegada
da investida; skills circulares de área ficam para o marco correspondente.
Sensação do input e legibilidade durante combate precisam de playtest do usuário.
Não foi feita medição de FPS por essas verificações.

Arte futura está descrita em `docs/ART_DIRECTION_NEXT.md`, com comparação de
resoluções, proposta inicial 64×64, chão 3D com sprites e pilotos antes de produção
em lote. Nenhum tileset/spritesheet foi produzido nem renderer migrado nesta rodada.

Status: aprovado tecnicamente para preparação de playtest; merge da nova UI em
master aguarda aceite do usuário sobre este candidato.

Na integração, a importação normal do checkout real encontrou a DLL temporária do
GitPlugin bloqueada (o plugin é local e não pertence à entrega). Testes de gameplay
normais passaram. O verificador oferece `-SkipEditorImport`, explícito, para repetir
os testes no projeto já importado depois de validar importação e suíte completa na
worktree limpa. Não ignora erros de testes, não encerra o editor e não remove nem
altera arquivos do plugin. A importação com o plugin local permanece bloqueada;
a importação normal sem plugin e a execução do jogo são verificadas separadamente.

# E04-AR — fechamento integrado do Arqueiro base

Base: `39bf0d9`. Escopo: compor e verificar o kit existente; nenhuma fórmula,
skill, schema de save ou contrato de input foi alterado neste pacote.

## Cenário automatizado

`tests/e04_archer_integrated_closure_test.gd` cria um Arqueiro pelo perfil real,
injeta XP de job válido como fixture, compra 19 ranks por transações da fachada,
salva dois presets e recarrega o perfil antes das runs:

| Preset | Ativas | Passivas |
|---|---|---|
| Arco | Disparo Duplo R3, Flecha Perfurante R1, Chuva de Flechas R2, Mira Estendida R1, Flecha Entorpecente R1 | Precisão R3, Cadência R1 |
| Armadilhas | Laço R1, Explosiva R2, Abrigo R1, Flecha Entorpecente R1, Disparo Duplo R3 | Técnica de Armadilhas R3, Precisão R3 |

Para cada preset, a suíte passa pelo menu de personagem, inicia a arena persistente,
compara slots/ranks e HIT do preview com o snapshot da run, verifica ausência de
augment, recebe ataque melee e projétil ranged, executa a composição principal,
encerra um encontro com inimigos melee/ranged, coleta XP e fecha a sessão sem
escolher augment. Os testes de pacote permanecem a autoridade para impacto,
cancelamento, limites e cada rank individual.

## Evidência e gates

- Import headless do Godot 4.7.2: aprovado no ciclo deste pacote.
- `tools/verify.ps1`: aprovado após a última alteração do cenário, incluindo
  `E04 Arqueiro integrado: PASS (49 checks)`. Import headless foi aprovado no
  mesmo ciclo; a repetição final da suíte reutilizou esse import.
- Revisão independente de Astra: pendente. Inspecionar sobretudo snapshot
  persistente → ranks/slots, efeito das passivas na build, aquisição de alvo sob
  Abrigo e limpeza das armadilhas ao concluir encontro/run.
- Playtest do usuário em `codex/playtest`: pendente; apenas após o gate técnico.
  Merge em `master` requer aceite explícito do candidato testado.

## Roteiro de playtest

No diretório habitual do Godot, abrir o Arqueiro, investir em ranks e montar os
dois presets acima. Iniciar uma run com cada um, conferir as cinco ativas e duas
passivas, experimentar autoataque e habilidades contra perseguidores e arqueiros
inimigos, vencer um encontro e coletar a recompensa sem depender de augment.
Conferir cooldown/SP, bloqueio por obstáculo, raiz/slow, ocultação/revelação e
se armadilhas antigas desaparecem ao fim do encontro. Fechar a run, reabrir o
perfil e conferir os dois presets e ranks.

## Limites da evidência

A suíte usa XP de job máximo válido como fixture para evitar 19 encontros de
progressão e aplica dano de finalização controlado após verificar as emissões
e os ataques dos dois tipos de inimigo. Ela não mede diversão, legibilidade
visual, FPS nem substitui a revisão independente ou o playtest humano.

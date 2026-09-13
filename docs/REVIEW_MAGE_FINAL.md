# Revisão técnica — Mago, animações e planejamento de classes

13/09/2026. Astra aprova tecnicamente a composição de gameplay Sol `6758a00`
com arte e integração Astra rebaseada (`c1b6355` antes deste relatório).
Base aceita de produto: `d76e7d3`. Backup da composição anterior ao rebase:
`codex/mage-animation-before-final-rebase`. Sem push e sem merge deste bloco em master.

## Evidências

Godot 4.7.2 standard, Compatibility. `tools/verify.ps1` completo na composição:
20 foundation + 30 animações + 63 Marco 1 + 41 perseguição/inércia + 47 UI de batalha
+ 32 fluxo + 28 layout + 52 gameplay Mago = **313 verificações passando**.
Import do editor e smoke também passaram, sem SCRIPT ERROR/ERROR. `git diff --check`
sem problemas. Captura com renderer real em 1280×720 revisada em
`docs/art/mage_runtime.png`; não representa medição de FPS ou aceite de gameplay.

Revisão manual de contratos: crítico garantido verifica queimadura no impacto;
lanças possuem contagens/níveis/augments próprios; custo é único por lançamento;
DEX aplica-se ao cast, recarga usa catálogo; menus/movimento/morte interrompem;
alvo liberado é resolvido por ID antes do commit. Pausa congela status/animação.
Projéteis verificam primeiro contato e origem dentro do alvo; parede testa
travessia entre frames. Eliminação simultânea gera uma recompensa e nenhuma
animação adia retirada do ator. Seleção é limpa após teleporte. Menus não empilham
classe sobre controles ou escolha de augment.

Os dois conflitos do rebase foram resolvidos preservando pausa no CombatActor e
travessia contínua da parede junto do novo desenho de chamas. A suíte acima foi
executada depois dessas resoluções, não apenas nas branches separadas.

## Entrega e limites

Atualizar codex/playtest por fast-forward e repetir verify no diretório habitual.
Preservar project.godot local com GitPlugin, addons, build e export_presets.cfg.
Usuário abre F5 e escolhe Mago pelo botão Classe; roteiro em PLAYTEST_MAGE_ANIMATION.md.
Master continua em d76e7d3 aguardando aceite deste candidato pelo usuário.

Integração concluída: candidato de código `a715f05` aplicado ao diretório habitual.
Verify completo repetido nesse diretório: as mesmas 313 verificações, import e
smoke passaram. Arquivos locais do usuário preservados; alterações de import
sem diferença de conteúdo foram normalizadas. Este adendo altera só documentação.

Animações são primeira passagem de quatro orientações, com espelhamento lateral,
não oito direções únicas. VFX ainda geométricos. Aprendizado de skills, distribuição
de atributos, revisão integral de fórmulas RO e demais partes do marco 2 não foram
implementados neste bloco. O roster de oito bases, 16 evoluções e 28 híbridas está
documentado como brainstorming, com nomes/skills propostos e decisões pendentes.

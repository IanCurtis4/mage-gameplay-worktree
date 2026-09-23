# E04-MG4 — ajuste visual do Impacto das Almas

Base: `9b04978` (asset provisório aprovado). Escopo: apenas integrar
`assets/art/vfx/soul_impact_orb.png` à sequência existente. Não inicia MGI.

O bitmap RGBA de execução, 64×64, é desenhado no centro visual do alvo com
filtro nearest e prioridade acima do ator. Cada um dos três impactos reinicia
um pulso curto de expansão e opacidade; a esfera dissipa após o último. Os
anéis anteriores agora são apenas apoio visual. Não há trajeto de projétil.
Cadência de 0,12 s, dano capturado/dividido, alvo, pausas e limpeza continuam
sob o contrato anterior de `SoulImpactSequence`.

`tests/e04_mage_soul_impact_rank_integration_test.gd` acrescenta verificações
do bitmap, filtro, ordem de desenho e avanço visual sem dano adicional. O
`tools/verify.ps1` completo passou no Godot 4.7.2: MG4 com 64 checks, demais
regressões e smoke headless. Inspeção do asset confirmou transparência e
silhueta; tentativa de captura do efeito por `SubViewport` headless não gerou
frame, então a legibilidade sobre o ator ainda requer playtest visual.

Não atualizar `codex/playtest` nem `master` neste ajuste. O fechamento MGI
permanece dependente de comando separado do usuário.

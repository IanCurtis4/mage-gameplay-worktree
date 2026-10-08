# Caçadora H6 — provas nativas controladas

08/10/2026. Godot4.7.2standard Compatibility, NVIDIA GTX1080. Implementador Sol.
Essas capturas não são revisão independente Astra nem aceite do usuário.

Reprodução segura: Godot --path . res://scenes/diagnostics/hunter_h6_probe.tscn
--resolution 1280x720. A cena posicional é a entrada principal explícita.
Não usar --script/SceneTree sobre CharacterMenu. Não abre ProfileStore/Facade;
controles usam fixture res://.godot/verification/hunter_h6_probe_controls.cfg.

Probe final: PASS282 checks,33 PNGs. 00_atlas_native.png mostra32 células,
espelhamento, pés, nearest, frente/costas/ação/hurt/morte nos dois pisos,
mais os oito SVGs originais. Fonte/raster distintos do Arqueiro e Sentinela.
Fonte hunter_source.png SHA256:
4b7ad5c72cb553aba872c5d8c77ab1dfc0d35c73bb8a3e5f5cba5a9b5e2521f6.
Atlas hunter.png SHA256:
b9130a8b3768443124140190eb716a14a6bb271347631fe6a02458e939e42176.
Prompt final/pipeline em assets/art/animation_sources/hunter_prompts.md.

Outras32 capturas: Preparadora/Emboscadora × claro/escuro × oito fases:
01silhueta/solo+boss,02preparando,03armado,04Marca/abertura no boss,
05Piche/grupo,06consumo/impacto/Passo,07Cobertura,08limpeza terminal.
Compras reais em memória pela progressão:19base/20evolução, sem save ou grants
extras. Emboscadora deliberadamente não compra Espinhos. Congelante/Piche
usam eventos pagos reais, tiro/projétil/resolver reivindicam a abertura;
limpeza usa _show_result, não apenas um clear cosmético do observador.

Pisos sólidos são palco de contraste; obstáculos de arte retirados para
corresponder à navegação vazia da fixture. Câmera fixa e HUD oculto somente
no probe. Essas capturas não certificam layout do HUD nem oclusão em batalha.
IA/processos/input congelados, SP/CD preparados entre snapshots, deslocamento
de pés dirigido após Passo real para tornar o rastro visível. Relógios de VFX
avançados manualmente; flinches/status base podem permanecer entre fases.
Sem afirmação de FPS/DPS/diversão/solo viável. H7 precisa IA30/60/144Hz e
fechamento integrado, além de revisão independente e playtest humano.

Inspeção de Sol: fonte/paleta/arma próprias, botas assentadas nos32 frames,
três mecanismos por forma, segmentado preparatório versus contorno armado,
campo ativado sem pote aguardando, prioridade diamante versus abertura
entalhada e breve impacto de consumo/rastro, limpos no fim. Entalhes permanecem
individuais em grupo; indicadores azuis de CC são os existentes, não novos VFX
Hunter. Legibilidade/percepção em combate ativo continuam sujeitas ao playtest.

Primeira rodada técnica PASS278 tinha oclusão por HUD/obstáculo no palco e uma
limpeza parcial (campo ainda visível). Não usada como prova visual final.
Sol ajustou o palco e usou a limpeza canônica; último PASS282 regenerou todos
os PNGs aqui. Perfil habitual e backup conservam a assinatura restaurada H5;
checkout de playtest permanece codex/playtest/3d452fa sem publicação.

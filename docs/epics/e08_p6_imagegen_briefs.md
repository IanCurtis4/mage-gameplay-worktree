# P6 — briefing de imagegen para o Codex (WIP)

Estado: **WIP, aguardando geração pelo Codex** a pedido do usuário. Claude não gera
raster; enquanto as folhas não chegam, cada assinatura usa a versão desenhada em
código (fallback permanente). Usar o imagegen embutido como em P3/P4/P5, salvar a
saída byte a byte (sem edição de raster por código). Proveniência: o usuário pode
dispensar `provenance.json`; nesse caso a coordenação registra com
`prompt: null` (política P5). Destino exclusivo: `assets/art/e08_vfx/staging/`.
Não editar runtime, catálogos, testes ou atlas.

## Formato comum

Uma folha PNG transparente por efeito, `<id>.png`, ~1254×1254, grade **4×4 = 16
quadros** em células iguais, lidos da esquerda para a direita e de cima para baixo
(início → pico → dissipação; último quadro quase vazio). Efeito centrado na célula,
mesma escala em todos os quadros, vista 3/4 de cima do jogo (chão como elipse
achatada ~2:1), sem personagens, chão, texto, moldura ou sombra. Pixel-art pintada
à mão, coerente com `assets/art/vfx/spiritualist_effects.png` e com os props de
`assets/art/map_authoring/props/`. Bordas limpas sobre alfa; núcleo luminoso com
2–3 tons, sem bloom cobrindo a célula inteira (indicadores de perigo vermelhos/
amarelos precisam continuar legíveis por cima).

## Folhas (9)

| id | Uso (assinaturas) | Direção |
|---|---|---|
| `fire_burst` | fireball, explosive_trap, explosive_shot | explosão de fogo radial com brasas, laranja/amarelo, fumaça curta no fim |
| `ice_shatter` | freezing_trap, glacial_ring, tri_nova (gelo) | cristais de gelo brotando e estilhaçando, ciano/branco |
| `lightning_burst` | lightning_arc, headshot, tri_nova (raio) | estalo elétrico com 3–5 ramos curtos, violeta-azulado/branco |
| `slash_arc` | slash, counterstroke, golpes físicos | arco de corte em meia-lua da esquerda para a direita, branco-aço com rastro; desenhado orientado para a direita (o jogo rotaciona) |
| `blood_rift` | blood_rift, wound_leap (aterrissagem) | fenda vermelho-escura no chão com respingos estilizados (sem gore realista) |
| `ground_shockwave` | reprisal_wave, terrifying_shout, investida do Guardião | anel de onda de choque no chão com poeira, bege/dourado |
| `arcane_warp` | teleport, collapse, triangulation | implosão/expansão de runas e fragmentos geométricos, azul-arcano/magenta |
| `nature_thorns` | arrow_rain (impacto), covering_shot, thorn/tar | espinhos e folhas irrompendo do chão, verde-musgo/marrom |
| `summon_portal` | invocação do Guardião | círculo de raízes e luz verde abrindo e fechando no chão |

Aceite: 16 quadros não vazios exceto o último, centrados, mesma escala, sem
elementos fora da célula. Entrega: avisar o usuário com a lista de arquivos.
B1 (Terra) empacota, integra sobre a versão em código e mede legibilidade.

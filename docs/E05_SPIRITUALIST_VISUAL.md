# Espiritualista — pacote visual Astra, 29/09/2026

Autorização: usuário atribuiu arte a Astra e implementação das skills a Sol,
uma a uma; playtest do Espiritualista é obrigatório antes das classes do Arqueiro.
Este documento descreve assets e composição visual; o único checkpoint de
progresso da classe continua E05_SPIRITUALIST_CHECKPOINT.md.

## Direção e produção

Silhueta proposta por Astra: mesmo cabelo/rosto do Mago, casaco ritual curto
em ameixa dessaturada e carvão, estola marfim, fechos prata, botas marrons
visíveis, cajado de crescente ritual e pequeno talismã. O violeta é acento/sombra,
não a cor única de todo efeito. Preserva tecido/metal físico versus vestígio
espectral pálido, sem equipamentos de ranger nem exigência de companheiro.
Não pretende fechar uma identidade de arte final para todo o jogo.

Criado pelo imagegen embutido: edição guiada pela folha de poses do Elementalista
para o personagem; geração original para as quatro famílias VFX.
Fontes preservadas em assets/art/animation_sources/spiritualist_source.png
e spiritualist_vfx_source.png. Prompts integrais: spiritualist_prompts.md.
Preparação local autorizada pelo usuário: tools/prepare_spiritualist_art.py
(Pillow), recorte por bandas de alfa reais, remoção de poeira, escala uniforme
nearest e pés alinhados. Nenhum atlas de outra classe foi modificado.

A fonte gerada trouxe duas poses frontais na linha de cast traseiro. O
preparo substitui essa sequência por poses traseiras existentes de repouso,
elevação, liberação e recuperação (índices-fonte 16/22/23/17). Não promete
32 desenhos independentes ou quatro casts traseiros inteiramente novos.

## Atlas de personagem

assets/art/animations/spiritualist.png: 256×512, grade4×8, célula64×64.
Mesmo mapa de CharacterAnimation/CombatAnimationState:
0–3 idle frente, 4–7 walk frente, 8–11 cast frente, 12–15 walk costas,
16–19 idle costas, 20–23 cast costas, 24–27 hurt frente/costas,
28–31 death frente/costas. Pivô lógico(32,58); último pixel dos pés y58.
Manter sincronismo de caminhada por distância percorrida, animação de cast
pela duração real ajustada por DES, pausa/cancelamento/morte do dono.
Nenhuma sombra quadrada embutida: usar a sombra de contato do renderer.

## Sprites animados de skills

assets/art/vfx/spiritualist_effects.png: grade4×4 de96×96 (384×384).
Cada linha também existe como strip independente4×1:
spiritualist_soul_wisp.png, spiritualist_curse_sigil.png,
spiritualist_spectral_burst.png, spiritualist_ritual_halo.png.
spiritualist_effects.json informa linhas/pivôs. Alfa real preservado, sem
retângulo opaco. Os quatro frames de cada família são distintos.

- Wisp: alma direcionada à direita com rastro à esquerda; rotacionar pela
  trajetória. Para posicionar a cabeça/contato no alvo, usar ponta aproximada
  (84,48) como âncora, e não o centro de toda a cauda.
- Sigil: quatro fases de formação, brilho, saturação e dissipação.
  Pivô(48,48), ancorado sobre corpo do alvo.
- Burst: crescente espiralado, 0→1→2→3, centro transparente,
  pivô(48,48). Não repetir como explosões novas enquanto o dano é único.
- Halo: anel elíptico com névoa ascendente; pivô de chão(48,63).
  Interior transparente. A elipse decorativa NÃO representa o raio de
  colisão; contorno autoritativo da área vem da geometria compartilhada.

## Receita de apresentação por skill

| Skill | Composição e timing |
|---|---|
| Maldição do Eco | Sigil 0→1 no impacto real, alternância discreta1/2 acima do alvo enquanto marca existe; ao consumir, dissipar3. Burst pequeno no eco real em +0,35s. Não criar impacto/carga por miss/absorção total. |
| Drenagem Espiritual | Vínculo fino code-native entre peito do caster(-24y) e corpo do alvo(-18y), com wisps retornando ao caster nos quatro ticks reais; halo suave no caster. Primeira onda somente ao primeiro tick0,5s, não no início do cast. Encerrar imediatamente no cancelamento; sem morte/cura visual fictícia. |
| Véu Espectral | Halo baixo no centro, névoa translúcida e poucas cópias espaciais no interior; um único contorno de alcance exato110 conforme runtime. Não desenhar parede sólida. Ciclo0/1/2/1 em ~0,64s durante3–5s reais, fade final subordinado ao término. |
| Procissão | Três wisps nos instantes0/0,20/0,40s com trajetória de0,22s cada, fase flicker0–3; pequeno burst somente no impacto correspondente. Alvo móvel: refletir posição real validada; nada de projéteis fantasmas após cancelamento. |
| Rito de Dissipação | Preview de raio100 e duração de preparo0,60s ajustada por DES conforme fonte única. No commit, burst0→1→2→3 em0,32s central com poucas instâncias distribuídas dentro da área; quebrar sigil de cada marca realmente consumida. Não ampliar a área por largura do bitmap. |
| Recolhimento | Wisp discreto retornando ao caster somente em restituição real de SP; 0,24s. Sem sugerir SP recuperado quando já no máximo. |
| Foco do Além | Sigil pequeno sobre caster ao completar canal válido, indicador discreto enquanto carga existe, burst breve no consumo real. Distinguir de maldição hostil por posição/silhueta menor, não só cor. |

Sol conecta esses assets/eventos ao runtime; a composição pode usar linhas,
contornos e transformações code-native. Não precisa gerar bitmaps novos.
Não esticar arbitrariamente o anel decorativo para representar uma circunferência
de regras. Área de preview/atingimento permanece fonte única do jogo.
O estado da apresentação é finito, por instância, limitado e com pausa,
expiração e limpeza de morte/fim de encontro; não cria dano nem atraso de ações.
Novas necessidades visuais retornam a Astra.

## Evidência e limites

Preparo verifica 32 poses não vazias, margem lateral, contato y58, alfa,
quatro frames distintos de walk frente/costas e 16 frames VFX com transparência.
Astra inspecionou atlas e composição sobre fundo contrastante e corrigiu
resíduos entre linhas da fonte. Pranchas:
docs/art/spiritualist_assets.png e spiritualist_animation_preview.gif
(animação comparativa sobre piso claro/escuro).

Não equivale a teste no renderer do Godot. Sol deve validar registry,
callbacks reais, importação, leitura na cena e tools/verify.ps1 no fechamento.
Astra revisará integração final antes de preparar o diretório habitual.
Balanceamento, FPS e leitura com múltiplas skills ainda dependem de teste.

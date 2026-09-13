# Candidato: Mago e animações

## Teste no projeto habitual

Após a integração técnica, abra o projeto habitual e use F5. O botão Classe abre
um menu com início explícito de nova run; selecione Mago. Não é preciso mudar Git.
O aceite de produto deste bloco ainda pertence ao usuário; master mantém o piloto
anterior até esse aceite.

Q: Bola de Fogo. W: Parede de Fogo. A: Lanças de Fogo. S: Lanças de Gelo.
D: Teleporte. Padrão: tecla seleciona, clique esquerdo confirma. Os modos de
soltar tecla e smart cast continuam em Controles. Direito/Esc cancela intenção.

- Coloque a parede perpendicular à direção do cursor e faça um inimigo atravessar.
  Atravesse também: ela não é um obstáculo. Bola de Fogo deve critar enquanto
  o inimigo estiver queimando; Lanças de Fogo ganham dano nessa condição.
- Use gelo para desacelerar uma perseguição. Fogo e gelo possuem recargas,
  níveis e quantidades próprios, com progressão futura separada.
- Lance contra um obstáculo: projétil deve parar. Teleporte atravessa obstáculo
  se o ponto de chegada for válido. A Investida do Espadachim respeita colisão.
- Observe a conjuração e tente cancelá-la andando; uma tentativa cancelada
  não deve gastar mana nem iniciar recarga. Reabra menus e troque classe para
  confirmar que nenhuma magia antiga fica pendurada.
- Observe parado, andando em quatro direções, atacando, recebendo dano e morrendo.
  Confirme legibilidade e sensação; os testes automáticos não substituem esse aceite.

## Arte e contratos visuais

Quatro atlases RGBA 256×512, com 32 células reais de 64×64 por personagem.
Quatro orientações via frente/costas e espelhamento. Idle e caminhada têm quatro
quadros; ataque/conjuração quatro; dano e morte dois por vista. O primeiro quadro
da conjuração traseira do Espadachim reutiliza idle para corrigir orientação
inconsistente na fonte gerada. Não são oito direções desenhadas independentemente.

Fontes originais em assets/art/animation_sources; prompts e método em
ANIMATION_PROMPTS_01.md. Limpeza de fundo, recorte, alinhamento e paleta local
explicitamente autorizados pelo usuário. Preparação reproduzível por
tools/prepare_animation_assets.py, Pillow/numpy; preview por preview_animations.py.

CombatAnimationState controla somente apresentação. Caminhada acompanha distância;
ação preserva direção do disparo; hurt exige dano real; morte prevalece sobre ações.
CharacterAnimation compartilha atlas imutável e mantém estado por ator. Remoção do
inimigo/recompensa é imediata; ActorDeathVisual é uma cópia sem combate de 0,7 s.
Somente a morte cosmética do jogador continua atrás do resultado pausado.
Sprites não alteram hitbox, velocidade, alcance, dano nem cooldown.

Chamas e projéteis usam desenho geométrico leve; não são spritesheets de VFX finais.
O chão permanece 2D com profundidade simulada. Níveis de skill existem no runtime,
mas a tela de aprendizado e a revisão completa de stats tipo RO são trabalho futuro.
As outras classes e híbridas são propostas em CLASS_ROSTER_BRAINSTORM.md.

# E08 P4 — extensão delimitada para quatro direções

6/11/2026. O usuário pediu norte/sul/leste/oeste para personagens e inimigos no
chat P4; retomada técnica solicitada a Sol no P0. Este é contrato de produção,
NÃO implementação entregue ou prova de quatro vistas no jogo. Substitui o limite
32 células apenas quando o conjunto direcional de uma identidade for produzido,
calibrado e validado como unidade. P4 continua aberto. Não inicia P5.

## Diagnóstico e decisão técnica

CombatAnimationState.face guarda direção contínua, mas seleciona só frente e
costas com flip horizontal; frame_index tem 32 índices. CharacterAnimation,
EquipmentHandRig, fingers, EquipmentAttachmentVisual e EquipmentHeadVisual usam
essa indexação. Alterar apenas o PNG não seleciona vistas laterais. Virar ou
retintar uma vista frontal não produz uma lateral.

A autoridade de movimento/combate fica intacta. A direção visual recebe o vetor
2D já projetado usado por face, sem reinterpretar coordenadas 3D ou pathfinding.
Nova seleção cardinal: eixo de maior módulo; y<0 norte, y>=0 sul, x>0 leste,
x<0 oeste. Zero conserva orientação. No empate, manter direção anterior se for
uma das duas candidatas; caso contrário escolher vertical. O cache visual precisa
incluir direção resolvida, inclusive se a fase de animação for a mesma.
Durante ação a direção continua a do lançamento; dano não gira o ator; morte e
sua cópia congelam direção, retomada mantém regras atuais de reconstrução.

## Formato e consumo único

- V2: atlas RGBA 256×1024, 64 células64×64; pivô-base (32,58), pés calibrados.
- Quatro blocos de16 poses, ordem sul/norte/leste/oeste. Cada bloco tem idle4,
  walk4, action4, hurt2 e death2; índice=16*direção+pose. Durações, deslocamento
  de caminhada e transições são os existentes, sem clock paralelo.
- Frente e costas atuais são mantidas no legado V1. V2 possui arte específica
  para as quatro vistas; sem flip automático do corpo em V2. As assimetrias de
  traje, arma, mão dominante e escudo devem continuar coerentes nas quatro.
- Manifesto imutável por identidade define versão, textura base/sem arma,
  pivô, hashes, calibração de pés/mãos/dedos/cabeça e profundidade. Catálogo
  apenas de apresentação; nenhum campo persistido na definição de gameplay.
- CharacterAnimation resolve um único descritor de desenho para corpo, anexos,
  dedos, cabeça, sombra de contato e cópia de morte. Não deixar cada drawer
  recomputar sua direção/índice/flip. API pública legada permanece compatível.
- V1 aceita exatamente os assets atuais sem mudar seus quadros. V2 é carregado
  só se textura,64poses,rig e metadados forem válidos. Rejeitar conjunto inválido
  de forma observável e manter V1 inteiro; nunca corpoV2 com rigV1 silencioso.
- RigsV2 têm64 calibrações reais por identidade: main/off, crops de dedos,
  orientação do equipamento e profundidade. Âncora em roupa opaca não comprova
  mão. Capacete recebe âncora/profundidade por pose, não a heurística antiga.
- Props de arma e escudo continuam equipamentos separados e imutáveis; nenhuma
  nova restrição de equipamento ou gameplay para acomodar um sprite.

## Abrangência e sequência produtora/consumidora

O inventário Sol [baseline_inventory.json](e08_evidence/p4_sol/baseline_inventory.json)
congela os atlas e mapeia recursos MobDefinition. Dez identidades jogáveis,
corpos warrior/archer/gel/beast_master/animal_companion e overrides wolf/boar
precisam ser avaliados. Archer também tem consumidores inimigos; warrior atende
várias espécies. Preservar os consumidores e os overrides individuais do piloto.
Recurso de teste existente não é promessa de que aparece na fase publicada.

1. Sol publica produtor V2 com suporte legado e fixtures sintéticas identificadas
   como teste, incluindo seleção cardinal, validação de manifesto, desenho e
   equipamentos. Não anunciar arte pronta a partir dessas fixtures.
2. Terra produz primeiro UMA identidade equipada completa, com quatro vistas e
   todas as poses, sobre API fechada; Sol valida rig, cabeça, dedos, orientação,
   transições, morte e ausência de alteração de simulação. Não fabricar todas
   as folhas antes de provar a integração de uma delas.
3. Terra conclui as demais identidades e corpos de inimigos no escopo autorizado,
   com inventário de preservar/corrigir/completar e fontes/prompts. Nenhuma classe
   pode terminar rotulada quatro direções enquanto ainda usa V1.
4. Revisar renderer nativo nos sentidos cardinais, diagonais/empates, chão claro/
   escuro, rampas/pontes/oclusão, zoom de câmera50/100/160 e UI120. Validar todas
   as combinações de equipamento atuais, não só sobreposição de marcadores.

Implementação produtora Sol ainda não transferida nesta rodada: escopo previsto
CombatAnimationState/CharacterAnimation, EquipmentHandRig/Attachment/HeadVisual,
catálogo/descritor de apresentação, testes de animação/alinhamento/direções,
probes/runner e metadados de fixture. Registrar lista EXATA e SHA no dispatch de
implementação antes de escrever. Terra não edita APIs compartilhadas por inferência.
A parte concluída nesta rodada é a triagem e prova atual da interface.

## Invariantes e aceites

Zero mudança a dano/alcance/colisão/LoS/cooldown/RNG/tempo de simulação/save.
Testes V1 atuais continuam intactos. V2 cobre64poses, quatro direções distintas,
limites dos recortes/alpha/pivô, rigs/flip/oclusão corretos, trocar equipamento,
pausa/cancelamento/revive, morte, troca de estágio/suspensão sem replay e export.
Asset inválido não muda estado de animação nem parcialmente ativa V2.
Não trocar só dimensões esperadas dos testes antigos para parecer aprovado.

Medir no renderer real CPU/p95/picos e memória por conjunto: pixelsRGBA brutos
sobem de0,5MiB para1MiB por atlas, mas isso não certifica RAM/VRAM nem custo final.
Reusar controles e limiares E08 (>10% reproduzível ou>16MiB retidos exige triagem).
Promover uma identidade só com arte e rig completos; relatório deve distinguir
produtor disponível, identidade integrada e cobertura total pendente.

# E04 — aprendizado e Arqueiro: decisões aprovadas

O usuário aprovou esta direção após o brainstorming de progressão e skills.
Este documento substitui os ranks gratuitos iniciais de bases no contrato E00
e a exigência de ao menos uma ativa equipada. Outros contratos continuam válidos.

## Aprendizado

- Personagens novos começam em job 1, somente com autoattack; ativas/passivas R0.
- Job 2 concede o primeiro ponto; cada job seguinte concede o ponto previsto
  na carteira correspondente. A base mantém os 19 pontos do E00.
- Aprender R1 custa 1 ponto; cada melhoria custa outro. Ativas R1–R5, passivas
  R1–R3. Respec gratuito no menu restitui apenas pontos efetivamente investidos.
- Barra vazia é válida para iniciar a run. Aprender não equipa automaticamente.
- Primeiro ponto após encontro introdutório curto; o primeiro cristal atual,
  com 80 XP job, já atinge JL2. Ajustar duração/dificuldade com evidência de
  playtest, sem antecipar campanha E07.
- Preservar saves existentes: XP, identidade, investimentos e direitos já
  adquiridos não podem desaparecer nem invalidar o perfil por trocar catálogo.
  A compatibilidade/migração precisa de estratégia explícita e testes antes da
  integração. Não sobrescrever saves antigos com defaults ou reset silencioso.
- Não alterar gratuitamente as evoluções E05 nesta implementação de bases;
  compatibilidade delas deve ser explicitada no próximo contrato correspondente.

## Crescimento das skills

| Tipo | Benefício principal | Custo |
|---|---|---|
| Dano direto | Dano linear | Curva côncava entre pontas por skill |
| Projéteis múltiplos | Quantidade ou dano total | Considerar sequência inteira |
| Controle | Duração ou intensidade limitada | Aumento moderado |
| Mobilidade | Alcance ou recarga | Pequeno aumento ou fixo |
| Defesa/suporte | Proteção ou duração | Conforme benefício total |
| Passivas | Bônus específico | Pontos de job, sem SP |

Evitar crescer dano, área e controle simultaneamente. Não aplicar crescimento
integral por projétil além do crescimento de quantidade sem balancear o total.
Curva do Corte em E04_S0C_DESIGN continua válida; R1 agora é comprado.

## Arqueiro — kit de base aprovado

| Ativa | Função | Crescimento prioritário |
|---|---|---|
| Disparo Duplo | Dano concentrado, dois projéteis fixos | Dano total |
| Flecha Perfurante | Acertar inimigos alinhados | Dano; perfuração previsível |
| Chuva de Flechas | Área anunciada contra grupos | Dano total, área fixa inicialmente |
| Mira Estendida | Janela de maior alcance | Duração; alcance limitado |
| Armadilha de Laço | Prender brevemente um alvo | Duração limitada |
| Armadilha Explosiva | Preparar dano em área | Dano |
| Flecha Entorpecente | Controlar distância com slow | Duração; intensidade moderada |
| Abrigo de Folhagem | Arbusto oculta de inimigos externos | Duração; atacar revela temporariamente |

Passivas: Precisão (HIT), Cadência (ASPD), Técnica de Armadilhas (inicialmente
tempo de permanência das armadilhas no chão).
DES: dano principal, inclusive armadilhas físicas. AGI: cadência/evasão.
INT: sustentação SP; VIT: sobrevivência. Não exigir INT como segundo atributo
de dano das armadilhas desta base. Vetor inicial do Arqueiro permanece o E00.

Mapas devem exigir capacidades com várias respostas possíveis, sem pressupor
uma skill específica comprada. Detalhamento e composição ficam para E07.

## Execução granular

Primeiro pacote L0: aprendizado sem gratuitos + barra vazia + compatibilidade
de perfis, com Sol por envolver persistência. Só esse pacote é despachado agora.
Depois: migração restante de ranks do piloto, kits de Espadachim/Mago e pacotes
do Arqueiro na ordem E04. Cada tabela numérica/requisito ainda não especificado
deve ser decidido no seu recorte; este documento não inventa valores finais.
E04-S0C entregue em a834941 ainda exige revisão; não pressupor aceite técnico.

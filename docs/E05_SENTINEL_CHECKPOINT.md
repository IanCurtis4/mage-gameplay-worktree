# E05 — Sentinela: checkpoint consolidado

03/10/2026. Implementação autorizada pelo usuário; condutor Sol 6.1.
Contrato: E05_SENTINEL_PLAN.md. Biblioteca 7 ativas/2 passivas, slots 5+2.

## Estado

Plano e checkpoint de Astra incorporados, sem código de menu-tabs. Branch isolada
`codex/e05-evolutions` avançou por fast-forward de b53eb58 para e103162, limpa
antes da abertura. A autorização humana foi conferida no chat de Astra.
Geômetra revisada está em playtest, sem aceite de produto inferido por iniciar
Sentinela. Diretório habitual/codex-playtest e saves pessoais permanecem intactos.

Próximo passo: S5 Concussão, Leitura e Absoluto; seguir S5–S7
autonomamente, um bloco/skill por vez, sem gate nem handoff intermediário.

## Abertura / S0

Base e103162; leitura dos contratos concluída. Foco observa `encounter_active`
canônico de RunController, inclusive treino/boss; não infere combate do alvo.
Reset será uma emissão especial imediata que inicia recuperação normal e não
consome a munição Explosiva. A classe continuará bloqueada até S7 integrado.
Catálogo/ranks são pacote delimitado independente; matemática e transações
permanecem com o condutor. Sem alteração de schema ou atributos globais.

S0 fechado: nove IDs/handlers/ranks, gates/free rank, override parcial e
`content_ready=false`; `SentinelTuning`/`SentinelMath` com INT isolada, coeficientes
aditivos e CD DES local. Duas builds de 20 pontos planejadas no contrato.
Import PASS, catálogo 749 checks, matemática 72 checks, Geômetra builds 341 PASS.

S0 commit b7ec8b8. S1 fechado: Foco run-only com movimento efetivo, estabilidade,
decay fora de encontro e pausa; Observar com três acertos e cadência por emissão;
Postura condicional no StatCalculator, retirada antes do auto após deslocamento.
Medidor/retículo/marca mínimos acompanham o sistema, sem save novo. Teste real e
pure: 338 checks PASS em 30/60/144 Hz, sem multiplicar ganho por AoE; hit letal
válido é distinguido de alvo previamente morto. S7 fará acabamento de apresentação.

S1 commit a258cec. S2 fechado: Cabeça valida alvo/LoS/SP/Foco/CC antes de cobrar,
emite um projétil com snapshot e inicia recuperação normal do auto. Um guard por
frame impede auto comum posterior no mesmo frame, inclusive com delta grande.
126 checks PASS (ranks, recusas, três modos de input, projétil real, pausa e
limpeza); regressão de perseguição/inércia 41 PASS. Trajetória própria e estado
SEM FOCO acompanham o disparo. Arte original gerada para normalização posterior.

## Registro compacto a manter pelo condutor

S2 commit 4e20f95. S3 fechado: Perfurante direcional sem alvo, um projétil mágico
INT+DES com crítico normal, atravessa corpos uma vez e para em paredes/alcance.
CD DES local aplicado antes do modificador canônico; mira acompanha cursor.
219 checks PASS: 30/60/144 Hz e delta longo, deduplicação, parede, snapshot,
marca e isolamento de atributos/CD. Cabeça 126 checks PASS novamente.

S3 commit 07a735b. S4 Rede fechada: projétil abre no primeiro corpo/terreno/ponto,
área com LoS/deduplicação, INT isolada, root após impacto pelo canal mágico.
167 checks PASS: ranks, boss cap/budget, ataque permitido sob root, preparo
cancelável grátis, revalidação, parede, delta/frequências, shield/proc/limpeza.
Revisão interna corrigiu a tag de controle para `magic`; ID da skill não é canal.

Rede commit 204533d. Explosivo fechado: reserva SP/Foco sem custo/CD/reset,
cancelamento libera, próximo auto revalida e paga uma vez, substituindo dano
físico por INT e área sem duplicar principal. 162 checks PASS: ranks, recursos
livres, snapshots no lançamento, alvo trocado/perdido, LoS, proc único, input,
pausa/morte/fim e nenhum auto gratuito. Resets não consomem a reserva.

Para cada unidade concluída: camada/skill, commit, teste/resultado, decisão
relevante e próxima unidade. Registrar uso somente quando mensurável. Não
duplicar o contrato neste arquivo nem criar um documento por microtarefa.

## Aceites

- Escopo e execução: autorizados em 03/10/2026.
- Revisão técnica integrada Astra: pendente da classe completa.
- Playtest humano e merge em master: pendentes.

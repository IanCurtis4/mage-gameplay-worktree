# Bosque — preparo passivo de encontros

Estado: somente preparação documental; aguarda liberação explícita de Sol após validação da quarta fatia AX. Não houve engine, importação, operação AX ou alteração de conteúdo. Base estável informada ff61b57b80a564a3244267ed3207c1663b490682; branch codex/map-editor-f9; checkout C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5. Há implementação e testes concorrentes ainda não validados: não tratá-los como PASS.

Mapa existente: data/map_authoring/sanctuary_woods.map.json; SHA256 de bytes 8e3f1c3c47709d204eeaf3061e3d98beabb0dfa987ed09ff24ad2ec79e6a631f, hash semântico 8a9051f8a416a58890365e1b262cea309053ff52c5ce20725d0598ef7875ed55 e pacote 098aa6b630015504ec47abfa45257fb0c7b571efabad590016dcc34acfc71fdc conforme checkpoint 26. Forest, 35 spans, 84 apoios/131 conexões; corpo 20×32 preparado em todos os apoios. Não prova App, posição efetiva do spawn ou caminhada. Preservar snapshots e 47 props.

## Intenção espacial

- Entrada no marcador existente de A [160,0,640]; localizar socket e apoio reais pela consulta, não presumir ID de face.
- Pincel disperso no entorno da clareira de A, próximo de [384,0,640], sem bloquear entrada, trilha, emenda ou props. Ajustar centro, raio, espaçamento e quota após consulta e preview; distribuição e contagem são hipóteses até compilação.
- Grupo concentrado no oeste de B, próximo de coordenadas locais [320,0,1088], isto é, mundo [1600,0,1088]. Reservar aproximação e retorno do beco. Slot manual fixo associado a brush compatível, próximo mas sem obstruir o corredor; patrulha ping_pong com dois ou mais pontos reais alcançáveis, próximos ao beco e dentro do leash da espécie. Definir pontos apenas após consulta e diagnóstico.
- Interação phase_completion existente no santuário do platô norte, em torno de local [1056,128,192], mundo [2336,128,192]; escolher ponto e apoio reais, sem inventar quest ou recompensa.
- Preservar rotas superior sobre ponte Y=128 e inferior sob ponte Y=0, com aproximações e retorno. B está deslocada +1280 em X. Coordenadas não certificam colisão nem escolhem entre apoios sobrepostos.

## Contexto e escolha

As fontes das peças declaram biome_ids forest, allow_rare=false, allowed_species vazio; áreas woods_clearing, woods_west e woods_shrine também têm allow_rare=false, allowed_species vazio e reserved vazio. Lista vazia não autoriza extrapolar elegibilidade: obedecer ao compilador e ao contexto efetivo. O catálogo versionado é carregado pelo PopulationCatalog a partir de ProfileCatalog.pilot; options verifica espécies/categorias e origens trial_stage_1 a trial_stage_4 com MobOccurrence e exclui companion. A política de origem e recompensa é a existente. Exemplos representative usam test_gel, mas não provam sua elegibilidade no Bosque. Escolher apenas combinações retornadas por population/catalog/options, compatíveis com contexto e validadas pelo compilador; evitar raros. Se não houver combinação válida, registrar diagnóstico e parar, sem criar exceção ou trocar contexto.

## Prova e limites futuros

Registrar resultado de compilação e reabertura das duas fontes, igualdade de hashes, slots gerados e fixo, sementes/round e diff da proposta, rota e pontos. No App com perfil descartável, verificar spawn efetivo no marcador, caminhada ida/volta pela emenda, rampa, ponte e piso inferior, leitura/oclusão, combate e retorno ao home/leash, patrulha ida/volta/esperas e objetivo phase_completion; registrar também restart/continuidade e ausência de duplicação. Observar trajetos, posições, diagnósticos, capturas e tempos, sem inferir FPS de compilação. Validação humana de aparência e jogabilidade permanece pendente. Requisitos de intercâmbio, release e restante F9 continuam abertos; esta preparação não fecha F9 nem abre F10.

Consulte receitas.md para campos, sequência e evidências. Gameplay e suíte não executados nesta entrega documental.

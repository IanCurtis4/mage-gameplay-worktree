# E07 — guia de validação e entrega

18/10/2026. Norma: [WORKFLOW](../../../WORKFLOW.md). [Contrato](../../e07_contract.md)
e [pacotes](../../e07_tasks.md). Este documento não registra execução de gameplay.

## Responsabilidades e evidência

Executor implementa/corrige e produz evidência autoral. Luna acompanha execução,
conclusão, erros e hashes; não altera oráculos para ocultar falha. Sol valida
contratos/invariantes e fecha tecnicamente. Supervisão não é auditoria semântica
independente. Astra é arquitetura, análise visual excepcional ou problema que
Sol justifique como muito complexo, sem carimbo automático de capítulo.

Cada entrega registra SHA-base completo, SHA entregue/integrado, checkout/branch,
diff real inclusive árvore suja, decisões/contrato, engine/hash, inputs/fixtures,
seleção do runner, plan/checks/logs com hashes, capturas/seeds quando pertinentes,
falhas e cobertura omitida. Uma referência planejada não é SHA executável.

Runtime usa tools/verify.ps1 por impacto, Godot 4.7.2 standard e fixture explícita.
Consultar `-List` antes de selecionar IDs. Nomes e índices são conferidos na base
do pacote; nomes propostos e arquivos abaixo não são testes já implementados.
Falha, timeout, SCRIPT ERROR ou rotina incompleta não são PASS por exit 0.

## Matriz de aceitação

| Fronteira | Positivo | Negativo/adverso | Integração exigida |
|---|---|---|---|
| F0 montagem | mesma entrada → mesmo manifesto; caminhos para todas as obrigações | conector incompatível, seed exausta, objetivo sem local, IDs duplicados | manifesto consumido por consultas de superfícies/população fixture |
| F1 espaço | rampa/ponte e ataques nas duas alturas | piso obstrui, raio não cabe, revisão obsoleta, clique ambíguo | travessia, AI, projeção e efeitos dos dez kits habilitados |
| F2 propriedade | destino único por exemplar/encaixe; wallet/unlocks | alt não dono, mapa incompleto, saldo/inteiro inválido | presets/build/rewards/codec/store com migração fixture |
| F3 congelamento | contínuo versus capturado/restaurado no mesmo tick | kind ausente, dangling ref, RNG inválido, versão futura | casts, projéteis, áreas, kit states, ofertas e causalidade |
| F4 durabilidade | suspensão e retomada com bens/recibos consistentes | todos os failpoints, write incerto, request conflitante, limite do arquivo | reabrir processo e retomar último corte durável sem grants repetidos |
| F5 ciclo | limpeza/retorno/onda/revive/conclusão | repetição de evento, boss morto, estágio não limpo, origem inválida | fase ramificada completa, mácula/tickets, morte no instante da onda |
| F6 ameaça | dano/cura/taunt/limiar e participação | empate, replay, overheal, ocultação/LoS, fonte morta | AI + UI futura usando mesma autoridade, sem reset ao descarregar |
| F7 conteúdo/UI | amostra variada, seleção clara, portais e retomada legíveis | erro de geração, migração pendente, save incerto, API indisponível | duas montagens; toda interação pt-BR; renderer nativo |
| F8 candidato | campanha completa, export e reentrada | fixture isolada, release sem editor, falhas de compatibilidade | regressão de fronteiras compartilhadas, medição e roteiro humano |

Para relógios, testar delta parcelado versus delta grande, pausa/suspensão,
inclusive participação mínima entregue em F5. A linha F6 aplica-se somente se
ameaça completa for incluída no marco por dispatch próprio. Testar
30/60/144 Hz onde aplicável e fronteiras exatas. Para causalidade/identidade,
variar ordem de criação dos Nodes sem mudar resultado semântico. Para geração,
guardar seeds e caminho testemunha, inclusive corpus adverso. Testes de RNG
não exigem que duas receitas diferentes produzam conteúdo igual.

Regressões existentes candidatas, observadas na base: profile_store_test,
profile_facade_test, profile_run_facade_test, e02_run_integration_test,
e06_tx_mob_test, e06_rewards_test, e06_gameplay_ai_test,
e06_gameplay_route_test, e06_gameplay_content_test, e06_rx_mob_ai_test,
verification_profile_isolation_test. Sua presença não comprova cobertura E07;
consultar runner e testes relevantes de cada kit/equipamento por impacto.

## Inspeção e escala

Renderer confere piso selecionado, altura, parede/ponte, marcador de destino,
portal local versus viagem/final, posição de retorno e estados de erro. Fazer
combate real, sem refill/HP inflado para alegar viabilidade. Desempenho registra
máquina, resolução, build/renderer, seed, área, população total/ativa, p50/p95/p99
de frame time e tempo de montagem/carga/save. Caps não provam 60 FPS.

Export release deve encontrar partes/catálogos/adaptadores sem depender de import
aberto no editor ou asserts de inicialização. Saves de fixture isolados, nunca
save pessoal. Reuso de evidência só com SHA/inputs compatíveis e delta declarado.
Ampliação da suíte precisa de motivo; fronteira compartilhada ampla pode justificar
suíte completa uma vez no fechamento, sem repetição automática após edição de texto.

## Entrega documental desta rodada

Verificar referências locais, nomes existentes contra código, diferença entre
proposta e aprovação, DAG/donos e ausência de consumidor PRONTO. Não executar
Godot/runner de gameplay. Não usar ausência do CLI de workflow como autorização
ou bloqueio de leitura; registrar limitação e conferir por Git/contratos.
O checkpoint de arquitetura registra o resultado real dessas verificações.

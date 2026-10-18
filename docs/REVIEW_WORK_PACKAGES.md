# Pacotes e validação proporcional ao impacto

Norma atual: [WORKFLOW](WORKFLOW.md), decisão humana de12/10/2026. Consolidação
documental17/10; [análise histórica](REVIEW_WORK_PACKAGES.history_2026_10_17.md).

| Pacote | Execução | Evidência |
|---|---|---|
| Textos/receitas sobre contrato fechado | Luna | Validador, conferência contextual e nenhum efeito inventado |
| UI/conteúdo sobre API estável | Terra | Testes do fluxo e inspeção visual |
| Sistemas, save, matemática, causalidade | Sol | Invariantes e integração; supervisão automatizada Luna e consolidação Sol |
| Arquitetura/planejamento | Astra | Contrato, guias, dependências e escolhas humanas registradas |
| Integração/candidato | Executor operacional designado | Evidência por impacto, roteiro, publicação autorizada e aceite humano separado |

Não existe gate Astra automático por microtarefa, capítulo ou fronteira crítica.
Astra pode receber exceção visual ou problema que Sol justifique como muito
complexo. Supervisão Luna não é auditoria semântica independente. Não passar
toda tarefa pelos quatro modelos nem selecionar Extra Alto por padrão.

Cada pacote entrega um comportamento verificável, com exclusões, base/checkout,
contrato, dono exclusivo por arquivo, APIs, aceites e testes. Consumidor de API
instável aguarda; escritores compartilhados são sequenciais. Correção reutiliza
o chat da tarefa. [Skills](DELIVERY_SKILLS.md) ajudam na matriz específica por domínio.

Registrar SHA entregue/integrado, inputs, engine, seleção e resultado dos testes,
logs/hashes, prova visual e limitações. Falha vai a Sol; não editar oráculos para
ocultá-la. Aproveitar evidência compatível conforme [TESTING](TESTING.md), sem
somar checks repetidos ou apresentar cauda como suíte completa.

Documentação apenas valida precedência, links, escopo, coerência e referências ao
código. Runtime executa `tools/verify.ps1` por impacto; regras novas têm invariantes.
Arquivar somente após entrega registrada, validada e integrada. Aprovação técnica
não autoriza merge sem o aceite humano do candidato testado.

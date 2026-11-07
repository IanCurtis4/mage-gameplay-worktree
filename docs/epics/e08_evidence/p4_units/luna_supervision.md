# Supervisão Luna — integridade P4 unidades

Data: 2026-11-07. Resultado: **integridade conferida; evidência automatizada consistente** para Elementalista, Mago, Espadachim e apoio V2. Esta conferência leu o ZIP, os manifests, os recibos e os logs já registrados; não executou Godot nem repetiu testes. Não constitui análise visual independente nem aceite de produto.

## Integridade e freeze

- `evidence.zip`: 657 membros únicos, 50.670.917 bytes; SHA-256 `59801ad23a11396bdee7f80dd2bca880a0ce19bb49ab1f650aeab11ead4be6e5`. Os 657 hashes de membros registrados conferem.
- Freeze: manifest de 2.431 inputs em `inputs/final_source_hashes.json`, hash `6f1cc9573f0d59e83fd1a84e0d7c3039686515c49f779360de6e6545e6294129`. Todos os 2.431 caminhos existem no candidato e conferem com o hash congelado. O recibo documenta a única exceção pós-snapshot: `docs/epics/e08_p4_units_sol_files.json` consolidou posse; não é input de runtime/teste/arte.
- Runtime/arte listados na posse atual: os 85 hashes de `owned_source_file_sha256` conferem. Engine standard registrada: Godot 4.7.2, SHA-256 `ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424`.
- Commit examinado: `5756f0944f129792f9c53f565ede9956b48ca8b9`; contém 107 caminhos. PCKs retidos estão presentes e conferem: promoted1 100.111.052 B, SHA-256 `cd645c5df6da1d598904f99c1c42ab146caeb20a00e6047ef572a55fdadb7d00`; final2 100.111.388 B, SHA-256 `778afecffdead1c060b98105ae6ffedc2a4a38e1706e38a4fd869aace3f2cb6b`. Ambos somam 200.222.440 B; permanecem retidos para Root.
- Quatro backups pessoais descritos no manifesto: inventariados como parte da evidência; não foram alterados.

## Registros de execução

- Nativo: cada unidade tem 661 checks, 0 falhas e 15 capturas; execução promovida termina com exit 0 e sem timeout. Espiritualista: 447 checks, 15 capturas, 0 falhas.
- Movimento: cada unidade tem 77 checks, 64 frames PNG e execução exit 0 sem timeout. GIFs: 6,4 s e 26 quadros codificados, conforme recibo; total agregado não foi usado para inferir verificação visual independente.
- Verificação selecionada: 23 etapas únicas de 317, 28.694 checks, 0 falhas/erros/timeouts **na composição válida**: 10 etapas aproveitadas da cabeça regression_final1 + 13 etapas da cauda regression_final2. Não somar repetições. Teste do pacote final: unidades 10.887 + conteúdo 3.461 + produtor 814 checks PASS.
- Logs/execuções das etapas válidas e dos três probes nativos/movimento: exit code 0, sem erro/timeout. Warnings existentes de plugin VCS ausente na exportação são registrados no recibo; não contam como erro de execução.

## Tentativas com falha preservadas

As falhas anteriores não foram convertidas em PASS nem incluídas na cobertura válida: Elementalista staging1 teve erro de inferência `Vector2`; calibrated1 falhou na tipagem `Array[StringName]` e terminou por timeout de 120 s; regression_final1 avançou nas 10 etapas compatíveis e falhou ao parsear a etapa 19 por três inferências `bool` no teste novo. As correções descritas pelo implementador foram tipagem explícita, sem alteração de expectativas/runtime/arte. Os artefatos dessas tentativas permanecem no ZIP.

## Limites e próximo estado

Esta auditoria confirma integridade e leitura coerente dos recibos congelados; não reexecuta o runtime, não avalia aparência por visão independente e não concede aceite artístico, de produto, conclusão de P4, merge ou playtest. Os dois PCKs permanecem para Root conferir antes de qualquer limpeza.

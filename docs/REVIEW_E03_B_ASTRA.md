# Revisão E03-B — 20/09/2026

Candidato `f217d9954c895dc3e24c7095a5b78e49de454088`.
**Aceite pendente de duas correções de catálogo.**

Escopo entregue: saldos derivados de XP, alocação, compra de ranks, requisitos,
respec, carteiras separadas e preview/snapshot pela autoridade de stats.
Sem mudança de schema nem evolução efetiva E05. Os caminhos transacionais usam
cópias candidatas, revisão esperada e recuperação do store existente.

Verificação independente: `tools/verify.ps1` com Godot 4.7.2, incluindo importação,
todas as suítes e smoke test, PASS. E03-B: 37 checks; matriz de stats: 275.

## Achados reproduzidos

1. `scripts/core/profile_catalog.gd`, `add_skill`/`add_equipment`: tentativa
   rejeitada de escrita após `seal` altera `_build_error`. Um catálogo válido
   passa a inválido mesmo retornando false. Separar rejeição por selo da marcação
   de erro de construção; catálogo selado deve conservar validade e conteúdo.
   Reprodução: `ProfileCatalog.pilot()` válido; `add_skill` retorna false;
   `is_valid()` passa a false.
2. `_normalized_rank_requirements` descarta chaves de rank desconhecidas e campos
   desconhecidos antes de validar. Um requisito malformado é silenciosamente
   substituído pelo padrão permissivo JL1/sem pré-requisitos. Reprodução com
   `rank_requirements={"wrong_rank": {"job_level":40,
   "skill_ranks":{"missing":5}}}`: catálogo aceito e requisito resultante
   rank 1/JL1/vazio. Validar entradas originais antes de normalizar; distinguir
   ausência legítima de requisito de declaração inválida. Cobrir ranks fora do
   intervalo, campos desconhecidos e aliases conflitantes.

Reprodução isolada registrada em `.tools/e03_b_catalog_probe.gd`, sem tocar saves.
Solicitadas correções e testes de regressão ao Sol na tarefa E03 existente.
Solicitado também handoff com API/erros/limites; E03-C1 ainda não liberado.
Playtest/master não foram atualizados com este candidato.

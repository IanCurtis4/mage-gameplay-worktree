# E07-F4 — suspensão/retomada duráveis

21/10/2026. EM_EXECUÇÃO, Sol/Alto, chat `01a150a6-9c43-7391-ad9d-febcab815a76`.
Aval humano: “F3 foi concluído. Podemos começar F4.”

Base real `6299e9a1f6540d6bbb21e6079808cbcaf8c9f229` (fechamento F3);
F1/F2 são ancestrais da composição sequencial tecnicamente validada, sem alegar
integração operacional no playtest. Branch `codex/e07-f4`, checkout exclusivo
`C:/Users/João Pedro/.codex/worktrees/e07-f4/RagRPG`.
CLI versionado/WORKFLOW_TOOLING ausentes; diagnóstico por Git/contratos.
D02 consumida: uma pendência/personagem e locks aprovados em F2; congelamento
local/global aprovado em F3. Quest antecipada/morte/ondas/campanha continuam F5+.

## Transferência exclusiva antes da edição

F2/F3 entregues, sem escritores paralelos. F4 recebe nominalmente:
- scripts/core/profile_state.gd, profile_codec.gd, profile_store.gd,
  profile_facade.gd, run_reward_service.gd e scripts/main.gd.
- scripts/core/expedition/ownership/expedition_asset_lock.gd e
  character_assets.gd: extensão tipada do lock e validação de transações
  materiais que incluem checkpoint, preservando bloqueios de lobby.
- tools/verify.ps1: registro/testes F4, transferência sequencial de F3.
- Novos scripts/core/expedition/persistence/*.gd e seus .uid;
  scripts/core/expedition/expedition_service.gd e .uid;
  tests/e07_f4_*.gd/.uid e tests/fixtures/e07/f4/**.
- Este despacho, f4_api.md, delivery/f4.md e seção F4 de docs/epics/e07.md.

SnapshotRegistry/manifesto F3 são API consumida sem fork de serialização ou novo
campo runtime nos atores. Envelope transporta bytes Variant sem objetos nativos;
revisões/conteúdo e limite são validados. Não criar segundo writer.

## Resultado e validação

Suspender, checkpoint, retomar e reconciliar pelo ProfileStore canônico;
recompensa e corte do mundo no mesmo candidato, publicação após commit.
Último corte durável sobrevive restart, sem abandono automático ou avanço offline.
Requests congelados/deduplicados e falha incerta bloqueiam novas intenções.
Provar I07/I11, tickets emitidos/coletados, falhas antes/depois de rename,
backup/corrupção/futuro/limites, conflito e alts. Luna supervisiona execução e
hashes; Sol corrige/consolida. Sem save pessoal, playtest/master/push ou F5+.

Captura F3 custa segundos nas fixtures: F4 expõe checkpoints explícitos e
transacionais; não inventa intervalo periódico de produção. Medir custo/limite.

## Adendo antes da correção final — isolamento por dono

A revisão Sol encontrou next_counter/revision globais da projeção de cartas no
digest do dono. Novo teste nominal tests/e07_f4_alt_isolation_test.gd/.uid fica
exclusivo de F4. Reproduziu checkpoint_assets_mismatch ao conceder carta a alt
com o personagem original suspenso, antes da correção (alt_red).
Corrigir somente a projeção do digest em expedition_checkpoint_codec.gd;
contadores globais permanecem íntegros no perfil/snapshot para IDs únicos.
A seleção final desse delta inclui seis F4, quatro F2 e transações inventory/loot.
Os outros16 IDs aprovados em8e53b40 são reaproveitáveis por impacto: nenhum
algoritmo/adaptador de snapshot, atores, combate ou operação legada foi alterado.

# F5 — proposta de transação de troca ativa

21/10/2026. **APROVADA e VALIDADA tecnicamente**; [entrega](delivery/f5.md).
Resposta humana explícita: “Aprovar esse delta transacional”.
Revisão automática rejeitou aplicar a mudança por considerá-la ampliação de
semântica de mutações persistentes/locks sem aprovação específica.

## Problema observado

F2 bloqueia mutações do dono com expedição pendente; D02 aprovado descreve
consulta/locks no lobby. O contrato F5 também exige que trocas consultem a
participação real em combate. Atualmente RunBuildService.preview chama
run_mutation_status e CharacterAssets.check_intent, que retornam
locked_by_expedition mesmo na expedição ativa e fora de combate.
Liberar só esses guards permitiria uma gravação de layout sem seu mundo;
isso violaria I07/I11 e o congelamento exato de recursos/recargas.

## Delta proposto para aprovação

Permitir equipar/desequipar/encaixar/desencaixar/transferir cartas somente
na expedição ativa, com sessão/dono corretos e fora do combate local real.
Usar a prévia e composição E06 existentes. Perfil (layout/encaixes), build
runtime, déficits HP/SP, cooldowns e checkpoint entram em uma única transação
do mesmo ProfileStore. Falha incerta bloqueia até reconciliar a mesma intenção;
retry não aplica duas vezes. Publicação da build acontece somente após commit.

O dono suspenso continua com os locks de lobby D02. Alts preservam sua liberdade.
Não autoriza edição de atributos/skills/presets no lobby, novos itens, economia,
transferência entre personagens, cura por troca ou reset de cooldown.

Implementação proposta, sem novo writer:
- RunBuildService prepara a intenção pelas mesmas regras; rota ativa usa
  ExpeditionService com barreira coerente. Prévia/commit validam o mesmo estado.
- ProfileFacade compartilha a preparação material com o caminho legado, que
  continua recusando commits separados para uma expedição.
- CharacterAssets aceita apenas layout/encaixes ligados a um recibo de build
  e checkpoint coerente; outros campos do personagem seguem protegidos.
- encounter_active consulta CombatParticipation diretamente no contexto F5,
  eliminando a janela de um frame depois de dano. O piloto conserva seu estado.

Arquivos já atribuídos a F5: run_build_service.gd, profile_facade.gd,
expedition_service.gd, character_assets.gd, expedition_asset_lock.gd,
runtime_manifest.json e main.gd; novo teste e07_f5_build_test.gd.

Prova exigida: prévia pura, bloqueio em combate/suspensão e dono errado,
troca sem cura/recarga, checkpoint/restart coerentes, rollback conhecido,
gravação incerta/retry e regressões E06 de inventário/transações.

Autorização desta proposta não equivale a aceite de gameplay ou merge em master.

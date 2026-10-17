# E06 — diagnóstico do export v0.6 e correção do conteúdo

17/10/2026. Escopo de correção dentro do candidato E06 `ec83b45ec8fde30d6e367b27bc972cd2a3ce0b72`, antes de novo playtest e sem aceite de produto ou merge. O PCK original `build/RagRPG v0.6.pck` (16/10/2026 16:52; SHA-256 `5399ef94d2d4c6493f0c496c56920cae2c344d2fd8ceda359878a0d2d07e679a`) foi lido sem alteração. A reprodução usou Godot 4.7.2 com `--main-pack` e `APPDATA`/`LOCALAPPDATA` temporários. Nenhum processo abriu o `user://` pessoal nem tentou repará-lo.

## Causa reproduzida

O PCK exportado lista recursos como `*.tres.remap`. `BuildContentLoader.definitions()` selecionava somente nomes terminados em `.tres`. No PCK isolado, retornou **0 mobs, 0 equipamentos, 0 cartas, 0 augments e 0 conjuntos**. O catálogo montado continha 0 mobs, 0 equipamentos, 0 cartas, 5 augments legados e 0 conjuntos. No editor, a pasta de fonte apresenta `.tres` e a falha fica escondida. `ProfileCatalog.pilot()` usa esse carregador para equipamentos e cartas; um save com essas identidades encontra catálogo incompleto. `ProfileStore.load_profile()` conserva perfis incompatíveis como somente leitura. Isso explica o sintoma relatado sem concluir que os bytes do save foram degradados. A confirmação do perfil específico deve usar uma cópia isolada e o novo export, nunca o save pessoal.

Há uma segunda falha de release independente, tratada na integração de `main.gd` e `build_effect_catalog.gd`: chamadas que registravam catálogo/mobs e augments legados estavam dentro de `assert()`. O export release não executa essas chamadas. A correção do carregador, sozinha, não valida o executável; o novo PCK deve incluir ambas as alterações.

## Correção e prova necessária

`BuildContentLoader` normaliza cada nome `.tres.remap` para a rota lógica `.tres`, deduplica quando ambos aparecem e ordena os nomes antes de carregar. Aplica a mesma descoberta aos recursos básicos, de progressão e de inventário E06. `tests/e06_export_content_test.gd` verifica as contagens fechadas do candidato e IDs únicos. `tools/export_content_probe.gd` lê um PCK isolado e retorna falha quando o catálogo obrigatório está incompleto.

Para fechar a entrega, importar e executar o teste na fonte sem `SCRIPT ERROR`; exportar novo PCK release em diretório ignorado, sem substituir o v0.6 original; executar teste/probe com `--main-pack` apontando ao novo PCK e diretório de usuário temporário; testar abertura de cópia do perfil schema 6 e uma sessão com mobs usando o mesmo isolamento. O PCK antigo deve continuar falhando no probe e o novo deve mostrar 11 mobs, 85 equipamentos, 6 cartas, 31 definições de augment e 14 conjuntos. Só então oferecer novo build ao usuário. O save pessoal permanece intocado até o playtest humano.

## Resultado17/10

Correção validada: PCK distribuível retorna11 mobs,85 equipamentos,6 cartas,31 augments e14 conjuntos. Entrada diagnóstica compilada no template Windows release real, com mesmo runtime, executou3ciclos em perfil novo e cópia de7personagens: spawn, HP, registro/loot, encerramento e recuperação após interrupção PASS. Inicialização do catálogo e registro de mobs saíram de assert, para executar também em release. A cópia abre em schema7/catalog14; originais preservados. Sem evidência de deterioração temporal e sem acesso aos saves privados das outras pessoas. [Validação](e06_admin_extension_validation.json).

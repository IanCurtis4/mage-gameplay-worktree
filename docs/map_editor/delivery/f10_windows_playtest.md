# F10 — executável Windows para revisão humana

Versão posterior disponível: [minimapa e zoom](f10_minimap_zoom.md). Esta página
preserva a distribuição anterior para continuar seus testes/checkpoints.

5/11/2026. Pedido humano: “Você criou um executável com as mudanças? Acho que
seria melhor para testar.” Entrega operacional do candidato já validado, sem
alterar gameplay ou aplicar mudanças ao checkout habitual. Q5 continua aberto.

## Abrir e jogar

Abra `C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.tools\playtest_f10\Jogar RagRPG F10.lnk`.
O alvo é `7ac05ff2\RagRPG-F10-Q5.exe`, nessa mesma pasta de teste. Também é
possível abrir o executável diretamente. Mantenha `RagRPG-F10-Q5.pck` junto
dele. Não é necessário instalar ou abrir o editor Godot.

1. Crie um personagem de teste e prepare a build no menu habitual.
2. Clique em **Expedições**, escolha **Floresta do Santuário** e inicie a fase.
3. Percorra **Prado dos Terraços → Vales da Mata → Covil do Guardião**.
   Observe movimentação, combate, altura/oclusão, objetivo, nomes e estado
   dos portais. Suspenda e retome a mesma expedição.
4. Anote pausas, erros e dificuldades. As pausas de entrada/portal ainda são
   longas; este executável não certifica fluidez ou conclui Q5.

O nome de aplicação exportado é **RagRPG F10 Q5**. Assim, inclusive ao abrir
o `.exe` diretamente, `user://` usa
`%APPDATA%\Godot\app_userdata\RagRPG F10 Q5`, separado do perfil **RagRPG**.
O progresso de teste permanece entre aberturas. Nenhum save pessoal foi
copiado, migrado, apagado ou desbloqueado. As restrições existentes de
debug/admin e de gravação continuam: o export não as remove.

O jogo exportado permite a revisão de gameplay. As nove tarefas de autoria
do editor continuam pelo [roteiro F10](f10_acceptance_script.md), na fixture
preparada; elas não são substituídas pelo executável.

## Vínculo e verificação

Fonte `codex/map-editor-f10`, commit documental
`7ac05ff2088e31e2164150c6531fe56d55ab671e`, runtime
`dc563d2e1c59e949591e1d25a4f5e21f274d3fe4`. **2.233 inputs** conferidos por
SHA256 entre fonte e fixture retida. Godot **4.7.2 standard**, template
Windows release x86_64. A cena inicial é `scenes/character_menu.tscn`, em vez
da prévia técnica usada nos testes de release anteriores.

| Arquivo | Bytes | SHA256 |
| --- | ---: | --- |
| `RagRPG-F10-Q5.exe` | 109.127.680 | `4a9eaded8955ef789ab02651ed9d2dde80328fbb342bd2a6db4db33e86305668` |
| `RagRPG-F10-Q5.pck` | 94.861.816 | `09a10b111b37ea3f9cd0a759ac189a15b3e69ee221820f917def99990facad41` |

Exportação e abertura nativa do `.exe` com encerramento programado passaram,
exit 0, sem erros. A inspeção do mesmo PCK pela engine standard confirmou
cena inicial, nome isolado e presença dos catálogos/fase/manifesto. Uma sonda
gráfica do PCK confirmou menu gravável, criação de personagem, gravação e
reabertura do perfil e **Floresta do Santuário** listada. Captura da seleção
preservada. O personagem da sonda pertence somente ao perfil descartável de
validação, separado também do novo perfil de teste humano.

Deltas exclusivamente de embalagem: nome de aplicação, VCS desativado,
plugin de exportação de mapas habilitado para preservar bytes originais,
template explícito, exclusão do plugin Git e supressão do wrapper de console.
`project.godot` e `export_presets.cfg` da fixture foram restaurados byte a
byte. Fontes, quatro backups e checkout habitual preservados.

Houve dois erros do preparador, preservados sem tratá-los como PASS: a
primeira inspeção tentou `--script` no template release, que não oferece essa
opção, e foi encerrada; a inspeção válida usa a engine standard com o mesmo
PCK. Uma assertiva posterior esperou `profile.json` antes da primeira mutação;
o menu mantém o perfil inicial em memória. A criação/reabertura efetiva de
personagem provou a gravação. Não houve correção de runtime ou reexportação
para contornar esses erros.

[Manifesto, logs e sondas](evidence/f10/reviewer/windows_playtest_2026_11_05/),
[supervisão Luna](evidence/f10/luna/windows_playtest_2026_11_05/supervision.md).
Esta rodada verifica a embalagem e o menu; não repetiu a suíte de gameplay.
A evidência de gameplay do [checkpoint18](f10.md#checkpoint18--511-retomada-navegação-e-portais-q5-aberto)
continua aplicável ao mesmo runtime. Não é aceite de produto, merge ou push.

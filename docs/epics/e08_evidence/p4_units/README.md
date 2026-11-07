# Evidência portátil — três unidades P4 e apoio de itens V2

Escopo: Elementalista/Mago/Espadachim e regressão da Espiritualista; autoria e
validação Sol, conferência automatizada Luna coordenada depois por Root.
O candidato usa somente a fixture F1 existente, com um delta de configuração:
version_control/autoload_on_startup=false. APPDATA/LOCALAPPDATA isolados em todos
os lançamentos. Godot4.7.2standard SHA256ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424.

O ZIP reúne logs, execuções, planos, deltas exatos/versões anteriores, manifestos
de inputs, capturas e código dos harnesses. Não contém perfis, saves, cache,
biblioteca da engine ou PCK. Fontes e atlas originais ficam no Git; seus hashes
são registrados. O arquivo hashes.json identifica cada membro, fontes atuais,
engine, quatro backups e os pacotes temporários mantidos para conferência.
Não é uma cópia executável completa do repositório.

## Reprodução em PowerShell7 no candidato

Usar o checkout/candidato e a fixture importada correspondentes; não copiar
esta fixture sobre o habitual nem usar o save pessoal. O manifesto de fontes
congelado do ZIP permite conferir origem e fixture antes de executar. Em outro
checkout limpo, preparar a fixture F1 pelo teste versionado de importação e
sincronizar apenas os deltas autorizados, conservando a única diferença VCS.

````powershell
$env:APPDATA=Join-Path (Get-Location) '.godot/verification/p4_units/reproduction/appdata'
$env:LOCALAPPDATA=Join-Path (Get-Location) '.godot/verification/p4_units/reproduction/localappdata'
$tests=@('combat_animation_test','e08_presentation_test','e08_pilot_ui_test','e08_audio_test','e08_pilot_test','e08_characters_test','e08_directional_animation_test','e08_directional_integration_test','e08_directional_content_test','e08_directional_units_test','equipment_hand_alignment_test','e06_icon_bar_test','e05_spiritualist_visuals_test','e05_elementalist_animation_test','e06_appearance_integration_test','e06_ui_inventory_test','e06_inventory_test','e07_f7_presentation_test','e07_f3_action_matrix_test','e07_f3_lifecycle_test','e07_f1_presentation_test','e07_f3_snapshot_test','e07_f3_continuation_test')
& tools/verify.ps1 -GodotPath '<Godot standard verificado>' -F1Fixture -Test $tests -VerificationDirectory '.godot/verification/p4_units/reproduction'
& tools/validate_e08_art_unit.ps1 -Kind mage -Stage native -EvidenceName reproduction1 -Default
& tools/validate_e08_art_unit.ps1 -Kind elementalist -Stage export -EvidenceName reproduction1 -Default
````

Cada EvidenceName é imutável. Custos foram executados antes da promoção padrão,
para preservar o controleV1; reproduzir esse controle pelos inputs e versões
anteriores arquivados, sem apagar os defaults do candidato.3janelas de3s por
estado/versão,96atores com anexos, redraw forçado, GPU GTX1080. Não certifica FPS
de mapa, RSS/VRAM ou ausência de vazamento. performance_summary.json por unidade
inclui medianas, p95 e retenção estática. PNGs são capturas exatas; GIFs são
prévias com paleta256 sem dithering e duração total6,4s, sem mudar sprites.

## Tentativas e compatibilidade

staging1 Elementalista: erro inicial de inferência Vector2, corrigido antes das
provas staging2. calibrated1: Array de ternário não satisfez Array[StringName],
erro e timeout120s conservados. regression_final1:10etapas PASS antes de erro de
parse no teste reforçado (três variáveisbool precisavam de tipo explícito).
regression_final2 retoma pela etapa19, sem repetir as dez compatíveis. Só mudou
a tipagem do novo teste; runtime/arte e os dez scripts já aprovados são idênticos.
O primeiro PCK promoted1 passou o teste anterior; o pacote final testa também
pathdefault no cold restore e a igualdade de todos os pixels/64calibrações.

O limite de uso interrompeu a execução após staged Mago/Espadachim; Root gravou
transferência temporária para contratos disjuntos e devolveu a posse antes da
retomada. Nenhum resultado parcial foi declarado PASS completo. Mudanças futuras
em equipamentos e outros conjuntos P4 usam arquivos disjuntos e não são inputs
desta prova. Fonte atual do capacete piloto e anexos permanece provisória,
aguardando o redesenho autorizado em contrato separado.

# Consumidor dos dois Bosques decorados — PASS

Sol executou e conferiu esta prova dirigida. Não há supervisão independente Luna
nesta fatia: ela foi interrompida por quota durante o rascunho dos testes de API.
Código `52798508efb7f274fdc3a42959c7af9b2da31c1b`; os dados Terra estavam congelados
com os bytes abaixo e foram integrados sem alteração em `b14ea3dc9f46bd3f072f41a51cbba5e8053a725a`.
Branch `codex/map-editor-f9`, checkout `.tools/map-editor-m5`.

## Resultado e alcance

Duas fontes válidas, 24/23 placements, hash semântico/compilado e bytes iguais ao
recibo Terra. Composição efêmera de TESTE com bioma `forest`, clearing em [0,0,0],
overpass em [1280,0,0], emenda `a_east` ↔ `b_west_gate`, rotação0. Maps.compile,
Candidate.create e Candidate.prepare PASS. Perfil canônico raio20/altura32;
a preparação encontrou um ponto caminhável em cada apoio e certificou acesso.
A fonte isolada com abertura sem destino continua rejeitada por `opening_unlinked`.

O marcador `woods_entry` preservou ID transformado, kind e posição exata
[160,0,640]. WorldGeometry.position_query e paths de ida/volta entre esse ponto
e a entrada provisória passaram com o mesmo corpo. A composição de mapa puro
preserva o socket mas não escolhe automaticamente a entrada; Maps mantém
stage.entrance vazio, Candidate.prepare usa um início provisório e o consumidor
Population seleciona a entrada explícita. Isso continua a ser autoria pendente.

Não foi salvo mapa de produto nem usada fonte pronta para contornar AX. Não houve
App, caminhada de ator, combate, oclusão final, restart ou medição de FPS. A prova
de dados e acesso permite preservar o incremento; não encerra a área final/F9.

## Identidades

| Peça | SHA256 de arquivo | Hash semântico | Hash compilado |
|---|---|---|---|
| Clareira | `150509026fddc323396d20fdd015fee47c1dacb47685c1f326842b77260484ab` | `e2172d1928ad5f83188fdba6e89b445bdf37e207af10f4e639a6b1ba44f8ad4f` | `0d4756a1176e63776a2bf1cf2014a54855ac71b63ed3ef0ec0ea198a8dc8f597` |
| Passagem | `1501a98d8e201ce10017c0f410d137da5bad0c21fbd97039c9e52a9d693341c9` | `1cae62332c2fbb490982dc6cbcda7d13f4f12a39f77303b6e4056c7382255fb4` | `34a235bcd4f410059b945a3ae90bfb2773e45c57d313fcc63bcb028b9178718d` |

Composição de teste `f64acd5bf7a4274b1ec64005e345f5bd67863e82b4f8c35acd961b3a6cb57aa0`; pacote `ce87b7170efb6031061a08a8875126751143a998b81c887c3bd56333da9443bd`;
candidato `67b1cf071a2b915af013af841eefcb524a0490e68fca638cc47a79ff84c66637`.

## Evidência e custo

`consumer.manifest.json`: exit0, ok, marcador único completo, sem erros genéricos
ou timeout; HEAD estável527 e2028 inputs primários source/fixture iguais antes e
depois. Incluem os dois backups .bak, que são locais e não serão versionados.
Os manifests anteriores tinham2032 inputs: seis imports de props estavam incluídos,
e os dois backups ainda não existiam. O novo primário exclui *.import; a auditoria
`import_dependencies_audit.json` confere separadamente os seis imports de props e
quatro de terreno, todos iguais à fixture e à evidência testada anterior. Não
confundir esses conjuntos ou declarar equivalência integral de manifests distintos.
Import05 sincronizou a fixture e registrou o delta permitido de project.godot.

Uma execução: terrenos 1.010s /
0.410s; mapa
26.056s (navegação 24.078s),
preparo 23.557s (navegação
21.681s); lote completo
187.726s, incluindo hash/IO e checagens extras de entrada.
As duas chamadas individuais de path não receberam cronômetros separados, portanto
não atribuir uma duração exata a cada uma. O custo adicional merece reprodução
instrumentada de runtime antes do playtest; F9-10 permanece aberto. Isto não é
medição de frames ou certificação de fluidez, nem uma meta de encurtar a suíte.

## Primeiro diagnóstico preservado

`../consumer/` terminou exit1: fontes/compilação/preparo/acesso PASS, mas a primeira
versão do diagnóstico exigiu indevidamente entrada não provisória para candidato
kind=map. A leitura de MapCompiler/Candidate/Population confirmou o contrato acima.
A segunda prova substituiu essa suposição por checks mais concretos: socket exato,
posição/corpo e paths em ambos os sentidos. Nenhum produtor, footprint, perfil,
limite ou expectativa já estabelecida de teste foi alterado para fazê-la passar.

## Reprodução sem sobrescrever recibos

Copie `run_consumer.py` e `decorated_source_consumer.gd.txt` desta pasta para uma
nova pasta de evidência; o runner escreve ao lado de si. Sincronize previamente
pelo runner normal Import em diretório de evidência ausente. Não use -SkipImport
como sincronização geral. Execute, com Python disponível e caminhos locais ajustados:

```powershell
& 'C:/Python314/python.exe' '<nova-pasta>/run_consumer.py' `
  'C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5' `
  'C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5/.godot/verification/e07_f1/fixture_project' `
  'C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/godot/Godot_v4.7.2-stable_win64.exe'
```

Não mudar código/dados/testes/tools/HEAD durante a prova. Fixture única como --path;
APPDATA/LOCALAPPDATA ficam dentro dela. Confirmar exit, marcador, contagem, erros,
hashes e terminalidade. UIDs de produção já foram geradas pelo engine e versionadas.
A cópia .gd do diagnóstico fica apenas na .godot da fixture.

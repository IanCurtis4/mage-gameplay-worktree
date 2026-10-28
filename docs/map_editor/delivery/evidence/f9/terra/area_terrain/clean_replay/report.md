# F9 — autoria AX do terreno: Bosque do Santuário

Base indicada pelo integrador: `17516a20f959fabdecf0af76777824d379d98f42`. Peças autoradas por Terra via operações AX reais; Sol mantém os produtores. Checkout `C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5`, engine Godot 4.7.2 standard, fixture importada `.godot/verification/e07_f1/fixture_project`; APPDATA e LOCALAPPDATA apontam à pasta `.godot/discardable_profile` dessa fixture. Comandos completos, ambiente, exit e hashes estão nos quatro arquivos `*_execution.json` neste diretório; receitas, resultados, logs e capturas estão ao lado. Nenhum conteúdo foi criado por edição manual da fonte.

| Peça | Ações replay | Bytes | SHA256 dos bytes originais e replay | Hash semântico | Hash de compilação na fixture correta |
|---|---:|---:|---|---|---|
| Clareira | 8/8 | 15116 | `65a26754c437695d7e7d60e93980c187371fddeec4fb71f78323104dbb55ced5` | `93a5d99c3110ec054fca292b3efe3778b4d4745003f35390ade9c3d6d307ba38` | `aa762ada7df22b49c8ece77f95c9104791e8fc8138adecbdadd545651838bc12` |
| Passagem | 27/27 | 8142 | `d0071096addfefcefad1f1df849c3977064a741b4ed1446ffaf50a3f25a95d7e` | `d0d0f5ba826a167facc6f703ef0e85d97ba74b1dcb75270de834f294c02ed94a` | `dd2da0720ecc3757d42378e5be0e97865fba979d637517f1513bf666ee490a88` |

As quatro execuções limpas terminaram com exit 0, sem `SCRIPT ERROR`, `Parse Error` ou `ERROR:` nos logs. Os replays compilaram antes de salvar e produziram bytes idênticos aos dois originais. Cada original foi reaberto e compilado em outro processo na mesma fixture: os hashes semântico e compilado coincidiram com o replay correspondente. Capturas nativas foram produzidas; sua qualidade visual e a travessia não são certificadas por esta rodada.

A primeira execução apontou `--path` ao checkout, sem cache da fixture, e registrou `Identifier not found: SnapshotGraphEncoding` e dependências; apesar de ações retornarem sucesso, não é evidência aprovada. Os hashes compilados daquela execução foram `c384aa8df281c2a1b17600c6c77031eec923d53121cce7697417f707fc8951f4` (clareira) e `3a6300d644c76a9cd3d5fa3067783fa3f037df5fa5c01be9866e6667059c1fb6` (passagem), diferentes dos replays limpos. Logs e resultados originais continuam preservados no diretório pai; a diferença histórica não prova falha de determinismo da fixture correta.

Limites: terreno criado; ainda faltam props, composição, população, patrulha, interação, teste real de todos os apoios com raio 20 e altura 32 e avaliação humana. Não foi executada suíte de gameplay, nem criado F10, commit ou alteração em código/testes. Próximo passo: integrar os demais conteúdos pelo editor quando suas operações AX forem disponibilizadas e validadas.

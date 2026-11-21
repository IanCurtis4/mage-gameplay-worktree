# Releases canary (Windows, para players)

Build canary = a ponta mais avançada já composta e validada tecnicamente, liberada para players
avaliarem **antes** do aceite de produto. Canary não é aceite, não entra em `master` e não avança
`codex/playtest`. Cada canary tem save próprio do app "RagRPG Canary", separado do RagRPG habitual
e dos candidatos de épico.

## Canary 2026-11-20

**Pedido do usuário (20/11/2026):** "Depois das entregas do E09 e E10a, quero reunir o que foi
mandado, criar um release para Windows para meus players poderem avaliar."

### O que entra

- **Runtime:** commit `a432e56fa454489db14b888a06fb8389911a62f6`, o candidato técnico do E10a
  exportado e sondado pela T13 ([recibo](../epics/e10a/t13_delivery.md)). Ele contém:
  - `master` `34228347`: E09 (quatro híbridas, aceito em 17/11) e E12 (HUD de combate, aceito em 18/11);
  - E10a completo: base Acólito, Sacerdote e Cultista, T1–T16 e decisões A1–A24.
- **Branch:** `release/canary-2026-11-20`, a partir de `claude/e10a-candidato` = `25ef8029` (depois
  de `a432e56f` só há documentos), mais `1faed97a` (parâmetros de release na ferramenta de pacote e
  notas dos players) e este recibo.
- **Fora:** `claude/e08-legacy-tests` (3 commits de testes legados e `.gitattributes`, sem runtime).
  Nenhuma outra branch local tem runtime fora do candidato; as que estão à frente são backups antigos
  (setembro e outubro).
- **Estado de produto do E10a:** sem aceite humano e sem a supervisão da T14. O canary não muda isso.

### Como foi gerado

- Ferramenta: `tools/e10a_package.ps1` de `1faed97a` (SHA256 `f7eb2642…3d72`), com
  `-AppName 'RagRPG Canary' -BaseName 'RagRPG-Canary' -LauncherLabel 'Teste rapido'` e
  `-OutputDir .tools/releases/canary_2026_11_20/build`. Sem os parâmetros, a ferramenta faz a build
  da T13 como antes.
- **Rodada sobre `a432e56f`, não sobre `1faed97a`.** A fixture da F1 guarda o hash do próprio
  script de pacote (`source_hashes.json`, 3695 entradas, `tools/` inclusive), então o commit novo
  quebra a paridade. Refazer a fixture apagaria a evidência da T13 que a T14 ainda vai conferir. Por
  isso o script de `1faed97a` rodou como cópia não rastreada (mesmo SHA256) no worktree
  `.claude/worktrees/e10a-suite` destacado em `a432e56f`, com a mesma fixture, o mesmo motor
  (`AB1824F8…`) e o mesmo template (`D34D36F3…`). A cópia foi apagada depois, e o worktree voltou a
  `a432e56f`.
- **Única diferença para a build da T13:** `application/config/name` = `RagRPG Canary`, que isola o
  save em `%APPDATA%\Godot\app_userdata\RagRPG Canary\`. O EXE é byte-idêntico ao da T13; o PCK
  tem 16 bytes a menos.

### Artefatos

Pasta (fora do Git): `.tools/releases/canary_2026_11_20/`.

| Arquivo | Bytes | SHA256 |
|---|---|---|
| `RagRPG-Canary-2026-11-20-win64.zip` | 238.550.056 | `1747e9e51a523883f1290b0be2bdf890b3a6e8a2e510d995b3b52025b9ab8750` |
| `RagRPG-Canary.exe` (no ZIP) | 109.127.680 | `4a9eaded8955ef789ab02651ed9d2dde80328fbb342bd2a6db4db33e86305668` |
| `RagRPG-Canary.pck` (no ZIP) | 252.113.456 | `0b7c4e25d12431e2c4518e90a0ea5ea919b8c619757cb0de300983459b678580` |

O ZIP tem uma pasta `RagRPG-Canary-2026-11-20-win64/` com o EXE, o PCK,
`LEIA-ME.txt` ([fonte](canary_2026_11_20_leia_me.txt), gravado em UTF-8 com BOM e CRLF), quatro
lançadores `Teste rapido - <classe> - <build>.cmd` e os quatro perfis de revisão no job 40
(`profiles/<chave>/…/profile.json`, iguais byte a byte aos que a ferramenta gerou). Os atalhos
`.lnk` não entram: apontam para caminhos absolutos desta máquina.

### Validação (no PCK exato)

`build/validation/runs.json`, SHA256 `8083341C…6BED`:

| Etapa | Resultado |
|---|---|
| `export` | ok, 46 s; fixture e projeto restaurados |
| `inspect_pack_e10a` | 23 de 23 checks (nome do app e save isolado inclusos) |
| `inspect_pack_e08` | 22 de 22 checks |
| `normal_boot` | ok, menu normal |
| `forest_map_pack` | 19 de 19 checks, a fase da floresta abre do PCK |
| `export_content` | 92 equipamentos, 37 augments |
| `review_profiles` | 4 perfis, 0 inválidos |
| `smoke_open_close` | janela "RagRPG Canary" viva 25 s, fechou limpa, sem linha de erro, perfil igual |

Além da ferramenta:
- Um lançador `.cmd` rodado de dentro da pasta do pacote (caminho com acento e espaços): janela
  "RagRPG Canary", `logs/godot.log` sem `ERROR`, perfil igual antes e depois. Os arquivos que o
  jogo criou (log e cache de shader) foram apagados antes do ZIP.
- O ZIP extraído dá EXE e PCK com os mesmos SHA256 da build.

**Não repetido:** a suíte completa. O runtime é o mesmo commit da T13 (371 passos sobre `363f6671`
e 37 repetidos sobre `a432e56f`, com a falha conhecida do passo 255); o canary muda só o nome do app.

### Limitações

- EXE sem assinatura digital: o SmartScreen avisa na primeira abertura (o LEIA-ME explica).
- Desempenho não certificado; a medição de multidão da T13 é só desta máquina.
- As limitações aceitas do E10a (A15.6) valem aqui: números provisórios, sem som novo de luz e
  sombra, nomes de skill e ícones provisórios, bônus do Exorcista dormente.
- Feedback dos players: o LEIA-ME pede para mandar a quem passou a build, sem canal fixo.

### Publicação

Pendente de decisão do usuário (canal e permissão). Nada foi enviado nem publicado.

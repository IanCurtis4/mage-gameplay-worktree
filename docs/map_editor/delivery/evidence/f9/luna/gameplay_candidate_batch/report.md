# Luna: supervisao de execucao F9

**Veredito geral: FAIL**

Engine esperada: Godot 4.7.2 standard, SHA256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`.

## Tabela por stage

| Stage | Esperado | Count | Exit | ok | Timeout | Abort | HEAD antes=depois | Inputs | Duracao (s) | Veredito |
|---|---|---|---|---|---|---|---|---|---|---|
| CandidateBatch | 18 | 18 | 0 | True | False | False | sim (e5fddf840f42) | 2063 | 10.391 | PASS |
| GameplayWindow | 33 | 33 | 0 | True | False | False | sim (e5fddf840f42) | 2063 | 56.969 | FAIL |
| GameplayCli | 18 | 18 | 0 | True | False | False | sim (e5fddf840f42) | 2063 | 109.709 | FAIL |
| GameplayControls | 29 | 29 | 0 | True | False | False | sim (e5fddf840f42) | 2063 | 63.200 | FAIL |
| GameplayNative | 52 | 52 | 0 | True | False | False | sim (e5fddf840f42) | 2063 | 87.465 | FAIL |

## Criterios por stage

| Criterio | CandidateBatch | GameplayWindow | GameplayCli | GameplayControls | GameplayNative |
|---|---|---|---|---|---|
| 1. Execucao (ok, exit 0, sem timeout/abort) | PASS | PASS | PASS | PASS | PASS |
| 2. Resultado do runner (count, checks, failed) | PASS | FAIL | FAIL | FAIL | FAIL |
| 3. Sem SCRIPT ERROR / Parse Error / ERROR: nos logs | PASS | PASS | PASS | PASS | PASS |
| 4. HEAD antes=depois e SHA do engine | PASS | PASS | PASS | PASS | PASS |
| 5. Marcador do resultado no output.log | PASS | PASS | PASS | PASS | PASS |
| 6. Inputs (contagem e consistencia interna) | PASS | PASS | PASS | PASS | PASS |
| 7. preview_process_exit.all_closed (GameplayCli) | N/A | N/A | PASS | N/A | N/A |
| 8. Inputs obrigatorios do CandidateBatch | PASS | N/A | N/A | N/A | N/A |
| 9. Duracao | INFO | INFO | INFO | INFO | INFO |

## Detalhes

### CandidateBatch

- **1. Execucao (ok, exit 0, sem timeout/abort)**: PASS. ok, exit 0, sem timeout/abort
- **2. Resultado do runner (count, checks, failed)**: PASS. 18/18 checks ok
- **3. Sem SCRIPT ERROR / Parse Error / ERROR: nos logs**: PASS. nenhuma ocorrencia (WARNINGs: 0)
- **4. HEAD antes=depois e SHA do engine**: PASS. head e5fddf840f4227f3449d1e4c00d7b93672853218 igual antes/depois; SHA do engine confere
- **5. Marcador do resultado no output.log**: PASS. F9_CANDIDATE_BATCH_RESULT presente, 18 checks identicos ao manifesto
- **6. Inputs (contagem e consistencia interna)**: PASS. 2063 inputs; sem divergencia interna
- **7. preview_process_exit.all_closed (GameplayCli)**: N/A. aplicavel so a GameplayCli
- **8. Inputs obrigatorios do CandidateBatch**: PASS. tests/map_editor_gameplay_candidate_batch_test.gd.uid=69D81AAA57B7EBBF1C3B8A347D321DF546C340289027BD1D34BA5100FF82B2B8; scripts/map_authoring/preview/gameplay_candidate.gd=E16DF1107EBF53F2450AA910783196591E5BF5AFA0C52B7718F9C0763E62420C
- **9. Duracao**: INFO. 10.391 s
- Nota: encoding output.log: utf-8; engine.log: utf-8

### GameplayWindow

- **1. Execucao (ok, exit 0, sem timeout/abort)**: PASS. ok, exit 0, sem timeout/abort
- **2. Resultado do runner (count, checks, failed)**: FAIL. campo 'failed' AUSENTE no manifesto (criterio exige lista vazia explicita; nao foi possivel verificar)
- **3. Sem SCRIPT ERROR / Parse Error / ERROR: nos logs**: PASS. nenhuma ocorrencia (WARNINGs: 0)
- **4. HEAD antes=depois e SHA do engine**: PASS. head e5fddf840f4227f3449d1e4c00d7b93672853218 igual antes/depois; SHA do engine confere
- **5. Marcador do resultado no output.log**: PASS. F9_WINDOW_RESULT presente, 33 checks identicos ao manifesto
- **6. Inputs (contagem e consistencia interna)**: PASS. 2063 inputs; sem divergencia interna
- **7. preview_process_exit.all_closed (GameplayCli)**: N/A. aplicavel so a GameplayCli
- **8. Inputs obrigatorios do CandidateBatch**: N/A. aplicavel so a CandidateBatch
- **9. Duracao**: INFO. 56.969 s
- Nota: encoding output.log: utf-8; engine.log: utf-8

### GameplayCli

- **1. Execucao (ok, exit 0, sem timeout/abort)**: PASS. ok, exit 0, sem timeout/abort
- **2. Resultado do runner (count, checks, failed)**: FAIL. campo 'failed' AUSENTE no manifesto (criterio exige lista vazia explicita; nao foi possivel verificar)
- **3. Sem SCRIPT ERROR / Parse Error / ERROR: nos logs**: PASS. nenhuma ocorrencia (WARNINGs: 0)
- **4. HEAD antes=depois e SHA do engine**: PASS. head e5fddf840f4227f3449d1e4c00d7b93672853218 igual antes/depois; SHA do engine confere
- **5. Marcador do resultado no output.log**: PASS. F9_GAMEPLAY_CLI_RESULT presente, 18 checks identicos ao manifesto
- **6. Inputs (contagem e consistencia interna)**: PASS. 2063 inputs; sem divergencia interna
- **7. preview_process_exit.all_closed (GameplayCli)**: PASS. all_closed=true; pids=[51084, 54016]
- **8. Inputs obrigatorios do CandidateBatch**: N/A. aplicavel so a CandidateBatch
- **9. Duracao**: INFO. 109.709 s
- Nota: encoding output.log: utf-8; engine.log: utf-8

### GameplayControls

- **1. Execucao (ok, exit 0, sem timeout/abort)**: PASS. ok, exit 0, sem timeout/abort
- **2. Resultado do runner (count, checks, failed)**: FAIL. campo 'failed' AUSENTE no manifesto (criterio exige lista vazia explicita; nao foi possivel verificar)
- **3. Sem SCRIPT ERROR / Parse Error / ERROR: nos logs**: PASS. nenhuma ocorrencia (WARNINGs: 0)
- **4. HEAD antes=depois e SHA do engine**: PASS. head e5fddf840f4227f3449d1e4c00d7b93672853218 igual antes/depois; SHA do engine confere
- **5. Marcador do resultado no output.log**: PASS. F9_CONTROLS_RESULT presente, 29 checks identicos ao manifesto
- **6. Inputs (contagem e consistencia interna)**: PASS. 2063 inputs; sem divergencia interna
- **7. preview_process_exit.all_closed (GameplayCli)**: N/A. aplicavel so a GameplayCli
- **8. Inputs obrigatorios do CandidateBatch**: N/A. aplicavel so a CandidateBatch
- **9. Duracao**: INFO. 63.200 s
- Nota: encoding output.log: utf-8; engine.log: utf-8

### GameplayNative

- **1. Execucao (ok, exit 0, sem timeout/abort)**: PASS. ok, exit 0, sem timeout/abort
- **2. Resultado do runner (count, checks, failed)**: FAIL. campo 'failed' AUSENTE no manifesto (criterio exige lista vazia explicita; nao foi possivel verificar)
- **3. Sem SCRIPT ERROR / Parse Error / ERROR: nos logs**: PASS. nenhuma ocorrencia (WARNINGs: 0)
- **4. HEAD antes=depois e SHA do engine**: PASS. head e5fddf840f4227f3449d1e4c00d7b93672853218 igual antes/depois; SHA do engine confere
- **5. Marcador do resultado no output.log**: PASS. F9_GAMEPLAY_RESULT presente, 52 checks identicos ao manifesto
- **6. Inputs (contagem e consistencia interna)**: PASS. 2063 inputs; sem divergencia interna
- **7. preview_process_exit.all_closed (GameplayCli)**: N/A. aplicavel so a GameplayCli
- **8. Inputs obrigatorios do CandidateBatch**: N/A. aplicavel so a CandidateBatch
- **9. Duracao**: INFO. 87.465 s
- Nota: encoding output.log: utf-8; engine.log: utf-8

## Hashes-chave

- SHA256 do engine (registrado por todos os stages): `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`
- HEAD (antes=depois, todos os stages): `e5fddf840f4227f3449d1e4c00d7b93672853218`
- `tests/map_editor_gameplay_candidate_batch_test.gd.uid` sha256 `69D81AAA57B7EBBF1C3B8A347D321DF546C340289027BD1D34BA5100FF82B2B8`
- `scripts/map_authoring/preview/gameplay_candidate.gd` sha256 `E16DF1107EBF53F2450AA910783196591E5BF5AFA0C52B7718F9C0763E62420C`

## Inputs entre stages

- Paths distintos somados: 2063; presentes em todos os 5 stages: 2063.
- Divergencias de hash para o mesmo path: nenhuma. Os inputs em comum estao congelados entre execucoes.

## Limites

- Esta e **supervisao de execucao**, nao auditoria semantica do codigo. Confirma que a selecao rodou na engine registrada, que o runner marcou conclusao sem erro, que os checks reportados passaram e que os hashes batem. Nao verifica se os testes medem a coisa certa nem se a implementacao esta correta.
- **FPS, desempenho e jogabilidade nao estao provados** por estes logs. Os checks sao funcionais; nao ha medicao de frame rate nem avaliacao de experiencia.
- Os PNGs de captura do stage GameplayNative (`gameplay_bridge.png`, `gameplay_combat.png`) nao foram inspecionados por esta auditoria.
- Os hashes de inputs provam o conteudo registrado no manifesto, nao a correcao do conteudo. O executavel Windows nao esta disponivel neste ambiente; o SHA256 e o registrado pelo runner, nao reverificado localmente.
- Nenhum arquivo de evidencia foi alterado; a leitura foi feita em modo somente leitura.

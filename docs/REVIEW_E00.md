# Revisão E00 — contrato final candidato v1

13/09/2026. Astra, autorrevisão na tarefa E00; sem novo agente ou tarefa de review.
Não apresentar essa revisão como avaliação independente. Base técnica `79196d5`;
ADR E00.1 registrado no commit `8fd02c4`. Segunda liberação do usuário: incorporar
ruminações do PDF, terminar o trabalho pendente e analisar para aceite do épico.

Resultado: **ACEITO** — contrato v1 aprovado técnica e documentalmente. E00.1–E00.3 concluídos
como entrega documental. Não encontrei bloqueador de contrato após as correções
abaixo. O gate de aceite de design foi fechado pelo usuário após a entrega.

Aceite explícito sobre o conteúdo `73f7a03`: “Eu acho que ficou bom. Podemos
encerrar sua entrega aqui e eu vou começar E1 em outro chat.” A presente alteração
registra somente esse encerramento, sem mudar regras ou executar E01.
Validação do registro: verificador documental e `git diff --check`; os resultados
de Godot abaixo pertencem ao conteúdo aprovado, sem alteração de gameplay neste fechamento.

## Matriz de conformidade

| Critério do handoff | Evidência / conclusão |
|---|---|
| Distinguir aprovado de proposto | ADR e índice final marcam direção recebida e números candidatos; PDF não é tratado como autorização operacional |
| Personagem/conta/run | Donos distintos, XP persistente e snapshot isolado; augments/cartas/recursos intrínsecos descartados |
| Evolução e respec | Origem fixa, IDs direcionais, carteiras 19/20, requisitos 10/20, respec sem gerar pontos |
| Kit completo | Biblioteca/slots/ranks, seis puras e seis híbridas além das 3 bases, duas builds e resposta a boss como gates de conteúdo |
| Painel e fórmulas | E00.2 lista fontes, unidades, limites e pipeline; inclui ATQ de precisão por DES e dano misto normalizado |
| DEF/MDEF, HIT/FLEE, crítico, ASPD e tempos | Exemplos numéricos, limites e ordem de cálculo explícitos; sem alegação de copiar fórmulas de RO |
| Resources/runtime/save | E00.3 especifica contratos tipados, imutabilidade, schema 2, origem da recompensa, seq/idempotência e recuperação |
| Migração e fixtures | Caminho controls-only e v1 planejado; preserva versão futura; fixtures positivas/negativas e propriedades algébricas |
| Conteúdo do PDF | 10 páginas transcritas, elenco 15/Geômetra, seis loops, skills/augments/visual, ambiguidades resolvidas ou destinadas ao gate de conteúdo |

## Correções da própria revisão

1. Primeiro unlock híbrido em job 21 conflitava com evolução no 20: definir entrada
   gratuita 20 e manter 23/25/28/31/34/37 para os demais.
2. “Terceira runa não repetida” admitia 12 ou 18 receitas: fixar `c != b`, enumerar 18
   sem duplicação. Triângulos classificados em 3/18/6 e unlock cumulativo 3/21/27.
3. Origem ranged vs payoff melee: manter vetor/herança, permitir conversão explícita
   do auto em Devastador/Saqueador; registrar exceção visual do Devastador.
4. Dano físico só por FOR não atendia ao PDF: separar melee/precisão e normalizar
   pesos físico/mágico antes da defesa e do arredondamento único.
5. Bônus/fórmulas em texto não bastavam: especificar freeze de cast/recarga/emissão,
   fontes do painel e separação do nível persistente do snapshot.
6. “Perene”, “sem distância” e resets permitiam recursos ilimitados: TTL/budgets,
   limite de rastro/trap/figura, rearme mínimo, sem cópia de procs por eco.
7. Banimento poderia dar DPS grátis e encerrar encontro errado: intangível não
   toma/causa dano, pausa DoTs, continua contado; boss recebe slow limitado.
8. Save v1 era só planejado: schema 2 explícito; migração sem fabricar personagem;
   versão futura não cai em defaults/backup e não é sobrescrita.
9. Trocar para máximo menor que o déficit podia recuperar SP ao reequipar:
   rejeitar troca voluntária inválida e conservar déficit em expiração de buff.

## Evidências de validação

`tools/verify.ps1` passou com importação de editor, oito suítes e smoke headless
em Godot **4.7.2.stable.official.ed1daf0bf**. Total 313 verificações existentes:
fundação 20, animações 30, marco 1 63, perseguição 41, UI batalha 47, arena 32, layout 28,
gameplay Mago 52. Nenhuma dessas contagens é teste do futuro save/personagem.

Comando executado:

```powershell
./tools/verify.ps1 -GodotPath 'C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/review-engine/Godot.exe'
```

`tools/verify_e00_contract.py` passou **4.630 verificações de especificação**:
limiares/curvas e carteiras; três vetores iniciais; dano misto/arredondamento;
limites/monotonicidade de defesa e HIT; cast; conservação de pontos/recursos;
gramáticas e seis pares; envelope de save e sete casos negativos; links locais.
É uma varredura algébrica e de fixtures, não 4.630 cenários de gameplay.

```powershell
& 'C:/Users/João Pedro/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/verify_e00_contract.py
```

PDF: extração das 10 páginas e inspeção visual da prancha; transcrição com SHA-256
preservada em docs/references. Não alterado ou reexportado o PDF do usuário.
`git diff --check` passou. Só documentação, fixtures e verificador de contrato
entram na entrega; arquivos de importação gerados pelo engine são restaurados.

Incidentes de ambiente: launcher de `.tools/godot` falhou com CreateProcess 193;
engine de revisão respondeu versão correta. Primeira importação desse engine no
sandbox acusou falha ao gravar preferências portáteis. Reexecução autorizada fora
do sandbox passou por completo, sem SkipEditorImport e sem alterar o engine/addon.

## Limitações e gate de conclusão

O código do jogo não foi alterado. As fixtures são oráculos de especificação,
não testes da futura implementação. Durabilidade Windows, migração real,
interações simultâneas, desempenho, input das 18 runas/33 construções e diversão
precisam dos épicos próprios. Não houve playtest de classes que ainda não existem.

O aceite técnico e o aceite de design explícito fecham a entrega de E00.1–E00.3.
O estado **ACEITO** refere-se ao contrato documental, conforme o handoff.
Nenhum merge/push, atualização de playtest ou início de E01–E11 integra esta entrega.

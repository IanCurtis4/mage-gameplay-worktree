#!/usr/bin/env python3
"""Luna: supervisao de execucao da evidencia F9 (somente leitura).

Verifica execucao, conclusao, erros, hashes e inputs dos cinco stages.
Nao altera nenhum arquivo de evidencia. Gera report.md em pt-BR.
"""
import datetime
import json
import os
import re
import sys

BASE = "/mnt/user-data/uploads/RagRPG/.tools/claude_bridge/outbox"
OUT_DIR = "/home/claude/f9/luna_audit"
REPORT = os.path.join(OUT_DIR, "report.md")
EXPECTED_SHA = "AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424"

# (stage, contagem esperada pelo runner, marcador do resultado no output.log)
STAGES = [
    ("CandidateBatch", 18, "F9_CANDIDATE_BATCH_RESULT"),
    ("GameplayWindow", 33, "F9_WINDOW_RESULT"),
    ("GameplayCli", 18, "F9_GAMEPLAY_CLI_RESULT"),
    ("GameplayControls", 29, "F9_CONTROLS_RESULT"),
    ("GameplayNative", 52, "F9_GAMEPLAY_RESULT"),
]

CB_REQUIRED_INPUTS = [
    "tests/map_editor_gameplay_candidate_batch_test.gd.uid",
    "scripts/map_authoring/preview/gameplay_candidate.gd",
]

ERROR_PATTERNS = [
    ("SCRIPT ERROR", re.compile(r"SCRIPT ERROR")),
    ("Parse Error", re.compile(r"Parse Error")),
    ("linha ERROR:", re.compile(r"^ERROR:", re.MULTILINE)),
]
WARNING_PATTERN = re.compile(r"WARNING")


def read_text(path):
    """Le um log como bytes e decodifica sem alterar o arquivo."""
    with open(path, "rb") as fh:
        raw = fh.read()
    note = ""
    if raw.startswith(b"\xff\xfe") or raw.startswith(b"\xfe\xff"):
        text = raw.decode("utf-16")
        note = "utf-16-bom"
    elif raw.startswith(b"\xef\xbb\xbf"):
        text = raw[3:].decode("utf-8", errors="replace")
        note = "utf-8-bom"
    else:
        try:
            text = raw.decode("utf-8")
            note = "utf-8"
        except UnicodeDecodeError:
            text = raw.decode("utf-8", errors="replace")
            note = "utf-8 com substituicoes"
    if "\x00" in text:
        text = text.replace("\x00", "")
        note += " (NULs removidos)"
    return text, note


def parse_utc(value):
    """Converte timestamps ISO com fracao de qualquer tamanho para segundos."""
    m = re.match(r"^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(\.\d+)?Z$", value)
    if not m:
        raise ValueError("timestamp invalido: %r" % value)
    base = datetime.datetime.strptime(m.group(1), "%Y-%m-%dT%H:%M:%S")
    base = base.replace(tzinfo=datetime.timezone.utc)
    frac = float("0" + (m.group(2) or ".0"))
    return base.timestamp() + frac


def extract_marker_json(text, marker):
    """Retorna (ocorrencias, json_parseado_ou_None) da linha do marcador."""
    occurrences = [line for line in text.splitlines() if marker in line]
    if not occurrences:
        return 0, None, "marcador ausente"
    line = occurrences[0]
    payload = line.split(marker, 1)[1].strip()
    try:
        obj, _ = json.JSONDecoder().raw_decode(payload)
    except json.JSONDecodeError as exc:
        return len(occurrences), None, "JSON do marcador invalido: %s" % exc
    return len(occurrences), obj, ""


def load_manifest(stage):
    path = os.path.join(BASE, "luna_" + stage, "runs.json")
    with open(path, "rb") as fh:
        return json.loads(fh.read().decode("utf-8"))


def audit_stage(stage, expected_count, marker):
    folder = os.path.join(BASE, "luna_" + stage)
    man = load_manifest(stage)
    res = man.get("result") or {}
    checks = res.get("checks") or []
    failed_list = res.get("failed")
    inputs = man.get("inputs") or []

    out = {"stage": stage, "expected": expected_count, "criteria": {}, "notes": [],
           "errors_found": [], "warnings": [], "duration_s": None,
           "head": None, "engine_sha": man.get("engine_sha256"), "count": res.get("count"),
           "inputs_n": len(inputs), "inputs": inputs, "marker_occ": 0}

    # Identidade do manifesto (meta, nao reprova por si so; registrada como nota).
    if man.get("stage") != stage:
        out["notes"].append("stage do manifesto (%r) difere da pasta (%r)" % (man.get("stage"), stage))

    # 1. Execucao
    c1_fail = []
    if man.get("ok") is not True:
        c1_fail.append("ok=%r" % man.get("ok"))
    if man.get("exit_code") != 0:
        c1_fail.append("exit_code=%r" % man.get("exit_code"))
    if man.get("timed_out") is not False:
        c1_fail.append("timed_out=%r" % man.get("timed_out"))
    if man.get("aborted") is not False:
        c1_fail.append("aborted=%r" % man.get("aborted"))
    out["criteria"]["1_execucao"] = ("PASS" if not c1_fail else "FAIL", "; ".join(c1_fail) or "ok, exit 0, sem timeout/abort")

    # 2. Resultado do runner
    c2_fail = []
    if res.get("ok") is not True:
        c2_fail.append("result.ok=%r" % res.get("ok"))
    if res.get("count") != expected_count:
        c2_fail.append("count=%r (esperado %d)" % (res.get("count"), expected_count))
    if res.get("expected_count") is not None and res.get("expected_count") != expected_count:
        c2_fail.append("expected_count=%r (esperado %d)" % (res.get("expected_count"), expected_count))
    if len(checks) != res.get("count"):
        c2_fail.append("len(checks)=%d != count=%r" % (len(checks), res.get("count")))
    if "failed" not in res:
        c2_fail.append("campo 'failed' AUSENTE no manifesto (criterio exige lista vazia explicita; nao foi possivel verificar)")
    elif failed_list != []:
        c2_fail.append("failed=%r" % (failed_list,))
    bad = [c.get("id") for c in checks if c.get("ok") is not True]
    if bad:
        c2_fail.append("checks nao ok: %s" % ", ".join(str(b) for b in bad))
    out["criteria"]["2_resultado"] = ("PASS" if not c2_fail else "FAIL",
                                       "; ".join(c2_fail) or "%d/%d checks ok" % (len(checks), expected_count))

    # 3. Erros nos dois logs
    text_out, enc_out = read_text(os.path.join(folder, "geometry.output.log"))
    text_eng, enc_eng = read_text(os.path.join(folder, "geometry.engine.log"))
    out["notes"].append("encoding output.log: %s; engine.log: %s" % (enc_out, enc_eng))
    c3_fail = []
    for logname, text in (("geometry.output.log", text_out), ("geometry.engine.log", text_eng)):
        for label, pat in ERROR_PATTERNS:
            for m in pat.finditer(text):
                line_start = text.rfind("\n", 0, m.start()) + 1
                line_end = text.find("\n", m.end())
                line = text[line_start:line_end if line_end != -1 else len(text)].strip()
                out["errors_found"].append("%s [%s]: %s" % (logname, label, line[:200]))
        for line in text.splitlines():
            if WARNING_PATTERN.search(line):
                out["warnings"].append("%s: %s" % (logname, line.strip()[:200]))
    if out["errors_found"]:
        c3_fail.append("%d ocorrencia(s) de erro" % len(out["errors_found"]))
    out["criteria"]["3_sem_erros_nos_logs"] = ("PASS" if not c3_fail else "FAIL",
                                               "; ".join(c3_fail) or "nenhuma ocorrencia (WARNINGs: %d)" % len(out["warnings"]))

    # 4. HEAD e SHA do engine
    head_before = man.get("head_before")
    head_after = man.get("head_after")
    out["head"] = head_before
    c4_fail = []
    if head_before != head_after:
        c4_fail.append("head_before=%s != head_after=%s" % (head_before, head_after))
    eng_sha = (man.get("engine_sha256") or "")
    if eng_sha.lower() != EXPECTED_SHA.lower():
        c4_fail.append("engine_sha256=%s" % eng_sha)
    out["criteria"]["4_head_e_engine"] = ("PASS" if not c4_fail else "FAIL",
                                          "; ".join(c4_fail) or "head %s igual antes/depois; SHA do engine confere" % head_before)

    # 5. Marcador do resultado no output.log (e JSON coerente com o manifesto)
    occ, marker_obj, marker_err = extract_marker_json(text_out, marker)
    out["marker_occ"] = occ
    c5_fail = []
    if marker_obj is None:
        c5_fail.append(marker_err or "marcador invalido")
    else:
        if marker_obj.get("ok") is not True:
            c5_fail.append("marcador ok=%r" % marker_obj.get("ok"))
        if marker_obj.get("count") != expected_count:
            c5_fail.append("marcador count=%r" % marker_obj.get("count"))
        mk_ids = [(c.get("id"), c.get("ok")) for c in (marker_obj.get("checks") or [])]
        mf_ids = [(c.get("id"), c.get("ok")) for c in checks]
        if mk_ids != mf_ids:
            c5_fail.append("checks do marcador diferem do manifesto")
    if occ > 1:
        out["notes"].append("marcador aparece %d vezes no output.log (usada a primeira)" % occ)
    out["criteria"]["5_marcador"] = ("PASS" if not c5_fail else "FAIL",
                                     "; ".join(c5_fail) or "%s presente, %d checks identicos ao manifesto" % (marker, len(mf_ids)))

    # 6. Inputs (contagem e consistencia interna; cruzamento entre stages e feito depois)
    dup = {}
    for item in inputs:
        dup.setdefault(item.get("path"), set()).add((item.get("sha256") or "").upper())
    internal_div = [p for p, shas in dup.items() if len(shas) > 1]
    c6_fail = []
    if not inputs:
        c6_fail.append("nenhum input registrado")
    if internal_div:
        c6_fail.append("%d path(s) com hashes divergentes dentro do proprio stage" % len(internal_div))
    out["criteria"]["6_inputs"] = ("PASS" if not c6_fail else "FAIL",
                                   "; ".join(c6_fail) or "%d inputs; sem divergencia interna" % len(inputs))

    # 7. Process exit (so GameplayCli)
    if stage == "GameplayCli":
        pps = man.get("preview_process_exit")
        if isinstance(pps, dict) and pps.get("all_closed") is True:
            out["criteria"]["7_preview_process_exit"] = ("PASS", "all_closed=true; pids=%s" % (pps.get("pids"),))
        else:
            out["criteria"]["7_preview_process_exit"] = ("FAIL", "preview_process_exit=%s" % (json.dumps(pps, ensure_ascii=False)))
    else:
        out["criteria"]["7_preview_process_exit"] = ("N/A", "aplicavel so a GameplayCli")

    # 8. Inputs obrigatorios do CandidateBatch
    if stage == "CandidateBatch":
        by_path = {}
        for item in inputs:
            by_path.setdefault(item.get("path"), []).append((item.get("sha256") or "").upper())
        missing = [p for p in CB_REQUIRED_INPUTS if p not in by_path]
        if missing:
            out["criteria"]["8_inputs_candidate"] = ("FAIL", "ausentes: %s" % ", ".join(missing))
        else:
            shas = "; ".join("%s=%s" % (p, by_path[p][0]) for p in CB_REQUIRED_INPUTS)
            out["criteria"]["8_inputs_candidate"] = ("PASS", shas)
            out["candidate_hashes"] = {p: by_path[p][0] for p in CB_REQUIRED_INPUTS}
    else:
        out["criteria"]["8_inputs_candidate"] = ("N/A", "aplicavel so a CandidateBatch")

    # 9. Duracao
    try:
        s = parse_utc(man["started_utc"])
        f = parse_utc(man["finished_utc"])
        out["duration_s"] = round(f - s, 3)
        out["started_utc"] = man["started_utc"]
        out["finished_utc"] = man["finished_utc"]
        out["criteria"]["9_duracao"] = ("INFO", "%.3f s" % out["duration_s"])
    except (KeyError, ValueError) as exc:
        out["criteria"]["9_duracao"] = ("FAIL", "nao calculada: %s" % exc)

    return out


def cross_stage_inputs(per_stage):
    """Compara hashes do MESMO path entre stages."""
    by_path = {}
    for st in per_stage:
        for item in st["inputs"]:
            p = item.get("path")
            sha = (item.get("sha256") or "").upper()
            by_path.setdefault(p, {}).setdefault(st["stage"], set()).add(sha)
    divergences = []
    for p, stages in by_path.items():
        all_shas = set()
        for shas in stages.values():
            all_shas |= shas
        if len(all_shas) > 1:
            divergences.append((p, {k: sorted(v) for k, v in stages.items()}))
    per_stage_paths = {st["stage"]: set(i.get("path") for i in st["inputs"]) for st in per_stage}
    common = set.intersection(*per_stage_paths.values()) if per_stage_paths else set()
    union = set.union(*per_stage_paths.values()) if per_stage_paths else set()
    return divergences, len(common), len(union), per_stage_paths


def md_escape(s):
    return str(s).replace("|", "\\|").replace("\n", " ")


def build_report(per_stage, divergences, n_common, n_union, per_stage_paths):
    lines = []
    all_pass = True
    for st in per_stage:
        for k, (verdict, _) in st["criteria"].items():
            if verdict == "FAIL":
                all_pass = False
    if divergences:
        all_pass = False
    overall = "PASS" if all_pass else "FAIL"

    lines.append("# Luna: supervisao de execucao F9")
    lines.append("")
    lines.append("**Veredito geral: %s**" % overall)
    lines.append("")
    lines.append("Engine esperada: Godot 4.7.2 standard, SHA256 `%s`." % EXPECTED_SHA)
    lines.append("")
    lines.append("## Tabela por stage")
    lines.append("")
    lines.append("| Stage | Esperado | Count | Exit | ok | Timeout | Abort | HEAD antes=depois | Inputs | Duracao (s) | Veredito |")
    lines.append("|---|---|---|---|---|---|---|---|---|---|---|")
    for st in per_stage:
        stage_pass = all(v != "FAIL" for v, _ in st["criteria"].values())
        # reconstruct fields from criteria notes is avoided; use stored values
        lines.append("| %s | %d | %s | %s | %s | %s | %s | %s | %d | %s | %s |" % (
            st["stage"], st["expected"], st["count"], st["exit_code"], st["ok"], st["timed_out"], st["aborted"],
            "sim (%s)" % st["head"][:12] if st["head_eq"] else "NAO",
            st["inputs_n"], "%.3f" % st["duration_s"] if st["duration_s"] is not None else "n/a",
            "PASS" if stage_pass else "FAIL"))
    lines.append("")
    lines.append("## Criterios por stage")
    lines.append("")
    crit_names = [
        ("1_execucao", "1. Execucao (ok, exit 0, sem timeout/abort)"),
        ("2_resultado", "2. Resultado do runner (count, checks, failed)"),
        ("3_sem_erros_nos_logs", "3. Sem SCRIPT ERROR / Parse Error / ERROR: nos logs"),
        ("4_head_e_engine", "4. HEAD antes=depois e SHA do engine"),
        ("5_marcador", "5. Marcador do resultado no output.log"),
        ("6_inputs", "6. Inputs (contagem e consistencia interna)"),
        ("7_preview_process_exit", "7. preview_process_exit.all_closed (GameplayCli)"),
        ("8_inputs_candidate", "8. Inputs obrigatorios do CandidateBatch"),
        ("9_duracao", "9. Duracao"),
    ]
    header = "| Criterio | " + " | ".join(st["stage"] for st in per_stage) + " |"
    lines.append(header)
    lines.append("|---|" + "---|" * len(per_stage))
    for key, label in crit_names:
        cells = []
        for st in per_stage:
            v, _ = st["criteria"][key]
            cells.append(v)
        lines.append("| %s | %s |" % (label, " | ".join(cells)))
    lines.append("")
    lines.append("## Detalhes")
    lines.append("")
    for st in per_stage:
        lines.append("### %s" % st["stage"])
        lines.append("")
        for key, label in crit_names:
            v, detail = st["criteria"][key]
            lines.append("- **%s**: %s. %s" % (label, v, md_escape(detail)))
        if st["errors_found"]:
            lines.append("- **Ocorrencias de erro**:")
            for e in st["errors_found"]:
                lines.append("  - `%s`" % md_escape(e))
        if st["warnings"]:
            lines.append("- **WARNING (nao reprovam)**: %d" % len(st["warnings"]))
            for w in st["warnings"]:
                lines.append("  - `%s`" % md_escape(w))
        for n in st["notes"]:
            lines.append("- Nota: %s" % md_escape(n))
        lines.append("")

    lines.append("## Hashes-chave")
    lines.append("")
    lines.append("- SHA256 do engine (registrado por todos os stages): `%s`" % per_stage[0]["engine_sha"])
    heads = set(st["head"] for st in per_stage)
    lines.append("- HEAD (antes=depois, todos os stages): `%s`" % (", ".join(sorted(heads))))
    cb = [st for st in per_stage if st["stage"] == "CandidateBatch"][0]
    if "candidate_hashes" in cb:
        for p, sha in cb["candidate_hashes"].items():
            lines.append("- `%s` sha256 `%s`" % (p, sha))
    lines.append("")

    lines.append("## Inputs entre stages")
    lines.append("")
    lines.append("- Paths distintos somados: %d; presentes em todos os 5 stages: %d." % (n_union, n_common))
    if divergences:
        lines.append("- **Divergencias de hash para o mesmo path (FAIL):** %d" % len(divergences))
        for p, stages in divergences[:50]:
            lines.append("  - `%s`: %s" % (p, json.dumps(stages, ensure_ascii=False)))
    else:
        lines.append("- Divergencias de hash para o mesmo path: nenhuma. Os inputs em comum estao congelados entre execucoes.")
    lines.append("")

    lines.append("## Limites")
    lines.append("")
    lines.append("- Esta e **supervisao de execucao**, nao auditoria semantica do codigo. Confirma que a selecao rodou na engine registrada, que o runner marcou conclusao sem erro, que os checks reportados passaram e que os hashes batem. Nao verifica se os testes medem a coisa certa nem se a implementacao esta correta.")
    lines.append("- **FPS, desempenho e jogabilidade nao estao provados** por estes logs. Os checks sao funcionais; nao ha medicao de frame rate nem avaliacao de experiencia.")
    lines.append("- Os PNGs de captura do stage GameplayNative (`gameplay_bridge.png`, `gameplay_combat.png`) nao foram inspecionados por esta auditoria.")
    lines.append("- Os hashes de inputs provam o conteudo registrado no manifesto, nao a correcao do conteudo. O executavel Windows nao esta disponivel neste ambiente; o SHA256 e o registrado pelo runner, nao reverificado localmente.")
    lines.append("- Nenhum arquivo de evidencia foi alterado; a leitura foi feita em modo somente leitura.")
    lines.append("")
    return "\n".join(lines), overall


def main():
    per_stage = []
    for stage, expected, marker in STAGES:
        st = audit_stage(stage, expected, marker)
        # campos auxiliares para a tabela
        man = load_manifest(stage)
        st["exit_code"] = man.get("exit_code")
        st["ok"] = man.get("ok")
        st["timed_out"] = man.get("timed_out")
        st["aborted"] = man.get("aborted")
        st["head_eq"] = man.get("head_before") == man.get("head_after")
        st["head"] = man.get("head_before") or ""
        per_stage.append(st)

    divergences, n_common, n_union, per_stage_paths = cross_stage_inputs(per_stage)
    text, overall = build_report(per_stage, divergences, n_common, n_union, per_stage_paths)

    os.makedirs(OUT_DIR, exist_ok=True)
    with open(REPORT, "w", encoding="utf-8") as fh:
        fh.write(text)

    print("Veredito geral:", overall)
    for st in per_stage:
        print(st["stage"], {k: v[0] for k, v in st["criteria"].items()})
    print("Divergencias de input entre stages:", len(divergences))
    print("Relatorio:", REPORT)
    return 0 if overall == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())

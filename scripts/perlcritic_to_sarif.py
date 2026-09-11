#!/usr/bin/env python3
"""
Конвертира изхода на `perlcritic --verbose "%f|||%l|||%c|||%s|||%p|||%m\n"`
в SARIF 2.1.0 файл (за GitHub Code Scanning) и в самостоятелен HTML доклад
(за човешко четене / архивиране).
"""
import html
import json
import sys
from collections import defaultdict
from pathlib import Path

INPUT_FILE = sys.argv[1] if len(sys.argv) > 1 else "perlcritic-output.txt"
OUTPUT_FILE = sys.argv[2] if len(sys.argv) > 2 else "perlcritic.sarif"
HTML_OUTPUT_FILE = sys.argv[3] if len(sys.argv) > 3 else "perlcritic-report.html"

# Perl::Critic severity: 1 (least severe) .. 5 (most severe)
SEVERITY_TO_LEVEL = {
    "5": "error",
    "4": "error",
    "3": "warning",
    "2": "note",
    "1": "note",
}

rules = {}
results = []
violations = []  # суров списък, ползван и за SARIF, и за HTML

path = Path(INPUT_FILE)
if path.exists():
    for raw_line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw_line.strip()
        if not line or "|||" not in line:
            continue
        parts = line.split("|||")
        if len(parts) != 6:
            continue
        file_path, line_no, col_no, severity, policy, message = parts

        rule_id = policy.strip()
        file_path = file_path.strip().replace("\\", "/")
        line_no_i = max(int(line_no or 1), 1)
        col_no_i = max(int(col_no or 1), 1)
        severity_s = severity.strip()
        message_s = message.strip()

        if rule_id not in rules:
            rules[rule_id] = {
                "id": rule_id,
                "name": rule_id,
                "shortDescription": {"text": rule_id},
                "helpUri": f"https://metacpan.org/pod/{rule_id}",
            }

        results.append({
            "ruleId": rule_id,
            "level": SEVERITY_TO_LEVEL.get(severity_s, "warning"),
            "message": {"text": message_s},
            "locations": [{
                "physicalLocation": {
                    "artifactLocation": {"uri": file_path},
                    "region": {"startLine": line_no_i, "startColumn": col_no_i},
                }
            }],
        })

        violations.append({
            "file": file_path,
            "line": line_no_i,
            "column": col_no_i,
            "severity": severity_s,
            "policy": rule_id,
            "message": message_s,
        })

sarif = {
    "$schema": "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json",
    "version": "2.1.0",
    "runs": [{
        "tool": {
            "driver": {
                "name": "Perl::Critic",
                "informationUri": "https://metacpan.org/pod/Perl::Critic",
                "rules": list(rules.values()),
            }
        },
        "results": results,
    }],
}

Path(OUTPUT_FILE).write_text(json.dumps(sarif, indent=2), encoding="utf-8")
print(f"Записани {len(results)} нарушения в {OUTPUT_FILE}")

# ---------------------------------------------------------------------------
# HTML доклад
# ---------------------------------------------------------------------------

SEVERITY_LABEL = {
    "5": "Severity 5 (най-тежко)",
    "4": "Severity 4",
    "3": "Severity 3",
    "2": "Severity 2",
    "1": "Severity 1 (най-леко)",
}
SEVERITY_CSS = {
    "5": "sev-5", "4": "sev-4", "3": "sev-3", "2": "sev-2", "1": "sev-1",
}

by_file = defaultdict(list)
for v in violations:
    by_file[v["file"]].append(v)

severity_counts = defaultdict(int)
for v in violations:
    severity_counts[v["severity"]] += 1

rows_html = []
for file_path in sorted(by_file):
    file_violations = sorted(by_file[file_path], key=lambda v: (v["line"], v["column"]))
    rows_html.append(f'<h2>{html.escape(file_path)} <span class="count">({len(file_violations)})</span></h2>')
    rows_html.append('<table><thead><tr><th>Ред:Кол.</th><th>Severity</th><th>Policy</th><th>Съобщение</th></tr></thead><tbody>')
    for v in file_violations:
        sev_css = SEVERITY_CSS.get(v["severity"], "")
        rows_html.append(
            f'<tr class="{sev_css}">'
            f'<td>{v["line"]}:{v["column"]}</td>'
            f'<td>{html.escape(v["severity"])}</td>'
            f'<td>{html.escape(v["policy"])}</td>'
            f'<td>{html.escape(v["message"])}</td>'
            f'</tr>'
        )
    rows_html.append('</tbody></table>')

summary_html = "".join(
    f'<span class="badge {SEVERITY_CSS.get(sev, "")}">{html.escape(SEVERITY_LABEL.get(sev, sev))}: {count}</span>'
    for sev, count in sorted(severity_counts.items(), key=lambda kv: kv[0], reverse=True)
)

html_doc = f"""<!DOCTYPE html>
<html lang="bg">
<head>
<meta charset="UTF-8">
<title>Perl::Critic - доклад</title>
<style>
  body {{ font-family: -apple-system, Segoe UI, Arial, sans-serif; margin: 2rem; color: #1a1a1a; }}
  h1 {{ margin-bottom: 0.2rem; }}
  .meta {{ color: #666; margin-bottom: 1.5rem; }}
  .summary {{ margin-bottom: 2rem; }}
  .badge {{ display: inline-block; padding: 0.3rem 0.7rem; border-radius: 6px; margin-right: 0.5rem; font-size: 0.9rem; font-weight: 600; }}
  h2 {{ margin-top: 2rem; border-bottom: 2px solid #eee; padding-bottom: 0.3rem; }}
  .count {{ color: #888; font-weight: normal; font-size: 0.9rem; }}
  table {{ width: 100%; border-collapse: collapse; margin-bottom: 1rem; }}
  th, td {{ text-align: left; padding: 0.5rem 0.7rem; border-bottom: 1px solid #eee; font-size: 0.92rem; }}
  th {{ background: #f5f5f5; }}
  tr.sev-5 {{ background: #ffecec; }}
  tr.sev-4 {{ background: #fff3ec; }}
  tr.sev-3 {{ background: #fffaec; }}
  tr.sev-2, tr.sev-1 {{ background: #fafafa; }}
  .badge.sev-5 {{ background: #ffb3b3; }}
  .badge.sev-4 {{ background: #ffd0b3; }}
  .badge.sev-3 {{ background: #ffedb3; }}
  .badge.sev-2, .badge.sev-1 {{ background: #e0e0e0; }}
</style>
</head>
<body>
  <h1>Perl::Critic — доклад за анализ</h1>
  <div class="meta">Общо нарушения: {len(violations)} · Файлове с нарушения: {len(by_file)}</div>
  <div class="summary">{summary_html}</div>
  {"".join(rows_html) if violations else "<p>Няма намерени нарушения.</p>"}
</body>
</html>
"""

Path(HTML_OUTPUT_FILE).write_text(html_doc, encoding="utf-8")
print(f"HTML доклад записан в {HTML_OUTPUT_FILE}")
# Reports

Output artifacts from security assessments, baseline scans, and the periodic PoC summary cuts.

## PoC Summary Reports

| Version | Date | File | Status |
|---|---|---|---|
| v1.1 | 2026-05-23 | `2026-05-23-poc-summary-v1.1.md` (canonical) + `.pdf` | **Current** |
| v1.0 | 2026-04-26 | `2026-04-26-poc-summary.pdf` | Historical |

**Notes on v1.0 vs v1.1:** the April PDF is preserved unchanged as the original PoC deliverable. It contains figures that have since moved on in production:

| Field | v1.0 (April) | v1.1 (May) |
|---|---|---|
| Modpack | Homestead 1.3.1 | Homestead 1.3.6 |
| Server-side mods | 312 | 427 |
| VPS tier | CX32 (incorrect in v1.0) | CX43 |
| Pentest stats | Medium:6 / Low:4 / Info:7 | Medium:7 / Low:5 / Info:5 |
| Remediation framing | "80% of actionable findings" | "7 of 8 non-accepted actionable" |
| Threat-model statuses | Many "Planned — Block N" | Updated to Implemented / Partial / Tested |

For current state, **use v1.1**. The v1.0 PDF is kept for audit-trail continuity and to show the delta over time.

## Other Artifacts

| File | Origin | Notes |
|---|---|---|
| `2026-04-26-ZAP-Report.html` (+ asset dir) | OWASP ZAP DAST | Generated against api.geigercapital.us and map.geigercapital.us |
| `lynis-baseline-summary.md` | Lynis CIS benchmark | Post-remediation score 67/100 (baseline was 65) |
| `lynis-baseline.txt` | Lynis raw output | Gitignored — re-run on the VPS to regenerate |
| `nikto-api.txt` | Nikto web scanner | API endpoint findings |
| `nikto-bluemap.txt` | Nikto web scanner | BlueMap endpoint findings |
| `nmap-summary.md` | nmap port scan | Summarised findings (full output gitignored) |

## Regenerating

- PoC summary PDF: `cupsfilter -i text/plain reports/2026-05-23-poc-summary-v1.1.md > reports/2026-05-23-poc-summary-v1.1.pdf`
- Lynis baseline: `sudo lynis audit system --report-file /tmp/lynis-report.txt` on the VPS
- nmap: `nmap -sV -p- mc.geigercapital.us` (full TCP) + `nmap -sU -F mc.geigercapital.us` (UDP)
- nikto: `nikto -h https://api.geigercapital.us -o reports/nikto-api.txt`
- ZAP: triggered by `.github/workflows/zap.yml` on a schedule

# Control Framework — Homestead SDLC PoC

## Mapping Methodology
Controls mapped to SOC 2 Trust Services Criteria (TSC),
ISO 27001 Annex A, and NIST Cybersecurity Framework (CSF).

## Control Inventory

| ID | Control | Implementation | SOC 2 | ISO 27001 | NIST CSF |
|---|---|---|---|---|---|
| C-001 | SSH key-only authentication | PasswordAuthentication no in sshd_config | CC6.1, CC6.2 | A.9.4.2 | PR.AC-1 |
| C-002 | Non-standard SSH port | Port 2222 in sshd_config | CC6.6 | A.9.4.2 | PR.AC-1 |
| C-003 | Root login disabled | PermitRootLogin no | CC6.1 | A.9.2.3 | PR.AC-1 |
| C-004 | fail2ban brute force protection | /etc/fail2ban/jail.local | CC6.1, CC7.2 | A.9.4.2 | DE.CM-1 |
| C-005 | Dual firewall layer | UFW + Hetzner firewall | CC6.6 | A.13.1.1 | PR.AC-5 |
| C-006 | RCON localhost binding | enable-rcon=true, localhost only | CC6.1 | A.9.4.2 | PR.AC-5 |
| C-007 | Secrets file restricted permissions | chmod 640, root:minecraft | CC6.1 | A.9.4.3 | PR.AC-1 |
| C-008 | No secrets in version control | gitleaks pre-commit hook | CC6.1 | A.9.4.3 | PR.DS-5 |
| C-009 | Branch protection on main | GitHub branch protection rules | CC8.1 | A.14.2.2 | PR.IP-1 |
| C-010 | Pull request review required | 1 required reviewer | CC8.1 | A.14.2.2 | PR.IP-1 |
| C-011 | Mod integrity verification | SHA-256 checksums, systemd ExecStartPre | CC7.1 | A.12.5.1 | PR.DS-6 |
| C-012 | Software bill of materials | docs/sbom.md | CC7.1 | A.12.5.1 | ID.SC-2 |
| C-013 | Automated SAST | CodeQL via GitHub Actions | CC7.1 | A.14.2.8 | DE.CM-4 |
| C-014 | Dependency scanning | Dependabot alerts and updates | CC7.1 | A.12.6.1 | DE.CM-4 |
| C-015 | IaC security scanning | Checkov via GitHub Actions | CC7.1 | A.14.2.5 | DE.CM-4 |
| C-016 | DAST scanning | OWASP ZAP via GitHub Actions | CC7.1 | A.14.2.8 | DE.CM-4 |
| C-017 | System metrics monitoring | Prometheus + Node Exporter | CC7.2 | A.12.1.3 | DE.CM-1 |
| C-018 | Application metrics monitoring | Minecraft Exporter + Grafana | CC7.2 | A.12.1.3 | DE.CM-1 |
| C-019 | Availability monitoring | Uptime Kuma — 3 monitors | A1.1, A1.2 | A.17.1.1 | DE.CM-1 |
| C-020 | Security audit logging | JSON structured event log | CC7.2 | A.12.4.1 | DE.AE-3 |
| C-021 | Daily world backups | systemd timer, 7-day retention | A1.2, A1.3 | A.12.3.1 | RC.RP-1 |
| C-022 | Automated deployment | GitHub Actions SSH deploy | CC8.1 | A.14.2.2 | PR.IP-1 |
| C-023 | Conventional commits | Enforced commit message format | CC8.1 | A.14.2.2 | PR.IP-1 |
| C-024 | Change management via PR | All changes via pull request | CC8.1 | A.14.2.2 | PR.IP-1 |
| C-025 | TLS on web services | Let's Encrypt via certbot | CC6.6 | A.10.1.1 | PR.DS-2 |
| C-026 | HTTP security headers | X-Frame, CSP, HSTS, etc | CC6.6 | A.14.2.5 | PR.DS-2 |
| C-027 | Rate limiting | Nginx limit_req_zone | CC6.6 | A.13.1.1 | PR.AC-5 |
| C-028 | Non-root service accounts | minecraft user for server process | CC6.1 | A.9.2.3 | PR.AC-1 |
| C-029 | Penetration testing | Self-assessment, 18 findings | CC7.1 | A.14.2.8 | ID.RA-1 |
| C-030 | Incident response runbooks | Three documented scenarios | CC7.3 | A.16.1.1 | RS.RP-1 |

## Coverage Summary

### SOC 2 Trust Services Criteria
| Category | Controls | Coverage |
|---|---|---|
| Security (CC) | C-001 through C-029 | High |
| Availability (A) | C-019, C-021 | Medium |
| Confidentiality (C) | C-007, C-008, C-025 | Medium |
| Processing Integrity (PI) | C-011, C-012 | Medium |
| Privacy (P) | See privacy-notice.md | Medium |

### ISO 27001 Annex A Coverage
| Domain | Controls Addressed |
|---|---|
| A.9 Access Control | C-001 through C-007, C-028 |
| A.10 Cryptography | C-025 |
| A.12 Operations Security | C-011, C-017, C-021 |
| A.13 Communications Security | C-005, C-027 |
| A.14 System Development | C-013 through C-016, C-022 through C-024 |
| A.16 Incident Management | C-030 |
| A.17 Business Continuity | C-019, C-021 |

### NIST CSF Coverage
| Function | Controls |
|---|---|
| Identify | C-012, C-029 |
| Protect | C-001 through C-011, C-025 through C-028 |
| Detect | C-013 through C-020 |
| Respond | C-030 |
| Recover | C-021 |

# Threat Model — Homestead SMP SDLC PoC

## Version
v1.0 — Initial assessment

## Methodology
STRIDE per component analysis across all identified attack surface elements.

## Scope
- Hetzner CX32 VPS (Minecraft server)
- Hetzner CX22 VPS (AI research — separate instance)
- Cloudflare DNS and Pages
- GitHub repository and CI/CD pipeline

## Asset Inventory

| Asset | Type | Sensitivity | Owner |
|---|---|---|---|
| World data | File | High | Server |
| Player UUIDs and IPs | Data | High | Server |
| RCON credentials | Secret | Critical | Admin |
| SSH private key | Secret | Critical | Admin |
| GitHub deploy key | Secret | Critical | Admin |
| Mod files | Binary | Medium | Server |
| Server logs | Data | Medium | Server |
| BlueMap tile data | File | Low | Server |
| Public site | Web | Low | Cloudflare |

## Attack Surface

### Network Ports
| Port | Protocol | Service | Exposure |
|---|---|---|---|
| 2222 | TCP | SSH | Public |
| 25565 | TCP | Minecraft | Public |
| 8100 | TCP | BlueMap | Localhost only (Nginx proxies) |
| 24454 | UDP | Voice Chat | Public |
| 25575 | TCP | RCON | Localhost only |
| 80 | TCP | Nginx | Public |
| 3000 | TCP | Grafana | Restricted |
| 9090 | TCP | Prometheus | Restricted |


## STRIDE Analysis

### Component: SSH (Port 2222)

| Threat | Category | Likelihood | Impact | Risk | Control | Status |
|---|---|---|---|---|---|---|
| Brute force credential attack | Spoofing | Low | Critical | Medium | fail2ban, key-only auth | Implemented |
| SSH key compromise | Spoofing | Low | Critical | Medium | Ed25519 key, no passphrase on deploy key | Partial |
| Man in the middle on initial connect | Tampering | Low | High | Low | Known host fingerprint | Manual |
| No audit trail of SSH sessions | Repudiation | Medium | Medium | Medium | auditd planned | Planned |
| Sensitive data in SSH session | Information Disclosure | Low | Medium | Low | Encrypted transport | Implemented |
| SSH service unavailable | Denial of Service | Low | High | Low | Hetzner web console fallback | Accepted |
| Root login via SSH | Elevation of Privilege | Low | Critical | Medium | PermitRootLogin no | Implemented |

### Component: Minecraft Protocol (Port 25565)

| Threat | Category | Likelihood | Impact | Risk | Control | Status |
|---|---|---|---|---|---|---|
| Player impersonation | Spoofing | Low | High | Medium | online-mode=true, Mojang auth | Implemented |
| Malformed packet injection | Tampering | Medium | High | High | Neruina crash handler | Implemented |
| No persistent chat audit log | Repudiation | High | Medium | High | Audit logger planned | Planned |
| Protocol sniffing | Information Disclosure | Low | Low | Low | Encrypted Minecraft protocol | Implemented |
| Packet flood / DDoS | Denial of Service | Medium | High | High | UFW rate limiting planned | Planned |
| OP privilege escalation via exploit | Elevation of Privilege | Low | Critical | Medium | online-mode, no known exploits | Monitor |

### Component: RCON (Port 25575)

| Threat | Category | Likelihood | Impact | Risk | Control | Status |
|---|---|---|---|---|---|---|
| Credential theft | Spoofing | Medium | Critical | High | Localhost only binding | Implemented |
| Command injection via RCON | Tampering | Low | Critical | Medium | Localhost only, trusted users | Implemented |
| No RCON command audit log | Repudiation | High | High | High | Audit logger planned | Planned |
| Password in plaintext | Information Disclosure | High | Critical | Critical | Secrets file migration planned | Planned |
| RCON service crash | Denial of Service | Low | Medium | Low | Server restart recovers RCON | Accepted |
| Full server control via RCON | Elevation of Privilege | Low | Critical | Medium | Localhost binding, strong password | Implemented |

### Component: BlueMap Web (Port 8100 / Nginx Port 80)

| Threat | Category | Likelihood | Impact | Risk | Control | Status |
|---|---|---|---|---|---|---|
| — | Spoofing | Low | Low | Low | No auth required by design | Accepted |
| Directory traversal | Tampering | Medium | High | High | ZAP DAST scanning | Planned |
| No access logging | Repudiation | Medium | Low | Low | Nginx access log enabled | Implemented |
| World data exposure via map tiles | Information Disclosure | Medium | Medium | Medium | Accepted — map is public | Accepted |
| HTTP flood | Denial of Service | Medium | Medium | Medium | Cloudflare proxy planned | Planned |
| — | Elevation of Privilege | Low | Low | Low | Read-only map data | Accepted |

### Component: Mod Supply Chain

| Threat | Category | Likelihood | Impact | Risk | Control | Status |
|---|---|---|---|---|---|---|
| Malicious mod impersonating legitimate one | Spoofing | Low | Critical | Medium | SHA-256 checksums planned | Planned |
| Jar file tampered post-download | Tampering | Low | Critical | Medium | Integrity check planned | Planned |
| No record of mod provenance | Repudiation | High | Medium | High | SBOM planned | Planned |
| Sensitive server data via mod exploit | Information Disclosure | Low | High | Medium | Mod source vetting | Manual |
| Malicious mod crashes server | Denial of Service | Low | High | Medium | Neruina crash handler | Implemented |
| Malicious mod executes arbitrary code | Elevation of Privilege | Low | Critical | High | Checksum verification planned | Planned |

### Component: KubeJS Scripts

| Threat | Category | Likelihood | Impact | Risk | Control | Status |
|---|---|---|---|---|---|---|
| — | Spoofing | Low | Low | Low | Scripts are server-side only | Accepted |
| Script injection via config file | Tampering | Low | High | Medium | File integrity monitoring planned | Planned |
| No script change audit trail | Repudiation | High | Medium | High | Git version control | Implemented |
| — | Information Disclosure | Low | Low | Low | No player data in scripts | Accepted |
| Malformed script crashes server | Denial of Service | Medium | High | High | Neruina, syntax validation | Partial |
| Script grants unintended permissions | Elevation of Privilege | Low | High | Medium | Script review process | Manual |

### Component: GitHub Repository and CI/CD

| Threat | Category | Likelihood | Impact | Risk | Control | Status |
|---|---|---|---|---|---|---|
| Compromised GitHub account | Spoofing | Low | Critical | High | 2FA on GitHub account | Verify |
| Malicious code in PR | Tampering | Low | High | Medium | Branch protection, PR review | Implemented |
| No PR review on solo project | Repudiation | High | Medium | Medium | Self-review documented | Accepted |
| Secret in committed code | Information Disclosure | Medium | Critical | High | gitleaks pre-commit hook | Implemented |
| CI pipeline taken offline | Denial of Service | Low | Low | Low | GitHub SLA | Accepted |
| Compromised deploy key grants VPS access | Elevation of Privilege | Low | Critical | High | Dedicated deploy key, restricted perms | Implemented |

## Risk Register Summary

| Risk ID | Component | Threat | Risk Level | Status |
|---|---|---|---|---|
| R-001 | RCON | Password in plaintext | Critical | Planned — Block 2 |
| R-002 | Minecraft | Packet flood / DDoS | High | Planned |
| R-003 | Mod Supply Chain | Arbitrary code execution | High | Planned — Block 3 |
| R-004 | Minecraft | No chat audit log | High | Planned — Block 5 |
| R-005 | RCON | No command audit log | High | Planned — Block 5 |
| R-006 | GitHub | Secret in committed code | High | Implemented |
| R-007 | BlueMap | Directory traversal | High | Planned — Sunday |
| R-008 | KubeJS | No script change audit | High | Implemented via git |
| R-009 | SSH | No session audit trail | Medium | Planned — Block 2 |
| R-010 | GitHub | Compromised deploy key | High | Implemented |

## Assumptions and Constraints
- Single administrator — no separation of duties achievable on solo project
- No budget for commercial tooling — free tier only
- Players assumed to be known trusted individuals
- Hetzner physical security accepted as given
- Cloudflare DDoS protection accepted as given for web layer

## Next Review
End of weekend project — update status fields as controls are implemented.

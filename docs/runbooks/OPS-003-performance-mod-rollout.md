# OPS-003 — Performance Mod Rollout (spark-first, supply-chain gated)

## Purpose

Add the standard Fabric 1.20.1 server-side performance stack — measured with
spark before and after — without weakening the mod supply-chain controls
(R-003 / C-controls: SHA-256 baseline + `ExecStartPre` verify gate). Every
jar is downloaded from Modrinth's CDN and verified against the SHA-512
pinned below *before* it enters `mods/`.

Baseline (2026-08-13): load ~2.8 on 8 cores, no PSI pressure, zero
performance mods in the 427-mod pack. This is headroom work, not a fix.

## Pinned artifacts (Modrinth, fabric + 1.20.1, resolved 2026-08-13)

| Mod | Version | File |
|---|---|---|
| spark | 1.10.53-fabric | spark-1.10.53-fabric.jar |
| FerriteCore | 6.0.1 | ferritecore-6.0.1-fabric.jar |
| ModernFix | 5.25.2+mc1.20.1 | modernfix-fabric-5.25.2+mc1.20.1.jar |
| Krypton | 0.2.3 | krypton-0.2.3.jar |
| Lithium | mc1.20.1-0.11.4 | lithium-fabric-mc1.20.1-0.11.4.jar |

SHA-512 manifest — save as `/tmp/modroll/SHA512SUMS` on the VPS:

```text
ce6e8f7071bb37369ad3e90d844926b424e82d0fe0ffd0db7058abddc9cfcdd594e145c9395677ad70ec532f3da0b23b6862d1f1c20f7600263c215abb4fcea7  spark-1.10.53-fabric.jar
9b7dc686bfa7937815d88c7bbc6908857cd6646b05e7a96ddbdcada328a385bd4ba056532cd1d7df9d2d7f4265fd48bd49ff683f217f6d4e817177b87f6bc457  ferritecore-6.0.1-fabric.jar
878e39d182767ffd08ad6a3539fae780739129db133abe02b9b73dc3df6e1ac9ddbe509620356b0aae5e7bfbed535d0e18741703334317a16fefef820269da2d  modernfix-fabric-5.25.2+mc1.20.1.jar
92b73a70737cfc1daebca211bd1525de7684b554be392714ee29cbd558f2a27a8bdda22accbe9176d6e531d74f9bf77798c28c3e8559c970f607422b6038bc9e  krypton-0.2.3.jar
31938b7e849609892ffa1710e41f2e163d11876f824452540658c4b53cd13c666dbdad8d200989461932bd9952814c5943e64252530c72bdd5d8641775151500  lithium-fabric-mc1.20.1-0.11.4.jar
```

Download URLs:

```text
https://cdn.modrinth.com/data/l6YH9Als/versions/XGW2fviP/spark-1.10.53-fabric.jar
https://cdn.modrinth.com/data/uXXizFIs/versions/unerR5MN/ferritecore-6.0.1-fabric.jar
https://cdn.modrinth.com/data/nmDcB62a/versions/rPmgLeZC/modernfix-fabric-5.25.2%2Bmc1.20.1.jar
https://cdn.modrinth.com/data/fQEb0iXm/versions/jiDwS0W1/krypton-0.2.3.jar
https://cdn.modrinth.com/data/gvQqBUqZ/versions/iEcXOkz4/lithium-fabric-mc1.20.1-0.11.4.jar
```

## Phase 0 — spark baseline + server.properties check

1. Download and verify:

   ```bash
   mkdir -p /tmp/modroll && cd /tmp/modroll
   # paste the SHA512SUMS block above into SHA512SUMS, then:
   curl -fsSLO <spark url>
   sha512sum -c --ignore-missing SHA512SUMS
   ```

2. Install through the integrity gate using the repo installer
   (`security/install-mods.sh`) — one invocation per phase. It re-verifies
   hashes, checks each jar's declared `fabricloader`/`breaks` constraints
   against the live server, installs, rebaselines checksums, does an
   announced restart, validates boot, and rolls the phase back automatically
   if the server does not return:

   ```bash
   sudo bash install-mods.sh /tmp/modroll spark-1.10.53-fabric.jar
   ```

3. Confirm the integrity gate passed: `sudo tail -2 /var/log/minecraft-integrity.log`
   (expect the new mod count) and the server came up.
4. While in there, check `grep -E "^(view|simulation)-distance" /opt/minecraft/homestead/server.properties`
   — targets: view-distance 8–10, simulation-distance 6–8.
5. Let spark run ≥24h with normal player load, then capture the baseline:
   `/spark profiler start --timeout 600` in-console (or via RCON), save the
   resulting URL in `reports/` notes.

## Phase 1 — the optimization mods, one per restart

Order (safest first): **FerriteCore → ModernFix → Krypton → Lithium**.
Lithium goes last — it patches the widest surface and is the only one with
meaningful mixin-conflict risk in a 427-mod pack.

For each mod (or a deliberately chosen batch), one installer invocation:

```bash
sudo bash install-mods.sh /tmp/modroll ferritecore-6.0.1-fabric.jar
```

The installer handles verify → install → rebaseline → announced restart →
boot validation, and rolls the batch back automatically on a failed boot.
One mod per restart keeps attribution trivial; batching the low-risk trio
with Lithium isolated in its own invocation is the accepted compressed
variant.

Compatibility verified 2026-08-13 against the live pack: Fabric Loader
0.18.6 satisfies every jar's constraint (strictest: ModernFix ≥0.16.10),
Fabric API 0.92.7 present for spark, and no installed mod matches any
declared `breaks` (hydrogen / optifabric / dashloader absent). The
preflight re-checks all of this on the box at install time.

## Phase 2 — world border + pre-generation (capacity control)

Bounding the world caps chunk-gen spikes *and* freezes the backup-size
math that caused the 2026-08-13 incident.

1. Pick a radius (e.g. 5000 blocks): `/worldborder center 0 0`,
   `/worldborder set 10000` (diameter).
2. Install Chunky (resolve current 1.20.1 fabric version + SHA-512 from
   Modrinth the same way), pre-generate: `/chunky radius 5000`,
   `/chunky start`. Expect hours; run overnight, it survives restarts.
3. When complete: remove the Chunky jar, regenerate checksums, restart.
   Chunky is a tool, not a resident — smaller attack/maintenance surface.
4. Record the new steady-state world size; revisit `CAP_GIB` if it shifts.

## Phase 3 — evidence and bookkeeping

- spark after-profile under comparable load; save both URLs.
- Add the retained mods to `docs/sbom.md` (name, version, date).
- CHANGELOG entry under the modpack section.
- Note in the threat model R-003 row that the perf mods entered via the
  standard gate (no control change).

## Explicitly out of scope

No changes to online-mode, RCON binding, audit services, or the verify
gate. If any optimization requires loosening a control, it is not an
optimization we want.

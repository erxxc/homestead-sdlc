# Spark Profile Analysis — 2026-08-13 (post perf-rollout)

Profile: <https://spark.lucko.me/5BSxrRmAjy> — 10 minutes, Server thread,
under player load, hours after the OPS-003 stack (spark, FerriteCore,
ModernFix, Krypton, Lithium) was installed. Analysis performed on the raw
sampler payload (self-time attribution via spark's class/method source maps).

## Headline

- **TPS 19.97** (11,983 ticks in 600 s — 17 dropped ticks in 10 minutes).
- Estimated real work ≈ **32 ms/tick** against the 50 ms budget once idle
  wait (~213 s of libc sleep between ticks) is excluded. Healthy headroom.
- **Create is 3.4% of server-thread self time (1.7 ms/tick).** No
  Create-specific optimizer is justified by this data.

## Self-time attribution (top sources)

| Share | ms/tick | Source |
|---|---|---|
| 40.3% | 20.2 | native (mostly inter-tick idle sleep + call stubs) |
| 30.4% | 15.2 | vanilla (block-entity ticking, chunk access) |
| 17.3% | 8.7 | JVM/libraries (HashMap/fastutil lookups) |
| 3.4% | 1.7 | **create** |
| 1.7% | 0.9 | pehkui |
| 0.7% | 0.4 | c2me |
| 0.7% | 0.4 | lithium |

## Create breakdown

Create-family mods present: create 6.0.8.1, create_oxidized 0.1.1,
createcontraptionterminals 1.2.0, createdeco 2.1.1.

Within Create's 20.7 s, the hotspots are **fluid pipe networks**
(`FluidTransportBehaviour`, `FlowSource$OtherPipe`, `FluidNetwork.tick`,
`PipeConnection` ≈ 3.4 s combined) and `SmartBlockEntity` behaviour
iteration (≈ 9.8 s — structural cost spread across every Create block
entity). If a targeted in-world optimization is ever wanted: simplify the
largest fluid pipe installation (fewer junctions/smart pipes). At 1.7
ms/tick total it is optional.

## Decisions

- **Create Optimizer: not installing.** Create is 3.4% of the tick; a
  small-author mixin mod patching Create internals is not worth the
  supply-chain and compat risk for that ceiling.
- **Alternate Current: not installing.** Redstone does not appear in the
  top self-time classes at all.
- Re-profile after OPS-003 Phase 2 (world border + pre-generation) or on
  any observed TPS drop; compare against this baseline URL.

## Incidental findings

- The pack already ships **C2ME** (c2me-base, c2me-notickvd,
  c2me-fixes-worldgen-threading-issues) — not visible in the SBOM because
  the 427 CurseForge pack mods are counted, not enumerated. It coexists
  cleanly with Lithium (0.7% self each). A full SBOM enumeration from
  `mod_checksums.sha256` would close this documentation gap.
- The dominant "cost" overall is the diffuse block-entity/map-lookup load
  characteristic of a 428-mod kitchen pack — no single villain, nothing
  actionable beyond what is already installed.

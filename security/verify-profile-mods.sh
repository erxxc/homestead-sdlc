#!/bin/bash
# Verify the selected profile's complete active mod set before launch.
set -euo pipefail
: "${MC_ROOT:?MC_ROOT is required}"
baseline=$MC_ROOT/mod_checksums.sha256
test -d "$MC_ROOT/mods"
test -s "$baseline"
test "$(stat -Lc %U "$baseline")" = root
test $((8#$(stat -Lc %a "$baseline") & 8#022)) -eq 0
(cd "$MC_ROOT/mods" && sha256sum --check "$baseline")
expected=$(wc -l <"$baseline")
actual=$(find "$MC_ROOT/mods" -maxdepth 1 -type f -name '*.jar' -printf . | wc -c)
[ "$actual" -eq "$expected" ] || {
  echo "active mod count differs from the reviewed baseline: expected $expected, found $actual" >&2
  exit 1
}

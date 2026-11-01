#!/bin/bash
# One-time migration to release-backed mc/sb slots and Homestead 2.0.1.
set -euo pipefail
PACK=${PACK:-/tmp/Homestead-2.0.1-Server.zip}
PACK_SHA256=c00faa8e2e98cec40e1d2fcc49a8947fa6db679d9f30a9a0b05d30e98a20d244
ROOT=/opt/minecraft; RELEASES=$ROOT/releases; SLOTS=$ROOT/slots
MC_COMPAT=$ROOT/homestead; SB_COMPAT=$ROOT/skyfactory4-4.2.4
OLD_HS=$RELEASES/homestead/1.3.6; NEW_HS=$RELEASES/homestead/2.0.1; SKY=$RELEASES/skyfactory4/4.2.4
HS_PROFILE=/etc/minecraft/profiles/homestead.env; SKY_PROFILE=/etc/minecraft/profiles/skyfactory4-staging.env
BACKUPS=$ROOT/backups/homestead; STAMP=$(date -u +%Y%m%dT%H%M%SZ)
ARCHIVE=$ROOT/archive/homestead-pre-2.0-$STAMP; STAGE=$ROOT/.homestead-2.0.1-$STAMP
MIGRATED=0; TIMERS_STOPPED=0
die() { echo "FATAL: $*" >&2; exit 1; }
is_up() { systemctl is-active --quiet "$1"; }
start_timers() { systemctl start minecraft-backup-homestead.timer minecraft-backup-verify-homestead.timer minecraft-backup-prune-homestead.timer 2>/dev/null || true; TIMERS_STOPPED=0; }
rollback() {
  rc=$?; trap - EXIT
  if [ "$rc" -ne 0 ] && { [ "$MIGRATED" -eq 1 ] || [ -d "$OLD_HS" ]; }; then
    echo "Cutover failed; repointing mc to Homestead 1.3.6" >&2
    systemctl stop minecraft.service 2>/dev/null || true
    ln -sfn "$OLD_HS" "$SLOTS/mc"; ln -sfn "$SLOTS/mc" "$MC_COMPAT"
    if [ -d "$SKY" ]; then ln -sfn "$SKY" "$SLOTS/sb"; ln -sfn "$SLOTS/sb" "$SB_COMPAT"; fi
    cp -a "$ARCHIVE/homestead.env.pre-2.0" "$HS_PROFILE"
    /usr/local/bin/minecraft-config-integrity generate 2>/dev/null || true
    systemctl start minecraft.service minecraft-exporter-homestead.service minecraft-mod-watcher.service 2>/dev/null || true
    if [ -d "$SKY" ]; then systemctl start minecraft-skyfactory4-staging.service minecraft-exporter-skyfactory.service 2>/dev/null || true; fi
  fi
  [ "$TIMERS_STOPPED" -eq 0 ] || start_timers
  exit "$rc"
}
trap rollback EXIT
[ "$(id -u)" -eq 0 ] || die "run as root"
for command in unzip curl sha256sum flock; do command -v "$command" >/dev/null || die "$command is required"; done
exec 9>/run/minecraft-release-migration.lock; flock -n 9 || die "another Minecraft release operation is running"
[ -d "$MC_COMPAT/world" ] && [ -f "$MC_COMPAT/world/level.dat" ] || die "live Homestead world is missing"
[ -d "$SB_COMPAT" ] || die "SkyFactory runtime is missing"
[ ! -L "$MC_COMPAT" ] || die "release layout is already installed"
[ ! -e "$OLD_HS" ] && [ ! -e "$NEW_HS" ] && [ ! -e "$SKY" ] || die "a release target already exists"
[ -f "$HS_PROFILE" ] && [ -f "$SKY_PROFILE" ] || die "an active profile is missing"
sha256sum -c <<<"$PACK_SHA256  $PACK" || die "server pack checksum mismatch"
unzip -tq "$PACK" >/dev/null || die "server pack is corrupt"
for exporter in 9225 9226; do
  if curl -fsS --max-time 5 "http://127.0.0.1:$exporter/metrics" 2>/dev/null | awk '/^minecraft_player_online.* 1$/{f=1} END{exit !f}'; then die "a player is online"; fi
done
world_bytes=$(du -sb "$MC_COMPAT/world" | awk '{print $1}'); free_bytes=$(df --output=avail -B1 "$ROOT" | tail -1)
[ "$free_bytes" -ge $((world_bytes + 10 * 1024 * 1024 * 1024)) ] || die "need world size plus 10 GiB free"
mkdir -p "$ARCHIVE" "$RELEASES/homestead" "$RELEASES/skyfactory4" "$SLOTS" "$STAGE"
cp -a "$HS_PROFILE" "$ARCHIVE/homestead.env.pre-2.0"; cp -a "$SKY_PROFILE" "$ARCHIVE/skyfactory4.env.pre-slot"
echo "Preparing Homestead 2.0.1 release"
unzip -q "$PACK" -d "$STAGE"; cp -a "$MC_COMPAT/server.properties" "$STAGE/server.properties"
for file in eula.txt ops.json whitelist.json banned-ips.json banned-players.json; do [ ! -f "$MC_COMPAT/$file" ] || cp -a "$MC_COMPAT/$file" "$STAGE/$file"; done
printf 'eula=true\n' > "$STAGE/eula.txt"; sed -i 's/^motd=.*/motd=Homestead 2.0.1/' "$STAGE/server.properties"
for setting in server-port=25565 enable-rcon=true rcon.port=25575 online-mode=true; do grep -qx "$setting" "$STAGE/server.properties" || die "missing server setting: $setting"; done
find "$MC_COMPAT/mods" -maxdepth 1 -type f -iname '*bluemap*.jar' -exec cp -a '{}' "$STAGE/mods/" ';'
find "$STAGE/mods" -maxdepth 1 -type f -iname '*bluemap*.jar' -print -quit | grep -q . || die "BlueMap add-on missing"
for config in bluemap voicechat; do if [ -d "$MC_COMPAT/config/$config" ]; then rm -rf "$STAGE/config/$config"; cp -a "$MC_COMPAT/config/$config" "$STAGE/config/$config"; fi; done
ln -s fabric-server-mc.1.20.1-loader.0.19.5-launcher.1.1.2.jar "$STAGE/fabric-server-launch.jar"
(cd "$STAGE/mods"; sha256sum ./*.jar | sed 's#  \./#  #' > "$STAGE/mod_checksums.sha256")
chown -R minecraft:minecraft "$STAGE"
systemctl stop minecraft-backup-homestead.timer minecraft-backup-verify-homestead.timer minecraft-backup-prune-homestead.timer; TIMERS_STOPPED=1
echo "Creating and validating final Homestead backup"
before=$(find "$BACKUPS" -maxdepth 1 -type f -name 'world-*.tar.gz' -printf '%T@ %p\n' | sort -nr | head -1 | cut -d' ' -f2- || true)
systemctl start minecraft-backup-homestead.service
final_backup=$(find "$BACKUPS" -maxdepth 1 -type f -name 'world-*.tar.gz' -printf '%T@ %p\n' | sort -nr | head -1 | cut -d' ' -f2- || true)
[ -n "$final_backup" ] && [ "$final_backup" != "$before" ] || die "no new Homestead backup was created"
systemctl start minecraft-backup-verify-homestead.service; systemctl reset-failed minecraft-restore-drill@homestead.service 2>/dev/null || true; systemctl start minecraft-restore-drill@homestead.service
echo "Creating and validating final SkyFactory backup"
systemctl start minecraft-backup-skyfactory4.service; systemctl start minecraft-backup-verify-skyfactory4.service
echo "Stopping both slots for atomic layout migration"
systemctl stop minecraft-exporter-homestead.service minecraft-exporter-skyfactory.service minecraft-mod-watcher.service
systemctl stop minecraft.service minecraft-skyfactory4-staging.service
is_up minecraft.service && die "Homestead did not stop"; is_up minecraft-skyfactory4-staging.service && die "SkyFactory did not stop"
mv "$final_backup" "$ARCHIVE/pre-2.0-final-world.tar.gz"; sha256sum "$ARCHIVE/pre-2.0-final-world.tar.gz" > "$ARCHIVE/SHA256SUMS"
mv "$MC_COMPAT" "$OLD_HS"; mv "$SB_COMPAT" "$SKY"; mv "$STAGE" "$NEW_HS"
ln -sfn "$NEW_HS" "$SLOTS/mc"; ln -sfn "$SKY" "$SLOTS/sb"; ln -sfn "$SLOTS/mc" "$MC_COMPAT"; ln -sfn "$SLOTS/sb" "$SB_COMPAT"; MIGRATED=1
cp -a "$ARCHIVE/homestead.env.pre-2.0" "$OLD_HS/.parallel-works-profile.env"; cp -a "$ARCHIVE/skyfactory4.env.pre-slot" "$SKY/.parallel-works-profile.env"
cp -a "$ARCHIVE/homestead.env.pre-2.0" "$NEW_HS/.parallel-works-profile.env"; sed -i 's/^MC_PACK_NAME=.*/MC_PACK_NAME="Homestead 2.0.1"/' "$NEW_HS/.parallel-works-profile.env"; cp -a "$NEW_HS/.parallel-works-profile.env" "$HS_PROFILE"
printf 'mc\n' > "$OLD_HS/.parallel-works-slot"; printf 'mc\n' > "$NEW_HS/.parallel-works-slot"; printf 'sb\n' > "$SKY/.parallel-works-slot"
chown root:root "$OLD_HS"/.parallel-works-* "$NEW_HS"/.parallel-works-* "$SKY"/.parallel-works-*; chmod 0644 "$OLD_HS"/.parallel-works-* "$NEW_HS"/.parallel-works-* "$SKY"/.parallel-works-*
/usr/local/bin/minecraft-config-integrity generate
systemctl start minecraft-skyfactory4-staging.service minecraft-exporter-skyfactory.service
echo "Starting Homestead 2.0.1 with a fresh world"; systemctl start minecraft.service
ready=0
for _ in $(seq 1 120); do systemctl is-failed --quiet minecraft.service && die "Homestead failed during first boot"; if [ -s "$MC_COMPAT/world/level.dat" ] && grep -q 'Done (' "$MC_COMPAT/logs/latest.log" 2>/dev/null; then ready=1; break; fi; sleep 10; done
[ "$ready" -eq 1 ] || die "Homestead did not finish booting within 20 minutes"
systemctl start minecraft-exporter-homestead.service minecraft-mod-watcher.service; sleep 10
is_up minecraft.service && is_up minecraft-skyfactory4-staging.service || die "a game service is down"
is_up minecraft-exporter-homestead.service && is_up minecraft-exporter-skyfactory.service || die "an exporter is down"
cat > "$ARCHIVE/ROLLBACK.txt" <<EOF
Homestead 1.3.6 remains at $OLD_HS.
Return the mc slot to it with:
  sudo /usr/local/sbin/minecraft-slot-switch mc homestead/1.3.6

The final reference world archive is:
  $ARCHIVE/pre-2.0-final-world.tar.gz
EOF
chown root:root "$ARCHIVE" "$ARCHIVE"/*; chmod 0700 "$ARCHIVE"; chmod 0600 "$ARCHIVE"/*
start_timers; trap - EXIT; rm -f "$PACK"
echo "RESULT: PASS"; echo "mc -> $(readlink -f "$SLOTS/mc")"; echo "sb -> $(readlink -f "$SLOTS/sb")"; echo "Reference archive: $ARCHIVE/pre-2.0-final-world.tar.gz"; df -h "$ROOT"

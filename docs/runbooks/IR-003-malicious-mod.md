# IR-003 — Malicious Mod Detected

## Trigger
- Mod integrity check fails on server start
- /var/log/minecraft-integrity.log shows FAIL entry
- Unexpected mod jar appears in mods folder
- Player reports unusual server behaviour suggesting code execution

## Severity
Critical — malicious mod can execute arbitrary code as the minecraft user

## Detection
- systemd ExecStartPre integrity check fails — server refuses to start
- Manual integrity check:
sudo /usr/local/bin/verify-mods
- Unexpected entries in mod checksum file:
sudo sha256sum -c /opt/minecraft/homestead/mod_checksums.sha256

## Containment (immediate)
1. Server will not start if integrity check fails — this is by design
2. Do NOT restart the server until the malicious mod is identified and removed
3. Isolate the mods folder for forensic review:
sudo cp -r /opt/minecraft/homestead/mods /opt/minecraft/mods-forensic-$(date +%Y%m%d)
4. Identify the offending jar:
sudo sha256sum -c /opt/minecraft/homestead/mod_checksums.sha256 2>&1 | grep FAILED

## Eradication
1. Remove the offending jar:
sudo -u minecraft rm /opt/minecraft/homestead/mods/[malicious-jar].jar
2. If jar is a tampered legitimate mod, re-download from original source
3. Update checksums after removing:
sudo chmod 644 /opt/minecraft/homestead/mod_checksums.sha256
sudo -u minecraft sha256sum /opt/minecraft/homestead/mods/*.jar | sort > /opt/minecraft/homestead/mod_checksums.sha256
sudo chmod 444 /opt/minecraft/homestead/mod_checksums.sha256

## Recovery
1. Verify integrity check passes:
sudo /usr/local/bin/verify-mods
echo "Exit code: $?"
2. Restart the server:
sudo systemctl start minecraft
sudo journalctl -u minecraft -f
3. Monitor for 30 minutes post-restart for unusual behaviour

## Post-Incident
- Identify how the jar was introduced (supply chain, manual transfer, CI/CD)
- Review SSH access logs for unauthorised access
- Review GitHub Actions deploy logs
- Update SBOM with finding
- Consider adding checksum verification to CI/CD pipeline

## Evidence to Collect
- Forensic copy of mods folder
- Integrity check failure log
- SSH access logs around time of introduction
- File creation timestamp of malicious jar

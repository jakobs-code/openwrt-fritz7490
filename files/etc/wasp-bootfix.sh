#!/bin/sh
# /etc/wasp-bootfix.sh v3
# Stellt den KOMPLETTEN WASP-Zustand her: Konfig-Dateien werden BYTE-EXAKT
# kopiert (nicht importiert!) - dadurch gibt es keine Fabrik-Reste
# (default_radio0/1, mesh0) die mit dem STA um den Funk-Chip kämpfen.
# Retry + Verifikation. Kein EEPROM-Handling (Kalibrierung ist im Image).

LOG=/tmp/bootfix.log
SRC=/etc/wasp-config
MAX=12
T=0

log() { echo "$(date) $*" >> "$LOG"; logger -t wasp-bootfix "$*"; }

log "Start (v3, file-copy)"
while [ $T -lt $MAX ]; do
  T=$((T+1))
  if ! ping -c1 -W2 192.168.1.2 >/dev/null 2>&1; then
    log "Versuch $T: WASP nicht bereit"
    sleep 20
    continue
  fi

  OK=1
  for pkg in network wireless firewall dhcp; do
    # kompletter Ersatz der Config-Datei (keine Merge-Artefakte!)
    if ! ssh -o StrictHostKeyChecking=no root@192.168.1.2 "cat > /etc/config/$pkg" < "$SRC/$pkg.uci"; then
      log "Versuch $T: Kopieren von $pkg fehlgeschlagen"
      OK=0
    fi
  done
  [ $OK -ne 1 ] && { sleep 20; continue; }

  ssh -o StrictHostKeyChecking=no root@192.168.1.2 \
    '/etc/init.d/network reload; /etc/init.d/firewall restart; wifi reload; sleep 6; ifup wwan' \
    >>"$LOG" 2>&1

  v=0
  while [ $v -lt 6 ]; do
    sleep 5
    v=$((v+1))
    if ssh -o StrictHostKeyChecking=no root@192.168.1.2 \
        'ip -4 addr show 2>/dev/null | grep -q "inet 192.168.0."'; then
      log "OK: Uplink aktiv nach Versuch $T (+${v}x5s)"
      exit 0
    fi
  done
  log "Versuch $T: Konfig steht, Uplink noch ohne IP"
done

log "FEHLGESCHLAGEN nach $MAX Versuchen"
exit 1

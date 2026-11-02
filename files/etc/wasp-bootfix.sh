#!/bin/sh
# /etc/wasp-bootfix.sh - spielt die gesicherte WASP-Konfiguration ein.
# Die WLAN-Kalibrierung ist im Image gebrannt - kein EEPROM-Handling noetig.
# Retry-Logik mit echten Fehlerpruefungen und Verifikation.

LOG=/tmp/bootfix.log
MAX=12
T=0

log() { echo "$(date) $*" >> "$LOG"; logger -t wasp-bootfix "$*"; }

log "Start"
while [ $T -lt $MAX ]; do
  T=$((T+1))
  if ! ping -c1 -W2 192.168.1.2 >/dev/null 2>&1; then
    log "Versuch $T: WASP nicht erreichbar"
    sleep 20
    continue
  fi

  OK=1
  for pkg in network wireless firewall dhcp; do
    if ! ssh -o StrictHostKeyChecking=no root@192.168.1.2 "uci import $pkg" < "/etc/wasp-config/$pkg.uci" 2>>"$LOG"; then
      log "Versuch $T: Import $pkg fehlgeschlagen"
      OK=0
    fi
  done
  if [ $OK -ne 1 ]; then
    sleep 20
    continue
  fi

  # Commit + anwenden (wifi reload statt up, damit neue Config greift)
  ssh -o StrictHostKeyChecking=no root@192.168.1.2 \
    'for p in network wireless firewall dhcp; do uci commit $p; done; /etc/init.d/firewall restart; /etc/init.d/network reload; wifi reload; sleep 5; ifup wwan' \
    >>"$LOG" 2>&1

  # Verifikation: Uplink-STA hat eine Adresse im Kabelbox-Netz?
  v=0
  while [ $v -lt 6 ]; do
    sleep 5
    v=$((v+1))
    if ssh -o StrictHostKeyChecking=no root@192.168.1.2 \
        'ip -4 addr show 2>/dev/null | grep -q "inet 192.168.0."'; then
      log "OK: Uplink nach Versuch $T (+${v}x5s)"
      exit 0
    fi
  done
  log "Versuch $T: Config eingespielt, aber noch keine Uplink-IP"
done

log "FEHLGESCHLAGEN nach $MAX Versuchen"
exit 1

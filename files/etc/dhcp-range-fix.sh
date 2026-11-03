#!/bin/sh
# DHCP-Range-Fix fuer die Box: netifd meldet bei Mehrfachadressen auf br-lan
# keine nutzbare IPv4 fuer den dnsmasq-Renderer -> Range fehlt -> kein DHCP.
# Wir schreiben die Range als Drop-in in den gerenderten conf-dir und starten
# dnsmasq neu. Idempotent und unabhaengig vom Instanz-Namen.

F=$(ls /var/etc/dnsmasq.conf.* 2>/dev/null | head -1)
[ -n "$F" ] || exit 0
D=$(sed -n 's/^conf-dir=//p' "$F" | head -1)
[ -n "$D" ] || exit 0
mkdir -p "$D"
cat > "$D/zz-dhcp-range.conf" <<'EOF'
dhcp-range=192.168.10.100,192.168.10.249,255.255.255.0,12h
dhcp-option=3,192.168.10.1
dhcp-option=6,192.168.10.1
EOF
# nur neu starten, wenn der Port noch nicht lauscht
if ! netstat -lnu 2>/dev/null | grep -q ':67 '; then
  /etc/init.d/dnsmasq restart
fi

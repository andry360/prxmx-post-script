#!/bin/sh

echo "🔹 Avvio diagnostica di OpenWrt per la connessione a Internet..."
echo "============================================"

# 1️⃣ 🔍 Verifica VLAN 835 su WAN
WAN_INTERFACE=$(uci get network.wan.device 2>/dev/null)
if [ "$WAN_INTERFACE" = "eth1.835" ]; then
    echo "✅ VLAN 835 correttamente configurata sulla WAN ($WAN_INTERFACE)."
else
    echo "❌ Errore: La WAN non è configurata su VLAN 835. Attuale: $WAN_INTERFACE"
    echo "   ▶ Per correggere, esegui:"
    echo "     uci set network.wan.device='eth1.835' && uci commit network && /etc/init.d/network restart"
    exit 1
fi

# 2️⃣ 🌐 Controllo assegnazione IP WAN (PPPoE)
WAN_IP=$(ifstatus wan | grep '"ipaddr"' | awk -F'"' '{print $4}')
if [ -n "$WAN_IP" ]; then
    echo "✅ IP WAN assegnato: $WAN_IP"
else
    echo "❌ Errore: Nessun IP ricevuto dalla WAN."
    echo "   ▶ Possibili cause:"
    echo "     - Username o password PPPoE errati (verifica in /etc/config/network)"
    echo "     - ISP che richiede un MAC address specifico (clonazione MAC)"
    echo "     ▶ Controlla i log con: logread | grep ppp"
    exit 1
fi

# 3️⃣ 📡 Test connettività Internet
echo "🔄 Test di connettività a Google (8.8.8.8)..."
if ping -c 4 8.8.8.8 >/dev/null 2>&1; then
    echo "✅ Connessione a Internet OK!"
else
    echo "❌ Errore: Il router non riesce a raggiungere Internet."
    echo "   ▶ Possibili problemi:"
    echo "     - DNS non configurati correttamente (aggiungi 8.8.8.8 in /etc/config/network)"
    echo "     - MTU sbagliato (prova a impostare 1492 con: uci set network.wan.mtu='1492' && uci commit network && /etc/init.d/network restart)"
    exit 1
fi

# 4️⃣ 📥 Verifica assegnazione IP ai dispositivi LAN
echo "🔄 Controllo dispositivi connessi alla LAN..."
DHCP_LEASES=$(cat /tmp/dhcp.leases 2>/dev/null)
if [ -n "$DHCP_LEASES" ]; then
    echo "✅ Client LAN rilevati:"
    echo "$DHCP_LEASES"
else
    echo "❌ Nessun dispositivo rilevato sulla LAN."
    echo "   ▶ Possibili cause:"
    echo "     - Il DHCP server non è attivo (verifica in /etc/config/dhcp)"
    echo "     - Il client è connesso con un IP statico sbagliato"
fi

echo "============================================"
echo "✅ Diagnostica completata!"

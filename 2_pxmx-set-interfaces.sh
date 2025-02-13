#!/bin/bash

# Backup del file di configurazione originale
cp /etc/network/interfaces /etc/network/interfaces.backup.$(date +%F_%T)

# Scrittura della nuova configurazione
cat <<EOF > /etc/network/interfaces
auto lo
iface lo inet loopback

iface enp87s0 inet manual
#WAN

iface enp88s0 inet manual

iface enp2s0f0np0 inet manual
#WAN-SFP+

iface enp2s0f1np1 inet manual

iface wlp89s0 inet manual

auto vmbr0
iface vmbr0 inet manual
        bridge-ports enp87s0
        bridge-stp off
        bridge-fd 0
#LAN WAN

auto vmbr1
iface vmbr1 inet static
        address 192.168.1.253/24
        gateway 192.168.1.1
        bridge-ports enp88s0
        bridge-stp off
        bridge-fd 0
#LAN Bridge

source /etc/network/interfaces.d/*
EOF

# Riavvio del networking per applicare le modifiche
if systemctl restart networking; then
    echo "Configurazione di rete applicata con successo."
else
    echo "Errore durante l'applicazione della configurazione di rete."
fi

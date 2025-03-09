#!/bin/sh

# Verifica se il sistema è OpenWRT
if ! grep -q "OpenWrt" /etc/os-release 2>/dev/null && ! uname -a | grep -qi "OpenWrt"; then
    echo "❌ Errore: Questo script è pensato per OpenWRT e non può essere eseguito su altri sistemi."
    exit 1
fi

echo "✅ OpenWRT rilevato, procedo con l'installazione..."

# Scelta dell'utente
echo "🔹 Cosa vuoi installare?"
echo "1) Solo driver delle schede di rete"
echo "2) Solo utilità di sistema"
echo "3) Entrambi"
echo "4) Esci"
read -p "👉 Inserisci il numero della tua scelta: " scelta

if [ "$scelta" = "4" ]; then
    echo "❌ Installazione annullata dall'utente."
    exit 0
fi

echo "🔄 Aggiornamento della lista dei pacchetti..."
opkg update && echo "✅ Update completato" || echo "❌ Errore durante l'aggiornamento"

# Installazione dei driver delle schede di rete (opzione 1 e 3)
if [ "$scelta" = "1" ] || [ "$scelta" = "3" ]; then
    echo "🔄 Installazione di kmod-mt76 (dipendenze generiche WiFi MediaTek)..."
    opkg install kmod-mt76 && echo "✅ Installato kmod-mt76" || echo "❌ Errore nell'installazione di kmod-mt76"

    echo "🔄 Installazione dei driver MediaTek MT7922..."
    opkg install kmod-mt7922-firmware && echo "✅ Installato kmod-mt7922-firmware" || echo "❌ Errore nell'installazione di kmod-mt7922-firmware"

    echo "🔄 Installazione di kmod-mt792x-common..."
    opkg install kmod-mt792x-common && echo "✅ Installato kmod-mt792x-common" || echo "❌ Errore nell'installazione di kmod-mt792x-common"

    echo "🔄 Installazione di kmod-mt7921-common..."
    opkg install kmod-mt7921-common && echo "✅ Installato kmod-mt7921-common" || echo "❌ Errore nell'installazione di kmod-mt7921-common"

    echo "🔄 Installazione di kmod-mt7921-firmware..."
    opkg install kmod-mt7921-firmware && echo "✅ Installato kmod-mt7921-firmware" || echo "❌ Errore nell'installazione di kmod-mt7921-firmware"

    echo "🔄 Verifica della scheda WiFi dopo l'installazione..."
    iw list | grep -A20 'Frequencies' || echo "❌ Errore: La scheda WiFi potrebbe non essere stata rilevata."
fi

# Installazione delle utilità di sistema (opzione 2 e 3)
if [ "$scelta" = "2" ] || [ "$scelta" = "3" ]; then
    echo "🔄 Installazione dell'editor Nano..."
    opkg install nano && echo "✅ Installato nano" || echo "❌ Errore nell'installazione di nano"

    echo "🔄 Installazione di wpad (driver WiFi completi)..."
    opkg install wpad && echo "✅ Installato wpad" || echo "❌ Errore nell'installazione di wpad"

    echo "🔄 Installazione di pciutils (per verificare dispositivi PCI)..."
    opkg install pciutils && echo "✅ Installato pciutils" || echo "❌ Errore nell'installazione di pciutils"
fi

echo "✅ Installazione completata. Riavvio in 5 secondi..."
sleep 5
reboot


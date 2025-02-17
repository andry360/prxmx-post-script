#!/bin/bash

# Script per configurare PCI Passthrough su Proxmox VE
# Genera un log dettagliato in /var/log/pci_passthrough.log

LOGFILE="/var/log/pci_passthrough.log"

echo "===== Avvio configurazione PCI Passthrough =====" | tee -a "$LOGFILE"
echo "Data e ora: $(date)" | tee -a "$LOGFILE"

# ----------------------------------------------------------------------------------------------------------------------
# 1. Abilitazione di IOMMU nel GRUB
echo ">>> Configurazione di IOMMU nel bootloader GRUB..." | tee -a "$LOGFILE"

GRUB_CONFIG="/etc/default/grub"

# 1.1. Determina se è un sistema Intel o AMD
if grep -q "vmx" /proc/cpuinfo; then
    IOMMU_FLAG="intel_iommu=on"
    echo "1.1 Sistema rilevato: Intel" | tee -a "$LOGFILE"
elif grep -q "svm" /proc/cpuinfo; then
    IOMMU_FLAG="amd_iommu=on"
    echo "1.1 Sistema rilevato: AMD" | tee -a "$LOGFILE"
else
    echo "Errore: Il processore non supporta la virtualizzazione!" | tee -a "$LOGFILE"
    exit 1
fi

# 1.2 Modifica GRUB se necessario
if ! grep -q "$IOMMU_FLAG" "$GRUB_CONFIG"; then
    echo "1.2 Abilitazione di IOMMU in GRUB..." | tee -a "$LOGFILE"
    sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"/GRUB_CMDLINE_LINUX_DEFAULT=\"$IOMMU_FLAG iommu=pt /" "$GRUB_CONFIG"
    update-grub | tee -a "$LOGFILE"
else
    echo "1.2 ⚠️ IOMMU è già attivo in GRUB. con $IOMMU_FLAG" | tee -a "$LOGFILE"
fi

# ----------------------------------------------------------------------------------------------------------------------
# 2 Aggiungere i moduli VFIO
echo ">>> 2 Configurazione dei moduli VFIO..." | tee -a "$LOGFILE"
MODULES_FILE="/etc/modules"
MODULES=("vfio" "vfio_iommu_type1" "vfio_pci" "vfio_virqfd")

for mod in "${MODULES[@]}"; do
    if ! grep -q "^$mod" "$MODULES_FILE"; then
        echo "$mod" >> "$MODULES_FILE"
        echo "✅ 2 Aggiunto modulo: $mod" | tee -a "$LOGFILE"
    else
        echo "⚠️ 2 Modulo già presente: $mod" | tee -a "$LOGFILE"
    fi
done

# ----------------------------------------------------------------------------------------------------------------------
# 3. Blacklist dei driver WiFi e Bluetooth
# 📌 File di blacklist
BLACKLIST_FILE="/etc/modprobe.d/blacklist-mt7921e.conf"

# 📌 Moduli da blacklistare
BLACKLIST_MODULES="
mt7921e
mt76
mt76_connac_lib
mt7921_common
cfg80211
btrtl
btusb
bluetooth
btmtk
mtd
spi_nor
cmdlinepart
iwlwifi
"

echo "🔍 Controllo della blacklist dei driver WiFi e Bluetooth..."

# 🔄 Controlla se i moduli sono già blacklistati in qualsiasi file .conf sotto /etc/modprobe.d/
for MODULE in $BLACKLIST_MODULES; do
    if grep -q "blacklist $MODULE" /etc/modprobe.d/*.conf 2>/dev/null; then
        echo "⚠️ Il modulo '$MODULE' è già blacklistato. Nessuna modifica necessaria."
    else
        echo "✅ Il modulo '$MODULE' non è ancora blacklistato. Verrà aggiunto."
        echo "blacklist $MODULE" >> "$BLACKLIST_FILE"
    fi
done

echo "✅ Aggiornamento completato. Verifica il file $BLACKLIST_FILE se necessario."

# ----------------------------------------------------------------------------------------------------------------------
# 4. Identificare i dispositivi PCI disponibili per il passthrough
echo ">>> 4 Ricerca dei dispositivi PCI disponibili...tramite lspci -nn" | tee -a "$LOGFILE"

PCI_LIST=$(lspci -nn)
declare -a PCI_IDS PCI_ADDRESSES

INDEX=1
if [ -z "$PCI_LIST" ]; then
    echo "Errore: Nessun dispositivo PCI rilevato!" | tee -a "$LOGFILE"
    exit 1
fi

echo "4 Elenco dispositivi PCI:" | tee -a "$LOGFILE"
while read -r LINE; do
    PCI_ADDR=$(echo "$LINE" | awk '{print $1}')
    PCI_ID=$(lspci -n -s "$PCI_ADDR" | awk '{print $3}')
    
    PCI_ADDRESSES+=("$PCI_ADDR")
    PCI_IDS+=("$PCI_ID")

    echo "$INDEX) $LINE (ID: $PCI_ID)" | tee -a "$LOGFILE"
    ((INDEX++))
done <<< "$PCI_LIST"

# Selezione multipla dei dispositivi per il passthrough
echo -n "Seleziona i numeri dei dispositivi PCI da passare alla VM (separati da spazio): " | tee -a "$LOGFILE"
read -r SELECTIONS

# Verifica che gli input siano numeri validi
SELECTED_IDS=()
for SELECTION in $SELECTIONS; do
    if [[ ! "$SELECTION" =~ ^[0-9]+$ ]] || (( SELECTION < 1 || SELECTION >= INDEX )); then
        echo "Errore: Selezione non valida ($SELECTION)!" | tee -a "$LOGFILE"
        exit 1
    fi
    SELECTED_IDS+=("${PCI_IDS[$((SELECTION-1))]}")
done

# ----------------------------------------------------------------------------------------------------------------------
# 5. Configurazione VFIO con i dispositivi scelti
VFIO_CONF="/etc/modprobe.d/vfio.conf"

echo ">>> 5 Configurazione di VFIO per i dispositivi selezionati..." | tee -a "$LOGFILE"
VFIO_IDS=$(IFS=,; echo "${SELECTED_IDS[*]}")

# il disable_idle_d3=1 è un parametro aggiuntivo per disabilitare lo stato di (idle) dei dispositivi. Assicura quindi che la scheda di rete non vada in sospensione.
echo "options vfio-pci ids=$VFIO_IDS disable_idle_d3=1" > "$VFIO_CONF"
echo "5 Dispositivi configurati per il passthrough: $VFIO_IDS" | tee -a "$LOGFILE"

# ----------------------------------------------------------------------------------------------------------------------
# 6. Aggiornare initramfs e riavviare
echo ">>> 6 Aggiornamento initramfs..." | tee -a "$LOGFILE"
update-initramfs -u | tee -a "$LOGFILE"

# ----------------------------------------------------------------------------------------------------------------------
# 7.  La scheda di rete MEDIATEK MT7922 PCIe supporta il reset a livello di bus invece del FLR standard. Forzo quindi il reset a livello di bus:
echo 'ACTION=="add", SUBSYSTEM=="pci", ATTR{reset_method}="bus"' | tee /etc/udev/rules.d/99-vfio.rules

echo "7 Operazione completata! Riavviare il sistema per applicare le modifiche." | tee -a "$LOGFILE"

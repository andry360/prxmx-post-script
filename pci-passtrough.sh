#!/bin/bash

# Script per configurare PCI Passthrough su Proxmox VE
# Genera un log dettagliato in /var/log/pci_passthrough.log

LOGFILE="/var/log/pci_passthrough.log"

echo "===== Avvio configurazione PCI Passthrough =====" | tee -a "$LOGFILE"
echo "Data e ora: $(date)" | tee -a "$LOGFILE"

# 1. Abilitazione di IOMMU nel GRUB
echo ">>> Configurazione di IOMMU nel bootloader GRUB..." | tee -a "$LOGFILE"

GRUB_CONFIG="/etc/default/grub"

# Determina se è un sistema Intel o AMD
if grep -q "vmx" /proc/cpuinfo; then
    IOMMU_FLAG="intel_iommu=on"
    echo "Sistema rilevato: Intel" | tee -a "$LOGFILE"
elif grep -q "svm" /proc/cpuinfo; then
    IOMMU_FLAG="amd_iommu=on"
    echo "Sistema rilevato: AMD" | tee -a "$LOGFILE"
else
    echo "Errore: Il processore non supporta la virtualizzazione!" | tee -a "$LOGFILE"
    exit 1
fi

# Modifica GRUB se necessario
if ! grep -q "$IOMMU_FLAG" "$GRUB_CONFIG"; then
    echo "Abilitazione di IOMMU in GRUB..." | tee -a "$LOGFILE"
    sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"/GRUB_CMDLINE_LINUX_DEFAULT=\"$IOMMU_FLAG iommu=pt /" "$GRUB_CONFIG"
    update-grub | tee -a "$LOGFILE"
else
    echo "IOMMU è già attivo in GRUB. con $IOMMU_FLAG" | tee -a "$LOGFILE"
fi

# 2. Aggiungere i moduli VFIO
echo ">>> Configurazione dei moduli VFIO..." | tee -a "$LOGFILE"
MODULES_FILE="/etc/modules"
MODULES=("vfio" "vfio_iommu_type1" "vfio_pci" "vfio_virqfd")

for mod in "${MODULES[@]}"; do
    if ! grep -q "^$mod" "$MODULES_FILE"; then
        echo "$mod" >> "$MODULES_FILE"
        echo "Aggiunto modulo: $mod" | tee -a "$LOGFILE"
    else
        echo "Modulo già presente: $mod" | tee -a "$LOGFILE"
    fi
done

# 3 Blacklist dei moduli WIFI e Bluetooth non necessari
BLACKLIST_FILE="/etc/modprobe.d/blacklist-mt7921e.conf"
echo "Blacklist dei driver WIFI e bluetooth scheda di rete MEDIATEK MT7922 WIFI 6e"
echo -e "# Driver WIFI\nblacklist mt7921e\nblacklist mt76\nblacklist mt76_connac_lib\nblacklist mt7921_common\nblacklist cfg80211\n\n# Driver Bluetooth\nblacklist btrtl\nblacklist btusb\nblacklist bluetooth\nblacklist btmtk\nblacklist mtd\nblacklist spi_nor\nblacklist cmdlinepart" > $BLACKLIST_FILE
echo "Blacklist dei driver WIFI e Bluetooth completata. nel file $BLACKLIST_FILE"

# 4. Identificare i dispositivi PCI disponibili per il passthrough
echo ">>> Ricerca dei dispositivi PCI disponibili...tramite lspci -nn" | tee -a "$LOGFILE"

PCI_LIST=$(lspci -nn)
declare -a PCI_IDS PCI_ADDRESSES

INDEX=1
if [ -z "$PCI_LIST" ]; then
    echo "Errore: Nessun dispositivo PCI rilevato!" | tee -a "$LOGFILE"
    exit 1
fi

echo "Elenco dispositivi PCI:" | tee -a "$LOGFILE"
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

# 5. Configurazione VFIO con i dispositivi scelti
VFIO_CONF="/etc/modprobe.d/vfio.conf"

echo ">>> Configurazione di VFIO per i dispositivi selezionati..." | tee -a "$LOGFILE"
VFIO_IDS=$(IFS=,; echo "${SELECTED_IDS[*]}")

echo "options vfio-pci ids=$VFIO_IDS disable_idle_d3=1" > "$VFIO_CONF"
echo "Dispositivi configurati per il passthrough: $VFIO_IDS" | tee -a "$LOGFILE"

# 6. Aggiornare initramfs e riavviare
echo ">>> Aggiornamento initramfs..." | tee -a "$LOGFILE"
update-initramfs -u | tee -a "$LOGFILE"

echo "Operazione completata! Riavviare il sistema per applicare le modifiche." | tee -a "$LOGFILE"

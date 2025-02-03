#!/bin/bash

echo "Configurazione di Proxmox VE per PCI Passthrough..."

# 1. Controlla il supporto alla virtualizzazione e il modello del processore
CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -n 1 | awk -F ': ' '{print $2}')
echo "Modello CPU rilevato: $CPU_MODEL"

if grep -q "vmx" /proc/cpuinfo; then
    echo "Processore Intel con supporto VT-x rilevato."
    IOMMU_FLAG="intel_iommu=on"
elif grep -q "svm" /proc/cpuinfo; then
    echo "Processore AMD con supporto AMD-V rilevato."
    IOMMU_FLAG="amd_iommu=on"
else
    echo "Errore: Il processore non supporta la virtualizzazione!"
    exit 1
fi

#####################################################################################################################################

# 2. Abilitare IOMMU nel GRUB
GRUB_CONFIG="/etc/default/grub"
if grep -q "$IOMMU_FLAG" $GRUB_CONFIG; then
    echo "IOMMU è già abilitato nel GRUB."
else
    echo "Abilitazione di IOMMU nel GRUB..."
    sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"/GRUB_CMDLINE_LINUX_DEFAULT=\"$IOMMU_FLAG iommu=pt /" $GRUB_CONFIG
    update-grub
fi

#####################################################################################################################################

# 3. Caricare i moduli necessari
MODULES_FILE="/etc/modules"
MODULES=("vfio" "vfio_iommu_type1" "vfio_pci" "vfio_virqfd")

echo "Aggiunta dei moduli VFIO..."
for mod in "${MODULES[@]}"; do
    if ! grep -q "^$mod" $MODULES_FILE; then
        echo "$mod" >> $MODULES_FILE
    fi
done

#####################################################################################################################################

# 4.1 Blacklist dei moduli grafici non necessari
#BLACKLIST_FILE="/etc/modprobe.d/blacklist.conf"
#echo "Blacklist dei moduli non necessari..."
#echo -e "blacklist nouveau\nblacklist nvidia\nblacklist radeon\nblacklist amdgpu" > $BLACKLIST_FILE

# 4.2 Blacklist dei moduli WIFI e Bluetooth non necessari
BLACKLIST_FILE="/etc/modprobe.d/blacklist-mt7921e.conf"
echo "Blacklist dei driver WIFI e bluetooth scheda di rete MEDIATEK MT7922 WIFI 6e"
echo -e "# Driver WIFI\nblacklist mt7921e\nblacklist mt76\nblacklist mt76_connac_lib\nblacklist mt7921_common\nblacklist cfg80211\n\n# Driver Bluetooth\nblacklist btrtl\nblacklist btusb\nblacklist bluetooth\nblacklist btmtk\nblacklist mtd\nblacklist spi_nor\nblacklist cmdlinepart" > $BLACKLIST_FILE
echo "Blacklist dei driver WIFI e Bluetooth completata."

#####################################################################################################################################

# 5. Configurazione di VFIO per PCI Passthrough
echo "Configurazione di vfio-pci..."
echo "options vfio_iommu_type1 allow_unsafe_interrupts=1" > /etc/modprobe.d/vfio.conf
echo "Configurazione di Proxmox VE per PCI Passthrough..."

# Identificare tutti i dispositivi PCI disponibili per il passthrough
echo "Ricerca dei dispositivi PCI disponibili..."

# Ottenere l'elenco completo delle periferiche PCI
PCI_LIST=$(lspci -nn)
PCI_IDS=()
PCI_ADDRESSES=()

# Creazione dell'elenco numerato
if [ -z "$PCI_LIST" ]; then
    echo "Nessun dispositivo PCI rilevato! Controlla con 'lspci -nn'."
    exit 1
fi

echo "Dispositivi PCI disponibili per il passthrough:"
INDEX=1
while read -r LINE; do
    PCI_ADDR=$(echo "$LINE" | awk '{print $1}')
    PCI_ID=$(lspci -n -s "$PCI_ADDR" | awk '{print $3}')
    
    PCI_ADDRESSES+=("$PCI_ADDR")
    PCI_IDS+=("$PCI_ID")

    echo "$INDEX) $LINE (ID: $PCI_ID)"
    ((INDEX++))
done <<< "$PCI_LIST"

# Chiedere all'utente quale dispositivo selezionare
echo -n "Seleziona il numero del dispositivo PCI da passare alla VM: "
read -r SELECTION

# Controllo validità input
if [[ ! "$SELECTION" =~ ^[0-9]+$ ]] || (( SELECTION < 1 || SELECTION >= INDEX )); then
    echo "Selezione non valida! Assicurati di inserire un numero tra 1 e $((INDEX-1))."
    exit 1
fi

# Ricavare ID e indirizzo PCI scelto
SELECTED_ID="${PCI_IDS[$((SELECTION-1))]}"
SELECTED_ADDR="${PCI_ADDRESSES[$((SELECTION-1))]}"

echo "Hai selezionato il dispositivo: $SELECTED_ADDR (ID: $SELECTED_ID)"

# Scrivere la configurazione VFIO
echo "options vfio-pci ids=$SELECTED_ID disable_idle_d3=1\noptions vfio_iommu_type1 allow_unsafe_interrupts=1" > /etc/modprobe.d/vfio.conf
echo "Configurazione aggiornata. Al riavvio del sistema verranno applicate le modifiche."

######################################################################################################################################

# 6. Configurazione delle opzioni per KVM
echo "Abilitazione del supporto IOMMU in Proxmox..."
echo -e "options kvm ignore_msrs=1\noptions kvm report_ignored_msrs=0" > /etc/modprobe.d/kvm.conf

# 7. Applicazione delle modifiche
echo "Aggiornamento initramfs..."
update-initramfs -u

echo "Configurazione completata! Riavviare il sistema per applicare le modifiche."

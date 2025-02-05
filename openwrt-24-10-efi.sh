#!/usr/bin/env bash

# ===================================================================
# Script per la creazione di una VM OpenWRT su Proxmox con UEFI
# Configurazione: WAN (vmbr0 - DHCP), LAN (vmbr1 - 192.168.1.254)
# Passthrough della scheda WiFi
# ===================================================================

# Impostazioni generali
VMID=$(pvesh get /cluster/nextid)    # Ottiene il prossimo ID VM disponibile
VM_NAME="OpenWRT"
IMAGE_URL="https://downloads.openwrt.org/releases/24.10.0-rc7/targets/x86/64/openwrt-24.10.0-rc7-x86-64-generic-ext4-combined-efi.img.gz"
STORAGE="local-lvm"  # Cambia se necessario
LOG_FILE="$(basename "$0" .sh).log"

# Pulizia file di log precedente
echo "==== Inizio script: $(date) ====" > "$LOG_FILE"

# ================================================================
# Funzioni di logging
# ================================================================
log_info() {
    echo -e "[INFO] $1" | tee -a "$LOG_FILE"
}
log_error() {
    echo -e "[ERROR] $1" | tee -a "$LOG_FILE" >&2
    exit 1
}

# ================================================================
# Verifica dell'ambiente
# ================================================================
log_info "Verifica versione di Proxmox..."
pveversion | grep -q "pve-manager" || log_error "Proxmox non rilevato!"

log_info "Verifica supporto UEFI..."
if ! [ -f "/usr/share/OVMF/OVMF_CODE.fd" ]; then
    log_error "UEFI non disponibile su Proxmox! Installa il pacchetto ed esegui nuovamente lo script."
fi

# ================================================================
# Download e preparazione immagine OpenWRT
# ================================================================
log_info "Scaricamento immagine OpenWRT..."
wget -q --show-progress "$IMAGE_URL" -O openwrt.img.gz || log_error "Download fallito!"
gunzip -f openwrt.img.gz || log_error "Estrazione fallita!"

log_info "Espansione immagine a 512MB..."
qemu-img resize openwrt.img 512M || log_error "Errore nel ridimensionamento immagine!"

# ================================================================
# Creazione VM su Proxmox
# ================================================================
log_info "Creazione VM con ID $VMID..."
qm create "$VMID" --name "$VM_NAME" --memory 512 --cores 2 --net0 virtio,bridge=vmbr0 \
    --bios ovmf --efidisk0 "$STORAGE":vm-"$VMID"-disk-0,efitype=4m,size=4M \
    --machine q35 --serial0 socket --boot order=scsi0 || log_error "Errore nella creazione della VM"

log_info "Importazione disco OpenWRT..."
qm importdisk "$VMID" openwrt.img "$STORAGE" --format raw || log_error "Errore nell'importazione del disco!"

log_info "Collegamento disco alla VM..."
qm set "$VMID" --scsi0 "$STORAGE":vm-"$VMID"-disk-1 || log_error "Errore nel collegamento del disco!"

# ================================================================
# Configurazione della rete
# ================================================================
log_info "Configurazione rete: WAN su vmbr0, LAN su vmbr1..."
qm set "$VMID" --net1 virtio,bridge=vmbr1 || log_error "Errore nella configurazione di rete!"

# ================================================================
# Passthrough della scheda WiFi
# ================================================================
log_info "Identificazione della scheda WiFi PCI..."
WIFI_PCI=$(lspci -nn | grep -i "network controller" | awk '{print $1}' | head -n1)

if [ -z "$WIFI_PCI" ]; then
    log_error "Nessuna scheda WiFi rilevata!"
else
    log_info "Scheda WiFi rilevata su PCI: $WIFI_PCI"
    WIFI_PCI_ID=$(lspci -n -s "$WIFI_PCI" | awk '{print $3}')
    echo "options vfio-pci ids=$WIFI_PCI_ID" > /etc/modprobe.d/vfio.conf
    update-initramfs -u
    qm set "$VMID" --hostpci0 "$WIFI_PCI",pcie=1 || log_error "Errore nel passthrough della scheda WiFi!"
    log_info "Passthrough WiFi completato!"
fi

# ================================================================
# Avvio VM
# ================================================================
log_info "Avvio della VM OpenWRT..."
qm start "$VMID" || log_error "Errore nell'avvio della VM!"

log_info "Script completato con successo!"
echo "==== Fine script: $(date) ====" >> "$LOG_FILE"

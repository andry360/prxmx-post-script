#!/bin/bash

# ====================================================
# Script per la creazione di una VM OpenWRT UEFI su Proxmox
# ====================================================

# CONFIGURAZIONE
VMID=$(pvesh get /cluster/nextid)                   # ID della VM (modifica se necessario)
VM_NAME="openwrt"        # Nome della VM
IMAGE_URL="https://downloads.openwrt.org/releases/24.10.0-rc7/targets/x86/64/openwrt-24.10.0-rc7-x86-64-generic-ext4-combined-efi.img.gz"
IMAGE_FILE="openwrt24.10.0efi.img"
STORAGE="local-lvm"         # Nome dello storage di Proxmox
LOG_FILE="$(basename "$0" .sh).log"

# Pulizia file di log precedente
echo "==== Inizio script: $(date) ====" > "$LOG_FILE"

# Inizializza il log
echo "[$(date)] Inizio installazione OpenWRT su Proxmox" | tee "$LOG_FILE"

# ================================================================
# 1️ Scarica e decomprime l'immagine OpenWRT
# ================================================================
echo "[$(date)] Scaricando OpenWRT..." | tee -a "$LOG_FILE"
wget -O openwrt.img.gz "$IMAGE_URL" 2>&1 | tee -a "$LOG_FILE"

echo "[$(date)] Decomprimendo OpenWRT..." | tee -a "$LOG_FILE"
gunzip -f openwrt.img.gz 2>&1 | tee -a "$LOG_FILE"

# ================================================================
# 2️ Creazione della VM UEFI su Proxmox
# ================================================================
echo "[$(date)] Creazione della VM ID $VM_ID..." | tee -a "$LOG_FILE"
qm create $VM_ID --name "$VM_NAME" --memory 512 --net0 virtio,bridge=vmbr0 --bios ovmf --machine q35 --cpu host 2>&1 | tee -a "$LOG_FILE"

# ================================================================
# 3️ Configurazione del disco della VM
# ================================================================
echo "[$(date)] Importazione dell'immagine disco OpenWRT su $STORAGE..." | tee -a "$LOG_FILE"
qm importdisk $VM_ID openwrt.img $STORAGE 2>&1 | tee -a "$LOG_FILE"

echo "[$(date)] Collegamento del disco alla VM..." | tee -a "$LOG_FILE"
qm set $VM_ID --scsihw virtio-scsi-pci --virtio0 $STORAGE:vm-$VM_ID-disk-0 2>&1 | tee -a "$LOG_FILE"

# ================================================================
# 4️ Configurazione UEFI
# ================================================================
echo "[$(date)] Configurazione UEFI..." | tee -a "$LOG_FILE"
qm set $VM_ID --efidisk0 $STORAGE:0,format=raw,efitype=4m,pre-enrolled-keys=1 2>&1 | tee -a "$LOG_FILE"

# ================================================================
# 5️ Configurazione interfacce di rete
# ================================================================
echo "[$(date)] Aggiunta interfaccia WAN (vmbr0)..." | tee -a "$LOG_FILE"
qm set $VM_ID --net0 virtio,bridge=vmbr0 2>&1 | tee -a "$LOG_FILE"

echo "[$(date)] Aggiunta interfaccia LAN (vmbr2)..." | tee -a "$LOG_FILE"
qm set $VM_ID --net1 virtio,bridge=vmbr2 2>&1 | tee -a "$LOG_FILE"

# ================================================================
# 6️ Configurazione del passthrough WiFi
# ================================================================
echo "[$(date)] Verifica della scheda WiFi PCI..." | tee -a "$LOG_FILE"
WIFI_PCI=$(lspci -nn | grep -i network | grep -oE '^[0-9a-f:.]+' | head -n 1)

if [[ -n "$WIFI_PCI" ]]; then
    echo "[$(date)] Trovata scheda WiFi: $WIFI_PCI" | tee -a "$LOG_FILE"
    qm set $VM_ID --hostpci0 $WIFI_PCI,pcie=1 2>&1 | tee -a "$LOG_FILE"
else
    echo "[$(date)] ⚠️ Nessuna scheda WiFi PCI trovata!" | tee -a "$LOG_FILE"
fi

# ================================================================
# 7 Avvio della VM
# ================================================================
echo "[$(date)] Avvio della VM..." | tee -a "$LOG_FILE"
qm start $VM_ID 2>&1 | tee -a "$LOG_FILE"

echo "[$(date)] ✅ Installazione completata con successo!" | tee -a "$LOG_FILE"

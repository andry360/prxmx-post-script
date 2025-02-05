#!/usr/bin/env bash

# Imposta il nome del file di log (stesso nome dello script con estensione .log)
LOG_FILE="$(basename "$0" .sh).log"
exec > >(tee -a "$LOG_FILE") 2>&1

function header_info {
  clear
  cat <<"EOF"
   ____                 _       __     __
  / __ \____  ___  ____| |     / /____/ /_
 / / / / __ \/ _ \/ __ \ | /| / / ___/ __/
 / /_/ / /_/ /  __/ / / / |/ |/ / /  / /_
 \____/ .___/\___/_/ /_/|__/|__/_/   \__/
    /_/ W I R E L E S S   F R E E D O M

EOF
}
header_info
echo -e "Loading..."

#0.1 Funzioni di logging con colori
msg_info() { echo -e "\033[33m[INFO]\033[0m $1"; }
msg_ok() { echo -e "\033[32m[OK]\033[0m $1"; }
msg_error() { echo -e "\033[31m[ERROR]\033[0m $1"; }

# 1. Imposta le variabili *PRIMA* di creare la VM
VMID=$(pvesh get /cluster/nextid) # Ottieni l'ID *prima* di creare la VM
HN="openwrt"
CORE_COUNT="2"
RAM_SIZE="2048"
DISK_SIZE="512M"
STORAGE="local-lvm"  # Modifica se necessario
ISO_DIR="/var/lib/vz/template/iso"
ISO_FILE="openwrt-24.10.0-rc7-x86-64-generic-ext4-rootfs.img.gz"
ISO_PATH="$ISO_DIR/$ISO_FILE"
RAW_FILE="${ISO_PATH%.gz}"
URL="https://downloads.openwrt.org/releases/24.10.0-rc7/targets/x86/64/$ISO_FILE"
SHA256SUM_EXPECTED="5c7e20a3667d1c0367d8abf666a73c5d28fa1fa3d3fd1ec680e10a05dd88984f"

# 2. Scarica e verifica l'immagine
if [[ ! -f "$ISO_PATH" ]]; then
  msg_info "Scaricamento di OpenWrt..."
  wget -O "$ISO_PATH" "$URL" || { msg_error "Errore nel download."; exit 1; }
  # Aggiungi la verifica dell'hash SHA256
  SHA256SUM_CALCULATED=$(sha256sum "$ISO_PATH" | awk '{print $1}')
  if [[ "$SHA256SUM_CALCULATED" != "$SHA256SUM_EXPECTED" ]]; then
    msg_error "Errore: Hash SHA256 non corrispondente. File corrotto."
    rm "$ISO_PATH"  # Cancella il file corrotto
    exit 1
  fi
  msg_ok "Download completato e verificato: $ISO_PATH"
fi

# 3. Estrai l'immagine
if [[ ! -f "$RAW_FILE" ]]; then
  msg_info "Estrazione dell'immagine OpenWrt..."
  gunzip -f "$ISO_PATH" || { msg_error "Errore nell'estrazione."; exit 1; }
  msg_ok "File estratto: $RAW_FILE"
fi


# 4. Crea la VM
msg_info "Creazione della VM UEFI..."
qm create $VMID \
  -name $HN \
  -memory $RAM_SIZE \
  -cores $CORE_COUNT \
  -cpu host \
  -net0 virtio,bridge=vmbr0 \
  -scsihw virtio-scsi-pci \
  -scsi0 $STORAGE:vm-$VMID-disk-0,size=$DISK_SIZE \
  -boot order=scsi0 \
  -machine q35 \
  -efidisk0 $STORAGE:vm-$VMID-efi,size=4M,efitype=4m \
  -bios ovmf \
  -ostype l26
msg_ok "VM $HN ($VMID) creata con firmware UEFI."

# 5. Importa il disco *dopo* aver creato la VM
msg_info "Importazione del disco OpenWrt..."
qm importdisk $VMID $RAW_FILE $STORAGE --format raw || { msg_error "Importazione disco fallita."; exit 1; }
qm set $VMID -scsi0 $STORAGE:vm-$VMID-disk-0 || { msg_error "Assegnazione disco fallita."; exit 1; }
msg_ok "Disco OpenWrt importato in $STORAGE."

# 6. Wi-Fi Passthrough (come nel tuo script originale)
WIFI_PCI_ID=$(lspci -nn | grep -i 'network' | awk '{print $1}')
if [[ -z "$WIFI_PCI_ID" ]]; then
  msg_error "Nessuna scheda Wi-Fi PCIe trovata."
  exit 1
fi
msg_ok "Scheda Wi-Fi trovata con ID: $WIFI_PCI_ID"
msg_info "Configurazione del passthrough PCIe..."
qm set $VMID -hostpci0 $WIFI_PCI_ID,pcie=1
msg_ok "Scheda Wi-Fi assegnata alla VM."

# 7. Avvia la VM
msg_info "Avvio della VM..."
qm start $VMID
msg_ok "VM avviata con successo."

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

#1 Imposta ID della VM e parametri
VMID=$(pvesh get /cluster/nextid)
HN="openwrt"
CORE_COUNT="2"
RAM_SIZE="2048"
DISK_SIZE="512M"
STORAGE="local-lvm"  # Modifica se necessario
ISO_DIR="/var/lib/vz/template/iso"
ISO_FILE="openwrt-24.10.0-rc7-x86-64-generic-ext4-rootfs.img.gz"
ISO_PATH="$ISO_DIR/$ISO_FILE"
RAW_FILE="${ISO_PATH%.gz}"  # Nome del file senza .gz
# URL fisso della versione desiderata di OpenWrt
URL="https://downloads.openwrt.org/releases/24.10.0-rc7/targets/x86/64/$ISO_FILE"
SHA256SUM_EXPECTED="5c7e20a3667d1c0367d8abf666a73c5d28fa1fa3d3fd1ec680e10a05dd88984f"  # Inserisci l'hash corretto

#1 Scarica l'immagine OpenWrt solo se non è già presente
if [[ ! -f "$ISO_PATH" ]]; then
  echo "[INFO] 1 Scaricamento di OpenWrt..."
  wget -O "$ISO_PATH" "$URL" || { echo "[ERROR] 1 Errore nel download."; exit 1; }
  echo "[OK] 1 Download completato: $ISO_PATH"
fi

#2 Estrazione se non è già stato estratto
if [[ ! -f "$RAW_FILE" ]]; then
  echo "[INFO] 2 Estrazione dell'immagine OpenWrt..."
  gunzip -f "$ISO_PATH" || { echo "[ERROR] 2 Errore nell'estrazione."; exit 1; }
  echo "[OK] 2 File estratto: $RAW_FILE"
fi

#3 Creazione della VM con UEFI
msg_info "3 Creazione della VM UEFI..."
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
msg_ok "3 VM $HN ($VMID) creata con firmware UEFI."

#4 Importa il disco in `local-lvm`
echo "[INFO] 4 Importazione del disco OpenWrt..."
qm importdisk $VMID $RAW_FILE $STORAGE --format raw || { echo "[ERROR] 4.1 Importazione disco fallita."; exit 1; }
qm set $VMID -scsi0 $STORAGE:vm-$VMID-disk-0 || { echo "[ERROR] 4.2 Assegnazione disco fallita."; exit 1; }
echo "[OK] 4 Disco OpenWrt importato in $STORAGE."

#5.1 Identifica l'ID della scheda Wi-Fi PCIe
WIFI_PCI_ID=$(lspci -nn | grep -i 'network' | awk '{print $1}')
if [[ -z "$WIFI_PCI_ID" ]]; then
  msg_error "5.1 Nessuna scheda Wi-Fi PCIe trovata. Assicurati che sia installata correttamente."
  exit 1
fi
msg_ok "5.1 Scheda Wi-Fi trovata con ID: $WIFI_PCI_ID"

#5.2 Abilita il passthrough della scheda Wi-Fi
msg_info "5.2 Configurazione del passthrough PCIe per la scheda Wi-Fi..."
qm set $VMID -hostpci0 $WIFI_PCI_ID,pcie=1
msg_ok "5.2 Scheda Wi-Fi assegnata alla VM."

#7 Avvia la VM
msg_info "Avvio della VM..."
qm start $VMID
msg_ok "VM avviata con successo."



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

# Funzioni di logging con colori
msg_info() { echo -e "\033[33m[INFO]\033[0m $1"; }
msg_ok() { echo -e "\033[32m[OK]\033[0m $1"; }
msg_error() { echo -e "\033[31m[ERROR]\033[0m $1"; }

# Imposta ID della VM e parametri
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

# Identifica l'ID della scheda Wi-Fi PCIe
WIFI_PCI_ID=$(lspci -nn | grep -i 'network' | awk '{print $1}')
if [[ -z "$WIFI_PCI_ID" ]]; then
  msg_error "Nessuna scheda Wi-Fi PCIe trovata. Assicurati che sia installata correttamente."
  exit 1
fi
msg_ok "Scheda Wi-Fi trovata con ID: $WIFI_PCI_ID"

# Controlla se l'immagine OpenWrt esiste già, altrimenti la scarica
if [[ -f "$ISO_PATH" ]]; then
  msg_ok "Il file OpenWrt esiste già: $ISO_PATH"
else
  msg_info "Scaricamento di OpenWrt..."
  wget -O "$ISO_PATH" "$URL"
  msg_ok "Download completato: $ISO_PATH"
fi

msg_info "Verifica dell'integrità del file con SHA256..."
SHA256SUM_ACTUAL=$(sha256sum "$ISO_PATH" | awk '{print $1}')

# Stampa i valori effettivo e atteso
echo "SHA256 Attuale:   $SHA256SUM_ACTUAL"
echo "SHA256 Atteso:    $SHA256SUM_EXPECTED"

# Confronto tra gli hash
#if [[ "$SHA256SUM_ACTUAL" != "$SHA256SUM_EXPECTED" ]]; then
 # msg_error "Checksum non valido! Il file potrebbe essere corrotto. Scarica nuovamente."
  #rm -f "$ISO_PATH"
  #exit 1
#fi
#msg_ok "Checksum valido!"


# Estrazione del file se non è già estratto
if [[ -f "$RAW_FILE" ]]; then
  msg_ok "Il file RAW esiste già: $RAW_FILE"
else
  msg_info "Estrazione dell'immagine OpenWrt..."
  gunzip -f "$ISO_PATH"
  msg_ok "File estratto: $RAW_FILE"
fi

# Controllo e abilitazione di IOMMU
msg_info "Verifica e abilitazione IOMMU..."
if grep -q "intel_iommu=on" /etc/default/grub; then
  msg_ok "IOMMU è già abilitato in GRUB."
else
  echo "intel_iommu=on" >> /etc/default/grub
  update-grub
  msg_ok "IOMMU abilitato in GRUB."
fi

# Configura VFIO per isolare la scheda Wi-Fi
WIFI_PCI_IDS=$(lspci -n | grep $WIFI_PCI_ID | awk '{print $3}')
echo "options vfio-pci ids=$WIFI_PCI_IDS" > /etc/modprobe.d/vfio.conf
update-initramfs -u
msg_ok "Modulo VFIO configurato per la scheda Wi-Fi ($WIFI_PCI_IDS)."

msg_info "Riavviare Proxmox per applicare le modifiche se necessario."

# Creazione della VM con UEFI
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

# Importa il disco OpenWrt in Proxmox
msg_info "Importazione del disco OpenWrt..."
qm importdisk $VMID $RAW_FILE $STORAGE --format raw
qm set $VMID -scsi0 $STORAGE:vm-$VMID-disk-0
msg_ok "Disco OpenWrt importato."

# Abilita il passthrough della scheda Wi-Fi
msg_info "Configurazione del passthrough PCIe per la scheda Wi-Fi..."
qm set $VMID -hostpci0 $WIFI_PCI_ID,pcie=1
msg_ok "Scheda Wi-Fi assegnata alla VM."

# Avvia la VM
msg_info "Avvio della VM..."
qm start $VMID
msg_ok "VM avviata con successo."

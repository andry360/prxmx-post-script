#!/usr/bin/env bash

function header_info {
  clear
  cat <<"EOF"
OPENWRT VM CREATION SCRIPT
EOF
}
# Richiamo funzione header_info
header_info

echo -e "Loading..."
GEN_MAC=02:$(openssl rand -hex 5 | awk '{print toupper($0)}' | sed 's/\(..\)/\1:/g; s/.$//')
GEN_MAC_LAN=02:$(openssl rand -hex 5 | awk '{print toupper($0)}' | sed 's/\(..\)/\1:/g; s/.$//')
NEXTID=$(pvesh get /cluster/nextid)
# ================================================================
YW=$(echo "\033[33m")  # Yellow
BL=$(echo "\033[36m") # Blue
HA=$(echo "\033[1;34m") # High Intensity Blue
RD=$(echo "\033[01;31m") # Red
BGN=$(echo "\033[4;92m") #
GN=$(echo "\033[1;92m") #
DGN=$(echo "\033[32m") #
CL=$(echo "\033[m") # 
BFR="\\r\\033[K" #
HOLD="-" #
CM="${GN}✓${CL}"
CROSS="${RD}✗${CL}" #
# Questo comando imposta diverse opzioni per la shell Bash, influenzando il modo in cui lo script gestisce gli errori e le pipeline di comandi
# E= Lo script termina immediatamente se un comando fallisce (ovvero, restituisce un codice di uscita diverso da zero)
# e= Quando un comando fallisce, viene visualizzato il comando stesso prima che lo script termini. Questo aiuta a capire quale comando ha causato l'errore.
# o pipefail= Se un comando in una pipeline fallisce, l'intera pipeline viene considerata fallita. Normalmente, in una pipeline (ad esempio, comando1 | comando2), se comando2 fallisce ma comando1 ha successo, la pipeline viene considerata riuscita. Questa opzione cambia tale comportamento.
set -Eeo pipefail
# imposta una trappola per il segnale di errore (ERR)
# Specifica il comando da eseguire quando viene catturato il segnale ERR. In questo caso, viene chiamata la funzione error_handler
# LINENO è la variabile Bash che contiene il numero di riga del comando che ha causato l'errore e BASH_COMMAND è quella che contiene il comando che l'ha causato.
trap 'error_handler $LINENO "$BASH_COMMAND"' ERR
trap cleanup EXIT

# ================================================================
# Error handler
# ================================================================

function error_handler() {
  local exit_code="$?"
  local line_number="$1"
  local command="$2"
  local error_message="${RD}[ERROR]${CL} in line ${RD}$line_number${CL}: exit code ${RD}$exit_code${CL}: while executing command ${YW}$command${CL}"
  echo -e "\n$error_message\n"
  cleanup_vmid
}

# ================================================================
# Funzioni di cleanup
# ================================================================
function cleanup_vmid() {
  if qm status $VMID &>/dev/null; then
    qm stop $VMID &>/dev/null
    qm destroy $VMID &>/dev/null
  fi
}

function cleanup() {
  popd >/dev/null
  rm -rf $TEMP_DIR
}

# ================================================================
# Creazione directory temporanea
# ================================================================
TEMP_DIR=$(mktemp -d)
pushd $TEMP_DIR >/dev/null

# ================================================================
# 
# ================================================================
function send_line_to_vm() {
  echo -e "${DGN}Sending line: ${YW}$1${CL}"
  for ((i = 0; i < ${#1}; i++)); do
    character=${1:i:1}
    case $character in
    " ") character="spc" ;;
    "-") character="minus" ;;
    "=") character="equal" ;;
    ",") character="comma" ;;
    ".") character="dot" ;;
    "/") character="slash" ;;
    "'") character="apostrophe" ;;
    ";") character="semicolon" ;;
    '\') character="backslash" ;;
    '`') character="grave_accent" ;;
    "[") character="bracket_left" ;;
    "]") character="bracket_right" ;;
    "_") character="shift-minus" ;;
    "+") character="shift-equal" ;;
    "?") character="shift-slash" ;;
    "<") character="shift-comma" ;;
    ">") character="shift-dot" ;;
    '"') character="shift-apostrophe" ;;
    ":") character="shift-semicolon" ;;
    "|") character="shift-backslash" ;;
    "~") character="shift-grave_accent" ;;
    "{") character="shift-bracket_left" ;;
    "}") character="shift-bracket_right" ;;
    "A") character="shift-a" ;;
    "B") character="shift-b" ;;
    "C") character="shift-c" ;;
    "D") character="shift-d" ;;
    "E") character="shift-e" ;;
    "F") character="shift-f" ;;
    "G") character="shift-g" ;;
    "H") character="shift-h" ;;
    "I") character="shift-i" ;;
    "J") character="shift-j" ;;
    "K") character="shift-k" ;;
    "L") character="shift-l" ;;
    "M") character="shift-m" ;;
    "N") character="shift-n" ;;
    "O") character="shift-o" ;;
    "P") character="shift-p" ;;
    "Q") character="shift-q" ;;
    "R") character="shift-r" ;;
    "S") character="shift-s" ;;
    "T") character="shift-t" ;;
    "U") character="shift-u" ;;
    "V") character="shift-v" ;;
    "W") character="shift-w" ;;
    "X") character="shift-x" ;;
    "Y") character="shift-y" ;;
    "Z") character="shift-z" ;;
    "!") character="shift-1" ;;
    "@") character="shift-2" ;;
    "#") character="shift-3" ;;
    '$') character="shift-4" ;;
    "%") character="shift-5" ;;
    "^") character="shift-6" ;;
    "&") character="shift-7" ;;
    "*") character="shift-8" ;;
    "(") character="shift-9" ;;
    ")") character="shift-0" ;;
    esac
    qm sendkey $VMID "$character"
  done
  qm sendkey $VMID ret
}

TEMP_DIR=$(mktemp -d)
pushd $TEMP_DIR >/dev/null

if (whiptail --backtitle "Proxmox VE Helper Scripts" --title "OpenWrt VM" --yesno "This will create a New OpenWrt VM. Proceed?" 10 58); then
  :
else
  header_info && echo -e "⚠ User exited script \n" && exit
fi

function msg_info() {
  local msg="$1"
  echo -ne " ${HOLD} ${YW}${msg}..."
}

function msg_ok() {
  local msg="$1"
  echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
}

function msg_error() {
  local msg="$1"
  echo -e "${BFR} ${CROSS} ${RD}${msg}${CL}"
}

function pve_check() {
  if ! pveversion | grep -Eq "pve-manager/8.[1-5]"; then
    msg_error "This version of Proxmox Virtual Environment is not supported"
    echo -e "Requires Proxmox Virtual Environment Version 8.1 or later."
    echo -e "Exiting..."
    sleep 2
    exit
fi
}

function exit-script() {
  clear
  echo -e "⚠  User exited script \n"
  exit
}

# ================================================================
# Funzione settaggi default VM
# ================================================================
function default_settings() {
  VMID=$NEXTID
  HN="openwrt"
  CORE_COUNT="2"
  RAM_SIZE="512"
  BRG="vmbr0"
  VLAN=""
  MAC=$GEN_MAC
  LAN_MAC=$GEN_MAC_LAN
  LAN_BRG="vmbr1"
  LAN_IP_ADDR="192.168.1.254"
  LAN_NETMASK="255.255.255.0"
  LAN_VLAN=""
  MTU=""
  START_VM="yes"
  EFI_DISK="yes"  # Attiva disco EFI
  STORAGE_POOL="local-lvm"  # Nome dello storage per il disco EFI

  echo -e "${DGN}Using Virtual Machine ID: ${BGN}${VMID}${CL}"
  echo -e "${DGN}Using Hostname: ${BGN}${HN}${CL}"
  echo -e "${DGN}Allocated Cores: ${BGN}${CORE_COUNT}${CL}"
  echo -e "${DGN}Allocated RAM: ${BGN}${RAM_SIZE}${CL}"
  echo -e "${DGN}Using WAN Bridge: ${BGN}${BRG}${CL}"
  echo -e "${DGN}Using WAN VLAN: ${BGN}Default${CL}"
  echo -e "${DGN}Using WAN MAC Address: ${BGN}${MAC}${CL}"
  echo -e "${DGN}Using LAN MAC Address: ${BGN}${LAN_MAC}${CL}"
  echo -e "${DGN}Using LAN Bridge: ${BGN}${LAN_BRG}${CL}"
  echo -e "${DGN}Using LAN VLAN: ${BGN}${CL}"
  echo -e "${DGN}Using LAN IP Address: ${BGN}${LAN_IP_ADDR}${CL}"
  echo -e "${DGN}Using LAN NETMASK: ${BGN}${LAN_NETMASK}${CL}"
  echo -e "${DGN}Using Interface MTU Size: ${BGN}Default${CL}"
  echo -e "${DGN}Using EFI Boot: ${BGN}${EFI_DISK}${CL}"
  echo -e "${DGN}Using Storage Pool: ${BGN}${STORAGE_POOL}${CL}"
  echo -e "${DGN}Start VM when completed: ${BGN}${START_VM}${CL}"
  echo -e "${BL}Creating an OpenWRT VM using the above default settings${CL}"
}

# ================================================================
# Funzione settaggi avanzati VM
# ================================================================

function advanced_settings() {
  while true; do
    if VMID=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set Virtual Machine ID" 8 58 $NEXTID --title "VIRTUAL MACHINE ID" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
      if [ -z "$VMID" ]; then
        VMID="$NEXTID"
      fi
      if pct status "$VMID" &>/dev/null || qm status "$VMID" &>/dev/null; then
        echo -e "${CROSS}${RD} ID $VMID is already in use${CL}"
        sleep 2
        continue
      fi
      echo -e "${DGN}Virtual Machine ID: ${BGN}$VMID${CL}"
      break
    else
      exit-script
    fi
  done

  # Aggiunta opzione per il tipo di boot (BIOS o UEFI)
  if (whiptail --backtitle "Proxmox VE Helper Scripts" --title "Enable EFI Boot" --yesno "Use UEFI boot (OVMF)?" 10 58); then
    USE_EFI="yes"
  else
    USE_EFI="no"
  fi
  echo -e "${DGN}Using EFI Boot: ${BGN}$USE_EFI${CL}"

  # Aggiunta opzione per lo storage pool
  if STORAGE_POOL=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set Storage Pool (default: local-lvm)" 8 58 local-lvm --title "STORAGE POOL" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z "$STORAGE_POOL" ]; then
      STORAGE_POOL="local-lvm"
    fi
    echo -e "${DGN}Using Storage Pool: ${BGN}$STORAGE_POOL${CL}"
  else
    exit-script
  fi

  if VM_NAME=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set Hostname" 8 58 openwrt --title "HOSTNAME" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $VM_NAME ]; then
      HN="openwrt"
    else
      HN=$(echo ${VM_NAME,,} | tr -d ' ')
    fi
    echo -e "${DGN}Using Hostname: ${BGN}$HN${CL}"
  else
    exit-script
  fi

  if CORE_COUNT=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Allocate CPU Cores" 8 58 1 --title "CORE COUNT" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $CORE_COUNT ]; then
      CORE_COUNT="2"
    fi
    echo -e "${DGN}Allocated Cores: ${BGN}$CORE_COUNT${CL}"
  else
    exit-script
  fi

  if RAM_SIZE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Allocate RAM in MiB" 8 58 256 --title "RAM" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $RAM_SIZE ]; then
      RAM_SIZE="512"
    fi
    echo -e "${DGN}Allocated RAM: ${BGN}$RAM_SIZE${CL}"
  else
    exit-script
  fi

  if BRG=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set a WAN Bridge" 8 58 vmbr0 --title "WAN BRIDGE" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $BRG ]; then
      BRG="vmbr0"
    fi
    echo -e "${DGN}Using WAN Bridge: ${BGN}$BRG${CL}"
  else
    exit-script
  fi

  if LAN_BRG=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set a LAN Bridge" 8 58 vmbr0 --title "LAN BRIDGE" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $LAN_BRG ]; then
      LAN_BRG="vmbr1"
    fi
    echo -e "${DGN}Using LAN Bridge: ${BGN}$LAN_BRG${CL}"
  else
    exit-script
  fi

  if LAN_IP_ADDR=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set a router IP" 8 58 $LAN_IP_ADDR --title "LAN IP ADDRESS" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $LAN_IP_ADDR ]; then
      LAN_IP_ADDR="192.168.1.254"
    fi
    echo -e "${DGN}Using LAN IP ADDRESS: ${BGN}$LAN_IP_ADDR${CL}"
  else
    exit-script
  fi

  if LAN_NETMASK=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set a router netmmask" 8 58 $LAN_NETMASK --title "LAN NETMASK" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $LAN_NETMASK ]; then
      LAN_NETMASK="255.255.255.0"
    fi
    echo -e "${DGN}Using LAN NETMASK: ${BGN}$LAN_NETMASK${CL}"
  else
    exit-script
  fi

  if MAC1=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set a WAN MAC Address" 8 58 $GEN_MAC --title "WAN MAC ADDRESS" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $MAC1 ]; then
      MAC="$GEN_MAC"
    else
      MAC="$MAC1"
    fi
    echo -e "${DGN}Using WAN MAC Address: ${BGN}$MAC${CL}"
  else
    exit-script
  fi

  if MAC2=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set a LAN MAC Address" 8 58 $GEN_MAC_LAN --title "LAN MAC ADDRESS" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $MAC2 ]; then
      LAN_MAC="$GEN_MAC_LAN"
    else
      LAN_MAC="$MAC2"
    fi
    echo -e "${DGN}Using LAN MAC Address: ${BGN}$LAN_MAC${CL}"
  else
    exit-script
  fi

  if VLAN1=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set a WAN Vlan (leave blank for default)" 8 58 --title "WAN VLAN" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $VLAN1 ]; then
      VLAN1="Default"
      VLAN=""
    else
      VLAN=",tag=$VLAN1"
    fi
    echo -e "${DGN}Using WAN Vlan: ${BGN}$VLAN1${CL}"
  else
    exit-script
  fi

  if VLAN2=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set a LAN Vlan" 8 58 999 --title "LAN VLAN" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $VLAN2 ]; then
      VLAN2=""
      LAN_VLAN=",tag=$VLAN2"
    else
      LAN_VLAN=",tag=$VLAN2"
    fi
    echo -e "${DGN}Using LAN Vlan: ${BGN}$VLAN2${CL}"
  else
    exit-script
  fi

  if MTU1=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set Interface MTU Size (leave blank for default)" 8 58 --title "MTU SIZE" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $MTU1 ]; then
      MTU1="Default"
      MTU=""
    else
      MTU=",mtu=$MTU1"
    fi
    echo -e "${DGN}Using Interface MTU Size: ${BGN}$MTU1${CL}"
  else
    exit-script
  fi

  if (whiptail --backtitle "Proxmox VE Helper Scripts" --title "START VIRTUAL MACHINE" --yesno "Start VM when completed?" 10 58); then
    START_VM="yes"
  else
    START_VM="no"
  fi
  echo -e "${DGN}Start VM when completed: ${BGN}$START_VM${CL}"

  if (whiptail --backtitle "Proxmox VE Helper Scripts" --title "ADVANCED SETTINGS COMPLETE" --yesno "Ready to create OpenWrt VM?" --no-button Do-Over 10 58); then
    echo -e "${RD}Creating a OpenWrt VM using the above advanced settings${CL}"
  else
    header_info
    echo -e "${RD}Using Advanced Settings${CL}"
    advanced_settings
  fi
}

function start_script() {
  if (whiptail --backtitle "Proxmox VE Helper Scripts" --title "SETTINGS" --yesno "Use Default Settings?" --no-button Advanced 10 58); then
    header_info
    echo -e "${BL}Using Default Settings${CL}"
    default_settings
  else
    header_info
    echo -e "${RD}Using Advanced Settings${CL}"
    advanced_settings
  fi
}

pve_check
start_script

# ================================================================
# Validazione storage
# ================================================================
msg_info "Validating Storage"
while read -r line; do
  TAG=$(echo $line | awk '{print $1}')
  TYPE=$(echo $line | awk '{printf "%-10s", $2}')
  FREE=$(echo $line | numfmt --field 4-6 --from-unit=K --to=iec --format %.2f | awk '{printf( "%9sB", $6)}')
  ITEM="  Type: $TYPE Free: $FREE "
  OFFSET=2
  if [[ $((${#ITEM} + $OFFSET)) -gt ${MSG_MAX_LENGTH:-} ]]; then
    MSG_MAX_LENGTH=$((${#ITEM} + $OFFSET))
  fi
  STORAGE_MENU+=("$TAG" "$ITEM" "OFF")
done < <(pvesm status -content images | awk 'NR>1')
VALID=$(pvesm status -content images | awk 'NR>1')
if [ -z "$VALID" ]; then
  echo -e "\n${RD}⚠ Unable to detect a valid storage location.${CL}"
  echo -e "Exiting..."
  exit
elif [ $((${#STORAGE_MENU[@]} / 3)) -eq 1 ]; then
  STORAGE=${STORAGE_MENU[0]}
else
  while [ -z "${STORAGE:+x}" ]; do
    STORAGE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "Storage Pools" --radiolist \
      "Which storage pool you would like to use for the OpenWrt VM?\n\n" \
      16 $(($MSG_MAX_LENGTH + 23)) 6 \
      "${STORAGE_MENU[@]}" 3>&1 1>&2 2>&3) || exit
  done
fi
msg_ok "Using ${CL}${BL}$STORAGE${CL} ${GN}for Storage Location."
msg_ok "Virtual Machine ID is ${CL}${BL}$VMID${CL}."
msg_info "Getting URL for OpenWrt Disk Image"

# ================================================================
# Download openwrt
# ================================================================
response=$(curl -s https://openwrt.org)
URL="https://mirror-03.infra.openwrt.org/releases/24.10.0-rc7/targets/x86/64/openwrt-24.10.0-rc7-x86-64-generic-ext4-combined-efi.img.gz"
stableversion=$(echo "$response" | sed -n 's/.*Current stable release - OpenWrt \([0-9.]\+\).*/\1/p')
#URL="https://downloads.openwrt.org/releases/$stableversion/targets/x86/64/openwrt-$stableversion-x86-64-generic-ext4-combined.img.gz"

sleep 2
msg_ok "${CL}${BL}${URL}${CL}"
# Controlla se il file è già scaricato
FILE=$(basename "$URL")
if [ -f "$FILE" ]; then
  msg_ok "File ${CL}${BL}$FILE${CL} già presente. Salto il download."
else
  wget -q --show-progress "$URL"
  echo -en "\e[1A\e[0K"
  msg_ok "Downloaded ${CL}${BL}$FILE${CL}"
fi
echo -en "\e[1A\e[0K"
FILE=$(basename $URL)
msg_ok "Downloaded ${CL}${BL}$FILE${CL}"
gunzip -f $FILE >/dev/null 2>/dev/null || true
NEWFILE="${FILE%.*}"
FILE="$NEWFILE"
mv $FILE ${FILE%.*}
qemu-img resize -f raw ${FILE%.*} 512M >/dev/null 2>/dev/null
msg_ok "Extracted & Resized OpenWrt Disk Image ${CL}${BL}$FILE${CL}"
STORAGE_TYPE=$(pvesm status -storage $STORAGE | awk 'NR>1 {print $2}')
case $STORAGE_TYPE in
nfs | dir)
  DISK_EXT=".qcow2"
  DISK_REF="$VMID/"
  DISK_IMPORT="-format qcow2"
  ;;
btrfs)
  DISK_EXT=".raw"
  DISK_REF="$VMID/"
  DISK_IMPORT="-format raw"
  ;;
esac
for i in {0,1}; do
  disk="DISK$i"
  eval DISK${i}=vm-${VMID}-disk-${i}${DISK_EXT:-}
  eval DISK${i}_REF=${STORAGE}:${DISK_REF:-}${!disk}
done

# ================================================================
# Creazione VM
# ================================================================
msg_info "Creating OpenWrt VM"
qm create $VMID -cores $CORE_COUNT -memory $RAM_SIZE -name $HN \
  -onboot 1 -ostype l26 -scsihw virtio-scsi-pci --tablet 0
pvesm alloc $STORAGE $VMID $DISK0 4M 1>&/dev/null
qm importdisk $VMID ${FILE%.*} $STORAGE ${DISK_IMPORT:-} 1>&/dev/null
qm set $VMID \
  -bios ovmf \
  -machine q35 \
  -efidisk0 ${DISK0_REF},efitype=4m,size=4M \
  -scsi0 ${DISK1_REF},size=512M \
  -boot order=scsi0 \
  -tags proxmox-helper-scripts \
  -description "<div align='center'><a href='https://Helper-Scripts.com'><img src='https://raw.githubusercontent.com/tteck/Proxmox/main/misc/images/logo-81x112.png'/></a>
  # OpenWRT
  </div>" >/dev/null

# Dato che senza l'efidisk ricevo un errore, ma considerando anche il fatto che dopo aver creato la VM questa non si avvia con l'efidisk...lo rimuovo subito dop averla creata.
qm set $VMID -delete efidisk0

# ================================================================
# Settaggio VM con i parametri creati in precedenza tramite UCI
# ================================================================
msg_ok "Created OpenWrt VM ${CL}${BL}(${HN})"
msg_info "OpenWrt is being started in order to configure the network interfaces."
qm start $VMID
sleep 15
msg_ok "Network interfaces are being configured as OpenWrt initiates."
  # Configurazione WAN
  send_line_to_vm "uci set network.wan=interface"
  send_line_to_vm "uci set network.wan.device=eth1"
  send_line_to_vm "uci set network.wan.proto=dhcp"

    # Settaggio connessione PPoE per WAN
  send_line_to_vm "uci set network.wan=interface"
  send_line_to_vm "uci set network.wan.device=eth1.835"
  send_line_to_vm "uci set network.wan.proto=pppoe"
  send_line_to_vm "uci set network.wan.username='benvenuto'"
  send_line_to_vm "uci set network.wan.password='ospite'"
  send_line_to_vm "uci set network.wan.encapsulation='llc'"
  send_line_to_vm "uci set network.wan.nat='1'"
    # Settaggio connessione PPoE per VOIP
  ## send_line_to_vm "uci set network.voice=interface"
  ## send_line_to_vm "uci set network.voice.device=eth1.836"
  ## send_line_to_vm "uci set network.voice.proto=none"
  ## send_line_to_vm "uci set network.wan.igmp_snooping='1'"
  # CoS=Class of Service. Gestito attraverso il pacchetto Traffic Control, permette di assegnare prioirità a determinati pacchetti.
  ## send_line_to_vm "uci set network.wan.dscp_prio='0'"  # CoS 0 per dati
  ## send_line_to_vm "uci set network.voice.igmp_snooping='1'"
  ## send_line_to_vm "uci set network.voice.dscp_prio='5'"  # CoS 5 per voce

    # Configurazione VLAN per la segmentazione della rete
  send_line_to_vm "uci set network.lan=interface"
  send_line_to_vm "uci set network.lan.device=eth0"
  send_line_to_vm "uci set network.lan.proto=static"
  send_line_to_vm "uci set network.lan.ipaddr=192.168.1.254"
  send_line_to_vm "uci set network.lan.netmask=255.255.255.0"
  
  send_line_to_vm "uci add network device"
  send_line_to_vm "uci set network.@device[-1].name=eth0.2"
  send_line_to_vm "uci set network.@device[-1].type=8021q"
  send_line_to_vm "uci set network.@device[-1].ifname=eth0"
  send_line_to_vm "uci set network.@device[-1].vid=2"
  
  send_line_to_vm "uci set network.vm_os_domotica=interface"
  send_line_to_vm "uci set network.vm_os_domotica.ifname=eth0.2"
  send_line_to_vm "uci set network.vm_os_domotica.proto=static"
  send_line_to_vm "uci set network.vm_os_domotica.ipaddr=192.168.2.1"
  send_line_to_vm "uci set network.vm_os_domotica.netmask=255.255.255.0"
  
  send_line_to_vm "uci add network device"
  send_line_to_vm "uci set network.@device[-1].name=eth0.3"
  send_line_to_vm "uci set network.@device[-1].type=8021q"
  send_line_to_vm "uci set network.@device[-1].ifname=eth0"
  send_line_to_vm "uci set network.@device[-1].vid=3"
  
  send_line_to_vm "uci set network.smartphone=interface"
  send_line_to_vm "uci set network.smartphone.ifname=eth0.3"
  send_line_to_vm "uci set network.smartphone.proto=static"
  send_line_to_vm "uci set network.smartphone.ipaddr=192.168.3.1"
  send_line_to_vm "uci set network.smartphone.netmask=255.255.255.0"

  send_line_to_vm "uci add network device"
  send_line_to_vm "uci set network.@device[-1].name=eth0.4"
  send_line_to_vm "uci set network.@device[-1].type=8021q"
  send_line_to_vm "uci set network.@device[-1].ifname=eth0"
  send_line_to_vm "uci set network.@device[-1].vid=4"
  
  send_line_to_vm "uci set network.pc=interface"
  send_line_to_vm "uci set network.pc.ifname=eth0.4"
  send_line_to_vm "uci set network.pc.proto=static"
  send_line_to_vm "uci set network.pc.ipaddr=192.168.4.1"
  send_line_to_vm "uci set network.pc.netmask=255.255.255.0"

echo "Configurazione DHCP in corso..."

  send_line_to_vm "uci set dhcp.vm_os_domotica=dhcp"
  send_line_to_vm "uci set dhcp.vm_os_domotica.interface=vm_os_domotica"
  send_line_to_vm "uci set dhcp.vm_os_domotica.start=100"
  send_line_to_vm "uci set dhcp.vm_os_domotica.limit=150"
  send_line_to_vm "uci set dhcp.vm_os_domotica.leasetime=12h"
  
  send_line_to_vm "uci set dhcp.smartphone=dhcp"
  send_line_to_vm "uci set dhcp.smartphone.interface=smartphone"
  send_line_to_vm "uci set dhcp.smartphone.start=100"
  send_line_to_vm "uci set dhcp.smartphone.limit=150"
  send_line_to_vm "uci set dhcp.smartphone.leasetime=12h"
  
  send_line_to_vm "uci set dhcp.pc=dhcp"
  send_line_to_vm "uci set dhcp.pc.interface=pc"
  send_line_to_vm "uci set dhcp.pc.start=100"
  send_line_to_vm "uci set dhcp.pc.limit=150"
  send_line_to_vm "uci set dhcp.pc.leasetime=12h"

  send_line_to_vm "uci commit dhcp"
  send_line_to_vm "/etc/init.d/dnsmasq restart"

echo "Configurazione firewall in corso..."

  send_line_to_vm "uci add firewall zone"
  send_line_to_vm "uci set firewall.@zone[-1].name=vm_os_domotica"
  send_line_to_vm "uci set firewall.@zone[-1].network=vm_os_domotica"
  send_line_to_vm "uci set firewall.@zone[-1].input=ACCEPT"
  send_line_to_vm "uci set firewall.@zone[-1].output=ACCEPT"
  send_line_to_vm "uci set firewall.@zone[-1].forward=ACCEPT"
  
  send_line_to_vm "uci add firewall zone"
  send_line_to_vm "uci set firewall.@zone[-1].name=smartphone"
  send_line_to_vm "uci set firewall.@zone[-1].network=smartphone"
  send_line_to_vm "uci set firewall.@zone[-1].input=ACCEPT"
  send_line_to_vm "uci set firewall.@zone[-1].output=ACCEPT"
  send_line_to_vm "uci set firewall.@zone[-1].forward=ACCEPT"

  send_line_to_vm "uci add firewall zone"
  send_line_to_vm "uci set firewall.@zone[-1].name=pc"
  send_line_to_vm "uci set firewall.@zone[-1].network=pc"
  send_line_to_vm "uci set firewall.@zone[-1].input=ACCEPT"
  send_line_to_vm "uci set firewall.@zone[-1].output=ACCEPT"
  send_line_to_vm "uci set firewall.@zone[-1].forward=ACCEPT"
  
  send_line_to_vm "uci commit firewall"
  send_line_to_vm "/etc/init.d/firewall restart"

# committo le modifiche
send_line_to_vm "uci commit"
send_line_to_vm "halt"
msg_ok "Network interfaces have been successfully configured."
msg_info "VM is being stopped."
until qm status $VMID | grep -q "stopped"; do
  sleep 2
  msg_info "VM is not stopped yet. Waiting..."
done
msg_info "Bridge interfaces are being added."
qm set $VMID \
  -net0 virtio,bridge=${LAN_BRG},macaddr=${LAN_MAC}${LAN_VLAN}${MTU} \
  -net1 virtio,bridge=${BRG},macaddr=${MAC}${VLAN}${MTU} >/dev/null 2>/dev/null
msg_ok "Bridge interfaces have been successfully added."
if [ "$START_VM" == "yes" ]; then
  msg_info "Starting OpenWrt VM"
  qm start $VMID
  msg_ok "Started OpenWrt VM"
fi
VLAN_FINISH=""
if [ "$VLAN" == "" ] && [ "$VLAN2" != "999" ]; then
  VLAN_FINISH=" Please adjust the VLAN tags to suit your network."
fi
msg_ok "Completed Successfully! remember to install: WLAN drivers; wpad drivers; nano; wpa-supplicant-openssl (for wireless and wpa3); pciutils.\n${VLAN_FINISH}"
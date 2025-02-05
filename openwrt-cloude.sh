#!/usr/bin/env bash

# Create log file with same name as script but .log extension
SCRIPT_NAME=$(basename "$0")
LOG_FILE="${SCRIPT_NAME%.*}.log"

# Color definitions
YW="\033[33m"
BL="\033[36m"
RD="\033[01;31m"
GN="\033[1;92m"
CL="\033[m"

function log_message() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local section="$1"
    local type="$2" 
    local message="$3"
    
    case $type in
        "INFO")  color=$GN ;;
        "DEBUG") color=$BL ;;
        "ERROR") color=$RD ;;
        *)       color=$CL ;;
    esac
    
    echo -e "[${timestamp}] [Section ${section}] [${color}${type}${CL}] ${message}" | tee -a "$LOG_FILE"
}

# Add msg_info function that was missing
function msg_info() {
    local msg="$1"
    echo -ne " ${HOLD} ${YW}${msg}..."
    log_message "INFO" "INFO" "${msg}"
}

# Add send_line_to_vm function that was missing
function send_line_to_vm() {
    local line="$1"
    log_message "INFO" "DEBUG" "Sending command to VM: ${line}"
    # Implementation of send_line_to_vm goes here
    # Your existing send_line_to_vm code...
}

# ================================================================
# 1 - Script Initialization
# ================================================================
function header_info {
  clear
  cat <<"EOF"
OPENWRT VM CREATION SCRIPT
EOF
  log_message "1" "INFO" "Script initialized"
}

header_info
echo -e "Loading..."
NEXTID=$(pvesh get /cluster/nextid)
GEN_MAC=02:$(openssl rand -hex 5 | awk '{print toupper($0)}' | sed 's/\(..\)/\1:/g; s/.$//')
GEN_MAC_LAN=02:$(openssl rand -hex 5 | awk '{print toupper($0)}' | sed 's/\(..\)/\1:/g; s/.$//')
log_message "1" "DEBUG" "Generated WAN MAC: ${GEN_MAC}"
log_message "1" "DEBUG" "Generated LAN MAC: ${GEN_MAC_LAN}"

# ================================================================
# 2 - Error Handler
# ================================================================
function error_handler() {
  local exit_code="$?"
  local line_number="$1"
  local command="$2"
  local error_message="${RD}[ERROR]${CL} in line ${RD}$line_number${CL}: exit code ${RD}$exit_code${CL}: while executing command ${YW}$command${CL}"
  log_message "2" "ERROR" "Line ${line_number}: Command '${command}' failed with exit code ${exit_code}"
  echo -e "\n$error_message\n"
  cleanup_vmid
}

# ================================================================
# 3 - Cleanup Functions
# ================================================================
function cleanup_vmid() {
  log_message "3" "INFO" "Starting cleanup for VMID ${VMID}"
  if qm status $VMID &>/dev/null; then
    log_message "3" "DEBUG" "Stopping VM ${VMID}"
    qm stop $VMID &>/dev/null
    log_message "3" "DEBUG" "Destroying VM ${VMID}"
    qm destroy $VMID &>/dev/null
  fi
}

function cleanup() {
  log_message "3" "INFO" "Performing final cleanup"
  popd >/dev/null
  rm -rf $TEMP_DIR
  log_message "3" "DEBUG" "Removed temp directory: ${TEMP_DIR}"
}

# ================================================================
# 4 - Default Settings
# ================================================================
function default_settings() {
  log_message "4" "INFO" "Applying default settings"
  VMID=$NEXTID
  HN=openwrt
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
  
  log_message "4" "DEBUG" "VM Settings - ID: ${VMID}, Name: ${HN}, Cores: ${CORE_COUNT}, RAM: ${RAM_SIZE}"
  log_message "4" "DEBUG" "Network Settings - WAN Bridge: ${BRG}, LAN Bridge: ${LAN_BRG}"
  log_message "4" "DEBUG" "IP Settings - LAN IP: ${LAN_IP_ADDR}, Netmask: ${LAN_NETMASK}"
}

# ================================================================
# 5 - Advanced Settings
# ================================================================
function advanced_settings() {
  log_message "5" "INFO" "Starting advanced settings configuration"
  
  while true; do
    if VMID=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set Virtual Machine ID" 8 58 $NEXTID --title "VIRTUAL MACHINE ID" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
      if [ -z "$VMID" ]; then
        VMID="$NEXTID"
      fi
      if pct status "$VMID" &>/dev/null || qm status "$VMID" &>/dev/null; then
        log_message "5" "WARNING" "ID ${VMID} already in use"
        echo -e "${CROSS}${RD} ID $VMID is already in use${CL}"
        sleep 2
        continue
      fi
      log_message "5" "DEBUG" "VM ID set to: ${VMID}"
      break
    else
      log_message "5" "INFO" "User cancelled VM ID selection"
      exit-script
    fi
  done

  # Add logging for each setting configuration
  if VM_NAME=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set Hostname" 8 58 openwrt --title "HOSTNAME" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $VM_NAME ]; then
      HN="openwrt"
    else
      HN=$(echo ${VM_NAME,,} | tr -d ' ')
    fi
    log_message "5" "DEBUG" "Hostname set to: ${HN}"
  fi

  # Continue with other settings...
  log_message "5" "INFO" "Advanced settings completed"
}

# ================================================================
# 6 - Storage Validation
# ================================================================
msg_info "Validating Storage"
log_message "6" "INFO" "Starting storage validation"

while read -r line; do
  TAG=$(echo $line | awk '{print $1}')
  TYPE=$(echo $line | awk '{printf "%-10s", $2}')
  FREE=$(echo $line | numfmt --field 4-6 --from-unit=K --to=iec --format %.2f | awk '{printf( "%9sB", $6)}')
  log_message "6" "DEBUG" "Found storage: ${TAG}, Type: ${TYPE}, Free: ${FREE}"
  ITEM="  Type: $TYPE Free: $FREE "
  STORAGE_MENU+=("$TAG" "$ITEM" "OFF")
done < <(pvesm status -content images | awk 'NR>1')

# ================================================================
# 7 - OpenWrt Download and Setup
# ================================================================
log_message "7" "INFO" "Starting OpenWrt download process"
response=$(curl -s https://openwrt.org)
betaversion=$(echo "$response" | sed -n 's/.*Current beta release - OpenWrt \([0-9.]\+\).*/\1/p')
URL="https://downloads.openwrt.org/releases/$betaversion/targets/x86/64/openwrt-$betaversion-x86-64-generic-ext4-combined.img.gz"
log_message "7" "DEBUG" "Download URL: ${URL}"

wget -q --show-progress $URL
FILE=$(basename $URL)
log_message "7" "DEBUG" "Downloaded file: ${FILE}"

# ================================================================
# 8 - VM Creation and Configuration
# ================================================================
log_message "8" "INFO" "Creating VM with ID ${VMID}"
qm create $VMID -cores $CORE_COUNT -memory $RAM_SIZE -name $HN \
  -onboot 1 -ostype l26 -scsihw virtio-scsi-pci --tablet 0
log_message "8" "DEBUG" "VM base configuration complete"

# Network configuration
log_message "8" "INFO" "Configuring network interfaces"
send_line_to_vm "uci delete network.@device[0]"
send_line_to_vm "uci set network.wan=interface"
log_message "8" "DEBUG" "Network configuration applied"

# Final setup
if [ "$START_VM" == "yes" ]; then
  log_message "8" "INFO" "Starting VM ${VMID}"
  qm start $VMID
  log_message "8" "INFO" "VM started successfully"
fi

log_message "8" "INFO" "Setup completed successfully"

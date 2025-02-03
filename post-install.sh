#!/usr/bin/env bash
#Configura i repository software: 
#Imposta i repository di Debian Bookworm (la distribuzione di base di Proxmox VE) e il repository "pve-no-subscription" (per il software open source di Proxmox).
#Disabilita il repository "pve-enterprise" (per il software a pagamento) 
#Configura i repository per Ceph (un software di storage distribuito), lasciandoli disabilitati di default.

header_info() {
  clear
  cat <<"EOF"
    ____ _    ________   ____             __     ____           __        ____
   / __ \ |  / / ____/  / __ \____  _____/ /_   /  _/___  _____/ /_____ _/ / /
  / /_/ / | / / __/    / /_/ / __ \/ ___/ __/   / // __ \/ ___/ __/ __ `/ / /
 / ____/| |/ / /___   / ____/ /_/ (__  ) /_   _/ // / / (__  ) /_/ /_/ / / /
/_/     |___/_____/  /_/    \____/____/\__/  /___/_/ /_/ weekend/\__/\__,_/_/_/

EOF
}

RD=$(echo "\033[01;31m")
YW=$(echo "\033[33m")
GN=$(echo "\033[1;92m")
CL=$(echo "\033[m")
BFR="\\r\\033[K"
HOLD="-"
CM="${GN}✓${CL}"
CROSS="${RD}✗${CL}"

set -euo pipefail
shopt -s inherit_errexit nullglob

msg_info() {
  local msg="$1"
  echo -e " ${HOLD} ${YW}${msg}..."
}

msg_ok() {
  local msg="$1"
  echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
}

msg_error() {
  local msg="$1"
  echo -e "${BFR} ${CROSS} ${RD}${msg}${CL}"
}

start_routines() {
  header_info

  # Configurazione automatica dei repository
  msg_info "Configuring Proxmox VE sources"
  cat <<EOF >/etc/apt/sources.list
deb http://deb.debian.org/debian bookworm main contrib
deb http://deb.debian.org/debian bookworm-updates main contrib
deb http://security.debian.org/debian-security bookworm-security main contrib
EOF
echo 'APT::Get::Update::SourceListWarnings::NonFreeFirmware "false";' >/etc/apt/apt.conf.d/no-bookworm-firmware.conf
  msg_ok "Configured Proxmox VE sources - I repository bookworm sono ora confiurati"

  msg_info "Disabling 'pve-enterprise' repository"
  echo "" >/etc/apt/sources.list.d/pve-enterprise.list
  msg_ok "Disabled 'pve-enterprise' repository"

  msg_info "Enabling 'pve-no-subscription' repository - Abilitati i repository gratuiti"
  cat <<EOF >/etc/apt/sources.list.d/pve-install-repo.list
deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription
EOF
  msg_ok "Enabled 'pve-no-subscription' repository"

  msg_info "Configuring Ceph package repositories"
  echo "" >/etc/apt/sources.list.d/ceph.list
  msg_ok "Configured Ceph package repositories - Sono sì configurati ma commentati e quindi non attivi"

  msg_info "Subscription nag disabled"
  echo "DPkg::Post-Invoke { \"dpkg -V proxmox-widget-toolkit | grep -q '/proxmoxlib\.js$'; if [ \$? -eq 1 ]; then { echo 'Removing subscription nag from UI...'; sed -i '/.*data\.status.*{/{s/\!//;s/active/NoMoreNagging/}' /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js; }; fi\"; };" >/etc/apt/apt.conf.d/no-nag-script
  apt --reinstall install proxmox-widget-toolkit &>/dev/null
  msg_ok "Eliminato l'avviso di sottoscrizione (Delete browser cache)"

  # Aggiornamento (con conferma)
  read -p "Update Proxmox VE now? (y/n): " choice
  case "$choice" in
    y|yes)
      msg_info "Updating Proxmox VE (Patience)"
      apt-get update &>/dev/null
      apt-get -y dist-upgrade &>/dev/null
      msg_ok "Updated Proxmox VE"
      ;;
    *)
      msg_error "Update skipped."
      ;;
  esac

  # Reboot (con conferma)
  read -p "Reboot Proxmox VE now? (y/n): " choice
  case "$choice" in
    y|yes)
      msg_info "Rebooting Proxmox VE"
      sleep 2
      msg_ok "Completed Post Install Routines"
      reboot
      ;;
    *)
      msg_error "Reboot skipped."
      msg_ok "Completed Post Install Routines"
      ;;
  esac
}

# Esecuzione automatica dello script
start_routines

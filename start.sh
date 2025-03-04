#!/bin/bash

# Elenco degli script
# Il comando per lanciare questo script da github è: bash -c "$(wget -qLO - https://raw.githubusercontent.com/andry360/prxmx-post-script/refs/heads/main/start.sh)"
scripts=(
    "https://raw.githubusercontent.com/andry360/prxmx-post-script/refs/heads/main/1_pxmx-post-install.sh Script post-installazione"
    "https://raw.githubusercontent.com/andry360/prxmx-post-script/refs/heads/main/2_pxmx-set-interfaces.sh Script settaggio Network"
    "https://raw.githubusercontent.com/andry360/prxmx-post-script/refs/heads/main/3_pci-passtrough.sh Script predisposizione PCI Passtrough"
    "https://raw.githubusercontent.com/andry360/prxmx-post-script/refs/heads/main/4_openwrt-24-10-v2.sh Script creazione VM openWRT 24.10"
    "https://raw.githubusercontent.com/andry360/prxmx-post-script/refs/heads/main/5_openwrt-drivers-software.sh Script installazione driver e software per OpenWRT"
)

# Mostra l'elenco numerato
echo "Seleziona lo script da eseguire:"
for i in "${!scripts[@]}"; do
    echo "$((i+1)) - ${scripts[$i]#* }"
done

# Leggi la scelta dell'utente
read -p "Inserisci il numero dello script da eseguire: " choice

# Controlla se la scelta è valida
if [[ "$choice" -ge 1 && "$choice" -le ${#scripts[@]} ]]; then
    # Seleziona l'URL dello script scelto
    script_url="${scripts[$((choice-1))]%% *}"
    echo "Eseguendo lo script: ${scripts[$((choice-1))]#* }"
    # Esegui lo script selezionato
    bash -c "$(wget -qLO - $script_url)"
else
    echo "Scelta non valida. Uscita."
    exit 1
fi

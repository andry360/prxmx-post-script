#!/bin/bash

# Scaricare l'intero progetto in una cartella
project_dir="/prxmx-post-script"
echo "Scaricamento del progetto nella directory $project_dir..."
mkdir -p "$project_dir"
wget -qO- https://github.com/andry360/prxmx-post-script/archive/refs/heads/main.tar.gz | tar -xz -C "$project_dir" --strip-components=1
echo "Progetto scaricato con successo."

# Elenco degli script (percorsi locali)
scripts=(
    "$project_dir/1_pxmx-post-install.sh Script post-installazione"
    "$project_dir/2_pxmx-set-interfaces.sh Script settaggio Network"
    "$project_dir/3_pci-passtrough.sh Script predisposizione PCI Passtrough (usalo solo se devi passare dei dispositivi PCI a una VM)"
    "$project_dir/4_openwrt/4.0_openwrt-24-10-v2.sh Script creazione VM openWRT 24.10"
    "$project_dir/4_openwrt/4.1_openwrt-drivers-software.sh Script installazione driver e software per OpenWRT"
    "$project_dir/5_diagnostica-rete.sh Script di verifica connessione ad internet di OpenWRT"
    "$project_dir/6_diagnostica-rete-totale-openwrt.sh Script diagnostica completa rete OpenWRT"
    "$project_dir/7_diagnostica-rete-totale-prxmx.sh Script diagnostica completa rete OpenWRT"
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
    # Seleziona il percorso dello script scelto
    script_path="${scripts[$((choice-1))]%% *}"
    echo "Eseguendo lo script: ${scripts[$((choice-1))]#* }"
    # Esegui lo script selezionato
    bash "$script_path"
else
    echo "Scelta non valida. Uscita."
    exit 1
fi

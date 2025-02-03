#!/usr/bin/env bash

# Identificare i dispositivi PCI disponibili per il passthrough
echo "Ricerca dei dispositivi PCI compatibili..."

# Dispositivi compatibili (GPU, Audio, 3D Controller)
PCI_TYPES=("vga" "audio" "3d controller")
PCI_DEVICES=()

# Trova dispositivi per tipo
for TYPE in "${PCI_TYPES[@]}"; do
    while IFS= read -r DEVICE; do
        PCI_DEVICES+=("$DEVICE")
    done < <(lspci -nn | grep -i "$TYPE")
done

# Verifica se trovati dispositivi
if [ ${#PCI_DEVICES[@]} -eq 0 ]; then
    echo "Nessun dispositivo PCI compatibile trovato! Controlla con 'lspci -nn'."
    exit 1
fi

echo "Dispositivi PCI disponibili per il passthrough:"

# Stampa dispositivi con indice
for i in "${!PCI_DEVICES[@]}"; do
    DEVICE="${PCI_DEVICES[$i]}"
    PCI_ADDR=$(echo "$DEVICE" | awk '{print $1}')
    PCI_ID=$(lspci -n -s "$PCI_ADDR" | awk '{print $3}')
    echo "$((i+1))) $DEVICE (ID: $PCI_ID)"
done

# Richiedi selezione
read -r -p "Seleziona il numero del dispositivo PCI da passare alla VM: " SELECTION

# Convalida input
if [[ ! "$SELECTION" =~ ^[0-9]+$ ]] || (( SELECTION < 1 || SELECTION > ${#PCI_DEVICES[@]} )); then
    echo "Selezione non valida! Inserisci un numero tra 1 e ${#PCI_DEVICES[@]}."
    exit 1
fi

# Ottieni ID e indirizzo del dispositivo selezionato
SELECTED_DEVICE="${PCI_DEVICES[$((SELECTION-1))]}"
SELECTED_ADDR=$(echo "$SELECTED_DEVICE" | awk '{print $1}')
SELECTED_ID=$(lspci -n -s "$SELECTED_ADDR" | awk '{print $3}')

echo "Hai selezionato il dispositivo: $SELECTED_ADDR (ID: $SELECTED_ID)"

# Scrivi configurazione VFIO
echo "options vfio-pci ids=$SELECTED_ID disable_idle_d3=1" > /etc/modprobe.d/vfio.conf
echo "Configurazione aggiornata. Riavviare il sistema per applicare le modifiche."

#!/bin/bash

# Identificare i dispositivi PCI disponibili per il passthrough. Testa questo script mettendolo da solo su github.
echo "Ricerca dei dispositivi PCI compatibili..."

# Lista dei dispositivi compatibili (GPU, Audio, 3D Controller)
PCI_LIST=$(lspci -nn | grep -i "vga\|audio\|3d controller")
PCI_IDS=()
PCI_ADDRESSES=()

# Creazione dell'elenco numerato
if [ -z "$PCI_LIST" ]; then
    echo "Nessun dispositivo PCI compatibile trovato! Controlla con 'lspci -nn'."
    exit 1
fi

echo "Dispositivi PCI disponibili per il passthrough:"
INDEX=1
while read -r LINE; do
    PCI_ADDR=$(echo "$LINE" | awk '{print $1}')
    PCI_ID=$(lspci -n -s "$PCI_ADDR" | awk '{print $3}')
    
    PCI_ADDRESSES+=("$PCI_ADDR")
    PCI_IDS+=("$PCI_ID")

    echo "$INDEX) $LINE (ID: $PCI_ID)"
    ((INDEX++))
done <<< "$PCI_LIST"

# Chiedere all'utente quale dispositivo selezionare
echo -n "Seleziona il numero del dispositivo PCI da passare alla VM: "
read -r SELECTION

# Controllo validità input
if [[ ! "$SELECTION" =~ ^[0-9]+$ ]] || (( SELECTION < 1 || SELECTION >= INDEX )); then
    echo "Selezione non valida! Assicurati di inserire un numero tra 1 e $((INDEX-1))."
    exit 1
fi

# Ricavare ID e indirizzo PCI scelto
SELECTED_ID="${PCI_IDS[$((SELECTION-1))]}"
SELECTED_ADDR="${PCI_ADDRESSES[$((SELECTION-1))]}"

echo "Hai selezionato il dispositivo: $SELECTED_ADDR (ID: $SELECTED_ID)"

# Scrivere la configurazione VFIO
echo "options vfio-pci ids=$SELECTED_ID disable_idle_d3=1" > /etc/modprobe.d/vfio.conf
echo "Configurazione aggiornata. Riavviare il sistema per applicare le modifiche."
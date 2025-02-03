#!/usr/bin/env bash

# Funzione per stampare un messaggio di debug con timestamp
debug() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Identificare i dispositivi PCI disponibili per il passthrough
debug "Inizio ricerca dispositivi PCI compatibili..."

# Dispositivi compatibili (GPU, Audio, 3D Controller)
PCI_TYPES=("vga" "audio" "3d controller")
PCI_DEVICES=()

# Trova dispositivi per tipo con debug
for TYPE in "${PCI_TYPES[@]}"; do
  debug "Ricerca dispositivi di tipo: $TYPE"
  lspci -nn | grep -i "$TYPE" | xargs -n 1 -I {} sh -c 'PCI_DEVICES+=("{}"")'
  debug "Trovati ${#PCI_DEVICES[@]} dispositivi finora."
done

# Verifica se trovati dispositivi
if [ ${#PCI_DEVICES[@]} -eq 0 ]; then
  debug "Nessun dispositivo PCI compatibile trovato! Controlla con 'lspci -nn'."
  exit 1
fi

debug "Dispositivi PCI disponibili per il passthrough:"

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
  debug "Selezione non valida! Inserisci un numero tra 1 e ${#PCI_DEVICES[@]}."
  exit 1
fi

# Ottieni ID e indirizzo del dispositivo selezionato
SELECTED_DEVICE="${PCI_DEVICES[$((SELECTION-1))]}"
SELECTED_ADDR=$(echo "$SELECTED_DEVICE" | awk '{print $1}')
SELECTED_ID=$(lspci -n -s "$SELECTED_ADDR" | awk '{print $3}')

debug "Hai selezionato il dispositivo: $SELECTED_ADDR (ID: $SELECTED_ID)"

# Scrivi configurazione VFIO
echo "options vfio-pci ids=$SELECTED_ID disable_idle_d3=1" > /etc/modprobe.d/vfio.conf
echo "Configurazione aggiornata. Riavviare il sistema per applicare le modifiche."

debug "Script completato."

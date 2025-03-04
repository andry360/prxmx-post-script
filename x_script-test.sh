#!/bin/bash
#Questo file serve per testare il funzionamento degli script

echo "Configurazione di Proxmox VE per PCI Passthrough..."

# Configurazione delle opzioni per KVM e VFIO con selezione interattiva
echo "Abilitazione del supporto IOMMU in Proxmox..."

# Creazione del file di configurazione per KVM
echo -e "options kvm ignore_msrs=1\noptions kvm report_ignored_msrs=0" > /etc/modprobe.d/kvm.conf

# Identificare tutti i dispositivi PCI disponibili per il passthrough
echo "Ricerca dei dispositivi PCI disponibili..."

# Ottenere l'elenco completo delle periferiche PCI
PCI_LIST=$(lspci -nn)
PCI_IDS=()
PCI_ADDRESSES=()

# Creazione dell'elenco numerato dei dispositivi PCI
if [ -z "$PCI_LIST" ]; then
    echo "Nessun dispositivo PCI rilevato! Controlla con 'lspci -nn'."
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

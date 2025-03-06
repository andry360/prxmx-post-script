#!/bin/sh

# Nome del file temporaneo
OUTPUT_FILE="/tmp/diagnosi_rete.txt"
SEPARATORE="----- FINE PRIMA PARTE - INIZIA QUI LA COPIA -----"
DEST_IP="192.168.1.243"
DEST_PORT="1234"
MAX_COPY_SIZE=60000  # Limite approssimativo per copia manuale

# Definizione dei comandi con i nomi leggibili
COMANDI=(
    "uci show network" 
    "ip a"
    "ip r"
    "brctl show"
    "uci show dhcp"
    "cat /etc/config/dhcp"
    "logread | grep dnsmasq"
    "uci show firewall"
    "nft list table inet filter"
    "nft list table inet nat"
    "cat /tmp/dhcp.leases"
    "ps | grep dnsmasq"
    "ping -c 4 8.8.8.8"
    "ping -c 4 google.com"
    "nslookup google.com"
    "traceroute 8.8.8.8"
)

echo "[INFO] Inizio diagnosi di rete - $(date)"
echo "Diagnosi di rete - $(date)" > "$OUTPUT_FILE"
echo "==============================" >> "$OUTPUT_FILE"

# Numero totale dei comandi
NUM_COMANDI=${#COMANDI[@]}
COUNT=0

# Funzione per eseguire un comando e salvarne l'output con numerazione progressiva
esegui_comando() {
    COUNT=$((COUNT + 1))
    echo "[INFO] Eseguendo comando $COUNT su $NUM_COMANDI: $1"
    echo "### Comando $COUNT su $NUM_COMANDI: $1 ###" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    
    # Eseguire il comando e salvare l'output
    eval "$1" >> "$OUTPUT_FILE" 2>&1
    EXIT_CODE=$?
    
    if [ "$EXIT_CODE" -ne 0 ]; then
        echo "[ERROR] Il comando '$1' ha restituito errore ($EXIT_CODE)"
        echo "[ERROR] Il comando '$1' ha restituito errore ($EXIT_CODE)" >> "$OUTPUT_FILE"
    fi
    
    echo "" >> "$OUTPUT_FILE"
    echo "------------------------------" >> "$OUTPUT_FILE"
}

# Esecuzione dei comandi
for CMD in "${COMANDI[@]}"; do
    esegui_comando "$CMD"
done

# Controllo dimensione del file per inserire un separatore
FILE_SIZE=$(wc -c < "$OUTPUT_FILE")
echo "[DEBUG] Dimensione file: $FILE_SIZE byte"

if [ "$FILE_SIZE" -gt "$MAX_COPY_SIZE" ]; then
    echo "[INFO] Il file è grande, aggiungo il separatore per la copia manuale"
    echo "$SEPARATORE" >> "$OUTPUT_FILE"
fi

# Invio del file al PC remoto tramite netcat
echo "[INFO] Invio del file di diagnosi a $DEST_IP:$DEST_PORT"
cat "$OUTPUT_FILE" | nc $DEST_IP $DEST_PORT
EXIT_CODE=$?

if [ "$EXIT_CODE" -ne 0 ]; then
    echo "[ERROR] Errore durante l'invio del file tramite netcat (codice: $EXIT_CODE)"
else
    echo "[INFO] File inviato con successo!"
fi

echo "[INFO] Diagnosi completata."

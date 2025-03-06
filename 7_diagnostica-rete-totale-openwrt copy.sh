#!/bin/sh

# Esegue i comandi richiesti, salva l'output in un file con una formattazione chiara e lo invia tramite nc al PC di rete specificato. 
# Inoltre, se il file è troppo lungo per essere copiato in una volta sola, lo script inserisce un indicatore di separazione.
# Nome del file temporaneo
OUTPUT_FILE="/tmp/diagnosi_rete.txt"
SEPARATORE="----- FINE PRIMA PARTE - INIZIA QUI LA COPIA -----"

# Pulizia del file di output
echo "Diagnosi di rete - $(date)" > "$OUTPUT_FILE"
echo "==============================" >> "$OUTPUT_FILE"

# Funzione per eseguire un comando e salvarne l'output con intestazione
esegui_comando() {
    echo "### $1 ###" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    $2 >> "$OUTPUT_FILE" 2>&1
    echo "" >> "$OUTPUT_FILE"
    echo "------------------------------" >> "$OUTPUT_FILE"
}

# Lista dei comandi da eseguire
esegui_comando "Configurazione di rete" "uci show network"
esegui_comando "Indirizzi IP" "ip a"
esegui_comando "Routing" "ip r"
esegui_comando "Bridge" "brctl show"
esegui_comando "Configurazione DHCP" "uci show dhcp"
esegui_comando "File di configurazione DHCP" "cat /etc/config/dhcp"
esegui_comando "Log dnsmasq" "logread | grep dnsmasq"
esegui_comando "Configurazione firewall" "uci show firewall"
esegui_comando "Regole firewall (filter)" "nft list table inet filter"
esegui_comando "Regole firewall (nat)" "nft list table inet nat"
esegui_comando "Lease DHCP attuali" "cat /tmp/dhcp.leases"
esegui_comando "Processi dnsmasq" "ps | grep dnsmasq"
esegui_comando "Ping 8.8.8.8" "ping -c 4 8.8.8.8"
esegui_comando "Ping google.com" "ping -c 4 google.com"
esegui_comando "NSLookup google.com" "nslookup google.com"
esegui_comando "Traceroute 8.8.8.8" "traceroute 8.8.8.8"

# Controllo dimensione del file per inserire un separatore
FILE_SIZE=$(wc -c < "$OUTPUT_FILE")
MAX_COPY_SIZE=60000  # Limite approssimativo per copia manuale

if [ "$FILE_SIZE" -gt "$MAX_COPY_SIZE" ]; then
    echo "$SEPARATORE" >> "$OUTPUT_FILE"
fi

# Invio del file al PC remoto tramite netcat
cat "$OUTPUT_FILE" | nc 192.168.1.243 1234

# Messaggio di conferma
echo "Diagnosi completata e inviata a 192.168.1.243 sulla porta 1234."

#!/bin/bash
# Questo script serve per la ricerca delle informazioni e modifica dell'ONT SFP Zyxel PMG3000-D20B.
# https://hack-gpon.org/ont-zyxel-pmg3000-d20b/
# Legenda comandi ssh
# ssh -o: Permette di specificare opzioni di configurazione per la connessione SSH. Ad esempio, puoi usare ssh -o "StrictHostKeyChecking=no" user@host per disabilitare il controllo della chiave host.
# ssh -l: Specifica il nome utente per la connessione SSH. È equivalente a ssh user@host. Ad esempio, ssh -l user host.
# ssh -p: Permette di specificare una porta diversa dalla porta predefinita (22) per la connessione SSH. Ad esempio, ssh -p 2222 user@host per connettersi alla porta 2222.

echo "Prima di avviare lo script assicurati di avere creato una WAN per accedere all'SFP."
echo "Dalla pagina del router, clicca sul menu burger -> network -> broadcast -> Aggiungi nuova interfaccia WAN."
echo "NOTA: La creazione di una nuova WAN potrebbe dare errore perché sui router Wind c'è un numero massimo di connessioni per VLAN, alcuni utenti hanno riportato che è presente una connessione ODU_MGMT senza VLAN tag, nel caso si può modificare quella e poi riportarla ai valori originali quando non serve più l'accesso all'SFP."
echo "La wan dovrà avere questta configurazione: Modalità ethernet; IP statico; IP: 10.10.1.2; GW: 10.10.1.1; DNS: a caso"
echo "Nelle opzioni va disabilitato VLAN, NAT e Applica come Gateway Predefinito"
echo "Una volta fatto, dalla pagina di diagnostica si controlla che il router pinghi 10.10.1.1"

#---------------------------------------------------------------------------------------------------------------------------------
# Variabili di configurazione e predisposizione script
ip_SFP="10.10.1.1"
ip_SFP_interface="10.10.1.2"
ip_GATEWAY="10.10.1.1"
ip_ROUTER="192.168.1.1"

#---------------------------------------------------------------------------------------------------------------------------------

clear
echo "Questo script ti aiuterà a connetterti e a interagire con il tuo ONT Zyxel PMG3000-D20B."
echo "Se necessario, modifica i seguenti indirizzi IP direttamente nello script:"
echo "  - IP SFP: $ip_SFP"
echo "  - IP Interfaccia SFP: $ip_SFP_interface"
echo "  - IP Gateway: $ip_GATEWAY"
echo "  - IP Router: $ip_ROUTER"
echo ""

# Queste condizioni controllano il tipo di sistema operativo e se è presente il windows terminal per essere sicuro che si possano creare successivamente due finestre diverse.
echo "Controllo del sistema operativo..."
if ! command -v uname &> /dev/null; then
    echo "[ERROR] Il comando uname non è disponibile. Impossibile determinare il sistema operativo."
    exit 1
fi
if [[ "$OS" == "Linux" || "$OS" == "Darwin" ]]; then
    echo "[INFO] Sistema compatibile: $OS"
elif [[ "$OS" == "MINGW64_NT" || "$OS" == "CYGWIN_NT" ]]; then
    echo "[INFO] Sistema Windows rilevato, controllo Windows Terminal..."
    if ! command -v wt &> /dev/null; then
        echo "[ERROR] Windows Terminal non trovato! Installalo prima di procedere."
        exit 1
    fi
else
    echo "[ERROR] Sistema Operativo non supportato. Uscita."
    exit 1
fi

#---------------------------------------------------------------------------------------------------------------------------------
# 1. SSH Tunneling. Crea un tunnel SSH (Secure Shell) tra il PC locale e il modulo SFP, passando attraverso il router.
# La parte di comando: -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa: opzioni necessarie per abilitare l'algoritmo di firma RSA, probabilmente richiesto da versioni più datate del firmware del router.
# La parte di comando: -L 127.0.0.1:2222:10.10.1.1:22 specifica che il traffico diretto alla porta 2222 del PC locale (127.0.0.1) deve essere inoltrato alla porta 22 del modulo SFP (10.10.1.1).
# admin@$ip_ROUTER: Indica l'utente admin e l'indirizzo IP del router (192.168.1.1) per l'autenticazione SSH.
ssh -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa -L 127.0.0.1:2222:$ip_SFP:22 admin@$ip_ROUTER &

if [ $? -ne 0 ]; then
    echo "Errore nella creazione del tunnel SSH. Controlla le credenziali e riprova."
    exit 1
fi
echo "Tunnel creato con successo!"

#---------------------------------------------------------------------------------------------------------------------------------
# 2. Una volta creato il tunnel, accedo al tunnel stesso sempre tramite SSH da un secondo terminale.
# La parte di comando: -p 2222: Specifica la porta 2222.

echo "Apertura di un nuovo terminale per la connessione all'ONT..."
echo "Le prime credenziali sono admin/admin, dopo inserisci twmanu/twmanu "
if [[ "$OS" == "Darwin" ]]; then
    osascript -e 'tell application "Terminal" to do script "ssh -p 2222 -oHostKeyAlgorithms=+ssh-dss admin@127.0.0.1"'
elif [[ "$OS" == "Linux" ]]; then
    gnome-terminal -- bash -c "ssh -p 2222 -oHostKeyAlgorithms=+ssh-dss admin@127.0.0.1; exec bash"
elif [[ "$OS" == "MINGW64_NT" || "$OS" == "CYGWIN_NT" ]]; then
    wt new-tab cmd /k "ssh -p 2222 -oHostKeyAlgorithms=+ssh-dss admin@127.0.0.1"
fi

#---------------------------------------------------------------------------------------------------------------------------------
# 3. Ora che siamo nel modulo sfp possiamo estrapolare le informazioni necessarie o modificarle
# Il comando: -oHostKeyAlgorithms=+ssh-dss: opzione necessaria per abilitare l'algoritmo di firma DSA.
echo "[INFO] Vuoi salvare le informazioni delle classi dell'ONT in un file sul Desktop? (s/n)"
read -r risposta
# Normalizza la risposta in caso l'utente abbia inserito una lettera maiuscola.
decisione=$(echo "$risposta" | tr '[:upper:]' '[:lower:]')
if [[ "$decisione" == "s" ]]; then
    output_file="$HOME/Desktop/ont_classid_info.txt"
    if [[ -f "$output_file" ]]; then
        echo "[WARNING] Il file $output_file esiste già. Vuoi sovrascriverlo? (s/n)"
        read -r conferma
        conferma_decisione=$(echo "$conferma" | tr '[:upper:]' '[:lower:]')
        if [[ "$conferma_decisione" != "s" ]]; then
            echo "[INFO] Operazione annullata."
            exit 0
        fi
    fi
    echo "Recupero informazioni delle classi e salvataggio su: $output_file"
    ssh -p 2222 -oHostKeyAlgorithms=+ssh-dss admin@127.0.0.1 << EOF > "$output_file"
show me classid 2
show me classid 3
show me classid 6
show me classid 7
show me classid 11
show me classid 256
show me classid 257
EOF
    echo "File salvato con successo in: $output_file"
else
    echo "Operazione di salvataggio saltata."
fi
echo "Script completato. Buon lavoro!"

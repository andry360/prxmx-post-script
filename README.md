# proxmox-custom-post-install-script
# Una versione custom dello script post install che comprende il settaggio completo del mio server

# -------------------------------------------------------------------------------------------------------------------------------------------------------
# LEGENDA
# XGS-PON (10 Gbps simmetrici in downstream e in upstream) e XGS-PON sta per X=10, G=Gigabit, S=simmetrici, PON=passive optical network
# NG-PON2 (minimo 4×10 Gbps in downstream e 2,5 Gbps in upstream).
# PON = passive optical network. E' composta da:
    OLT = optical line terminal,  posizionato nel sito centrale dell'operatore
    ONU = optical network unit, insieme di unità di rete ottica
    ONT = optical network terminal, terminali prossimi agli utenti finali (dove entra o finisce il cavo in fibra per intenderci)
    OMCI = ONU Management Control Interface, defines a mechanism and message format that is used by the OLT to configure, manage, and monitor ONUs
# 
# Attualmente, esistono 4 tipi di lucidatura della superficie di connessione: PC , SPC , UPC e APC.
# I connettori ottici (connettori) con smalto APC non sono compatibili con altri tipi di connettori, quindi viene utilizzato il verde per designarli. 
    PC = La lucidatura per PC (contatto fisico) ha un connettore piatto che si è scoperto essere poco performante
    SPC = La lucidatura per SPC (Super Physical Contact) è un'evoluzione della lucidatura per PC. riflettività di -40 dB
    APC Con la lucidatura APC, viene utilizzato il contatto fisico angolare (obliquo)
    UPC = L'ultima opzione disponibile è la lucidatura UPC (Ultra Physical Contact), che non impiega la lucidatura convenzionale, ma una lucidatura dritta normale, che considera il raggio della punta. Permette di raggiungere una riflettività di -50 dB, di poco inferiore ai connettori lucidati APC, ma superiore ad altre opzioni di lucidatura, importante per i connettori monomodali.
 SC / APC è il connettore usato dagli ISP in italia (almeno la maggior parte)
 SC / UPC
 
 ATTENZIONE: I tipi di connettori con lucidatura APC e UPC non sono compatibili. Collegando un connettore APC a uno UPC, o viceversa, si rischia di danneggiare le superfici lucide di entrambi i connettori

# -------------------------------------------------------------------------------------------------------------------------------------------------------
# Avvertenze CLONAZIONE PON 
L'ONT ha un seriale e diversi parametri (OMCI) come vendor, versione hardware, software e ID equipaggiamento.
Se si cambia solo il seriale, l'OLT può riconoscerlo come appartenente a un vendor differente da quello originale.
Se si cambiano anche i parametri OMCI per corrispondere a quelli del nuovo seriale, l'OLT vedrà l'ONT come un dispositivo del vendor corretto.
Alcuni OLT possono bloccare un ONT se i parametri non corrispondono al seriale, mentre altri possono accettarlo.
Ad esempio, gli OLT Huawei controllano solo il numero seriale GPON, mentre quelli Nokia verificano tutti i parametri.
Pertanto, per evitare problemi, è consigliabile clonare completamente i parametri dell'ONT, assicurandosi così che tutto corrisponda.
Se hai un ONT come il f6005v6, LEOX, VSOL/UPLINK puoi essere più sicuro nel cambiare il seriale e i parametri per evitare di essere bloccato dagli OLT.

# Parametri OMCI (ONT Management and Control Interface)
   Vendor ID: Identifica il produttore dell'ONT.
   Serial Number: Il numero seriale univoco dell'ONT.
   Hardware Version: La versione hardware dell'ONT.
   Software Version: La versione del firmware o software in esecuzione sull'ONT.
   Equipment ID: Un identificatore unico per l'equipaggiamento dell'ONT.
   ONT Type: Il tipo specifico di ONT (es. GPON, EPON).
   Capabilities: Funzionalità supportate dall'ONT come velocità, VLAN, supporto multicast, ecc.
   Traffic Management: Parametri relativi alla gestione del traffico come profili di QoS (Quality of Service).
   Security Parameters: Parametri di sicurezza come chiavi di crittografia e autenticazione.
   Performance Monitoring: Dati relativi al monitoraggio delle prestazioni, come contatori di errore, stato delle interfacce, ecc.

# --------------------------------------------------------------------------------------------------------------------------------------------------------
# 1.0 Informazioni su ONT ZTE F6005
F6005v3 è il più nuovo dei due e il più performante. Permette di modificiare
 seriale
 ploam = password di autenticazione per l'olt (dovrebbe iniziare con 3 A). Potrebbe non essere richiesto da WIND, potrebbe volerlo fibercop
 equipment

F6005v6 è più vecchio e nelle prime versioni soffre di flowqualcosa. permette di modificare
 parametri omci = 
 seriale
 ploam = password di autenticazione per l'olt
 Equipment ID
# --------------------------------------------------------------------------------------------------------------------------------------------------------
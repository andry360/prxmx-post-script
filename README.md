# proxmox-custom-post-install-script
# Una versione custom dello script post install che comprende il settaggio completo del mio server

# LEGENDA
# XGS-PON (10 Gbps simmetrici in downstream e in upstream) e XGS-PON sta per X=10, G=Gigabit, S=simmetrici, PON=passive optical network
# NG-PON2 (minimo 4×10 Gbps in downstream e 2,5 Gbps in upstream).
# PON = passive optical network. E' composta da:
#   OLT = optical line terminal,  posizionato nel sito centrale dell'operatore
#   ONU = optical network unit, insieme di unità di rete ottica
#   ONT = optical network terminal, terminali prossimi agli utenti finali (dove entra o finisce il cavo in fibra per intenderci)
# OMCI = ONU Management Control Interface, defines a mechanism and message format that is used by the OLT to configure, manage, and monitor ONUs
# 
# Attualmente, esistono 4 tipi di lucidatura della superficie di connessione: PC , SPC , UPC e APC.
# i connettori ottici (connettori) con smalto APC non sono compatibili con altri tipi di connettori, quindi viene utilizzato il verde per designarli. 
#   PC = La lucidatura per PC (contatto fisico) ha un connettore piatto che si è scoperto essere poco performante
#   SPC = La lucidatura per SPC (Super Physical Contact) è un'evoluzione della lucidatura per PC. riflettività di -40 dB
#   APC Con la lucidatura APC, viene utilizzato il contatto fisico angolare (obliquo)
#   UPC = L'ultima opzione disponibile è la lucidatura UPC (Ultra Physical Contact), che non impiega la lucidatura convenzionale, ma una lucidatura dritta normale, che considera il raggio della punta. Permette di raggiungere una riflettività di -50 dB, di poco inferiore ai connettori lucidati APC, ma superiore ad altre opzioni di lucidatura, importante per i connettori monomodali.
# SC / APC è il connettore usato dagli ISP in italia (almeno la maggior parte)
# SC / UPC
# Attenzione: I tipi di connettori con lucidatura APC e UPC non sono compatibili. Collegando un connettore APC a uno UPC, o viceversa, si rischia di danneggiare le superfici lucide di entrambi i connettori



# 1.0 Informazioni su ONT ZTE F6005
# 1.1 ONT F6005v3 è il più nuovo dei due e il più performante. Permette di modificiare
# seriale
# ploam = password di autenticazione per l'olt (dovrebbe iniziare con 3 A). Potrebbe non essere richiesto da WIND, potrebbe volerlo fibercop
# equipment

# 1.2 ONT F6005v6 è più vecchio e nelle prime versioni soffre di flowqualcosa. permette di modificiare
# parametri omci = 
# seriale
# ploam = password di autenticazione per l'olt
# equipment


# L'ont ha un seriale e ha dei parametri (sto parametri omci) che presenta all'ont. Tipo Vendor, versione hardware, software e equip id. Se tu sostituisci solo il seriale, all'olt appare un ONT che ha un seriale di un sercomm (SCOM12345678 per esempio) e poi Vendor ZTE. Se tu cambi anche i parametri omci con quelli del sercomm, agli occhi dell'olt appare come un sercomm in tutto e per tutto. Con f6005v6 si fa sicuramente, v3 ho dei dubbi
# Motivo per cui su alcuni olt metti il seriale sul Fritz e va mentre su altri non va o addirittura ti banna. Appare Vendor AVM con tutte minchiate avm ma il seriale è ZTEG o SCOM

#  Si infatti. Non corrispondendo comunque il Vendor nel seriale agli altri parametri meglio clonare e ciao
# Così sei sicuro al 100%

by ste:
# se hai un v6 cambia tutto per star tranquillo, ma sono entrambi ont ufficialmente forniti e su olt huawei il check dovrebbe essere solo sul gpon serial number
# olt nokia fa check su tutto
# però anche li, essendo che gli ont sono ufficialmente forniti sale lo stesso, a patto per esempio si avere le version fc e non openfiber sullo zte
# personalmente avrei il tim hub executive, quindi swappato il serial su f6005 sono stealth by design
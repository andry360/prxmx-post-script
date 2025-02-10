# proxmox-custom-post-install-script
# Una versione custom dello script post install che comprende il settaggio completo del mio server

# LEGENDA
# PON = passive optical network. E' composta da:
#   OLT = optical line terminal,  posizionato nel sito centrale dell'operatore
#   ONU = optical network unit, insieme di unità di rete ottica
#   ONT = optical network terminal, terminali prossimi agli utenti finali
# OMCI = ONU Management Control Interface, defines a mechanism and message format that is used by the OLT to configure, manage, and monitor ONUs
#
#


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
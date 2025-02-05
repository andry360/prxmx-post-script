#Verificare se IOMMU è attivo
dmesg | grep -e DMAR -e IOMMU

#Controllare se i dispositivi PCI sono disponibili per il passthrough
lspci -nnk | grep -i vfio

#Verifica i dispositivi ethernet e wifi per controllare i moduli kernel utilizzati e se utilizzano
#il driver loro o quello vfio. Se usa il vfio vuol dire che è pronto per il passtrough
lspci -k | grep -A 3 -i 'ethernet\|network'

#Verifica configurazione di rete Proxmox
nano /etc/network/interfaces
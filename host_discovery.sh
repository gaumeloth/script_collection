#!/bin/bash

# Directory per i log
log_directory="${HOME}/audit"

# Disclaimer
toilet HOST DISCOVERY -w 100 --filter metal 2>/dev/null || figlet -ct HOST DISCOVERY 2>/dev/null || banner -C -l -w 60 HOST DISCOVERY 2>/dev/null
echo "----------------------------------------------------"
echo "ATTENZIONE: Questo script è stato progettato per scoprire gli host attivi sulla stessa subnet della macchina su cui viene eseguito."
echo "Utilizzare esclusivamente in reti in cui si dispone dell'autorizzazione per eseguire scansioni di rete."
echo "Lo script utilizza nmap per eseguire una 'ping scan' al fine di elencare gli host attivi e salva i risultati in un file univoco nella directory 'audit' della tua home."
echo "Se desideri cambiare la directory predefinita per i file di log, puoi farlo modificando la variabile 'log_directory' presente all'inizio dello script."
echo "Il nome del file di output include la data e l'ora della scansione, e viene gestito per evitare sovrascritture accidentali."
echo "Se non viene fornita alcuna risposta alla richiesta di conferma, lo script verrà annullato per impostazione predefinita."
echo "----------------------------------------------------"

# Richiesta di conferma per proseguire
while true; do
    read -p "Vuoi proseguire con la scansione? (s/n, default=n): " choice
    case $choice in
        [Ss]* ) break;;
        [Nn]* | "" ) echo "Scansione annullata dall'utente."; exit 1;;
        * ) echo "Opzione non valida. Inserisci 's' per proseguire o 'n' per annullare.";;
    esac
done

echo "Inizio della scoperta della rete..."

# Ottieni l'indirizzo IP e la maschera di sottorete dell'interfaccia di rete principale
echo "recupero dell'indirizzo IP e della maschera di sottorete dell'interfaccia di rete principale..."
IP_INFO=$(ip addr show $(ip route | grep default | awk '{print $5}') | grep "inet\b")
IP_ADDR=$(echo $IP_INFO | awk '{print $2}' | cut -d '/' -f1)
CIDR=$(echo $IP_INFO | awk '{print $2}' | cut -d '/' -f2)

# Stampa i valori ottenuti
echo "Indirizzo IP: $IP_ADDR"
echo "CIDR: $CIDR"

# Converti CIDR in netmask
echo "Conversione del CIDR in maschera di sottorete..."
value=$((0xffffffff ^ ((1 << (32 - $CIDR)) - 1)))
NETMASK="$(((value >> 24) & 0xff)).$(((value >> 16) & 0xff)).$(((value >> 8) & 0xff)).$((value & 0xff))"
echo "Maschera di sottorete convertita: $NETMASK"

# Calcola l'indirizzo di rete
echo "Calcolo dell'indirizzo di rete..."
IFS='.' read -r i1 i2 i3 i4 <<< "$IP_ADDR"
IFS='.' read -r m1 m2 m3 m4 <<< "$NETMASK"
network=( $((i1 & m1)) $((i2 & m2)) $((i3 & m3)) $((i4 & m4)) )

# Stampa l'indirizzo di rete per il debugging
echo "Indirizzo di rete calcolato: ${network[0]}.${network[1]}.${network[2]}.${network[3]}"

# Costruisci l'indirizzo di rete
NETWORK="${network[0]}.${network[1]}.${network[2]}.${network[3]}/$CIDR"
echo "La tua subnet è: $NETWORK"

# Crea la directory dei log se non esiste
mkdir -p "$log_directory"
# Generazione del nome file con contatore incrementale
base_name="hosts_up-$(date +%F_%H-%M)"
counter=0
output_file="${log_directory}/${base_name}_${counter}.txt"
# Controllo per evitare la sovrascrittura dei file esistenti
while [[ -e "$output_file" ]]; do
echo "Il file $output_file esiste già"
    ((counter++))
    output_file="${log_directory}/${base_name}_${counter}.txt"
done

echo "Utilizzo il file di output: $output_file"

echo "Scansione in corso sulla subnet $NETWORK. Attendere prego..."
# Esegue la scansione con nmap per individuare tutti gli host attivi nella subnet
nmap -sn $NETWORK | grep "Nmap scan report for" | awk '{print $NF}' | grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' > $output_file
# Mostra i risultati
echo "Scansione completata. Elenco degli host attivi trovati nella subnet $NETWORK:"
cat $output_file

echo "I risultati della scansione sono stati salvati nel file: $output_file"

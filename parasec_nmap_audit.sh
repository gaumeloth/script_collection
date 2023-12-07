#!/bin/bash

# Disclaimer
echo "ATTENZIONE: Questo script esegue scansioni di sicurezza dettagliate utilizzando nmap su un elenco di indirizzi IP."
echo "Assicurati di avere l'autorizzazione necessaria per eseguire scansioni su ogni target specificato."
echo "L'uso non autorizzato di questo script su reti o host non consentiti può violare le leggi sulla privacy e sulla sicurezza informatica."
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

# Richiesta di input dall'utente
echo "Inserisci il nome del file contenente gli indirizzi IP da scansionare"
read file_input
echo "Inserisci il nome della cartella in cui salvare i log delle scnsioni"
read output_directory
mkdir -p "$output_directory"

# File di log temporaneo
temp_log=$(mktemp)
export temp_log

# Funzione per eseguire e loggare le scansioni nmap
nmap_scan() {
    ip=$1
    type=$2
    directory=$3
    host_output_directory="$directory/$ip"
    mkdir -p "$host_output_directory"
    output_file="$host_output_directory/nmap_${type// /_}_$(date '+%Y-%m-%d_%H-%M-%S').log"
    echo "$(date '+%Y-%m-%d %H:%M:%S'): Inizio scansione $type su $ip" >> $temp_log
    nmap $type $ip > "$output_file"
    echo "$(date '+%Y-%m-%d %H:%M:%S'): Completata scansione $type su $ip" >> $temp_log
    echo "Log file creato: $output_file"
}

export -f nmap_scan

# Utilizza una sotto-shell per eseguire le scansioni nmap in parallelo
(
    cat "$file_input" | xargs -I % -P 10 bash -c "nmap_scan % '-sC -sV -A' '$output_directory'" &
    cat "$file_input" | xargs -I % -P 10 bash -c "nmap_scan % '--script vuln' '$output_directory'" &
    cat "$file_input" | xargs -I % -P 10 bash -c "nmap_scan % '-vv' '$output_directory'" &
    wait
    pgrep -f "tail -f $temp_log" | xargs kill
) &

# Esegue tail -f nel processo principale per mostrare i log in tempo reale
tail -f $temp_log

echo "Scansioni completate."

# Rimuove il file di log
rm $temp_log

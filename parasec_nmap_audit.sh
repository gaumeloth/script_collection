#!/bin/bash

# Inizio dello script

# Messaggio di disclaimer per l'utente
# Avvisa che lo script esegue scansioni di sicurezza e richiede l'autorizzazione appropriata
echo "ATTENZIONE: Questo script esegue scansioni di sicurezza dettagliate utilizzando nmap su un elenco di indirizzi IP."
echo "Assicurati di avere l'autorizzazione necessaria per eseguire scansioni su ogni target specificato."
echo "L'uso non autorizzato di questo script su reti o host non consentiti può violare le leggi sulla privacy e sulla sicurezza informatica."
echo "----------------------------------------------------"

# Richiesta di conferma per proseguire con la scansione
# Loop fino a quando l'utente non inserisce una risposta valida
while true; do
    read -p "Vuoi proseguire con la scansione? (s/n, default=n): " choice
    case $choice in
        [Ss]* ) break;; # Prosegue se la risposta è 's' o 'S'
        [Nn]* | "" ) echo "Scansione annullata dall'utente."; exit 1;; # Esce se la risposta è 'n', 'N' o vuota
        * ) echo "Opzione non valida. Inserisci 's' per proseguire o 'n' per annullare.";; # Gestisce input non validi
    esac
done


# Richiesta di input per il file di indirizzi IP e la directory di output
echo "Inserisci il nome del file contenente gli indirizzi IP da scansionare"
read file_input

# Controllo esistenza del file di input
# Verifica se il file specificato dall'utente esiste
if [[ ! -f "$file_input" ]]; then
    echo "Errore: Il file '$file_input' non esiste."
    exit 1
fi

# Controllo leggibilità del file di input
# Verifica se il file può essere letto (i.e., ha i permessi di lettura)
if [[ ! -r "$file_input" ]]; then
    echo "Errore: Il file '$file_input' non è leggibile."
    exit 1
fi

echo "Inserisci il nome della cartella in cui salvare i log delle scansioni"
read output_directory

# Controllo esistenza della directory di output
# Se la directory non esiste, prova a crearla
if [[ ! -d "$output_directory" ]]; then
    echo "La directory '$output_directory' non esiste. Creazione in corso..."
    mkdir -p "$output_directory" || { echo "Errore nella creazione della directory."; exit 1; }
fi

# Creazione di un file di log temporaneo
temp_log=$(mktemp)
export temp_log # Esporta la variabile per renderla accessibile alle sotto-shell

# Definizione della funzione nmap_scan per eseguire le scansioni
# Prende come parametri un indirizzo IP, un tipo di scansione e una directory di output
nmap_scan() {
    ip=$1
    type=$2
    directory=$3
    host_output_directory="$directory/$ip"
    mkdir -p "$host_output_directory" # Crea una sottodirectory per ogni IP
    output_file="$host_output_directory/nmap_${type// /_}_$(date '+%Y-%m-%d_%H-%M-%S').log" # Formatta il nome del file di log
    echo "$(date '+%Y-%m-%d %H:%M:%S'): Inizio scansione $type su $ip" >> $temp_log
    nmap $type $ip > "$output_file" # Esegue nmap e redirige l'output nel file di log
    echo "$(date '+%Y-%m-%d %H:%M:%S'): Completata scansione $type su $ip" >> $temp_log
    echo "Log file creato: $output_file"
}

export -f nmap_scan # Esporta la funzione per l'uso nelle sotto-shell

# Esecuzione parallela delle scansioni nmap in una sotto-shell
# La sotto-shell permette di eseguire i comandi in background
(
    # Utilizza xargs per parallelizzare le scansioni
    cat "$file_input" | xargs -I % -P 10 bash -c "nmap_scan % '-sC -sV -A' '$output_directory'" &
    cat "$file_input" | xargs -I % -P 10 bash -c "nmap_scan % '--script vuln' '$output_directory'" &
    cat "$file_input" | xargs -I % -P 10 bash -c "nmap_scan % '-vv' '$output_directory'" &
    
    wait # Aspetta il completamento di tutte le scansioni in parallelo

    # Una volta completate le scansioni, cerca e termina il processo tail
    # Questo è necessario perché tail -f continua a eseguire fino a quando non viene esplicitamente terminato
    pgrep -f "tail -f $temp_log" | xargs kill
) & # Esecuzione in background della sotto-shell

# tail -f viene eseguito nel processo principale
# Questo comando segue il contenuto del file di log in tempo reale
# tail -f continuerà a eseguire fino a quando non sarà terminato dalla sotto-shell
tail -f $temp_log # Visualizzazione dei log in tempo reale

echo "Scansioni completate."

rm $temp_log # Rimozione del file di log temporaneo

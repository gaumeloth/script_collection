#!/bin/bash

# Inizio dello script

# Messaggio di disclaimer per l'utente
# Avvisa che lo script esegue scansioni di sicurezza e richiede l'autorizzazione appropriata
echo "ATTENZIONE: Questo script esegue scansioni di sicurezza dettagliate utilizzando nmap su un elenco di indirizzi IP."
echo "Assicurati di avere l'autorizzazione necessaria per eseguire scansioni su ogni target specificato."
echo "L'uso non autorizzato di questo script su reti o host non consentiti può violare le leggi sulla privacy e sulla sicurezza informatica."
echo "----------------------------------------------------"

# Il ciclo while richiede una conferma all'utente prima di procedere con la scansione.
# Il loop prosegue fino a quando l'utente non inserisce una risposta valida
# L'utente deve rispondere con 's' oppure "S" per (sì) o con 'n' oppure "N" per (no).
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

# Verifica se il file specificato dall'utente esiste
if [[ ! -f "$file_input" ]]; then
    echo "Errore: Il file '$file_input' non esiste."
    exit 1
fi

# Verifica se il file può essere letto (i.e., ha i permessi di lettura)
if [[ ! -r "$file_input" ]]; then
    echo "Errore: Il file '$file_input' non è leggibile."
    exit 1
fi

# Cartella di log predefinita
output_directory=~/audit2

if [[ ! -d "$output_directory" ]]; then
    echo "La directory di log predefinita '$output_directory' non esiste. Creazione in corso..."
    mkdir -p "$output_directory" || { echo "Errore nella creazione della directory di log."; exit 1; }
fi

# Organizzazione basata sulla data e contatori per scansioni eseguite
today=$(date '+%Y-%m-%d')
daily_directory="$output_directory/$today"

if [[ ! -d "$daily_directory" ]]; then
    mkdir -p "$daily_directory"
    counter=1
else
    counter=$(ls "$daily_directory" | wc -l)
    ((counter++))
fi

scan_directory="$daily_directory/${counter}_$(date '+%H-%M')"
mkdir -p "$scan_directory"


# Creazione di un file di log temporaneo per le scansioni.
temp_log=$(mktemp)
export temp_log # Esporta la variabile per renderla accessibile alle sotto-shell

# Funzione nmap_scan modificata con nomi di file di log descrittivi
declare -A scan_descriptions=(
    ["-sC -sV -A"]="full_scan"
    ["--script vuln"]="vulnerability_scan"
    ["-vv"]="detailed_scan"
    ["-F"]="quick_scan"
    ["--top-ports"]="top_ports_scan"
    ["-p"]="custom_port_scan"
)

# Funzione nmap_scan: esegue una scansione nmap su un indirizzo IP specifico.
# Argomenti:
#   1. ip: Indirizzo IP su cui eseguire la scansione.
#   2. type: Tipo di scansione nmap da eseguire.
#   3. directory: Directory in cui salvare i log delle scansioni.
nmap_scan() {
    # Questa funzione esegue una scansione nmap su un dato indirizzo IP. 
    # I messaggi relativi al progresso della scansione, come l'inizio, il completamento e la creazione del file di log per ogni IP,
    # vengono rediretti al file di log temporaneo per il monitoraggio in tempo reale tramite 'tail -f'.
    # L'output dettagliato della scansione nmap viene salvato in un file separato per analisi successive.
    ip=$1  # Assegna il primo argomento alla variabile 'ip'.
    type=$2 # Assegna il secondo argomento alla variabile 'type'.
    directory=$3  # Assegna il terzo argomento alla variabile 'directory'.
    scan_type_description=${scan_descriptions[$type]}
    host_output_directory="$directory/$ip" # Crea una directory specifica per l'indirizzo IP all'interno della directory di output.
    mkdir -p "$host_output_directory" # Crea una sottodirectory per ogni IP
    output_file="$host_output_directory/nmap_${scan_type_description}_$(date '+%Y-%m-%d_%H-%M-%S').log"  # Formatta il nome del file di log, includendo il tipo di scansione e la data.
    echo "$(date '+%Y-%m-%d %H:%M:%S'): Inizio scansione $scan_type_description (nmap $type) su $ip" >> $temp_log # Registra l'inizio della scansione nel file di log temporaneo.
    nmap $type $ip > "$output_file" # Esegue nmap e redirige l'output nel file di log
    echo "$(date '+%Y-%m-%d %H:%M:%S'): Completata scansione $scan_type_description (nmap $type) su $ip" >> $temp_log # Registra il completamento della scansione nel file di log temporaneo.
    echo "Log file creato: $output_file" >> $temp_log # Registra la creazione del file di log specifico della scansione.
}

export -f nmap_scan # Esporta la funzione per l'uso nelle sotto-shell

# Selezione del tipo di scansioni nmap
# Presenta un menu all'utente per selezionare il tipo di scansione nmap desiderato.
# Include opzioni per varie tipologie di scansioni.
echo "Seleziona i tipi di scansioni che desideri eseguire:"
echo "1. Scansione completa (-sC -sV -A)"
echo "2. Scansione vulnerabilità (--script vuln)"
echo "3. Scansione dettagliata (-vv)"
echo "4. Scansione rapida (-F)"
echo "5. Scansione delle porte comuni (--top-ports)"
echo "6. Scansione di porte personalizzata (-p)"
echo "Inserisci i numeri separati da spazi (es. 1 3):"
read -a scan_choices

# Inizializza le variabili per tenere traccia delle scansioni selezionate
port_scan_selected=false  # Indica se è stata selezionata la scansione personalizzata delle porte
top_ports_selected=false  # Indica se è stata selezionata la scansione delle porte più comuni
top_ports_count=100       # Numero di default delle porte più comuni da scansionare

# Dichiarazione di un array per memorizzare i comandi di scansione
declare -a scan_commands

# Ciclo for che itera su ogni scelta di scansione fornita dall'utente
for choice in "${scan_choices[@]}"; do    case $choice in
        1) scan_commands+=("-sC -sV -A");; # Aggiunge la scansione completa al comando
        2) scan_commands+=("--script vuln");; # Aggiunge la scansione delle vulnerabilità al comando
        3) scan_commands+=("-vv");; # Aggiunge la scansione dettagliata al comando
        4) scan_commands+=("-F");; # Aggiunge la scansione rapida al comando
        5) top_ports_selected=true;; # Imposta la variabile per indicare che è stata selezionata la scansione delle porte più comuni
        6) port_scan_selected=true;; # Imposta la variabile per indicare che è stata selezionata la scansione personalizzata delle porte
        *) echo "Scelta non valida: $choice";; # Gestisce le scelte non valide fornendo un feedback all'utente
    esac
done

# Chiedi il numero di porte se --top-ports è selezionato
if [ "$top_ports_selected" = true ]; then
    while true; do
        echo "Hai selezionato la scansione delle porte più comuni con --top-ports."
        read -p "Quante delle porte più comuni vuoi scansionare? (1-65535, default 100): " input_ports_count

        # Se l'utente non inserisce nulla, usa il valore di default
        if [[ -z "$input_ports_count" ]]; then
            echo "Utilizzo del valore di default: 100 porte."
            top_ports_count=100
            break
        # Verifica che l'input sia un numero valido
        elif [[ $input_ports_count =~ ^[0-9]+$ ]] && [ $input_ports_count -ge 1 ] && [ $input_ports_count -le 65535 ]; then
            top_ports_count=$input_ports_count
            break
        else
            echo "Input non valido. Inserisci un numero intero tra 1 e 65535."
        fi
    done

    scan_commands+=("--top-ports $top_ports_count")
fi

# Verifica se l'opzione di scansione personalizzata delle porte è stata selezionata
if [ "$port_scan_selected" = true ]; then
    while true; do
        read -p "Inserisci la porta o le porte da scansionare (es. 20-22 80, 8080): " custom_ports # Chiede all'utente di inserire le porte da scansionare

        IFS=', ' read -ra ADDR <<< "$custom_ports" # Utilizza spazi e virgole come separatori per dividere l'input dell'utente
        valid_port=true
        for i in "${ADDR[@]}"; do
            i=$(echo $i | xargs) # Rimuove spazi bianchi extra per standardizzare l'input

            # Verifica se l'input rappresenta un numero di porta singolo o un range di porte
            if [[ $i =~ ^[0-9]+$ ]]; then 
                if [ "$i" -gt 65535 ] || [ "$i" -lt 1 ]; then # Controlla se il numero di porta è nel range valido (1-65535)
                    valid_port=false
                    break
                fi
            elif [[ $i =~ ^[0-9]+-[0-9]+$ ]]; then # Controlla se il range di porte è valido
                IFS='-' read -ra RANGE <<< "$i"
                if [ "${RANGE[0]}" -gt 65535 ] || [ "${RANGE[0]}" -lt 1 ] || [ "${RANGE[1]}" -gt 65535 ] || [ "${RANGE[1]}" -lt 1 ]; then
                    valid_port=false
                    break
                fi
            else
                valid_port=false  # Imposta la validità della porta a false se il formato non è riconosciuto
                break
            fi
        done

        if [ "$valid_port" = true ]; then
            # Riassembla le porte in una stringa separata da virgole
            custom_ports=$(IFS=,; echo "${ADDR[*]}")
            scan_commands+=("-p $custom_ports")
            break
        else
            echo "Una o più porte specificate non sono nel range valido (1-65535)."
        fi
    done
fi




# Esecuzione parallela delle scansioni nmap in una sotto-shell
# La sotto-shell permette di eseguire i comandi in background
(
    # Utilizza xargs per parallelizzare le scansioni
    for scan_command in "${scan_commands[@]}"; do
        cat "$file_input" | xargs -I % -P 10 bash -c "nmap_scan % '$scan_command' '$scan_directory'" &
    done
    
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

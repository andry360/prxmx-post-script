#!/bin/bash

# Il comando per lanciare questo script da github è: bash -c "$(wget -qLO - https://raw.githubusercontent.com/andry360/prxmx-post-script/refs/heads/main/start_local.sh)"

# Cartella locale del progetto
project_dir="/prxmx-post-script"

# URL del repository remoto
repo_url="https://github.com/andry360/prxmx-post-script/archive/refs/heads/main.tar.gz"

# Scarica il progetto in una directory temporanea
temp_dir=$(mktemp -d)
echo "Scaricamento del progetto in una directory temporanea..."
wget -qO- "$repo_url" | tar -xz -C "$temp_dir" --strip-components=1

# Verifica la presenza della directory locale
if [[ -d "$project_dir" ]]; then
    echo "Confronto dei file con la directory locale: $project_dir"
    
    # Loop attraverso i file scaricati
    for file in $(find "$temp_dir" -type f); do
        relative_path="${file#$temp_dir/}"
        local_file="$project_dir/$relative_path"
        
        # Controlla se il file esiste localmente
        if [[ -f "$local_file" ]]; then
            echo "Trovato file esistente: $relative_path"
            
            # Confronta i file
            if ! diff -q "$file" "$local_file" > /dev/null; then
                echo "Il file è cambiato: $relative_path"
                read -p "Vuoi sovrascrivere questo file? (s/n): " choice
                if [[ "$choice" == "s" ]]; then
                    cp "$file" "$local_file"
                    echo "File sovrascritto: $relative_path"
                else
                    echo "File mantenuto invariato: $relative_path"
                fi
            else
                echo "Il file è identico: $relative_path"
            fi
        else
            echo "Nuovo file trovato: $relative_path"
            read -p "Vuoi copiare questo file? (s/n): " choice
            if [[ "$choice" == "s" ]]; then
                mkdir -p "$(dirname "$local_file")"
                cp "$file" "$local_file"
                echo "File copiato: $relative_path"
            fi
        fi
    done
else
    echo "Directory locale non trovata. Copia dell'intero progetto..."
    mkdir -p "$project_dir"
    cp -r "$temp_dir/"* "$project_dir/"
    echo "Progetto copiato nella directory locale."
fi

# Rimuovi la directory temporanea
rm -rf "$temp_dir"
echo "Pulizia completata. Operazione terminata."

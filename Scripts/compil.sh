#!/bin/bash

# -----------------------------------------------------------------------------
#  Acompilator.sh
#  Copyright (c) 2024 Asha the Fox 🦊
#  All rights reserved.
#
#  This is the main script for Acompilator
#  The goal of this script is to compile and upload scripts to one or multiple arduino UNO (mostly multiples for easy deployment).
#  The script is divided into several parts:
#      Boot - Code to initialize the script and check requirements.
#      Configuration - Load configuration options or variables.
#      Main Tasks - The main operations the script will perform.
#      Cleanup - Actions taken after the main operations, like logging or cleanup.
#
# -----------------------------------------------------------------------------

# Some metadata
readonly AUTHOR="Asha Geyon (Natpol50)"
readonly VERSION="0.1"
readonly LAST_REVISION="2024-10-03"

# /////////////////
# //////SETUP//////
# /////////////////

readonly BAUDRATE="115200"
readonly SUPPORTED_ARGS=(-v -p -y -boards -n -help -all) 
readonly YESNOOPTIONS=("N" "n" "Y" "y")
ARGS_LIST=()
FOLDER=""
SELECTION=()
ANSWER=""

readonly LOG_FILE="logs/$(date +'%Y%m%d-%H%M%S').log"
if [ ! -d "logs" ]; then
    mkdir logs
fi

# /////////////////
# ////FUNCTIONS////
# /////////////////

log() { # A function used to log a message
    local message="$1"
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S") # Format de date/heure
    echo "$timestamp: $message" >> "$LOG_FILE"
}

x_in_array() { # A Function allowing us to verify if something's in an array
    local element="$1"
    shift  
    local array=("$@")
    
    for item in "${array[@]}"; do
        if [[ "$item" == "$element" ]]; then
            return 0
        fi
    done
    return 1
}



# /////////////////
# ////ARGUMENTS////
# /////////////////


log "ACompilator started"

# First, we extract all arguments (and values for folder and card selection)
for arg in "$@"; do
    ARGS_LIST+=("${arg%%=*}")
    log "Got argument: ${ARGS_LIST[-1]}"
    if ! x_in_array "${ARGS_LIST[-1]}" "${SUPPORTED_ARGS[@]}"; then
        log "${ARGS_LIST[-1]} is not recognized by the script, exiting..."
        echo -e "${ARGS_LIST[-1]} is not supported by current version of ACompil \n Are you sure you used the correct syntax ?"
        exit 1
    elif [ "${ARGS_LIST[-1]}" == "-p" ]; then
        FOLDER="${arg#*=}"
    elif [ "${ARGS_LIST[-1]}" == "-boards" ]; then
        SELECTION="${arg#*=}"
    fi
done
log "FOLDER value is : $FOLDER"
log "SELECTION value is : $SELECTION"

# [DEBUG, will be cut] then, we display all arguments received  
echo -e "\033[31m [DEBUG, will be cut] \033[0m Arguments collected in the list:"
for name in "${ARGS_LIST[@]}"; do
    echo "$name"
done
echo "FOLDER value is : $FOLDER"
echo "SELECTION value is : $SELECTION"

# -v argument check and handling
if x_in_array "-v" "${ARGS_LIST[@]}"; then
    if [ ${#ARGS_LIST[@]} -gt 1 ]; then
        log "-v not understood in combination with other arguments, exiting"
        echo "-v not understood in combination with other arguments, exiting"
        exit 1
    fi

    echo -e "
    \033[32m
 █████╗        ██████╗ ██████╗ ███╗   ███╗██████╗ ██╗██╗     
██╔══██╗      ██╔════╝██╔═══██╗████╗ ████║██╔══██╗██║██║     
███████║█████╗██║     ██║   ██║██╔████╔██║██████╔╝██║██║     
██╔══██║╚════╝██║     ██║   ██║██║╚██╔╝██║██╔═══╝ ██║██║     
██║  ██║      ╚██████╗╚██████╔╝██║ ╚═╝ ██║██║     ██║███████╗
╚═╝  ╚═╝       ╚═════╝ ╚═════╝ ╚═╝     ╚═╝╚═╝     ╚═╝╚══════╝
\033[0m

Acompilator Version: \033[34m$VERSION\033[0m
Developed by \033[34m Asha the fox \033[0m

Last Revision: \033[34m$LAST_REVISION\033[0m
Last Revision by : \033[34m$AUTHOR\033[0m
    "
    exit 0
fi

# -y and -n argument check and handling
if x_in_array "-y" "${ARGS_LIST[@]}"; then
    if x_in_array "-n" "${ARGS_LIST[@]}"; then
        log "-y and -n argument conflicts, exiting"
        echo "-y and -n argument conflicts, exiting"
        exit 1
    fi
    ANWSER="Y"
elif x_in_array "-n" "${ARGS_LIST[@]}"; then
    ANWSER="N"
fi



# /////////////////
# ///ACTUAL CODE///
# /////////////////



# Welcome banner
echo -e "                     
\033[32m
 █████╗        ██████╗ ██████╗ ███╗   ███╗██████╗ ██╗██╗     
██╔══██╗      ██╔════╝██╔═══██╗████╗ ████║██╔══██╗██║██║     
███████║█████╗██║     ██║   ██║██╔████╔██║██████╔╝██║██║     
██╔══██║╚════╝██║     ██║   ██║██║╚██╔╝██║██╔═══╝ ██║██║     
██║  ██║      ╚██████╗╚██████╔╝██║ ╚═╝ ██║██║     ██║███████╗
╚═╝  ╚═╝       ╚═════╝ ╚═════╝ ╚═╝     ╚═╝╚═╝     ╚═╝╚══════╝
\033[0m
"




# Folder decision making, will verify if exists and try to cd to it.
if [ -z "$FOLDER" ]; then
    FOLDER=$(pwd)
    log "No directory specified, will be using the current working directory"
    echo -e "No directory, current working directory will be used"
fi

log "working directory is $FOLDER"
echo "working directory is $FOLDER"

if [ ! -d "$FOLDER" ]; then
    log "$FOLDER was not found, exiting..."
    echo "It seems that $FOLDER doesn't exists..."
    exit 1
fi
cd "$FOLDER" || { echo "Cannot access $FOLDER."; log "Cannot access folder"; exit 1; }



ls -lai

echo "###############################"
echo "Partie 1, création de l'environnement"

# Création ou réinitialisation des dossiers .tmp et build
rm -rf .tmp build
mkdir -p .tmp build

echo "L'environnement a été créé"

echo "###############################"
echo "Partie 2, compilation directe des fichiers à l'aide de avr-gcc"

# Création des fichiers objets pour chaque fichier C
filesO=""
for c in *.c; do
    if [ -f "$c" ]; then
        avr-gcc -Os -DF_CPU=16000000UL -mmcu=atmega328p -c "$c" -o ".tmp/${c%.*}.o"
        filesO="$filesO .tmp/${c%.*}.o"
    fi
done

if [ -z "$filesO" ]; then
    echo "Aucun fichier .c trouvé dans le dossier."
    exit 1
fi

echo "Fichiers compilés : $filesO"

echo "###############################"
echo "Partie 3, linking et build"

avr-gcc -DF_CPU=16000000UL -mmcu=atmega328p $filesO -o build/firmware.elf

echo "Build terminé"

echo "###############################"
echo "Partie 4, conversion en fichier HEX"

avr-objcopy -O ihex -R .eeprom build/firmware.elf build/firmware.hex
echo "Compilation en un fichier HEX terminé"

echo "###############################"
echo "Partie 5, téléversement sur l'Arduino"

while ! x_in_array "$ANSWER" "${YESNOOPTIONS[@]}"; do
    echo "Voulez-vous téléverser cela sur l'arduino ? [Y/N]"
    read -r ANSWER
    if ! x_in_array "$ANSWER" "${YESNOOPTIONS[@]}"; then
    echo "Answer is invalid. Please enter a new answer [Y/N]:"
    fi
done
if [ "$ANSWER" == "N" ] || [ "$ANSWER" == "n" ]; then
    echo "Bon bah salut, bonne chance pour la suite"
    exit 0
else
    echo "Détection de l'Arduino connectée..."
    
    # Récupérer les ports et les noms des cartes$
    IFS=$'\n' read -r -d '' -a boards < <(arduino-cli board list | grep tty | awk '{print $1, $6, $7}' && printf '\0')

    while [ ${#boards[@]} -eq 0 ]; do
        echo "Aucune Arduino détectée. Assurez-vous que l'Arduino est connectée et appuyez sur entrée..."
        read -r NULL
        IFS=$'\n' read -r -d '' -a boards < <(arduino-cli board list | grep tty | awk '{print $1, $6, $7}' && printf '\0')
    done

    # Si plusieurs cartes sont détectées, afficher la liste et demander à l'utilisateur de choisir
    if [ ${#boards[@]} -gt 1 ]; then
        echo "Plusieurs Arduino détectées :"
        for i in "${!boards[@]}"; do
            echo "$i: ${boards[i]}"
        done

        while [[ ! "$SELECTION" =~ ^[0-9]+$ ]] || [ "$SELECTION" -lt 0 ] || [ "$SELECTION" -ge ${#boards[@]} ]; do
            echo "Veuillez sélectionner le numéro de l'Arduino à utiliser :"
            read -r selection
            if [[ ! "$SELECTION" =~ ^[0-9]+$ ]] || [ "$SELECTION" -lt 0 ] || [ "$SELECTION" -ge ${#boards[@]} ]; then
                echo "Sélection invalide."
            fi

        done


        PORT=$(echo "${boards[selection]}" | awk '{print $1}')
        BOARD=$(echo "${boards[selection]}" | awk '{print $2, $3}')
    else
        PORT=$(echo "${boards[0]}" | awk '{print $1}')
        BOARD=$(echo "${boards[0]}" | awk '{print $2, $3}')
    fi

    echo "Ok, carte $BOARD détectée sur $PORT. Téléversement commencé via avrdude."
    avrdude -V -F -p atmega328p -c arduino -b "$BAUDRATE" -P "$PORT" -U flash:w:build/firmware.hex:i
    if [ $? -eq 0 ]; then
        echo "Téléversement réussi !"
    else
        echo "Erreur lors du téléversement."
        exit 1
    fi
fi

exit 0

#!/bin/bash
echo "###############################"
echo "#      COMPIL ARDUINO        #"
echo "###############################"

BAUDRATE="115200"   
FOLDER=""

# Traitement des arguments de ligne de commande
for i in "$@"; do
    case $i in
        -f=*)
        FOLDER="${i#*=}"
        shift
        ;;
        -p=*)
        PORT="${i#*=}"
        shift
        ;;
        -b=*)
        BAUDRATE="${i#*=}"
        shift
        ;;
    esac
done

# Définition du dossier de travail
if [ -z "$FOLDER" ]; then
    FOLDER=$(pwd)
    echo "Aucun paramètre valide ne semble avoir été passé. Utilisation du dossier courant : $FOLDER"
fi

echo "Dossier de travail : $FOLDER"
cd "$FOLDER" || { echo "Impossible de se déplacer dans $FOLDER."; exit 1; }

if [ ! -d "$FOLDER" ]; then
    echo "Il semblerait que le dossier $FOLDER n'existe pas..."
    exit 1
fi

ls -lai

echo "###############################"
echo "Partie 1, création de l'environnement"

# Création ou réinitialisation des dossiers .tmp et build
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

echo "Voulez-vous téléverser cela sur l'arduino ? [Y/N]"
read -r ANSWER
if [ "$ANSWER" == "N" ]; then
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
        echo "Veuillez sélectionner le numéro de l'Arduino à utiliser :"
        read -r selection

        while [[ ! "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 0 ] || [ "$selection" -ge ${#boards[@]} ]; do
            echo "Sélection invalide."
            echo "Veuillez sélectionner le numéro de l'Arduino à utiliser :"
            read -r selection
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

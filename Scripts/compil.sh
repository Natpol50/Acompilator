#!/bin/bash

# -----------------------------------------------------------------------------
#  Acompilator.sh
#  Copyright (c) 2024 Asha the Fox 🦊
#  All rights reserved.
#
#  This is the main script for Acompilator
#  The goal of this script is to compile and upload scripts to one or multiple Arduino UNO R3 (mostly multiples for easy deployment).
#  The script is divided into several parts:
#      Boot - Code to initialize the script and check requirements.
#      Configuration - Load configuration options or variables.
#      Main Tasks - The main operations the script will perform.
#      Cleanup - Actions taken after the main operations, like logging or cleanup.
#
# -----------------------------------------------------------------------------


# Some metadata
readonly AUTHOR="Asha Geyon (Natpol50)"
readonly VERSION="0.2"
readonly LAST_REVISION="2024-10-08"

# /////////////////
# //////SETUP//////
# /////////////////

readonly BAUDRATE="115200"
readonly SUPPORTED_ARGS=(-v -p -y -boards -n -help -h -all -nocleanup) 
readonly YESNOOPTIONS=("N" "n" "Y" "y")
readonly ORIGIN=$(pwd)


ARGS_LIST=()
FOLDER=""
SELECTION=""
ANSWER=""
UPLOADALL="N"
DONTCLEAN="N"

readonly LOG_FILE="$ORIGIN/logs/$(date +'%Y%m%d-%H%M%S').log"
mkdir -p "$(dirname "$LOG_FILE")"

# /////////////////
# ////FUNCTIONS////
# /////////////////

log() {
# log: Appends a log message to the log file with a timestamp.
# 
# Args:
#   $1 (string): The message to be logged.
#
# Effects:
#   Appends a line to the log file in the format "YYYY-MM-DD HH:MM:SS: message".


    local message="$1"
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "$timestamp: $message" >> "$LOG_FILE"
}

x_in_array() {
# x_in_array: Check if an element is present in an array.
# 
# Usage: x_in_array <element> <array_element1> <array_element2> ...
# 
# Returns 0 if the element is found in the array, 1 otherwise.


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


# Here, we'll treat arguments.


log "ACompilator started"




# Reading the arguments and extracting the board list
for arg in "$@"; do
    current_arg="${arg%%=*}"
    ARGS_LIST+=("$current_arg")
    log "Got argument: $current_arg"
    if ! x_in_array "$current_arg" "${SUPPORTED_ARGS[@]}"; then
        log "$current_arg is not recognized by the script, exiting..."
        echo -e "$current_arg is not supported by current version of ACompil \nAre you sure you used the correct syntax?"
        exit 1
    elif [ "$current_arg" == "-p" ]; then
        FOLDER="${arg#*=}"
    elif [ "$current_arg" == "-boards" ]; then
        SELECTION="${arg#*=}"
    fi
done

log "FOLDER value is : $FOLDER"
log "SELECTION value is : $SELECTION"




# Treating -v argument.
if x_in_array "-v" "${ARGS_LIST[@]}"; then
    if [ ${#ARGS_LIST[@]} -gt 1 ]; then
        log "-v not understood in combination with other arguments, exiting"
        echo "-v not understood in combination with other arguments, exiting"
        exit 1
    fi

    echo -e "\033[32m
 █████╗        ██████╗ ██████╗ ███╗   ███╗██████╗ ██╗██╗     
██╔══██╗      ██╔════╝██╔═══██╗████╗ ████║██╔══██╗██║██║     
███████║█████╗██║ 🦊  ██║   ██║██╔████╔██║██████╔╝██║██║     
██╔══██║╚════╝██║     ██║   ██║██║╚██╔╝██║██╔═══╝ ██║██║     
██║  ██║      ╚██████╗╚██████╔╝██║ ╚═╝ ██║██║     ██║███████╗
╚═╝  ╚═╝       ╚═════╝ ╚═════╝ ╚═╝     ╚═╝╚═╝     ╚═╝╚══════╝
\033[0m

Acompilator Version: \033[34m$VERSION\033[0m
Developed by \033[34m Asha the fox \033[0m

Last Revision: \033[34m$LAST_REVISION\033[0m
Last Revision by : \033[34m$AUTHOR\033[0m
    "
    log "got -v argument, printed version files..."
    exit 0
fi

# Treating -h & -help arguments.
if x_in_array "-help" "${ARGS_LIST[@]}" || x_in_array "-h" "${ARGS_LIST[@]}"; then
    if [ ${#ARGS_LIST[@]} -gt 1 ]; then
        log "-help or -h not understood in combination with other arguments, exiting"
        echo "-help or -h not understood in combination with other arguments, exiting"
        exit 1
    fi
    log "got -help argument, printing doc.."
    echo "
Acompilator
Copyright (c) 2024 Asha the Fox 🦊

This the is the main script for the small Acoompilator project.
The goal of this script is to compile and upload scripts to one or multiple Arduino UNO R3 (mostly multiples for easy deployment).

To use it, simply run the script in the folder in which the c code you want to use is located.
The script will automatically detect the c code files and compile them before uploading it.

Arguments : 

-help- Displays help information (Use alone)
-h- Displays help information (Use alone)

-v - Will print some informations about the script version (Use alone)

-y - Will automatically accept the script upload prompt. (Do not use with -n)

-n - Will automatically refuse the script upload prompt. (Do not use with -y)

-boards - Allows the user to preselect the board(s) he wants to upload to. (best used with -y, useless if used with -n) 
        Syntax : boards="number1 number 2 number3" (Example : boards="1 5 3")

- all - Automatically select all available boards when trying to upload, overrides the boards argument. (best used with -y, useless if used with -n) 

-nocleanup - Allows the user to keep the .tmp and build folders and not just the logs.
    "

    exit 0
fi


# Treating -y & -n arguments.
if x_in_array "-y" "${ARGS_LIST[@]}"; then
    if x_in_array "-n" "${ARGS_LIST[@]}"; then
        log "-y and -n argument conflicts, exiting"
        echo "-y and -n argument conflicts, exiting"
        exit 1
    fi
    log "got -y arg, setting ANSWER as Y"
    ANSWER="Y"
elif x_in_array "-n" "${ARGS_LIST[@]}"; then
    log "got -n arg, setting ANSWER as N"
    ANSWER="N"
fi

# Treating -nocleanup argument.
if x_in_array "-nocleanup" "${ARGS_LIST[@]}"; then
    log "got -cleanup arg, setting DONTCLEAN as Y"
    DONTCLEAN="Y"
fi


# Treating -all argument.
if x_in_array "-all" "${ARGS_LIST[@]}"; then
    log "got -all arg, setting UPLOADALL as Y"
    UPLOADALL="Y"
fi






# /////////////////
# ///ACTUAL CODE///
# /////////////////

# Welcome banner, you now entered the script, congrats :3
echo -e "\033[32m
 █████╗        ██████╗ ██████╗ ███╗   ███╗██████╗ ██╗██╗     
██╔══██╗      ██╔════╝██╔═══██╗████╗ ████║██╔══██╗██║██║     
███████║█████╗██║     ██║   ██║██╔████╔██║██████╔╝██║██║     
██╔══██║╚════╝██║     ██║   ██║██║╚██╔╝██║██╔═══╝ ██║██║     
██║  ██║      ╚██████╗╚██████╔╝██║ ╚═╝ ██║██║     ██║███████╗
╚═╝  ╚═╝       ╚═════╝ ╚═════╝ ╚═╝     ╚═╝╚═╝     ╚═╝╚══════╝
\033[0m
"

# Folder decision making, and accessing
if [ -z "$FOLDER" ]; then
    # If no directory is specified, use the current working directory
    FOLDER=$ORIGIN
    log "No directory specified, will be using the current working directory"
    echo -e "\033[33mNo directory specified, current working directory will be used\033[0m"
fi

log "Working directory is: $FOLDER"
echo -e "\033[34mWorking directory is: $FOLDER\033[0m"

# Check if the specified directory exists
if [ ! -d "$FOLDER" ]; then
    log "$FOLDER was not found, exiting..."
    echo -e "\033[31mIt seems that $FOLDER doesn't exist...\033[0m"
    exit 1
fi

# Change directory to the specified folder
cd "$FOLDER" || { 
    echo -e "\033[31mCannot access $FOLDER. Do you have the right permissions?\033[0m"
    log "Cannot access $FOLDER"
    exit 1
}

echo -e "\n \n\033[34mHere's the content of the folder:\033[0m"
ls -la

# Check if the folder is accessible and exists
if [ $? -ne 0 ]; then
    log "Error accessing folder $FOLDER"
    exit 1
fi

echo -e "\n \n###############################"
echo "Part 1, Initializing environment..."

# Environment initialization
echo "Initializing environment..."
echo "---------------------------"

# Remove existing .tmp and build directories
for dir in "$ORIGIN/.tmp" "$ORIGIN/build"; do
    if [ -d "$dir" ]; then
        echo "Removing existing $dir directory..."
        rm -rf "$dir" || { 
            echo -e "\033[31mError: Cannot delete $dir. Do you have the right permissions?\033[0m"
            log "Couldn't delete $dir"
            exit 1
        }
        log "$dir deleted"
    fi
done

# Create new .tmp and build directories
for dir in "$ORIGIN/.tmp" "$ORIGIN/build"; do
    echo "Creating $dir directory..."
    mkdir "$dir" || { 
        echo -e "\033[31mError: Cannot create $dir. Do you have the right permissions?\033[0m"
        log "Couldn't create $dir"
        exit 1
    }
    log "$dir created"
done

echo "---------------------------"
echo -e "\033[32mEnvironment initialized successfully!\033[0m"


echo "###############################"
echo "Part 2, Compilation itself"

# Create object files for each C file
filesO=""

echo -e "Files will include:\n$ARDUINO_CORE_PATH\n$ARDUINO_COREUNO_PATH\n${USER_INSTALLED_LIB[*]}"
for c in *.c; do
    if [ -f "$c" ]; then
        avr-gcc -Os -DF_CPU=16000000UL -mmcu=atmega328p -I"$ARDUINO_CORE_PATH" -I"$ARDUINO_COREUNO_PATH" $INCLUDE_OPTIONS -c "$c" -o "$ORIGIN/.tmp/${c%.*}.o"
        filesO="$filesO $ORIGIN/.tmp/${c%.*}.o"
    fi
done

if [ -z "$filesO" ]; then
    echo "No .c files found in the folder."
    exit 1
fi

echo "Compiled files: $filesO"

echo "###############################"
echo "Part 3, linking and build"

avr-gcc -DF_CPU=16000000UL -mmcu=atmega328p $filesO -o "$ORIGIN/build/firmware.elf"

echo "Build completed"

echo "###############################"
echo "Part 4, conversion to HEX file"

avr-objcopy -O ihex -R .eeprom "$ORIGIN/build/firmware.elf" "$ORIGIN/build/firmware.hex"
echo "Compilation to HEX file completed"

echo "###############################"
echo "Part 5, uploading to Arduino"

while [[ ! "$ANSWER" =~ ^[YyNn]$ ]]; do
    echo "Do you want to upload this to the Arduino? [Y/N]"
    read -r ANSWER
    if [[ ! "$ANSWER" =~ ^[YyNn]$ ]]; then
        echo "Answer is invalid. Please enter Y or N:"
    fi
done

if [[ "$ANSWER" =~ ^[Nn]$ ]]; then
    echo "Alright, good luck with the rest!"
    exit 0
else
    echo "Detecting connected Arduino..."
    
    # Get ports and board names
    mapfile -t boards < <(arduino-cli board list | grep tty | awk '{print $1, $6, $7}')

    while [ ${#boards[@]} -eq 0 ]; do
        echo "No Arduino detected. Make sure the Arduino is connected and press Enter..."
        read -r
        mapfile -t boards < <(arduino-cli board list | grep tty | awk '{print $1, $6, $7}')
    done

    # If multiple boards are detected, display the list and ask the user to choose
    if [ ${#boards[@]} -gt 1 ]; then
        echo "Multiple Arduinos detected:"
        for i in "${!boards[@]}"; do
            echo "$i: ${boards[i]}"
        done

        while [[ ! "$SELECTION" =~ ^[0-9]+$ ]] || [ "$SELECTION" -lt 0 ] || [ "$SELECTION" -ge ${#boards[@]} ]; do
            echo "Please select the number of the Arduino to use:"
            read -r SELECTION
            if [[ ! "$SELECTION" =~ ^[0-9]+$ ]] || [ "$SELECTION" -lt 0 ] || [ "$SELECTION" -ge ${#boards[@]} ]; then
                echo "Invalid selection."
            fi
        done

        PORT=$(echo "${boards[SELECTION]}" | awk '{print $1}')
        BOARD=$(echo "${boards[SELECTION]}" | awk '{print $2, $3}')
    else
        PORT=$(echo "${boards[0]}" | awk '{print $1}')
        BOARD=$(echo "${boards[0]}" | awk '{print $2, $3}')
    fi

    echo "Okay, $BOARD detected on $PORT. Starting upload via avrdude."
    if avrdude -V -F -p atmega328p -c arduino -b "$BAUDRATE" -P "$PORT" -U flash:w:"$ORIGIN/build/firmware.hex":i; then
        echo "Upload successful!"
    else
        echo "Error during upload."
        exit 1
    fi
fi

exit 0
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
#      Cleanup - Actions taken after the main operations like cleanup.
#
# -----------------------------------------------------------------------------

# Ensure necessary commands are available
command -v avr-gcc >/dev/null 2>&1 || { echo >&2 "avr-gcc is required but it's not installed. Aborting."; exit 1; }
command -v avr-g++ >/dev/null 2>&1 || { echo >&2 "avr-g++ is required but it's not installed. Aborting."; exit 1; }
command -v avr-objcopy >/dev/null 2>&1 || { echo >&2 "avr-objcopy is required but it's not installed. Aborting."; exit 1; }
command -v avrdude >/dev/null 2>&1 || { echo >&2 "avrdude is required but it's not installed. Aborting."; exit 1; }
command -v arduino-cli >/dev/null 2>&1 || { echo >&2 "arduino-cli is required but it's not installed. Aborting."; exit 1; }


# Some metadata
readonly AUTHOR="Asha Geyon (Natpol50)"
readonly VERSION="0.8"
readonly LAST_REVISION="2024-10-21"

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
DONTCLEAN="N"


readonly ARDUINO_CORE_PATH="/usr/share/arduino/hardware/arduino/avr/cores/arduino"
readonly ARDUINO_COREUNO_PATH="/usr/share/arduino/hardware/arduino/avr/variants/standard"
readonly ARDUINO_LIBS_PATH="/usr/share/arduino/libraries"


readonly LOG_FILE="$ORIGIN/logs/$(date +'%Y%m%d-%H%M%S').log"
mkdir -p "$(dirname "$LOG_FILE")"

# /////////////////
# ////FUNCTIONS////
# /////////////////

log() {
    local message="$1"
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "$timestamp: $message" >> "$LOG_FILE"
}

x_in_array() {
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
        ANSWER="Y"
    fi
done

log "FOLDER value is : $FOLDER"
IFS=' ' read -r -a SELECTION_ARRAY <<< "$SELECTION"
log "SELECTION value is : ${SELECTION_ARRAY[*]}"

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

-help - Displays help information (Use alone)
-h - Displays help information (Use alone)

-v - Will print some informations about the script version (Use alone)

-y - Will automatically accept the script upload prompt. (Do not use with -n)

-n - Will automatically refuse the script upload prompt. (Do not use with -y)

-boards - Allows the user to preselect the board(s) he wants to upload to. (best used with -y, useless if used with -n) 
        Syntax : boards="number1 number 2 number3" (Example : boards="1 5 3")

- all - Automatically select all available boards when trying to upload, overrides the boards, y and n arguments.

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
# Treating -all argument.
if x_in_array "-all" "${ARGS_LIST[@]}"; then
    if x_in_array "-n" "${ARGS_LIST[@]}"; then
        log "-all and -n argument conflicts, exiting"
        echo "-all and -n argument conflicts, exiting"
        exit 1
    fi
    log "got -all arg, setting ANSWER as A"
    ANSWER="A"
fi

# Treating -nocleanup argument.
if x_in_array "-nocleanup" "${ARGS_LIST[@]}"; then
    log "got -cleanup arg, setting DONTCLEAN as Y"
    DONTCLEAN="Y"
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

echo -e "\n\n###############################\n\n"
echo "Part 1, Initializing environment..."

# Environment initialization
echo "Initializing environment..."
log "Starting environment initialization"
echo "---------------------------"

# Remove existing .tmp and build directories
for dir in "$ORIGIN/.tmp" "$ORIGIN/build"; do
    if [ -d "$dir" ]; then
        echo "Removing existing $dir directory..."
        log "Removing existing $dir directory"
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
    log "Creating $dir directory"
    mkdir "$dir" || { 
        echo -e "\033[31mError: Cannot create $dir. Do you have the right permissions?\033[0m"
        log "Couldn't create $dir"
        exit 1
    }
    log "$dir created"
done

echo "---------------------------"
echo -e "\033[32mEnvironment initialized successfully!\033[0m"
log "Environment seems to have correctly initialized."

echo -e "\n\n###############################\n\n"
echo "Part 2, Compilation"

# Compile Arduino core files
echo "Compiling Arduino core files..."
log "Starting Compilation on arduino core."
echo "---------------------------"
for file in "$ARDUINO_CORE_PATH"/*.cpp "$ARDUINO_CORE_PATH"/*.c "$ARDUINO_COREUNO_PATH"/*.cpp "$ARDUINO_COREUNO_PATH"/*.c; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        echo -e "\e[90mCompiling $filename...\e[0m"
        log "Compiling $filename"
        if ! avr-g++ -c -Os -w -std=gnu++11 -fpermissive -fno-exceptions -ffunction-sections -fdata-sections -fno-threadsafe-statics -Wno-error=narrowing -mmcu=atmega328p -DF_CPU=16000000L -DARDUINO=10812 -DARDUINO_AVR_UNO -DARDUINO_ARCH_AVR -I"$ARDUINO_CORE_PATH" -I"$ARDUINO_COREUNO_PATH" -I"$ARDUINO_LIBS_PATH" "$file" -o "$ORIGIN/.tmp/${filename%.*}.o"; then
            echo -e "\033[31mError compiling core file: $filename\033[0m"
            log "Error compiling user file: $filename"
            exit 1
        fi
        log "Compiled $filename"
    fi
done
echo -e "---------------------------"
echo -e "\033[32mCompiled Arduino core successfully !\033[0m\n"

echo "Compiling user files..."
echo "---------------------------"
filesO=""
for c in *.c *.cpp *.ino; do
    if [ -f "$c" ]; then
        echo -e "\e[90mCompiling $c...\e[0m"
        if ! avr-g++ -c -Os -w -std=gnu++11 -fpermissive -fno-exceptions -ffunction-sections -fdata-sections -fno-threadsafe-statics -Wno-error=narrowing -mmcu=atmega328p -DF_CPU=16000000L -DARDUINO=10812 -DARDUINO_AVR_UNO -DARDUINO_ARCH_AVR -I"$ARDUINO_CORE_PATH" -I"$ARDUINO_COREUNO_PATH" -I"$ARDUINO_LIBS_PATH" -o "$ORIGIN/.tmp/${c%.*}.o" "$c"; then
            echo -e "\033[31mError compiling user file: $c\033[0m"
            log "Error compiling user file: $c"
            exit 1
        fi
        filesO="$filesO $ORIGIN/.tmp/${c%.*}.o"
    fi
done
echo -e "---------------------------"
echo -e "\033[32mCompiled user files successfully !\033[0m\n"

if [ -z "$filesO" ]; then
    echo -e "\033[31m No .c, .cpp, or .ino files found in the folder.\033[0m"
    log "No .c, .cpp, or .ino files found in the folder."
    exit 1
else 
    echo "Compilation successful! The following files were compiled:"
    log "The following user files were compiled:"
    for file in $filesO; do
        echo "  - ${file##*/}"
        log "  - ${file##*/}"
    done
fi

echo -e "\n\n###############################\n\n"
echo "Part 3, linking and build"
log "Starting linking and build process"

# Collect all object files
filesO=""
for file in "$ORIGIN/.tmp"/*.o; do
    if [ -f "$file" ]; then
        filesO="$filesO $file"
    fi
done

echo "Linking and building firmware..."
log "Linking and building firmware with object files:"
for obj_file in $filesO; do
    log "  - $obj_file"
done
if ! avr-gcc -w -Os -g -flto -fuse-linker-plugin -Wl,--gc-sections -mmcu=atmega328p \
-o "$ORIGIN/build/firmware.elf" $filesO \
-I"$ARDUINO_CORE_PATH" -L"$ARDUINO_CORE_PATH" -lm; then
    echo -e "---------------------------"
    echo -e "\033[31mError during linking and building.\033[0m"
    log "Error during linking and building"
    echo -e "---------------------------"
    exit 1
fi

echo -e "\033[32mFirmware built successfully!\033[0m"
log "Firmware built successfully"

echo -e "\n\n###############################\n\n"



echo "Part 4, conversion to HEX file"

echo "Starting conversion to HEX file ... "
log "Starting conversion to HEX file ... "
if ! avr-objcopy -O ihex -R .eeprom "$ORIGIN/build/firmware.elf" "$ORIGIN/build/firmware.hex"; then
    echo -e "---------------------------"
    echo -e "\033[31mError during ELF to GEX conversion.\033[0m"     # Say gex
    log "Error during elf to hex conversion"
    echo -e "---------------------------"
    exit 1
fi


echo -e "\033[32mConversion successfull !\033[0m"
log "Conversion was successfull !"



echo -e "\n\n###############################\n\n"
echo "Part 5, uploading to Arduino"


while [[ ! "$ANSWER" =~ ^[YyNnAa]$ ]]; do
    log "No pre-given answer, prompting user"
    echo "Do you want to upload this to the Arduino? [Y/N/A]"
    read -r ANSWER
    if [[ ! "$ANSWER" =~ ^[YyNnAa]$ ]]; then
        log "User entered invalid answer, $ANSWER"
        echo "Answer is invalid. Please enter Y, N, or A:"
    fi
done


if [[ "$ANSWER" =~ ^[Nn]$ ]]; then
    log "User requested not to upload to Arduino"
    echo "Alright, good luck with the rest!"
    echo -e "\033[8mAfox out !\033[0m"
    exit 0
elif [[ "$ANSWER" =~ ^[Yy]$ ]]; then
    echo "Detecting connected Arduino..."
    log "Starting arduino uno board detection."
    
    # Get ports and board names
    mapfile -t boards < <(arduino-cli board list | grep tty | awk '{print $1, $6, $7}')

    while [ ${#boards[@]} -eq 0 ]; do
        echo "No Arduino detected. Make sure the Arduino is connected and press Enter..."
        log "No arduino connected, prompting user"
        read -r
        mapfile -t boards < <(arduino-cli board list | grep tty | awk '{print $1, $6, $7}')
    done

    # If multiple boards are detected, display the list and ask the user to choose
    if [ ${#boards[@]} -gt 1 ]; then
        echo "Multiple Arduinos detected:"
        log "Multiple Arduinos detected:"
        for i in "${!boards[@]}"; do
            log "   $i: ${boards[i]}"
            echo " $i: ${boards[i]}"
        done

        # Check if there's already a valid selection
        valid_selection=true
        if [ ${#SELECTION_ARRAY[@]} -eq 0 ]; then
            valid_selection=false
        else
            for index in "${SELECTION_ARRAY[@]}"; do
            if [[ ! "$index" =~ ^[0-9]+$ ]] || [ "$index" -lt 0 ] || [ "$index" -ge ${#boards[@]} ]; then
                echo "Selection is invalid, please select again."
                log "Selection is invalid, prompting user."
                valid_selection=false
                break
            fi
            done
        fi

        # If no valid selection, ask for it
        if ! $valid_selection; then
            while ! $valid_selection; do
                log "Prompting user for selection"
                echo "Please select the Arduino(s) you want to upload to. You can select multiple (e.g., 0 2):"
                read -r SELECTION
                IFS=' ' read -r -a SELECTION_ARRAY <<< "$SELECTION"
                valid_selection=true
                for index in "${SELECTION_ARRAY[@]}"; do
                    if [[ ! "$index" =~ ^[0-9]+$ ]] || [ "$index" -lt 0 ] || [ "$index" -ge ${#boards[@]} ]; then
                        log "Invalid selection: $index ,  reprompting user"
                        echo "Invalid selection: $index"
                        valid_selection=false
                        break
                    fi
                done
            done
        fi

        for index in "${SELECTION_ARRAY[@]}"; do
            PORT=$(echo "${boards[index]}" | awk '{print $1}')
            BOARD=$(echo "${boards[index]}" | awk '{print $2, $3}')
            log "Selected board: $BOARD on $PORT, starting upload using avrdude."
            echo "Okay, $BOARD detected on $PORT. Starting upload via avrdude."
            if avrdude -V -F -p atmega328p -c arduino -b "$BAUDRATE" -P "$PORT" -U flash:w:"$ORIGIN/build/firmware.hex":i; then
                log "Upload to $BOARD on $PORT successful!"
                echo "Upload to $BOARD on $PORT successful!"
            else
                log "Error during upload to $BOARD on $PORT."
                echo "Error during upload to $BOARD on $PORT."
                exit 1
            fi
        done
    else
        PORT=$(echo "${boards[0]}" | awk '{print $1}')
        BOARD=$(echo "${boards[0]}" | awk '{print $2, $3}')
        log "Single board detected: $BOARD on $PORT, starting upload using avrdude."
        echo "Okay, $BOARD detected on $PORT. Starting upload via avrdude."
        if avrdude -V -F -p atmega328p -c arduino -b "$BAUDRATE" -P "$PORT" -U flash:w:"$ORIGIN/build/firmware.hex":i; then
            echo "Upload successful!"
        else
            echo "Error during upload."
            exit 1
        fi
    fi
elif [[ "$ANSWER" =~ ^[Aa]$ ]]; then
    log "User requested to upload to all Arduinos"
    log "Detecting All connected Arduinos..."
    echo "Detecting connected Arduino(s)..."

    # Get ports and board names
    mapfile -t boards < <(arduino-cli board list | grep tty | awk '{print $1, $6, $7}')

    while [ ${#boards[@]} -eq 0 ]; do
        log "No Arduino detected, prompting user"
        echo "No Arduino detected. Make sure the Arduino is connected and press Enter..."
        read -r
        mapfile -t boards < <(arduino-cli board list | grep tty | awk '{print $1, $6, $7}')
    done

    # Filter for Arduino Uno boards
    uno_boards=()
    for board in "${boards[@]}"; do
        if [[ "$board" == *"Arduino Uno"* ]]; then
            uno_boards+=("$board")
        fi
    done

    if [ ${#uno_boards[@]} -eq 0 ]; then
        log "No Arduino Uno detected, exiting."
        echo "No Arduino Uno detected., exiting"
        exit 1
    fi

    for uno_board in "${uno_boards[@]}"; do
        PORT=$(echo "$uno_board" | awk '{print $1}')
        BOARD=$(echo "$uno_board" | awk '{print $2, $3}')
        log "$BOARD on $PORT, starting upload using avrdude."
        echo "Uploading to $BOARD on $PORT..."

        if avrdude -V -F -p atmega328p -c arduino -b "$BAUDRATE" -P "$PORT" -U flash:w:"$ORIGIN/build/firmware.hex":i; then
            log "Upload to $BOARD on $PORT successful!"
            echo "Upload to $BOARD on $PORT successful!"
        else
            log "Error during upload to $BOARD on $PORT."
            echo "Error during upload to $BOARD on $PORT."
            exit 1
        fi
    done
fi

echo -e "\n\n###############################\n\n"

echo "Part 6, cleanup"

if [[ "$DONTCLEAN" =~ ^[Nn]$ ]]; then
    echo "Cleaning up..."
    log "Cleaning up..."
    if ! rm -rf "$ORIGIN/.tmp" "$ORIGIN/build"; then
        echo "Error cleaning up .tmp and build folders."
        log "Error cleaning up .tmp and build folders."
    fi
    echo -e "\033[32mCleaned up successfully!\033[0m"
    log "Cleaned up successfully"
else
    echo "Keeping .tmp and build folders..."
    log "Keeping .tmp and build folders"
fi


echo -e "\n\n###############################\n\n"

echo -e "Acompilator finished successfully! \nThanks for using it ! \n\033[8mAfox out !\033[0m"
log "Acompilator finished successfully!"
exit 0

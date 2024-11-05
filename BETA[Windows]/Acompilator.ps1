# Acompilator.ps1
# Copyright (c) 2024 Sp3ctrale 👻
# All rights reserved.

param(
    [string]$p
)

# Set project path
$projectPath = $p
if (-not $projectPath) {
    Write-Host "Error: Project path not specified. Use -p parameter to specify the project path." -ForegroundColor Red
    exit 1
}

# Verify that the project path exists
if (-not (Test-Path $projectPath)) {
    Write-Host "Error: Specified project path does not exist: $projectPath" -ForegroundColor Red
    exit 1
}

# Configuration des chemins
$arduinoCorePath = "C:\Users\Administrateur\AppData\Local\Arduino15\packages\arduino\hardware\avr\1.8.6\cores\arduino"
$avrGccPath = "C:\Users\Administrateur\AppData\Local\Arduino15\packages\arduino\tools\avr-gcc\7.3.0-atmel3.6.1-arduino7\bin"
$arduinoVariantPath = "C:\Users\Administrateur\AppData\Local\Arduino15\packages\arduino\hardware\avr\1.8.6\variants\standard"
$arduinoPath = "C:\Users\Administrateur\AppData\Local\Arduino15\packages\arduino\hardware\avr\1.8.6"

# Ensure necessary commands are available
$requiredCommands = @("avr-gcc", "avr-g++", "avr-objcopy", "avrdude", "arduino-cli")
foreach ($command in $requiredCommands) {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
        Write-Host "$command is required but it's not installed. Aborting." -ForegroundColor Red
        exit 1
    }
}

# Some metadata
$author = "Sp3ctrale 👻"
$version = "0.1"
$lastRevision = (Get-Date).ToString("yyyy-MM-dd")

# Setup
$baudrate = "115200"
$supportedArgs = @("-v", "-p", "-y", "-boards", "-n", "-help", "-h", "-all", "-nocleanup")
$origin = Get-Location

$logFile = Join-Path $origin "logs\$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
New-Item -ItemType Directory -Path (Split-Path $logFile) -Force | Out-Null

# Functions
function Log {
    param (
        [string]$message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logFile -Value "$timestamp : $message"
}

function x_in_array {
    param (
        [string]$element,
        [string[]]$array
    )
    return $array -contains $element
}

# Initial cleanup
Remove-Item "$origin\.tmp\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$origin\build\*" -Recurse -Force -ErrorAction SilentlyContinue

# Arguments
Log "ACompilator started"
$argsList = @()
$folder = ""
$selection = ""
$answer = ""
$dontClean = "N"

# Reading the arguments
foreach ($arg in $args) {
    $currentArg = $arg -split "=" | Select-Object -First 1
    $argsList += $currentArg
    Log "Got argument: $currentArg"
    
    if (-not (x_in_array $currentArg $supportedArgs)) {
        Log "$currentArg is not recognized by the script, exiting..."
        Write-Host "$currentArg is not supported by current version of ACompilator. Are you sure you used the correct syntax?" -ForegroundColor Red
        exit 1
    } elseif ($currentArg -eq "-p") {
        $folder = $arg -split "=" | Select-Object -Last 1
    } elseif ($currentArg -eq "-boards") {
        $selection = $arg -split "=" | Select-Object -Last 1
        $answer = "Y"
    }
}

Log "FOLDER value is: $folder"
$selectionArray = $selection -split ' '
Log "SELECTION value is: $($selectionArray -join ', ')"

# Treating arguments
if (x_in_array "-v" $argsList) {
    if ($argsList.Count -gt 1) {
        Log "-v not understood in combination with other arguments, exiting"
        Write-Host "-v not understood in combination with other arguments, exiting" -ForegroundColor Red
        exit 1
    }
    Write-Host "Acompilator Version: $version`nDeveloped by $author`nLast Revision: $lastRevision" -ForegroundColor Green
    Log "got -v argument, printed version files..."
    exit 0
}

if (x_in_array "-help" $argsList -or x_in_array "-h" $argsList) {
    if ($argsList.Count -gt 1) {
        Log "-help or -h not understood in combination with other arguments, exiting"
        Write-Host "-help or -h not understood in combination with other arguments, exiting" -ForegroundColor Red
        exit 1
    }
    Log "got -help argument, printing doc.."
    Write-Host @"
Acompilator
Copyright (c) 2024 Sp3ctrale 👻

This is the main script for the small Acompilator project.
The goal of this script is to compile and upload scripts to one or multiple Arduino UNO R3.

Arguments:
-help/-h - Displays help information (Use alone)
-v - Prints script version information (Use alone)
-y - Automatically accepts script upload prompt
-n - Automatically refuses script upload prompt
-boards - Preselect upload boards (syntax: boards="1 5 3")
-all - Select all available boards
-nocleanup - Keep .tmp and build folders
"@ -ForegroundColor Green
    exit 0
}

if (x_in_array "-y" $argsList) {
    if (x_in_array "-n" $argsList) {
        Log "-y and -n argument conflicts, exiting"
        Write-Host "-y and -n argument conflicts, exiting" -ForegroundColor Red
        exit 1
    }
    Log "got -y arg, setting ANSWER as Y"
    $answer = "Y"
} elseif (x_in_array "-n" $argsList) {
    Log "got -n arg, setting ANSWER as N"
    $answer = "N"
}

if (x_in_array "-all" $argsList) {
    if (x_in_array "-n" $argsList) {
        Log "-all and -n argument conflicts, exiting"
        Write-Host "-all and -n argument conflicts, exiting" -ForegroundColor Red
        exit 1
    }
    Log "got -all arg, setting ANSWER as A"
    $answer = "A"
}

if (x_in_array "-nocleanup" $argsList) {
    Log "got -cleanup arg, setting DONTCLEAN as Y"
    $dontClean = "Y"
}

# Display ASCII Art
Write-Host @"
 
 █████╗        ██████╗ ██████╗ ███╗   ███╗██████╗ ██╗██╗     
██╔══██╗      ██╔════╝██╔═══██╗████╗ ████║██╔══██╗██║██║     
███████║█████╗██║     ██║   ██║██╔████╔██║██████╔╝██║██║     
██╔══██║╚════╝██║     ██║   ██║██║╚██╔╝██║██ ╔═══╝ ██║██║     
██║  ██║      ╚██████╗╚██████╔╝██║ ╚═╝ ██║██║     ██║██║ 
██║  ██║      ╚██████╗╚██████╔╝██║ ╚═╝ ██║██║     ██║███████╗
╚═╝  ╚═╝       ╚═════╝ ╚═════╝ ╚═╝     ╚═╝╚═╝     ╚═╝╚══════╝
"@ -ForegroundColor Green

# Folder handling
if (-not $folder) {
    $folder = $projectPath
    Log "No directory specified, using project path"
    Write-Host "No directory specified, project path will be used" -ForegroundColor Yellow
}

Log "Working directory is: $folder"
Write-Host "Working directory is: $folder" -ForegroundColor Cyan

if (-not (Test-Path $folder)) {
    Log "$folder was not found, exiting..."
    Write-Host "It seems that $folder doesn't exist..." -ForegroundColor Red
    exit 1
}

Set-Location $folder

Write-Host "`nFolder contents:`n"
Get-ChildItem -Force

Write-Host "`n###############################`n"
Write-Host "Part 1, Initializing environment..."

# Environment initialization
foreach ($dir in @("$origin\.tmp", "$origin\build")) {
    if (Test-Path $dir) {
        Write-Host "Removing existing $dir directory..."
        Log "Removing existing $dir directory"
        Remove-Item $dir -Recurse -Force
    }
    Write-Host "Creating $dir directory..."
    Log "Creating $dir directory"
    New-Item -ItemType Directory -Path $dir | Out-Null
}

Write-Host "Environment initialized successfully!" -ForegroundColor Green
Log "Environment initialized successfully"

Write-Host "`n###############################`n"
Write-Host "Part 2, Compilation"

# Compile Arduino core files
Write-Host "Compiling Arduino core files..."
Log "Starting compilation of Arduino core files"

$coreFiles = @(
    "wiring_digital.c", "wiring.c", "wiring_analog.c", "WInterrupts.c",
    "hooks.c", "wiring_pulse.c", "wiring_shift.c",
    "CDC.cpp", "HardwareSerial.cpp", "HardwareSerial0.cpp",
    "HardwareSerial1.cpp", "HardwareSerial2.cpp", "HardwareSerial3.cpp",
    "IPAddress.cpp", "new.cpp", "Print.cpp", "Stream.cpp",
    "Tone.cpp", "USBCore.cpp", "WMath.cpp", "WString.cpp",
    "abi.cpp", "main.cpp", "PluggableUSB.cpp"
)

foreach ($file in $coreFiles) {
    $sourcePath = "$arduinoPath\cores\arduino\$file"
    $outputFile = "$origin\.tmp\$($file -replace '\.c(pp)?$', '.o')"
    if ($file -match '\.cpp$') {
        $compileCommand = @(
            "$avrGccPath\avr-g++",
            "-c", "-g", "-Os", "-w", "-std=gnu++11",
            "-fpermissive", "-fno-exceptions", "-ffunction-sections", "-fdata-sections", "-fno-threadsafe-statics",
            "-MMD", "-flto", "-mmcu=atmega328p",
            "-DF_CPU=16000000L", "-DARDUINO=10607", "-DARDUINO_AVR_UNO", "-DARDUINO_ARCH_AVR",
            "-I`"$arduinoPath\cores\arduino`"",
            "-I`"$arduinoPath\variants\standard`"",
            $sourcePath,
            "-o", $outputFile
        )
    } else {
        $compileCommand = @(
            "$avrGccPath\avr-gcc",
            "-c", "-g", "-Os", "-w", "-std=gnu11",
            "-ffunction-sections", "-fdata-sections",
            "-MMD", "-flto", "-mmcu=atmega328p",
            "-DF_CPU=16000000L", "-DARDUINO=10607", "-DARDUINO_AVR_UNO", "-DARDUINO_ARCH_AVR",
            "-I`"$arduinoPath\cores\arduino`"",
            "-I`"$arduinoPath\variants\standard`"",
            $sourcePath,
            "-o", $outputFile
        )
    }
    Write-Host "Compiling $file..."
    & $compileCommand[0] $compileCommand[1..($compileCommand.Length-1)]
    if ($LASTEXITCODE -ne 0) {
        Write-Host " Error compiling $file" -ForegroundColor Red
        exit 1
    }
}

# Compile user sketch
Write-Host "Compiling user sketch..."
$sketchFile = "test.cpp"
$sketchPath = Join-Path -Path $projectPath -ChildPath $sketchFile

if (-not (Test-Path $sketchPath)) {
    Write-Host "Error: Sketch file not found: $sketchPath" -ForegroundColor Red
    exit 1
}

$sketchOutput = "$origin\.tmp\sketch.o"

$compileCommand = @(
    "$avrGccPath\avr-g++",
    "-c", "-g", "-Os", "-w", "-std=gnu++11",
    "-fpermissive", "-fno-exceptions", "-ffunction-sections", "-fdata-sections", "-fno-threadsafe-statics",
    "-MMD", "-flto", "-mmcu=atmega328p",
    "-DF_CPU=16000000L", "-DARDUINO=10607", "-DARDUINO_AVR_UNO", "-DARDUINO_ARCH_AVR",
    "-I`"$arduinoPath\cores\arduino`"",
    "-I`"$arduinoPath\variants\standard`"",
    $sketchPath,
    "-o", $sketchOutput
)

Write-Host "Compiling $sketchFile..."
& $compileCommand[0] $compileCommand[1..($compileCommand.Length-1)]
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error compiling $sketchFile" -ForegroundColor Red
    exit 1
}

# Debugging output
Write-Host "Contents of .tmp folder:"
Get-ChildItem "$origin\.tmp" | Format-Table Name, Length

Write-Host "Object files to be linked:"
$objectFiles = @()
$objectFiles += Get-ChildItem -Path "$origin\.tmp" -Filter "*.o" | Where-Object { $_.Name -ne "sketch.o" } | Select-Object -ExpandProperty FullName
$objectFiles += $sketchOutput
$objectFiles | ForEach-Object { Write-Host $_ }

Write-Host "Sketch output file: $sketchOutput"
if (Test-Path "$origin\.tmp\sketch.o") {
    Write-Host "sketch.o exists in .tmp folder"
} else {
    Write-Host "sketch.o does not exist in .tmp folder"
}

# Linking
Write-Host "`n###############################`n"
Write-Host "Part 3, Linking and Building Firmware"

$outputElf = "$origin\build\firmware.elf"

# Build link command
$linkCommand = @(
    "$avrGccPath\avr-gcc",
    "-w", "-Os", "-g", "-flto", "-fuse-linker-plugin",
    "-Wl,--gc-sections", "-mmcu=atmega328p",
    "-o", $outputElf
)
$linkCommand += $objectFiles
$linkCommand += @(
    "-L`"$arduinoPath\variants\standard`"",
    "-L`"$arduinoPath\cores\arduino`"",
    "-lm"
)

Write-Host "Link command:"
Write-Host ($linkCommand -join ' ')

# Execute link command
$process = Start-Process -FilePath $linkCommand[0] -ArgumentList $linkCommand[1..($linkCommand.Length-1)] -NoNewWindow -PassThru -Wait -RedirectStandardOutput "$origin\link_output.txt" -RedirectStandardError "$origin\link_error.txt"

if ($process.ExitCode -ne 0) {
    Write-Host "Error linking firmware. Exit code: $($process.ExitCode)" -ForegroundColor Red
    if (Test-Path "$origin\link_output.txt") {
        Write-Host "Standard Output:"
        Get-Content "$origin\link_output.txt"
    }
    if (Test-Path "$origin\link_error.txt") {
        Write-Host "Standard Error:"
        Get-Content "$origin\link_error.txt"
    }
    exit 1
}

# Convert to HEX
Write-Host "`n###############################`n"
Write-Host "Part 4, Converting to HEX"

$outputHex = "$origin\build\firmware.hex"
& "$avrGccPath\avr-objcopy" -O ihex -R .eeprom $outputElf $outputHex
if ($LASTEXITCODE -ne 0) {
    Log "Error converting to HEX"
    Write-Host "Error converting to HEX" -ForegroundColor Red
    exit 1
}

# Upload prompt
Write-Host "`n###############################`n"
Write-Host "Part 5, Upload to Arduino"

while (-not ($answer -match "^[YyNnAa]$")) {
    Log "Prompting user for upload confirmation"
    Write-Host "Upload to Arduino? [Y/N/ All]" -ForegroundColor Yellow
    $answer = Read-Host
    if ($answer -eq "Y" -or $answer -eq "y") {
        $answer = "Y"
    } elseif ($answer -eq "N" -or $answer -eq "n") {
        $answer = "N"
    } elseif ($answer -eq "A" -or $answer -eq "a") {
        $answer = "A"
    } else {
        Write-Host "Invalid input, please try again" -ForegroundColor Red
    }
}

# Upload to Arduino
if ($answer -eq "Y" -or $answer -eq "A") {
    Write-Host "Uploading to Arduino..."
    Log "Uploading to Arduino..."
    & "avrdude" -c arduino -p m328p -P COM3 -b $baudrate -U flash:w:$outputHex
    if ($LASTEXITCODE -ne 0) {
        Log "Error uploading to Arduino"
        Write-Host "Error uploading to Arduino" -ForegroundColor Red
        exit 1
    }
}

# Cleanup
if ($dontClean -eq "N") {
    Write-Host "Cleaning up..."
    Log "Cleaning up..."
    Remove-Item "$origin\.tmp" -Recurse -Force
    Remove-Item "$origin\build" -Recurse -Force
}

Write-Host "`n###############################`n"
Write-Host "Script finished successfully!" -ForegroundColor Green
Log "Script finished successfully"
exit 0
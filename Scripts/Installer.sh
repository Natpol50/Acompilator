#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Pretty print functions
print_step() {
    echo -e "\n${BLUE}==>${NC} ${BOLD}$1${NC}"
}

print_success() {
    echo -e "${GREEN}✔${NC} $1"
}

print_error() {
    echo -e "${RED}✘ ERROR:${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}!${NC} $1"
}

print_header() {
    echo -e "\n${BOLD}╔════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║        Acompil Installation Tool       ║${NC}"
    echo -e "${BOLD}╚════════════════════════════════════════╝${NC}\n"
}

# Function to check if script is run with sudo
is_sudo() {
    return $(id -u)
}

# Function to copy Arduino folder contents
copy_arduino_folder() {
    print_step "Copying Arduino hardware files"
    
    # Define source and destination paths
    local ARDUINO_SOURCE="./arduino"
    local ARDUINO_DEST="/usr/share/arduino/hardware/arduino"
    
    # Check if source directory exists
    if [ ! -d "$ARDUINO_SOURCE" ]; then
        print_error "Arduino source folder not found in current directory"
        return 1
    fi
    
    # Create destination directory if it doesn't exist
    mkdir -p "$ARDUINO_DEST"
    
    # Copy contents
    if cp -r "$ARDUINO_SOURCE/"* "$ARDUINO_DEST/"; then
        print_success "Arduino files copied successfully to $ARDUINO_DEST"
    else
        print_error "Failed to copy Arduino files"
        return 1
    fi
    
    # Set appropriate permissions
    chmod -R 755 "$ARDUINO_DEST"
    
    return 0
}

# Function to install curl based on package manager
install_curl() {
    local PKG_MANAGER=$(detect_package_manager)
    print_step "Installing curl"
    
    case $PKG_MANAGER in
        "apt")
            apt-get update
            apt-get install -y curl
            ;;
        "dnf"|"yum")
            $PKG_MANAGER install -y curl
            ;;
        "pacman")
            pacman -Sy --noconfirm curl
            ;;
        *)
            print_error "Unsupported package manager. Please install curl manually."
            exit 1
            ;;
    esac
}

# Function to install arduino-cli
install_arduino_cli() {
    print_step "Installing arduino-cli"
    
    # Check if curl is installed
    if ! command -v curl >/dev/null 2>&1; then
        print_warning "curl is not installed. Installing curl first..."
        install_curl
    fi
    
    # Create temporary directory
    local TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    # Download and install arduino-cli
    curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh | sh
    
    # Move to system binary location
    if [ -f "./bin/arduino-cli" ]; then
        mv "./bin/arduino-cli" "/usr/local/bin/arduino-cli"
        chmod 755 "/usr/local/bin/arduino-cli"
        print_success "Arduino CLI installed to /usr/local/bin"
    else
        print_error "Failed to install arduino-cli"
        return 1
    fi
    
    # Cleanup
    cd - > /dev/null
    rm -rf "$TEMP_DIR"
    
    return 0
}

# Function to check if arduino-cli exists in common locations
check_arduino_cli() {
    # Check in PATH
    if command -v arduino-cli >/dev/null 2>&1; then
        return 0
    fi
    
    # Check common installation locations
    local COMMON_LOCATIONS=(
        "/usr/local/bin/arduino-cli"
        "/usr/bin/arduino-cli"
        "$HOME/bin/arduino-cli"
        "$HOME/.local/bin/arduino-cli"
        "/opt/arduino-cli"
    )
    
    for location in "${COMMON_LOCATIONS[@]}"; do
        if [ -x "$location" ]; then
            return 0
        fi
    done
    
    return 1
}

# Detect package manager
detect_package_manager() {
    if command -v apt-get >/dev/null; then
        echo "apt"
    elif command -v dnf >/dev/null; then
        echo "dnf"
    elif command -v yum >/dev/null; then
        echo "yum"
    elif command -v pacman >/dev/null; then
        echo "pacman"
    else
        echo "unknown"
    fi
}

# Function to install dependencies based on package manager
install_dependencies() {
    local PKG_MANAGER=$(detect_package_manager)
    print_step "Installing dependencies"
    
    case $PKG_MANAGER in
        "apt")
            print_warning "Using apt package manager"
            apt-get update
            apt-get install -y gcc build-essential
            apt-get install -y gcc-avr binutils-avr avr-libc gdb-avr
            apt-get install -y avrdude
            ;;
        "dnf"|"yum")
            print_warning "Using ${PKG_MANAGER} package manager"
            $PKG_MANAGER install -y avr-gcc avr-gcc-c++ avr-libc avrdude
            ;;
        "pacman")
            print_warning "Using pacman package manager"
            pacman -Sy --noconfirm avr-gcc avr-libc avrdude
            ;;
        *)
            print_error "Unsupported package manager. Please install dependencies manually:"
            echo "- avr-gcc"
            echo "- avr-g++"
            echo "- avr-objcopy"
            echo "- avrdude"
            echo "- arduino-cli"
            exit 1
            ;;
    esac
}

# Function to check dependencies
check_dependencies() {
    local MISSING_DEPS=0
    local DEPS=("avr-gcc" "avr-g++" "avr-objcopy" "avrdude")
    
    print_step "Checking dependencies"
    
    # Check regular dependencies
    for dep in "${DEPS[@]}"; do
        if command -v $dep >/dev/null 2>&1; then
            print_success "$dep is installed"
        else
            print_warning "$dep is not installed"
            MISSING_DEPS=1
        fi
    done
    
    # Special check for arduino-cli
    if check_arduino_cli; then
        print_success "arduino-cli is installed"
    else
        print_warning "arduino-cli is not installed"
        install_arduino_cli
    fi
    
    if [ $MISSING_DEPS -eq 1 ]; then
        print_step "Installing missing dependencies"
        install_dependencies
    else
        print_success "All core dependencies are satisfied"
    fi
}

# Print header
print_header

# Auto-elevate privileges
if ! is_sudo; then
    print_warning "This installation requires administrator privileges."
    print_warning "You will be prompted for your password."
    exec sudo "$0" "$@"
    exit $?
fi

# Check and install dependencies
check_dependencies

# Define source and destination paths
SOURCE_SCRIPT="Acompil.sh"
DEST_PATH="/bin/Acompil"

# Check if source script exists
if [ ! -f "$SOURCE_SCRIPT" ]; then
    print_error "$SOURCE_SCRIPT not found in current directory"
    exit 1
fi

# Copy the script to /bin
print_step "Installing Acompil.sh to /bin"
if cp "$SOURCE_SCRIPT" "$DEST_PATH"; then
    print_success "File copied successfully"
else
    print_error "Failed to copy file"
    exit 1
fi

# Copy Arduino folder contents
if ! copy_arduino_folder; then
    print_error "Failed to copy Arduino files"
    exit 1
fi

# Set executable permissions for all users
print_step "Setting executable permissions"
if chmod 755 "$DEST_PATH"; then
    print_success "Permissions set successfully"
else
    print_error "Failed to set permissions"
    exit 1
fi

# Verify installation
if [ ! -x "$DEST_PATH" ]; then
    print_error "Installation verification failed"
    exit 1
fi

# Reload bash configuration for the current user
print_step "Reloading bash configuration"
if [ -n "$SUDO_USER" ]; then
    # Get the actual user's home directory
    USER_HOME=$(eval echo ~$SUDO_USER)
    
    # Source both .bashrc and .bash_profile if they exist
    if [ -f "$USER_HOME/.bashrc" ]; then
        sudo -u $SUDO_USER bash -c "source $USER_HOME/.bashrc"
        print_success "Reloaded .bashrc"
    fi
    
    if [ -f "$USER_HOME/.bash_profile" ]; then
        sudo -u $SUDO_USER bash -c "source $USER_HOME/.bash_profile"
        print_success "Reloaded .bash_profile"
    fi
else
    # Fallback for direct root execution
    if [ -f "$HOME/.bashrc" ]; then
        source "$HOME/.bashrc"
        print_success "Reloaded .bashrc"
    fi
    
    if [ -f "$HOME/.bash_profile" ]; then
        source "$HOME/.bash_profile"
        print_success "Reloaded .bash_profile"
    fi
fi

echo -e "\n${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║      Installation Complete! 🎉         ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo -e "\n${BOLD}You can now run '${BLUE}Acompil${NC}${BOLD}' from anywhere in the system${NC}\n\033[8mAfox out !\033[0m"
echo -e "\033[2mYou should start with Acompil -h\033[0m\n"

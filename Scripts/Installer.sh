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

# Print header
print_header

# Auto-elevate privileges
if ! is_sudo; then
    print_warning "This installation requires administrator privileges."
    print_warning "You will be prompted for your password."
    exec sudo "$0" "$@"
    exit $?
fi

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
echo -e "\n${BOLD}You can now run '${BLUE}Acompil${NC}${BOLD}' from anywhere in the system${NC}\n \n\033[8mAfox out !\033[0m"

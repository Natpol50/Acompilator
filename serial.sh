#!/bin/bash

# Set the serial port
PORT="/dev/ttyACM0"

# Set the baud rate (change this to match your Arduino's baud rate)
BAUD_RATE=9600

# Check if the port exists
if [ ! -e "$PORT" ]; then
    echo "Error: $PORT does not exist. Make sure your Arduino is connected."
    exit 1
fi

# Check if the user has permission to access the port
if [ ! -r "$PORT" ] || [ ! -w "$PORT" ]; then
    echo "Error: You don't have permission to access $PORT."
    echo "Try running the script with sudo, or add your user to the dialout group:"
    echo "sudo usermod -a -G dialout $USER"
    exit 1
fi

# Check if screen is installed
if ! command -v screen &> /dev/null; then
    echo "Error: 'screen' is not installed. Please install it first."
    echo "On Ubuntu/Debian: sudo apt-get install screen"
    echo "On macOS with Homebrew: brew install screen"
    exit 1
fi

echo "Starting to read from $PORT at $BAUD_RATE baud. Press Ctrl-A + D to detach, or Ctrl-C to exit."

# Configure the terminal settings
stty -F $PORT $BAUD_RATE cs8 -cstopb -parenb

# Start screen session to read from the serial port
screen $PORT $BAUD_RATE
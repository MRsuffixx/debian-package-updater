#!/bin/bash

# Check if script is running with root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "This script requires root privileges to run."
    echo "Please enter your root password:"
    exec sudo "$0" "$@"
    exit 1
fi

# Check if running on Debian 11 or 12
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [ "$ID" != "debian" ]; then
        echo "This script only works on Debian systems."
        exit 1
    fi
    
    if [ "$VERSION_ID" != "11" ] && [ "$VERSION_ID" != "12" ]; then
        echo "This script only works on Debian 11 or Debian 12."
        exit 1
    fi
    
    DEBIAN_VERSION="$VERSION_ID"
else
    echo "Cannot determine OS version."
    exit 1
fi

# Check and modify /etc/resolv.conf
echo "Checking DNS configuration..."
ORIGINAL_NAMESERVER=$(grep -m 1 "nameserver" /etc/resolv.conf | awk '{print $2}')

if [ "$ORIGINAL_NAMESERVER" != "1.1.1.1" ]; then
    echo "Current nameserver is: $ORIGINAL_NAMESERVER"
    echo "Temporarily changing to 1.1.1.1..."
    
    # Create a backup of the original file
    cp /etc/resolv.conf /etc/resolv.conf.backup
    
    # Replace the nameserver with 1.1.1.1
    sed -i 's/nameserver '"$ORIGINAL_NAMESERVER"'/nameserver 1.1.1.1/' /etc/resolv.conf
else
    echo "Nameserver is already set to 1.1.1.1"
    ORIGINAL_NAMESERVER=""
fi

# Update sources.list based on Debian version
echo "Updating sources.list for Debian $DEBIAN_VERSION..."

if [ "$DEBIAN_VERSION" = "12" ]; then
    echo "Getting sources list for Debian 12..."
    SOURCES_URL="https://gist.githubusercontent.com/ishad0w/e1ba0843edc9eb3084a1a0750861d073/raw/8148f9eac76d380f4340242e5a835dc1b9e4d2e7/sources_full.list"
elif [ "$DEBIAN_VERSION" = "11" ]; then
    echo "Getting sources list for Debian 11..."
    SOURCES_URL="https://gist.githubusercontent.com/ishad0w/7665cde882aa7dc3eec99613802e61e4/raw/1b250a3fea94f8337b73f70be6694daa9f0ac8d3/sources.list"
fi

# Backup original sources.list
cp /etc/apt/sources.list /etc/apt/sources.list.backup

# Download and replace the sources.list
if command -v curl &> /dev/null; then
    curl -s "$SOURCES_URL" > /etc/apt/sources.list
elif command -v wget &> /dev/null; then
    wget -q -O /etc/apt/sources.list "$SOURCES_URL"
else
    echo "Error: Neither curl nor wget is installed. Cannot download sources list."
    
    # Restore original DNS if it was changed
    if [ -n "$ORIGINAL_NAMESERVER" ]; then
        echo "Restoring original nameserver: $ORIGINAL_NAMESERVER"
        sed -i 's/nameserver 1.1.1.1/nameserver '"$ORIGINAL_NAMESERVER"'/' /etc/resolv.conf
    fi
    
    exit 1
fi

# Run update and upgrade
echo "Running apt update and upgrade..."
apt update && apt upgrade -y

# Restore original nameserver if it was changed
if [ -n "$ORIGINAL_NAMESERVER" ]; then
    echo "Restoring original nameserver: $ORIGINAL_NAMESERVER"
    sed -i 's/nameserver 1.1.1.1/nameserver '"$ORIGINAL_NAMESERVER"'/' /etc/resolv.conf
fi

echo "All operations completed successfully!"

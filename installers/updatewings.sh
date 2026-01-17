#!/usr/bin/env bash

########################################################################
#                                                                      #
#            Pterodactyl Installer, Updater, Remover and More          #
#            Copyright 2026, Malthe K, <me@malthe.cc>                  # 
#  https://github.com/guldkage/Pterodactyl-Installer/blob/main/LICENSE #
#                                                                      #
#  This script is not associated with the official Pterodactyl Panel.  #
#  You may not remove this line                                        #
#                                                                      #
########################################################################

function trap_ctrlc ()
{
    echo ""
    echo "Bye!"
    exit 2
}
trap "trap_ctrlc" 2

if [[ $EUID -ne 0 ]]; then
    echo "[!] Sorry, but you need to be root to run this script."
    exit 1
fi

for tool in curl uname chmod systemctl; do
    if ! [ -x "$(command -v $tool)" ]; then
        echo "[!] $tool is required but not installed. Aborting."
        exit 1
    fi
done

if [ ! -f "/usr/local/bin/wings" ]; then
    echo "[✖] Wings binary not found at /usr/local/bin/wings."
    echo "[!] It looks like Wings is not installed on this server. Aborting update."
    exit 1
fi

ARCH=$([[ "$(uname -m)" == "x86_64" ]] && echo "amd64" || echo "arm64")

echo "[!] Stopping Wings..."
systemctl stop wings || echo "[!] Warning: Wings was not running or could not be stopped."

echo "[!] Downloading latest Wings binary ($ARCH)..."
if ! curl -L -o /usr/local/bin/wings_new "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_$ARCH"; then
    echo "[!] Failed to download Wings. Starting old version again..."
    systemctl start wings
    exit 1
fi

echo "[!] Updating binary and setting permissions..."
mv /usr/local/bin/wings_new /usr/local/bin/wings || { echo "[✖] Failed to replace wings binary"; exit 1; }
chmod u+x /usr/local/bin/wings || { echo "[✖] Failed to set execute permissions"; exit 1; }

echo "[!] Restarting Wings..."
if ! systemctl restart wings; then
    echo "[!] Wings failed to start. Check logs with: journalctl -u wings"
    exit 1
fi

echo "[✔] Update completed successfully!"

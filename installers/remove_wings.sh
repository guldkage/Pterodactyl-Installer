#!/bin/bash
#!/usr/bin/env bash

########################################################################
#                                                                      #
#            Pterodactyl Installer, Updater, Remover and More          #
#            Copyright 2025, Malthe K, <me@malthe.cc> hej              # 
#  https://github.com/guldkage/Pterodactyl-Installer/blob/main/LICENSE #
#                                                                      #
#  This script is not associated with the official Pterodactyl Panel.  #
#  You may not remove this line                                        #
#                                                                      #
########################################################################

### VARIABLES ###

dist="$(. /etc/os-release && echo "$ID")"
version="$(. /etc/os-release && echo "$VERSION_ID")"
USERPASSWORD=""
WINGSNOQUESTIONS=false

### OUTPUTS ###

function trap_ctrlc ()
{
    echo ""
    echo "Bye!"
    exit 2
}
trap "trap_ctrlc" 2

warning(){
    echo -e '\e[31m'"$1"'\e[0m';

}

### CHECKS ###

if [[ $EUID -ne 0 ]]; then
    echo ""
    echo "[!] Sorry, but you need to be root to run this script."
    echo "Most of the time this can be done by typing sudo su in your terminal"
    exit 1
fi

if ! [ -x "$(command -v curl)" ]; then
    echo ""
    echo "[!] cURL is required to run this script."
    echo "To proceed, please install cURL on your machine."
    echo ""
    echo "apt install curl"
    exit 1
fi

if ! [ -x "$(command -v dig)" ]; then
    echo ""
    echo "[!] dig is required to run this script."
    echo "To proceed, please install dnsutils on your machine."
    echo ""
    echo "apt install dnsutils"
    exit 1
fi

### Pterodactyl Wings Removal ####

wings_remove(){
    echo ""
    echo "[!] Are you sure you want to remove Wings? If you have any servers on this machine, they will also get removed. (Y/N)"
    read -r UNINSTALLWINGS

    if [[ "$UNINSTALLWINGS" =~ [Yy] ]]; then
         systemctl stop wings # Stops wings
         rm -rf /var/lib/pterodactyl # Removes game servers and backup files
         rm -rf /etc/pterodactyl  || exit || warning "Pterodactyl Wings not installed!"
         rm /usr/local/bin/wings || exit || warning "Wings is not installed!" # Removes wings
         rm /etc/systemd/system/wings.service # Removes wings service file
        echo ""
        echo "[!] Pterodactyl Wings has been uninstalled."
        echo ""
    fi
}

wings_remove
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

### Removal of Panel ###

uninstallpanel(){
    echo ""
    echo "[!] Do you really want to delete Pterodactyl Panel? All files & configurations will be deleted. (Y/N)"
    read -r UNINSTALLPANEL

    if [[ "$UNINSTALLPANEL" =~ ^[Yy]$ ]]; then
        uninstallpanel_backup
    elif [[ "$UNINSTALLPANEL" =~ ^[Nn]$ ]]; then
        echo "[!] Removal aborted."
    else
        echo "[!] Invalid input. Please enter 'Y' or 'N'."
        uninstallpanel
    fi
}

uninstallpanel_backup(){
    echo ""
    echo "[!] Do you want to keep your database and backup your .env file? (Y/N)"
    read -r UNINSTALLPANEL_CHANGE

    case "$UNINSTALLPANEL_CHANGE" in
        [Yy]) 
            BACKUPPANEL=true
            uninstallpanel_confirm
            ;;
        [Nn])
            BACKUPPANEL=false
            uninstallpanel_confirm
            ;;
        *)
            echo "[!] Invalid input. Please enter 'Y' or 'N'."
            uninstallpanel_backup
            ;;
    esac
}

uninstallpanel_confirm(){
    if [ "$BACKUPPANEL" = "true" ]; then
        # Backup .env file before removing panel files
        mv /var/www/pterodactyl/.env .

        # Remove panel files, checking if they exist
        if [ -d "/var/www/pterodactyl" ]; then
            rm -rf /var/www/pterodactyl || { echo "Error: Failed to remove panel files."; exit 1; }
        else
            echo "Panel files not found, skipping removal."
        fi

        # Remove service and config files if they exist
        [ -f "/etc/systemd/system/pteroq.service" ] && rm /etc/systemd/system/pteroq.service
        [ -f "/etc/nginx/sites-enabled/pterodactyl.conf" ] && unlink /etc/nginx/sites-enabled/pterodactyl.conf
        [ -f "/etc/apache2/sites-enabled/pterodactyl.conf" ] && unlink /etc/apache2/sites-enabled/pterodactyl.conf

        # Restart services
        systemctl restart nginx

        # Confirmation
        clear
        echo ""
        echo "[!] Pterodactyl Panel has been uninstalled."
        echo "    Your Panel database has not been deleted."
        echo "    Your .env file is in your current directory."
        echo ""
    fi

    if [ "$BACKUPPANEL" = "false" ]; then
        # Remove panel files, checking if they exist
        if [ -d "/var/www/pterodactyl" ]; then
            rm -rf /var/www/pterodactyl || { echo "Error: Failed to remove panel files."; exit 1; }
        else
            echo "Panel files not found, skipping removal."
        fi

        # Remove service and config files if they exist
        [ -f "/etc/systemd/system/pteroq.service" ] && rm /etc/systemd/system/pteroq.service
        [ -f "/etc/nginx/sites-enabled/pterodactyl.conf" ] && unlink /etc/nginx/sites-enabled/pterodactyl.conf
        [ -f "/etc/apache2/sites-enabled/pterodactyl.conf" ] && unlink /etc/apache2/sites-enabled/pterodactyl.conf

        DB_NAME="panel"
        USERS=("pterodactyl" "pterodactyluser")

        # Drop database
        mariadb -u root -e "DROP DATABASE IF EXISTS \`${DB_NAME}\`;" || { echo "Could not delete database '${DB_NAME}'."; exit 1; }

        # Drop users
        for user in "${USERS[@]}"; do
            mariadb -u root -e "DROP USER IF EXISTS '${user}'@'127.0.0.1';" || { echo "Could not delete user '${user}'."; exit 1; }
        done
        # Restart services
        systemctl restart nginx

        # Confirmation
        clear
        echo ""
        echo "[!] Pterodactyl Panel has been uninstalled."
        echo "    Files, services, configs, and your database have been deleted."
        echo ""
    fi
}

uninstallpanel
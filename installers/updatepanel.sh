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

for tool in curl dig tar composer php; do
    if ! [ -x "$(command -v $tool)" ]; then
        echo "[!] $tool is required but not installed. Aborting."
        exit 1
    fi
done

if [ ! -d "/var/www/pterodactyl" ]; then
    echo "[✖] Directory /var/www/pterodactyl does not exist."
    exit 1
fi
cd /var/www/pterodactyl

if [ ! -d "/var/www/pterodactyl" ] || [ ! -f "/var/www/pterodactyl/artisan" ]; then
    echo "[!] Pterodactyl Panel not found in /var/www/pterodactyl."
    exit 1
fi

echo "[!] Checking for updates..."
CURRENT_VERSION=$(php artisan p:info 2>/dev/null | grep "Panel Version" | awk '{print $NF}')
LATEST_VERSION=$(curl -s https://api.github.com/repos/pterodactyl/panel/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

if [ -z "$LATEST_VERSION" ]; then
    echo "[!] Could not fetch latest version from GitHub. Skipping update check..."
elif [ -z "$CURRENT_VERSION" ]; then
    echo "[!] Could not detect local version. Proceeding with update to be safe..."
else
    echo "[!] Current Version: $CURRENT_VERSION"
    echo "[!] Latest Version: $LATEST_VERSION"

    if [ "$CURRENT_VERSION" == "$LATEST_VERSION" ]; then
        echo "[✔] Your panel is already up to date ($CURRENT_VERSION). Nothing to do."
        exit 0
    fi
fi

echo "[!] Update found! Starting update to $LATEST_VERSION..."
if [ -f ".env" ]; then
    echo "[!] Existing .env found. Creating backup in /tmp/.env"
    cp .env /tmp/.env || { echo "[✖] Failed to create backup of .env"; exit 1; }
else
    echo "[!] Warning: No .env file found in /var/www/pterodactyl/"
fi

echo "[!] Putting panel into maintenance mode..."
php artisan down || echo "[!] Warning: Could not set maintenance mode."

echo "[!] Downloading and extracting latest release..."
if ! curl -L https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz | tar -xzv; then
    php artisan up
    echo "[!] Failed to download or extract files."
    exit 1
fi

echo "[!] Setting permissions..."
chmod -R 755 storage/* bootstrap/cache || { echo "[✖] Failed to set permissions"; exit 1; }

echo "[!] Installing composer dependencies..."
export COMPOSER_ALLOW_SUPERUSER=1
if ! composer install --no-dev --optimize-autoloader --no-interaction; then
    echo "[!] Composer installation failed."
    exit 1
fi

echo "[!] Clearing cache and migrating database..."
php artisan view:clear
php artisan config:clear
if ! php artisan migrate --seed --force; then
    echo "[✖] Database migration failed."
    exit 1
fi

echo "[!] Finalizing permissions and restarting queue..."
chown -R www-data:www-data /var/www/pterodactyl/* || echo "[!] Warning: Could not change ownership."
php artisan queue:restart
php artisan up

if [ ! -f "/var/www/pterodactyl/.env" ]; then
    if [ -f "/tmp/.env" ]; then
        echo "[!] .env missing after update! Restoring from backup..."
        cp /tmp/.env /var/www/pterodactyl/.env
        
        if [ -f "/var/www/pterodactyl/.env" ]; then
            echo "[!] .env restored successfully. Removing temporary backup."
            rm /tmp/.env
        else
            echo "[!] Failed to restore .env"
        fi
    fi
else
    echo "[!] Removing temporary backup."
    [ -f "/tmp/.env" ] && rm /tmp/.env
fi

echo "[✔] Update completed successfully!"

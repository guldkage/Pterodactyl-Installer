#!/usr/bin/env bash

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root."
   exit 1
fi

# Variables from arguments
FQDN="$1"
SSLSTATUS="$2"
EMAIL="$3"
USERNAME="$4"
FIRSTNAME="$5"
LASTNAME="$6"
PASSWORD="$7"
WINGS="$8"
WEBSERVER="NGINX"

dist="$(. /etc/os-release && echo "$ID")"
version="$(. /etc/os-release && echo "$VERSION_ID")"

# --- HELPERS ---

retry() {
    local n=1; local max=3; local delay=5
    while true; do
        "$@" && break || {
            if [[ $n -lt $max ]]; then
                ((n++))
                echo "[!] Command failed. Retrying in $delay seconds ($n/$max)..."
                sleep $delay
            else
                echo "[X] Command '$*' failed after $max attempts."
                return 1
            fi
        }
    done
}

ensure_service() {
    local service=$1
    systemctl daemon-reload
    systemctl enable "$service" >/dev/null 2>&1
    systemctl restart "$service"
    sleep 2
    if ! systemctl is-active --quiet "$service"; then
        return 1
    fi
}

panel_install() {
    echo -e "\nStarting Pterodactyl Panel Installation...\n"

    if ! ping -c 1 -W 5 google.com > /dev/null 2>&1; then
        if ! ping -c 1 -W 5 8.8.8.8 > /dev/null 2>&1; then
            echo "[✖] No internet access detected."; exit 1
        fi
        echo "[✖] DNS broken. Check /etc/resolv.conf"; exit 1
    fi

    echo "Updating package lists..."
    if ! apt update -y; then
        rm -f /var/lib/apt/lists/lock /var/lib/dpkg/lock*
        apt update -y || { echo "[✖] Apt update failed twice."; exit 1; }
    fi

    base_packages=(wget ca-certificates apt-transport-https gnupg curl lsb-release cron)
    [[ "$version" != "13" ]] && base_packages+=(software-properties-common)
    apt install -y "${base_packages[@]}"

    case "$dist" in
        "ubuntu")
            LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
            ;;
        "debian")
            echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list
            curl -fsSL https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/sury-keyring.gpg
            ;;
    esac

    DISTRO_CODENAME=$(lsb_release -cs)
    [[ "$DISTRO_CODENAME" == "trixie" ]] && DISTRO_CODENAME="bookworm"
    curl -fsSL https://packages.redis.io/gpg | gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $DISTRO_CODENAME main" | tee /etc/apt/sources.list.d/redis.list

    apt update -y
    packages=(
        mariadb-server tar unzip git redis-server certbot nginx
        php8.3 php8.3-{cli,gd,mysql,pdo,mbstring,tokenizer,bcmath,xml,fpm,curl,zip}
    )
    apt install -y "${packages[@]}"

    if [ -f "/etc/mysql/mariadb.conf.d/50-server.cnf" ]; then
        sed -i 's/character-set-collations = utf8mb4=uca1400_ai_ci/character-set-collations = utf8mb4=utf8mb4_general_ci/' /etc/mysql/mariadb.conf.d/50-server.cnf
        systemctl restart mariadb
    fi

    mkdir -p /var/www/pterodactyl && cd /var/www/pterodactyl
    retry curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
    tar -xzvf panel.tar.gz
    chmod -R 755 storage/* bootstrap/cache/
    [ ! -f .env ] && cp .env.example .env
    
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
    COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader --no-interaction
    php artisan key:generate --force
    
    DBPASSWORD=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 16 | head -n 1)
    mariadb -u root -e "CREATE DATABASE IF NOT EXISTS panel;"
    mariadb -u root -e "GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '$DBPASSWORD';"
    
    [ "$SSLSTATUS" == "true" ] && appurl="https://$FQDN" || appurl="http://$FQDN"
    
    php artisan p:environment:setup --author="$EMAIL" --url="$appurl" --timezone="CET" --telemetry=false --cache="redis" --session="redis" --queue="redis" --redis-host="localhost" --redis-pass="null" --redis-port="6379" --settings-ui=true
    php artisan p:environment:database --host="127.0.0.1" --port="3306" --database="panel" --username="pterodactyl" --password="$DBPASSWORD"
    php artisan migrate --seed --force --no-interaction
    php artisan p:user:make --email="$EMAIL" --username="$USERNAME" --name-first="$FIRSTNAME" --name-last="$LASTNAME" --password="$PASSWORD" --admin=1 --no-interaction

    if [ "$WINGS" == "true" ]; then
        echo "Installing Wings..."
        retry curl -sSL https://get.docker.com/ | CHANNEL=stable bash
        ensure_service docker
        mkdir -p /etc/pterodactyl
        arch=$([[ "$(uname -m)" == "x86_64" ]] && echo "amd64" || echo "arm64")
        retry curl -L -o /usr/local/bin/wings "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_$arch"
        chmod u+x /usr/local/bin/wings
        curl -o /etc/systemd/system/wings.service https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/wings.service
        systemctl enable --now wings
    fi

    chown -R www-data:www-data /var/www/pterodactyl/*
    curl -o /etc/systemd/system/pteroq.service https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/pteroq.service
    (crontab -l 2>/dev/null; echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1") | crontab -
    ensure_service redis-server
    ensure_service pteroq.service

    configure_webserver
}

configure_webserver() {
    rm -f /etc/nginx/sites-enabled/default
    curl -fsSL -o /etc/nginx/sites-enabled/pterodactyl.conf https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/refs/heads/main/configs/pterodactyl-nginx.conf
    sed -i "s@<domain>@${FQDN}@g" /etc/nginx/sites-enabled/pterodactyl.conf
    systemctl reload nginx

    FAIL=false
    if [ "$SSLSTATUS" == "true" ]; then
        attempt=1
        while [ $attempt -le 2 ]; do
            apt install -y python3-certbot-nginx
            if certbot --nginx --redirect --no-eff-email --email "$EMAIL" -d "$FQDN" --agree-tos; then
                FAIL=false; break
            else
                FAIL=true; ((attempt++))
            fi
        done

        if [ "$FAIL" == "false" ]; then
            curl -o /etc/nginx/sites-enabled/pterodactyl.conf https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/pterodactyl-nginx-ssl.conf
            [[ $(lsb_release -cs) == "trixie" ]] && sed -i '1d' /etc/nginx/sites-enabled/pterodactyl.conf
            sed -i "s@<domain>@${FQDN}@g" /etc/nginx/sites-enabled/pterodactyl.conf
        else
            SSLSTATUS="false"
        fi
    fi

    if [ "$SSLSTATUS" == "false" ]; then
        echo "SESSION_SECURE_COOKIE=false" >> /var/www/pterodactyl/.env
    fi

    if grep -q "server_tokens off" /etc/nginx/nginx.conf; then
        sed -i '/server_tokens off;/d' /etc/nginx/sites-enabled/pterodactyl.conf
    fi

    cd /var/www/pterodactyl && php artisan config:clear
    systemctl restart nginx
    echo "Panel installed"
}

if [ -z "$FQDN" ] || [ -z "$PASSWORD" ]; then
    echo "Usage: ./script.sh <FQDN> <SSL true/false> <EMAIL> <USER> <FIRST> <LAST> <PASS> <WINGS true/false>"
    exit 1
fi

panel_install

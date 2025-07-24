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

set -euo pipefail

### VARIABLES ###

dist="$(. /etc/os-release && echo "$ID")"
version="$(. /etc/os-release && echo "$VERSION_ID")"
USERPASSWORD=""
WINGSNOQUESTIONS=false
INSTALLBOTH=${INSTALLBOTH:-false}

for var in FQDN WEBSERVER EMAIL SSLSTATUS CUSTOMSSL USERNAME FIRSTNAME LASTNAME; do
    declare "$var=Not set.."
done

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

if [ -d "/var/www/pterodactyl" ]; then
    echo ""
    echo "[!] WARNING: Pterodactyl is already installed!"
    echo ""
    echo "Choose one of the following options:"
    echo "  1) Uninstall Pterodactyl automatically (deletes everything related to the panel)"
    echo "  2) Continue anyway (may cause errors!)"
    echo "  3) Cancel installation"
    echo ""

    while true; do
        read -rp "Enter your choice (1/2/3): " CHOICE
        case "$CHOICE" in
            1)
                echo "[!] Running automatic uninstallation..."
                if [ -d "/var/www/pterodactyl" ]; then
                    rm -rf /var/www/pterodactyl || { echo "Error: Failed to remove panel files."; exit 1; }
                else
                    echo "Panel files not found, skipping removal."
                fi
        
                [ -f "/etc/systemd/system/pteroq.service" ] && rm /etc/systemd/system/pteroq.service
                [ -f "/root/panel_credentials.txt" ] && rm /root/panel_credentials.txt
                [ -f "/etc/nginx/sites-enabled/pterodactyl.conf" ] && unlink /etc/nginx/sites-enabled/pterodactyl.conf
                [ -f "/etc/apache2/sites-enabled/pterodactyl.conf" ] && unlink /etc/apache2/sites-enabled/pterodactyl.conf
        
                DB_NAME="panel"
                USERS=("pterodactyl" "pterodactyluser")
        
                mariadb -u root -e "DROP DATABASE IF EXISTS \`${DB_NAME}\`;" || { echo "Could not delete database '${DB_NAME}'."; exit 1; }
        
                for user in "${USERS[@]}"; do
                    mariadb -u root -e "DROP USER IF EXISTS '${user}'@'127.0.0.1';" || { echo "Could not delete user '${user}'."; exit 1; }
                done
                break
                ;;
            2)
                echo "[!] Continuing anyway"
                break
                ;;
            3)
                echo "[!] Install cancelled"
                exit 1
                ;;
            *)
                echo "[!] Invalid selection. Please select 1, 2, or 3."
                ;;
        esac
    done
fi

### Pterodactyl Panel Installation ###

send_summary() {
    clear
    clear
    if [ -d "/var/www/pterodactyl" ]; then
        warning "[!] WARNING: Pterodactyl is already installed. This script have a high chance of failing."
    fi
    echo ""
    echo "[!] Summary:"
    echo "    Panel URL: $FQDN"
    echo "    Webserver: $WEBSERVER"
    echo "    Email: $EMAIL"
    echo "    SSL: $SSLSTATUS"
    echo "    Custom SSL: $CUSTOMSSL"
    echo "    Username: $USERNAME"
    echo "    First name: $FIRSTNAME"
    echo "    Last name: $LASTNAME"
    if [ -n "$USERPASSWORD" ]; then
    echo "    Password: $(printf "%0.s*" $(seq 1 ${#USERPASSWORD}))"
    else
        echo "    Password: Not set.."
    fi
    echo ""
}

panel(){
    echo ""
    echo "[!] Before installation, we need some information."
    echo ""
    panel_webserver
}

finish(){
    clear

    echo "[!] Installation of Pterodactyl Panel done"
    echo ""
    echo "    Summary of the installation" 
    echo "    Panel URL: $appurl"
    echo "    Webserver: $WEBSERVER"
    echo "    Email: $EMAIL"
    echo "    SSL: $SSLSTATUS"
    echo "    Username: $USERNAME"
    echo "    First name: $FIRSTNAME"
    echo "    Last name: $LASTNAME"
    echo "    Password: $(printf "%0.s*" $(seq 1 ${#USERPASSWORD}))"
    echo "" 
    echo "    Database password: $DBPASSWORD"
    echo "    Password for Database Host: $DBPASSWORDHOST"
    echo "" 
    echo "    These credentials have been saved in panel_credentials.txt in your root directory"
    echo "    As this file contains passwords, you should delete it when it is not needed anymore." 
    echo ""
    echo "    Please backup your APP_KEY below, as you might need it in the future."
    grep APP_KEY /var/www/pterodactyl/.env
    echo ""

    echo "[!] Checking if the panel is accessible..."
    HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}" "$appurl")

    if [ "$HTTP_STATUS" == "502" ]; then
        echo "[!] Bad Gateway detected! Restarting php8.3-fpm..."
        systemctl restart php8.3-fpm
        sleep 5
        HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}" "$appurl")
    fi

    if [[ "$HTTP_STATUS" != "200" ]]; then
        echo "[!] Panel is still not accessible. Restarting webserver..."
        if [[ "$WEBSERVER" == "NGINX" ]]; then
            systemctl restart nginx
        elif [[ "$WEBSERVER" == "Apache" ]]; then
            systemctl restart apache2
        fi
        sleep 5
        HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}" "$appurl")
    fi

    if [[ "$HTTP_STATUS" == "200" ]]; then
        echo "[✔] Panel is accessible!"
    else
        echo "[✖] Panel is still not accessible. Please check logs"
        if [[ "$WEBSERVER" == "NGINX" ]]; then
            journalctl -u nginx --no-pager | tail -n 10
        elif [[ "$WEBSERVER" == "Apache" ]]; then
            journalctl -u apache2 --no-pager | tail -n 10
        fi
        exit 1
    fi

    read -r -p "    Would you like to install Wings too? (Y/N): " WINGS_ON_PANEL
    
    case "${WINGS_ON_PANEL,,}" in
        y|yes)
            if ! command -v docker &> /dev/null; then
                curl -sSL https://get.docker.com/ | CHANNEL=stable bash
                 systemctl enable --now docker
            else
                echo "Docker is already installed"
            fi
    
            if ! mkdir -p /etc/pterodactyl; then
                echo "Could not create directory." >&2
                exit 1
            fi
    
            curl -L -o /usr/local/bin/wings "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_$([[ "$(uname -m)" == "x86_64" ]] && echo "amd64" || echo "arm64")"
            curl -o /etc/systemd/system/wings.service https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/wings.service
            chmod u+x /usr/local/bin/wings
            echo ""
            echo "[!] Pterodactyl Wings successfully installed."
            echo "    As you have installed Panel & Wings at once, you can use your Panel URL ($appurl) as FQDN, which is $FQDN"
            echo "    You can see a guide here to learn how to setup a node on your Pterodactyl Panel: https://docs.malthe.cc"
            echo ""
            ;;
        n|no)
            echo "Bye!"
            exit 0
            ;;
        *)
            echo "Invalid input. Please enter Y or N."
            exit 1
            ;;
    esac
}

panel_webserver(){
    send_summary
    echo "[!] Select Webserver"
    echo "    (1) NGINX (recommended)"
    echo "    (2) Apache"
    echo "    Input 1-2"
    read -r option
    case $option in
        1 ) option=1
            WEBSERVER="NGINX"
            panel_fqdn
            ;;
        2 ) option=2
            WEBSERVER="Apache"
            panel_fqdn
            ;;
        * ) echo ""
            echo "Please enter a valid option from 1-2"
            panel_webserver
    esac
}

panel_conf() {
    set -e
    appurl=$([ "$SSLSTATUS" == true ] && echo "https://$FQDN" || echo "http://$FQDN")

    if [ -f "/root/panel_credentials.txt" ]; then
        echo "Found existing panel_credentials.txt, importing DB passwords..."

        DBPASSWORD=$(grep -i "Database password:" /root/panel_credentials.txt | awk -F': ' '{print $2}')
        DBPASSWORDHOST=$(grep -i "Password for Database Host:" /root/panel_credentials.txt | awk -F': ' '{print $2}')

        echo "Imported DBPASSWORD and DBPASSWORDHOST"
    else
        echo "Nothing to import"    
        DBPASSWORD=$(head -c 64 /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 16)
        DBPASSWORDHOST=$(head -c 64 /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 16)
        mariadb -u root -e "
            CREATE USER 'pterodactyluser'@'127.0.0.1' IDENTIFIED BY '$DBPASSWORDHOST';
            GRANT ALL PRIVILEGES ON *.* TO 'pterodactyluser'@'127.0.0.1' WITH GRANT OPTION;
            CREATE USER 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '$DBPASSWORD';
            CREATE DATABASE panel;
            GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'127.0.0.1' WITH GRANT OPTION;
            FLUSH PRIVILEGES;
        "
    fi

    echo -e "Summary of the installation\n\nPanel URL: $FQDN\nWebserver: $WEBSERVER\nUsername: $USERNAME\nEmail: $EMAIL\nFirst name: $FIRSTNAME\nLast name: $LASTNAME\nPassword: $(printf "%0.s*" $(seq 1 ${#USERPASSWORD}))\nDatabase password: $DBPASSWORD\nPassword for Database Host: $DBPASSWORDHOST" >> /root/panel_credentials.txt
    chmod 600 /root/panel_credentials.txt

    php artisan p:environment:setup --author="$EMAIL" --url="$appurl" --timezone="CET" --telemetry=$TELEMETRY --cache="redis" --session="redis" --queue="redis" --redis-host="localhost" --redis-pass="null" --redis-port="6379" --settings-ui=true
    php artisan p:environment:database --host="127.0.0.1" --port="3306" --database="panel" --username="pterodactyl" --password="$DBPASSWORD"
    php artisan migrate --seed --force
    php artisan p:user:make --email="$EMAIL" --username="$USERNAME" --name-first="$FIRSTNAME" --name-last="$LASTNAME" --password="$USERPASSWORD" --admin=1

    chown -R www-data:www-data /var/www/pterodactyl/*

    curl -o /etc/systemd/system/pteroq.service https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/pteroq.service

    echo "Adding artisan schedule to crontab..."

    CRON_JOB="* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1"
    EXISTING_CRON=$(crontab -l 2>/dev/null || true)

    if ! echo "$EXISTING_CRON" | grep -qF "$CRON_JOB"; then
        (echo "$EXISTING_CRON"; echo "$CRON_JOB") | crontab -
        echo "Cronjob added"
    else
        echo "Cronjob already exists"
    fi

    systemctl enable --now redis-server
    systemctl enable --now pteroq.service

    if [ "$WEBSERVER" == "NGINX" ]; then
        if [ -f /etc/nginx/sites-enabled/default ]; then
            rm -f /etc/nginx/sites-enabled/default
        fi
        echo "Downloading dummy config"
        curl -fsSL -o /etc/nginx/sites-enabled/pterodactyl.conf \
            https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/refs/heads/main/configs/pterodactyl-nginx.conf \
            || { echo "Could not download dummy config."; exit 1; }

        sed -i "s@<domain>@${FQDN}@g" /etc/nginx/sites-enabled/pterodactyl.conf
        systemctl reload nginx || { echo "Could not download dummy config"; exit 1; }
    fi

    if [ "$CUSTOMSSL" == false ] && [ "$WEBSERVER" == "NGINX" ]; then
        warning "ACTION REQUIRED"
        echo "[!] How do you want to request the SSL certificate?"
        echo "    1) Webserver mode (recommended, requires ports 80/443 open)"
        echo "    2) DNS challenge (manual DNS setup required)"
        read -rp "[1/2]: " SSL_MODE

        if [[ "$SSL_MODE" != "2" ]]; then
            attempt=1
            max_attempts=2
            while [ $attempt -le $max_attempts ]; do
                echo "Attempt $attempt of $max_attempts to obtain Let's Encrypt certificate via webserver..."
                apt install -y python3-certbot-nginx
                certbot --nginx --redirect --no-eff-email --email "$EMAIL" -d "$FQDN" && FAIL=false || FAIL=true

                if [ ! -d "/etc/letsencrypt/live/$FQDN/" ] || [ "$FAIL" == true ]; then
                    echo "[!] Let's Encrypt certificate attempt $attempt failed."
                    if [ $attempt -lt $max_attempts ]; then
                        echo "Do you want to try again? (Y/N)"
                        read -r TRY_AGAIN
                        if [[ ! "$TRY_AGAIN" =~ ^[Yy]$ ]]; then
                            break
                        fi
                    fi
                else
                    FAIL=false
                    break
                fi
                ((attempt++))
            done

        else
            echo "[!] You selected DNS Challenge mode."
            apt install -y certbot
            echo "[!] When prompted, you will need to create TXT records in your DNS panel."
            echo "[!] Please create the records, wait at least 2-5 minutes then press enter."
            echo "[!] If you normally use CTRL+C to copy text in terminal, please use SHIFT+CTRL+C or else you will stop the script."
            certbot certonly --manual --preferred-challenges dns --email "$EMAIL" -d "$FQDN" && FAIL=false || FAIL=true
        fi

        if [ "$FAIL" == true ]; then
            echo "[!] Let's Encrypt certificate failed after $max_attempts attempts."
            echo "Do you want to continue without SSL? (Y/N)"
            read -r CONTINUE_NO_SSL

            if [[ "$CONTINUE_NO_SSL" =~ ^[Yy]$ ]]; then
                echo "Setting up NGINX without SSL..."
                SSLSTATUS=false
                [ -f /etc/nginx/sites-enabled/default ] && rm -f /etc/nginx/sites-enabled/default
                rm -f /etc/nginx/sites-enabled/pterodactyl.conf

                curl -o /etc/nginx/sites-enabled/pterodactyl.conf https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/pterodactyl-nginx.conf
                sed -i -e "s@<domain>@${FQDN}@g" /etc/nginx/sites-enabled/pterodactyl.conf

                echo "SESSION_SECURE_COOKIE=false" >> /var/www/pterodactyl/.env
                systemctl restart nginx

                echo "Continuing installation without SSL..."
                FAIL=false
            else
                echo "[!] Installation aborted due to SSL failure."
                exit 1
            fi
        fi
    fi

    if [ "$SSLSTATUS" == "true" ]; then
        if [ "$WEBSERVER" == "NGINX" ]; then
            if [ -f /etc/nginx/sites-enabled/pterodactyl.conf ]; then
                rm -f /etc/nginx/sites-enabled/pterodactyl.conf
            fi
            curl -o /etc/nginx/sites-enabled/pterodactyl.conf https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/pterodactyl-nginx-ssl.conf
            if [ "$CUSTOMSSL" == true ]; then
                sed -i -e "s@ssl_certificate /etc/letsencrypt/live/<domain>/fullchain.pem;@ssl_certificate ${CERTIFICATEPATH};@g" /etc/nginx/sites-enabled/pterodactyl.conf
                sed -i -e "s@ssl_certificate_key /etc/letsencrypt/live/<domain>/privkey.pem;@ssl_certificate_key ${PRIVATEKEYPATH};@g" /etc/nginx/sites-enabled/pterodactyl.conf
            fi
            sed -i -e "s@<domain>@${FQDN}@g" /etc/nginx/sites-enabled/pterodactyl.conf
            systemctl restart nginx
        elif [ "$WEBSERVER" == "Apache" ]; then
            systemctl stop apache2
            certbot certonly --standalone -d $FQDN --staple-ocsp --no-eff-email -m $EMAIL --agree-tos
            a2dissite 000-default.conf && systemctl reload apache2
            if [ -f /etc/apache2/sites-enabled/pterodactyl.conf ]; then
                rm -f /etc/apache2/sites-enabled/pterodactyl.conf
            fi
            curl -o /etc/apache2/sites-enabled/pterodactyl.conf https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/pterodactyl-apache-ssl.conf
            if [ "$CUSTOMSSL" == true ]; then
                sed -i -e "s@SSLCertificateFile /etc/letsencrypt/live/<domain>/fullchain.pem@SSLCertificateFile ${CERTIFICATEPATH}@g" /etc/nginx/sites-enabled/pterodactyl.conf
                sed -i -e "s@SSLCertificateKeyFile /etc/letsencrypt/live/<domain>/privkey.pem@SSLCertificateKeyFile ${PRIVATEKEYPATH}@g" /etc/nginx/sites-enabled/pterodactyl.conf
            fi
            sed -i -e "s@<domain>@${FQDN}@g" /etc/apache2/sites-enabled/pterodactyl.conf
            a2enmod rewrite ssl
            systemctl restart apache2
        fi
    else
        if [ "$WEBSERVER" == "NGINX" ]; then
            if [ -f /etc/nginx/sites-enabled/default ]; then
                rm -f /etc/nginx/sites-enabled/default
            fi
            if [ -f /etc/nginx/sites-enabled/pterodactyl.conf ]; then
                rm -f /etc/nginx/sites-enabled/pterodactyl.conf
            fi
            curl -o /etc/nginx/sites-enabled/pterodactyl.conf https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/pterodactyl-nginx.conf
            sed -i -e "s@<domain>@${FQDN}@g" /etc/nginx/sites-enabled/pterodactyl.conf
            systemctl restart nginx
        elif [ "$WEBSERVER" == "Apache" ]; then
            a2dissite 000-default.conf && systemctl reload apache2
            if [ -f /etc/apache2/sites-enabled/pterodactyl.conf ]; then
                rm -f /etc/apache2/sites-enabled/pterodactyl.conf
            fi
            curl -o /etc/apache2/sites-enabled/pterodactyl.conf https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/pterodactyl-apache.conf
            sed -i -e "s@<domain>@${FQDN}@g" /etc/apache2/sites-enabled/pterodactyl.conf
            a2enmod rewrite
            systemctl stop apache2 && systemctl start apache2
        fi
    fi

    finish
}

panel_install() {
    set -euo pipefail
    echo -e "\nStarting Pterodactyl Panel Installation...\n"

    echo "Updating package lists..."
    apt update -y

    echo "Installing required base packages..."

    base_packages=(
        wget
        software-properties-common
        ca-certificates
        apt-transport-https
        gnupg
        curl
        lsb-release
    )

    to_install=()
    for pkg in "${base_packages[@]}"; do
        if ! dpkg -s "$pkg" &> /dev/null; then
            to_install+=("$pkg")
        fi
    done

    if [ ${#to_install[@]} -gt 0 ]; then
        echo "Installing missing packages: ${to_install[*]}"
        apt update
        apt install -y "${to_install[@]}"
    else
        echo "All base packages already installed, skipping installation."
    fi

    case "$dist" in
        "ubuntu")
            echo "Setting up for Ubuntu $version..."
            if ! grep -q "^deb .\+ondrej/php" /etc/apt/sources.list /etc/apt/sources.list.d/*.list 2>/dev/null; then
                echo "Setting up PHP for Ubuntu"
                LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
            else
                echo "PHP repository already exists, skipping."
            fi
            ;;

        "debian")
            echo "Setting up for Debian $version..."

            case "$version" in
                "11"|"12")
                    if [[ ! -f /etc/apt/sources.list.d/php.list || ! -f /etc/apt/trusted.gpg.d/sury-keyring.gpg ]]; then
                        echo "Adding PHP repository for Debian $version..."
                        echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list
                        curl -fsSL https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/sury-keyring.gpg
                    else
                        echo "PHP repository and key already exist, skipping."
                    fi
                    ;;
                *)
                    echo "⚠ Unsupported Debian version: $version"
                    exit 1
                    ;;
            esac
            ;;

        *)
            echo "⚠ Unsupported distribution: $dist"
            exit 1
            ;;
    esac

    if [[ ! -f /usr/share/keyrings/redis-archive-keyring.gpg || ! -f /etc/apt/sources.list.d/redis.list ]]; then
        echo "Adding Redis repository..."
        curl -fsSL https://packages.redis.io/gpg | gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/redis.list
    else
        echo "Redis repository and key already exist, skipping."
    fi

    echo "Updating package lists again..."
    apt update -y

    echo "Installing required software..."

    packages=(
        mariadb-server tar unzip git redis-server certbot cron
        php8.3 php8.3-cli php8.3-gd php8.3-mysql php8.3-pdo php8.3-mbstring php8.3-tokenizer php8.3-bcmath php8.3-xml php8.3-fpm php8.3-curl php8.3-zip
    )

    to_install=()

    for pkg in "${packages[@]}"; do
        if ! dpkg -s "$pkg" &> /dev/null; then
            to_install+=("$pkg")
        fi
    done

    if [ ${#to_install[@]} -gt 0 ]; then
        echo "Installing missing packages: ${to_install[*]}"
        apt update
        apt install -y "${to_install[@]}"
    else
        echo "All packages already installed, skipping installation."
    fi

    if ! php -v &> /dev/null; then
        echo "[ERROR] PHP does not seem to be installed correctly."
        echo "Please investigate the installation issues and try again."
        exit 1
    else
        echo "PHP installation verified:"
        php -v
    fi

    echo "Configuring MariaDB..."
    if [ -f "/etc/mysql/mariadb.conf.d/50-server.cnf" ]; then
        sed -i 's/character-set-collations = utf8mb4=uca1400_ai_ci/character-set-collations = utf8mb4=utf8mb4_general_ci/' /etc/mysql/mariadb.conf.d/50-server.cnf
        systemctl restart mariadb
    else
        echo "⚠ MariaDB config file not found! Skipping modification..."
    fi

    echo "Installing Composer..."

    if command -v composer >/dev/null 2>&1; then
        echo "Composer is already installed, skipping installation."
    else
        curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
        if command -v composer >/dev/null 2>&1; then
            echo "Composer installed successfully."
        else
            echo "Failed to install Composer. Please check manually."
            exit 1
        fi
    fi

    echo "Creating Pterodactyl directory..."

    if [ ! -d "/var/www/pterodactyl" ]; then
        mkdir -p /var/www/pterodactyl
        echo "Directory /var/www/pterodactyl created."
    else
        echo "Directory /var/www/pterodactyl already exists, skipping creation."
    fi

    cd /var/www/pterodactyl

    echo "Downloading Pterodactyl Panel..."
    curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
    tar -xzvf panel.tar.gz

    echo "Setting permissions..."
    chmod -R 755 storage/* bootstrap/cache/
    cp .env.example .env

    echo "Installing PHP dependencies..."
    COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader --no-interaction

    echo "Generating application key..."
    php artisan key:generate --force

    case "$WEBSERVER" in
        "NGINX")
            if ! dpkg -s nginx &> /dev/null; then
                echo "Installing Nginx..."
                apt update
                apt install -y nginx
            else
                echo "Nginx is already installed, skipping."
            fi
            panel_conf
            ;;
        "Apache")
            if ! dpkg -s apache2 &> /dev/null; then
                echo "Installing Apache..."
                apt update
                apt install -y apache2 libapache2-mod-php8.3
            else
                echo "Apache is already installed, skipping."
            fi
            panel_conf
            ;;
        *)
            echo "No webserver selected! Skipping webserver installation..."
            ;;
    esac
}

panel_summary(){
    clear
    LATEST_VERSION=$(curl -s "https://api.github.com/repos/pterodactyl/panel/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")')
    echo ""
    echo "[!] Summary:"
    echo ""
    echo "    This will install Pterodactyl $LATEST_VERSION (latest)"
    echo ""
    echo "    Panel URL: $FQDN"
    echo "    Webserver: $WEBSERVER"
    echo "    SSL: $SSLSTATUS"
    echo "    Username: $USERNAME"
    echo "    First name: $FIRSTNAME"
    echo "    Last name: $LASTNAME"
    echo "    Password: $(printf "%0.s*" $(seq 1 ${#USERPASSWORD}))"
    echo ""
    echo "    These credentials will be saved in a file called" 
    echo "    panel_credentials.txt in root directory. (excluding your personal password)"
    echo "" 
    echo "    Do you want to start the installation? (Y/N)" 
    read -r PANEL_INSTALLATION

    if [[ "$PANEL_INSTALLATION" =~ [Yy] ]]; then
        panel_install
    fi
    if [[ "$PANEL_INSTALLATION" =~ [Nn] ]]; then
        echo "[!] Installation has been aborted."
        exit 1
    fi
}

panel_input(){
    send_summary
    local prompt="$1"
    local var_name="$2"
    local max_length="$3"
    local hide_input="${4:-}"
    
    while :; do
        echo "$prompt"
        
        if [ "$hide_input" == "true" ]; then
            local input=""
            while IFS= read -r -s -n 1 char; do
                if [[ $char == $'\0' ]]; then
                    break
                elif [[ $char == $'\177' ]]; then
                    if [ -n "$input" ]; then
                        input="${input%?}"
                        echo -en "\b \b"
                    fi
                else
                    echo -n '*'
                    input+="$char"
                fi
            done
            echo
        else
            read -r input
        fi

        if [ -z "$input" ]; then
            echo "[!] This field cannot be empty."
        elif [ ${#input} -gt "$max_length" ]; then
            echo "[!] Input cannot be more than $max_length characters."
        elif [[ "$input" =~ [æøåÆØÅ] ]]; then
            echo "[!] Invalid characters detected. Only A-Z, a-z, 0-9, and common symbols are allowed."
        else
            eval "$var_name=\"$input\""
            break
        fi
    done
}

panel_fqdn(){
    send_summary
    echo "[!] Please enter FQDN. You will access the Panel with this."
    echo "[!] Example: panel.yourdomain.dk."
    read -r FQDN
    FQDN=$(echo "$FQDN" | tr '[:upper:]' '[:lower:]')
    [ -z "$FQDN" ] && echo "FQDN can't be empty." && return 1

    if [[ "$FQDN" == "localhost" || "$FQDN" == "127.0.0.1" ]]; then
        echo "[!] You cannot use 'localhost' or '127.0.0.1' as the FQDN."
        return 1
    fi

    if [[ "$FQDN" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        echo "[!] You entered an IPv4 address, not a domain name."
        echo "[!] SSL certificates won't work with IP addresses."
        SSLSTATUS=false
    elif [[ "$FQDN" =~ ^([0-9a-f]{0,4}:){2,7}[0-9a-f]{0,4}$ ]]; then
        echo "[!] You entered an IPv6 address, not a domain name."
        echo "[!] SSL certificates won't work with IP addresses."
        SSLSTATUS=false
    else
        if ! [[ "$FQDN" =~ ^[a-z0-9.-]+$ ]]; then
            echo "[!] Invalid characters detected in FQDN."
            echo "[!] Use only lowercase letters, digits, dots and hyphens."
            return 1
        fi
    fi

    echo ""
    echo "[+] Fetching public IP..."
    
    IP_CHECK=$(curl -s -4 --max-time 3 https://api.malthe.cc/checkip || curl -s -4 --max-time 3 https://ipinfo.io/ip)
    IPV6_CHECK=$(curl -s -6 --max-time 3 https://v6.ipinfo.io/ip || curl -s -6 --max-time 3 https://api.malthe.cc/checkip)

    if [ -z "$IP_CHECK" ] && [ -z "$IPV6_CHECK" ]; then
        echo "[ERROR] Failed to retrieve public IP."
        return 1
    fi
    
    echo "[+] Detected Public IP: $IP_CHECK"
    [ -n "$IPV6_CHECK" ] && echo "[+] Detected Public IPv6: $IPV6_CHECK"
    sleep 1s
    DOMAIN_PANELCHECK=$(dig +short "$FQDN" | head -n 1)

    if [ -z "$DOMAIN_PANELCHECK" ]; then
        echo "[!] Could not resolve $FQDN to an IP."
        echo "[!] If you run this locally and only using IP, ignore this."
        echo "[!] Proceeding anyway in 10 seconds... Press CTRL+C to cancel."
        sleep 10
    fi

    sleep 1s
    echo "[+] $FQDN resolves to: $DOMAIN_PANELCHECK"
    sleep 1s
    echo "[+] Checking if $DOMAIN_PANELCHECK is behind Cloudflare Proxy..."
    
    ORG_CHECK=$(curl -s "https://ipinfo.io/$DOMAIN_PANELCHECK/json" | grep -o '"org":.*' | cut -d '"' -f4)

    if [[ "$ORG_CHECK" == *"Cloudflare"* ]]; then
        echo "[!] Your FQDN is behind Cloudflare Proxy."
        echo "[!] This is fine if you know what you are doing."
        echo "[!] If you are using Cloudflare Flexible SSL, please set TRUSTED_PROXIES in .env after installation."
        echo "[!]"
        echo "[!] Proceeding anyway in 10 seconds... Press CTRL+C to cancel."
        sleep 10
        CLOUDFLARE_MATCHED=true
    else
        echo "[+] Your FQDN is NOT behind Cloudflare."
    fi

    panel_ssl
}

panel_ssltype() {
    send_summary
    echo "[!] Select SSL type"
    echo "    (1) Let's Encrypt (recommended)"
    echo "        You will later be asked if you agree to their Terms of Service."
    echo "    (2) Custom"
    echo "    Input 1-2"
    read -r option
    case $option in
        1) 
            CUSTOMSSL=false
            panel_email
            ;;
        2)
            CUSTOMSSL=true
            send_summary
            panel_input "Please enter the filepath for SSL certificate. The file must exist." "CERTIFICATEPATH" 250
            panel_input "Please enter the filepath for private key. The file must exist." "PRIVATEKEYPATH" 250
            panel_validate_ssl_files "$CERTIFICATEPATH" "$PRIVATEKEYPATH"
            ;;
        *)
            echo ""
            echo "Please enter a valid option from 1-2"
            panel_ssltype
    esac
}

panel_validate_ssl_files() {
    local cert_path="$1"
    local key_path="$2"
    
    if [ ! -f "$cert_path" ]; then
        echo "[!] Error: Fullchain certificate file does not exist at $cert_path."
        exit 1
    fi
    if [ ! -f "$key_path" ]; then
        echo "[!] Error: Private key file does not exist at $key_path."
        exit 1
    fi

    if ! openssl x509 -in "$cert_path" -noout; then
        echo "[!] Error: $cert_path is not a valid SSL certificate."
        exit 1
    fi

    if ! openssl rsa -in "$key_path" -check -noout; then
        echo "[!] Error: $key_path is not a valid private key."
        exit 1
    fi
    
    echo "[+] SSL files are valid."
    panel_email
}

panel_ssl(){
    send_summary
    echo "[!] Do you want to use SSL for your Panel? This is recommended. (Y/N)"
    echo "[!] SSL is recommended for every panel."
    while :; do
        read -r SSL_CONFIRM
        if [[ "$SSL_CONFIRM" =~ [Yy] ]]; then
            SSLSTATUS=true
            panel_ssltype
            break
        elif [[ "$SSL_CONFIRM" =~ [Nn] ]]; then
            SSLSTATUS=false
            panel_email
            break
        else
            echo "[!] Invalid input, please enter Y or N."
            panel_ssl
        fi
    done
}

panel_email(){
    send_summary

    while true; do
        if [ "$SSLSTATUS" = "true" ]; then
            panel_input "[!] Please enter your email. It will be shared with Lets Encrypt (if you selected that as SSL type) and used to set up this Panel." "EMAIL" 50
        else
            panel_input "[!] Please enter your email. It will be used to set up this Panel." "EMAIL" 50
        fi

        EMAIL="${EMAIL,,}"
        EMAIL="${EMAIL:0:32}"

        if [[ "$EMAIL" =~ ^[a-z0-9._%-]+@[a-z0-9.-]+\.[a-z]{2,}$ ]]; then
            break
        else
            echo "[!] Invalid email format or unsupported characters detected."
            echo "[!] Use only lowercase english letters, digits, and symbols . _ - @"
            echo "Would you like to try entering the email again? (Y/N)"
            read -r answer
            if [[ ! "$answer" =~ ^[Yy]$ ]]; then
                echo "[!] Email setup aborted."
                exit 1
            fi
        fi
    done

    panel_admin_setup
}

telemetry_prompt(){
    send_summary
    echo ""
    echo "Starting from Pterodactyl 1.11, telemetry is enabled by default."
    echo "Telemetry collects anonymized usage data from the panel to help improve the project."
    echo "You can read more here: https://pterodactyl.io/panel/1.0/additional_configuration.html#telemetry"
    echo ""
    read -rp "Do you want to enable telemetry? (Y/n) " telemetry_input

    telemetry_input=${telemetry_input:-Y}

    case "$telemetry_input" in
        [Yy]* ) TELEMETRY=true ;;
        [Nn]* ) TELEMETRY=false ;;
        * ) 
            echo "Invalid input. Please answer Y or N."
            telemetry_prompt
            ;;
    esac

    panel_summary
}

panel_admin_setup(){
    send_summary
    
    declare -A fields=(
        ["FIRSTNAME"]="🔹 Enter your first name"
        ["LASTNAME"]="🔹 Enter your last name"
        ["USERNAME"]="🔹 Enter a username for your admin account"
        ["USERPASSWORD"]="🔒 Enter a secure password"
    )
    keys=("FIRSTNAME" "LASTNAME" "USERNAME" "USERPASSWORD")
    
    i=1
    total=${#keys[@]}

    for key in "${keys[@]}"; do
        echo -ne "  [${i}/${total}] ${fields[$key]}...\n"
        panel_input "${fields[$key]}" "$key" 16 $([ "$key" = "USERPASSWORD" ] && echo "true")
        ((i++))
        echo -e "  ✅ \033[1;32mDone\033[0m\n"
        sleep 0.3
    done
    telemetry_prompt
}

panel

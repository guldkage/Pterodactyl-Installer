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

### Pterodactyl Panel Installation ###

send_summary() {
    clear
    clear
    if [ -d "/var/www/pterodactyl" ]; then
        warning "[!] WARNING: Pterodactyl is already installed. This script will fail!"
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
        echo "    Password:"
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
    cd
    echo -e "Summary of the installation\n\nPanel URL: $FQDN\nWebserver: $WEBSERVER\nUsername: $USERNAME\nEmail: $EMAIL\nFirst name: $FIRSTNAME\nLast name: $LASTNAME\nPassword: $(printf "%0.s*" $(seq 1 ${#USERPASSWORD}))\nDatabase password: $DBPASSWORD\nPassword for Database Host: $DBPASSWORDHOST" >> panel_credentials.txt

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
    echo "    These credentials have been saved in panel_credentials.txt"
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

    if [ "$INSTALLBOTH" = "true" ]; then
        WINGSNOQUESTIONS=true
        wings
    fi

    if [ "$INSTALLBOTH" = "false" ]; then
        WINGSNOQUESTIONS=false
        echo "    Would you like to install Wings too? (Y/N)"
        read -r WINGS_ON_PANEL

        if [[ "$WINGS_ON_PANEL" =~ [Yy] ]]; then
            wings
        elif [[ "$WINGS_ON_PANEL" =~ [Nn] ]]; then
            echo "Bye!"
            exit 0
        fi
    fi
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

    mariadb -u root -e "
        CREATE USER 'pterodactyluser'@'127.0.0.1' IDENTIFIED BY '$DBPASSWORDHOST';
        GRANT ALL PRIVILEGES ON *.* TO 'pterodactyluser'@'127.0.0.1' WITH GRANT OPTION;
        CREATE USER 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '$DBPASSWORD';
        CREATE DATABASE panel;
        GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'127.0.0.1' WITH GRANT OPTION;
        FLUSH PRIVILEGES;
    "

    php artisan p:environment:setup --author="$EMAIL" --url="$appurl" --timezone="CET" --telemetry=false --cache="redis" --session="redis" --queue="redis" --redis-host="localhost" --redis-pass="null" --redis-port="6379" --settings-ui=true
    php artisan p:environment:database --host="127.0.0.1" --port="3306" --database="panel" --username="pterodactyl" --password="$DBPASSWORD"
    php artisan migrate --seed --force
    php artisan p:user:make --email="$EMAIL" --username="$USERNAME" --name-first="$FIRSTNAME" --name-last="$LASTNAME" --password="$USERPASSWORD" --admin=1

    chown -R www-data:www-data /var/www/pterodactyl/*

    curl -o /etc/systemd/system/pteroq.service https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/pteroq.service
    (crontab -l ; echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1") | crontab -
    systemctl enable --now redis-server
    systemctl enable --now pteroq.service

    if [ "$CUSTOMSSL" == false ]; then
        if [ "$WEBSERVER" == "NGINX" ]; then
            apt install python3-certbot-nginx -y
            certbot --nginx --redirect --no-eff-email --email "$EMAIL" -d "$FQDN" || FAIL=true
            if [ ! -d "/etc/letsencrypt/live/$FQDN/" ] || [ "$FAIL" == true ]; then
                echo "[!] Let's Encrypt certificate failed."
                echo "[!] Would you still like to continue? (Y/N)" 
                read -r SSL_FAILED

                if [[ "$SSL_FAILED" =~ ^[Nn]$ ]]; then
                    echo "[!] Installation has been aborted."
                    echo "[!] As most of the panel has already been setup, you should clean up this server or reinstall."
                    exit 1
                fi
            fi
        fi
    fi

    if [ "$SSLSTATUS" == "true" ]; then
        if [ "$WEBSERVER" == "NGINX" ]; then
            rm -rf /etc/nginx/sites-enabled/default
            curl -o /etc/nginx/sites-enabled/pterodactyl.conf https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/pterodactyl-nginx-ssl.conf
            if [ "$CUSTOMSSL" == true ]; then
                sed -i -e "s@ssl_certificate /etc/letsencrypt/live/<domain>/fullchain.pem;@ssl_certificate ${CERTIFICATEPATH};@g" /etc/nginx/sites-enabled/pterodactyl.conf
                sed -i -e "s@ssl_certificate_key /etc/letsencrypt/live/<domain>/privkey.pem;@ssl_certificate_key ${PRIVATEKEYPATH};@g" /etc/nginx/sites-enabled/pterodactyl.conf
            fi
            sed -i -e "s@<domain>@${FQDN}@g" /etc/nginx/sites-enabled/pterodactyl.conf
        elif [ "$WEBSERVER" == "Apache" ]; then
            systemctl stop apache2
            certbot certonly --standalone -d $FQDN --staple-ocsp --no-eff-email -m $EMAIL --agree-tos
            a2dissite 000-default.conf && systemctl reload apache2
            curl -o /etc/apache2/sites-enabled/pterodactyl.conf https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/pterodactyl-apache-ssl.conf
            if [ "$CUSTOMSSL" == true ]; then
                sed -i -e "s@SSLCertificateFile /etc/letsencrypt/live/<domain>/fullchain.pem@SSLCertificateFile ${CERTIFICATEPATH}@g" /etc/nginx/sites-enabled/pterodactyl.conf
                sed -i -e "s@SSLCertificateKeyFile /etc/letsencrypt/live/<domain>/privkey.pem@SSLCertificateKeyFile ${PRIVATEKEYPATH}@g" /etc/nginx/sites-enabled/pterodactyl.conf
            fi
            sed -i -e "s@<domain>@${FQDN}@g" /etc/apache2/sites-enabled/pterodactyl.conf
            a2enmod rewrite ssl
        fi
    else
        if [ "$WEBSERVER" == "NGINX" ]; then
            rm -rf /etc/nginx/sites-enabled/default
            curl -o /etc/nginx/sites-enabled/pterodactyl.conf https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/pterodactyl-nginx.conf
            sed -i -e "s@<domain>@${FQDN}@g" /etc/nginx/sites-enabled/pterodactyl.conf
        elif [ "$WEBSERVER" == "Apache" ]; then
            a2dissite 000-default.conf && systemctl reload apache2
            curl -o /etc/apache2/sites-enabled/pterodactyl.conf https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/pterodactyl-apache.conf
            sed -i -e "s@<domain>@${FQDN}@g" /etc/apache2/sites-enabled/pterodactyl.conf
            a2enmod rewrite
        fi
    fi

    if [ "$WEBSERVER" == "NGINX" ]; then
        systemctl restart nginx
    elif [ "$WEBSERVER" == "Apache" ]; then
        systemctl stop apache2 && systemctl start apache2
    fi

    finish
}

panel_install(){
    echo -e "\nStarting Pterodactyl Panel Installation...\n"

    echo "🔄 Updating package lists..."
    apt update -y || { echo "❌ Failed to update package lists!"; exit 1; }

    echo "📦 Installing required packages..."
    apt install -y wget software-properties-common ca-certificates apt-transport-https || { echo "❌ Failed to install base packages!"; exit 1; }

    case "$dist" in
        "ubuntu")
            if [[ "$version" =~ ^20\.04|22\.04|24\.04$ ]]; then
                echo "🛠 Setting up for Ubuntu $version..."
                apt -y install gnupg || { echo "❌ Failed to install gnupg!"; exit 1; }
                LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php || { echo "❌ Failed to add PHP repository!"; exit 1; }
                if [[ "$version" == "20.04" ]]; then
                    echo "📦 Setting up MariaDB repository..."
                    curl -LsS https://r.mariadb.com/downloads/mariadb_repo_setup | sudo bash || { echo "❌ Failed to set up MariaDB repository!"; exit 1; }
                fi
            fi
            ;;
        "debian")
            echo "🛠 Setting up for Debian $version..."
            apt -y install gnupg2 || { echo "❌ Failed to install gnupg2!"; exit 1; }
            case "$version" in
                "11")
                    echo "Adding PHP repository for Debian 11..."
                    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/sury-php.list
                    curl -fsSL https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/sury-keyring.gpg || { echo "❌ Failed to fetch PHP GPG key!"; exit 1; }
                    ;;
                "12")
                    echo "Adding PHP repository for Debian 12..."
                    wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg || { echo "❌ Failed to fetch PHP GPG key!"; exit 1; }
                    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list
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

    echo "Setting up Redis repository..."
    curl -fsSL https://packages.redis.io/gpg | gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg || { echo "❌ Failed to fetch Redis GPG key!"; exit 1; }
    echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/redis.list

    apt update -y || { echo "❌ Failed to update package lists after adding repositories!"; exit 1; }

    echo "Installing required software..."
    apt install -y mariadb-server tar unzip git redis-server certbot cron php8.3 php8.3-{cli,gd,mysql,pdo,mbstring,tokenizer,bcmath,xml,fpm,curl,zip} || { echo "❌ Failed to install required packages!"; exit 1; }

    echo "Configuring MariaDB..."
    if [ -f "/etc/mysql/mariadb.conf.d/50-server.cnf" ]; then
        sed -i 's/character-set-collations = utf8mb4=uca1400_ai_ci/character-set-collations = utf8mb4=utf8mb4_general_ci/' /etc/mysql/mariadb.conf.d/50-server.cnf
        systemctl restart mariadb || { echo "❌ Failed to restart MariaDB!"; exit 1; }
    else
        echo "⚠ MariaDB config file not found! Skipping modification..."
    fi

    echo "Installing Composer..."
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer || { echo "❌ Failed to install Composer!"; exit 1; }

    echo "Creating Pterodactyl directory..."
    mkdir -p /var/www/pterodactyl || { echo "❌ Failed to create directory!"; exit 1; }
    cd /var/www/pterodactyl || { echo "❌ Failed to change directory!"; exit 1; }

    echo "⬇Downloading Pterodactyl Panel..."
    curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz || { echo "❌ Failed to download Pterodactyl Panel!"; exit 1; }
    tar -xzvf panel.tar.gz || { echo "❌ Failed to extract Pterodactyl Panel!"; exit 1; }

    echo "🔧 Setting permissions..."
    chmod -R 755 storage/* bootstrap/cache/ || { echo "❌ Failed to set permissions!"; exit 1; }

    cp .env.example .env || { echo "❌ Failed to copy .env file!"; exit 1; }

    echo "Installing PHP dependencies..."
    command composer install --no-dev --optimize-autoloader --no-interaction || { echo "❌ Failed to install PHP dependencies!"; exit 1; }

    echo "Generating application key..."
    php artisan key:generate --force || { echo "❌ Failed to generate application key!"; exit 1; }

    if [ "$WEBSERVER" = "NGINX" ]; then
        echo "Installing Nginx..."
        apt install nginx -y || { echo "❌ Failed to install Nginx!"; exit 1; }
        panel_conf
    elif [ "$WEBSERVER" = "Apache" ]; then
        echo "Installing Apache..."
        apt install apache2 libapache2-mod-php8.3 -y || { echo "❌ Failed to install Apache!"; exit 1; }
        panel_conf
    else
        echo "No webserver selected! Skipping installation..."
    fi
}


panel_summary(){
    clear
    DBPASSWORD=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1`
    DBPASSWORDHOST=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1`
    echo ""
    echo "[!] Summary:"
    echo "    Panel URL: $FQDN"
    echo "    Webserver: $WEBSERVER"
    echo "    SSL: $SSLSTATUS"
    echo "    Username: $USERNAME"
    echo "    First name: $FIRSTNAME"
    echo "    Last name: $LASTNAME"
    echo "    Password: $(printf "%0.s*" $(seq 1 ${#USERPASSWORD}))"
    echo ""
    echo "    These credentials will be saved in a file called" 
    echo "    panel_credentials.txt in your current directory"
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
    local hide_input="$4"
    
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
    [ -z "$FQDN" ] && echo "FQDN can't be empty." && return 1

    echo ""
    echo "[+] Fetching public IP..."
    
    IP_CHECK=$(curl -s ipinfo.io/ip -4)
    IPV6_CHECK=$(curl -s v6.ipinfo.io/ip -6)

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
        return 1
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
    if [ "$SSLSTATUS" = "true" ]; then
        panel_input "[!] Please enter your email. It will be shared with Lets Encrypt (if you selected that as SSL type) and used to set up this Panel." "EMAIL" 50
    else
        panel_input "[!] Please enter your email. It will be used to set up this Panel." "EMAIL" 50
    fi
    panel_admin_setup
}

panel_admin_setup(){
    send_summary
    
    declare -A fields=(
        ["FIRSTNAME"]="🔹 Enter your first name"
        ["LASTNAME"]="🔹 Enter your last name"
        ["USERNAME"]="🔹 Enter a username for your admin account"
        ["USERPASSWORD"]="🔒 Enter a secure password"
    )
    i=1
    total=${#fields[@]}

    for key in "${!fields[@]}"; do
        echo -ne "  [${i}/${total}] ${fields[$key]}...\n"
        panel_input "${fields[$key]}" "$key" 16 $([ "$key" = "USERPASSWORD" ] && echo "true")
        ((i++))
        echo -e "  ✅ \033[1;32mDone\033[0m\n"
        sleep 0.3
    done
    panel_summary
}


### Pterodactyl Wings Installation ###

wings(){
    if [ "$dist" = "debian" ] || [ "$dist" = "ubuntu" ]; then
         apt install dnsutils certbot curl tar unzip -y
    fi
    
    if [ "$WINGSNOQUESTIONS" = "true" ]; then
        WINGS_FQDN_STATUS=false
        wings_full
    elif [ "$WINGSNOQUESTIONS" = "false" ]; then
        clear
        echo ""
        echo "[!] Before installation, we need some information."
        echo ""
        wings_fqdn
    fi
}


wings_fqdnask(){
    echo "[!] Do you want to install a SSL certificate? (Y/N)"
    echo "    If yes, you will be asked for an email."
    echo "    The email will be shared with Lets Encrypt."
    read -r WINGS_SSL

    if [[ "$WINGS_SSL" =~ [Yy] ]]; then
        panel_fqdn
    fi
    if [[ "$WINGS_SSL" =~ [Nn] ]]; then
        WINGS_FQDN_STATUS=false
        wings_full
    fi
}

wings_full(){
    if [ "$dist" = "debian" ] || [ "$dist" = "ubuntu" ]; then
        apt-get update && apt-get -y install curl tar unzip

        if ! command -v docker &> /dev/null; then
            curl -sSL https://get.docker.com/ | CHANNEL=stable bash
             systemctl enable --now docker
        else
            echo "[!] Docker is already installed."
        fi

        if ! mkdir -p /etc/pterodactyl; then
            echo "[!] An error occurred. Could not create directory." >&2
            exit 1
        fi

        if  [ "$WINGS_FQDN_STATUS" =  "true" ]; then
            systemctl stop nginx apache2
            apt install -y certbot && certbot certonly --standalone -d $WINGS_FQDN --staple-ocsp --no-eff-email --agree-tos
            fi

        curl -L -o /usr/local/bin/wings "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_$([[ "$(uname -m)" == "x86_64" ]] && echo "amd64" || echo "arm64")"
        curl -o /etc/systemd/system/wings.service https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/wings.service
        chmod u+x /usr/local/bin/wings
        clear
        echo ""
        echo "[!] Pterodactyl Wings successfully installed."
        echo "    You still need to setup the Node"
        echo "    on the Panel and restart Wings after."
        echo ""

        if [ "$INSTALLBOTH" = "true" ]; then
            INSTALLBOTH="0"
            finish
            fi
    else
        echo "[!] Your OS is not supported for installing Wings with this installer"
    fi
}

wings_fqdn(){
    echo "[!] Please enter your FQDN if you want to install an SSL certificate."
    echo "[!] If you don't want to use SSL, press ENTER to continue without one."
    
    if [ -d "/etc/letsencrypt/live" ]; then
        echo "[i] Existing SSL certificates found:"
        ls /etc/letsencrypt/live/
        echo ""
    fi

    read -r WINGS_FQDN

    if [ -z "$WINGS_FQDN" ]; then
        echo "[i] No FQDN entered. Skipping SSL setup."
        WINGS_FQDN_STATUS=false
        wings_full
        return
    fi

    IP=$(dig +short myip.opendns.com @resolver2.opendns.com -4)
    DOMAIN_IP=$(dig +short "$WINGS_FQDN")

    if [ "$IP" != "$DOMAIN_IP" ] || [ -z "$DOMAIN_IP" ]; then
        echo ""
        echo "[!] Warning: The FQDN '$WINGS_FQDN' does not resolve to this machine's IP."
        echo "[!] Continuing anyway in 10 seconds... Press CTRL+C to cancel."
        sleep 10
    else
        echo "[i] FQDN '$WINGS_FQDN' is correctly configured."
    fi

    WINGS_FQDN_STATUS=true
    wings_full
}


### PHPMyAdmin Installation ###

phpmyadmin() {
    apt install dnsutils -y || { echo "Error installing dnsutils"; exit 1; }
    echo ""
    echo "[!] Before installation, we need some information."
    echo ""
    phpmyadmin_fqdn
}

phpmyadmin_finish() {
    cd || { echo "Error accessing the home directory"; exit 1; }
    echo -e "PHPMyAdmin Installation\n\nSummary of the installation\n\nPHPMyAdmin URL: $PHPMYADMIN_FQDN\nPreselected webserver: NGINX\nSSL: $PHPMYADMIN_SSLSTATUS\nUser: $PHPMYADMIN_USER_LOCAL\nPassword: $PHPMYADMIN_PASSWORD\nEmail: $PHPMYADMIN_EMAIL" > phpmyadmin_credentials.txt
    clear
    echo "[!] Installation of PHPMyAdmin done"
    echo ""
    echo "    Summary of the installation"
    echo "    PHPMyAdmin URL: $PHPMYADMIN_FQDN"
    echo "    Preselected webserver: NGINX"
    echo "    SSL: $PHPMYADMIN_SSLSTATUS"
    echo "    User: $PHPMYADMIN_USER_LOCAL"
    echo "    Password: $PHPMYADMIN_PASSWORD"
    echo "    Email: $PHPMYADMIN_EMAIL"
    echo ""
    echo "    These credentials have been saved in a file called"
    echo "    phpmyadmin_credentials.txt in your current directory"
    echo ""
}

phpmyadminweb() {
    rm -rf /etc/nginx/sites-enabled/default || { echo "Error removing default NGINX config"; exit 1; }
    apt install mariadb-server -y || { echo "Error installing MariaDB"; exit 1; }
    PHPMYADMIN_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
    mariadb -u root -e "CREATE USER '$PHPMYADMIN_USER_LOCAL'@'localhost' IDENTIFIED BY '$PHPMYADMIN_PASSWORD';" && mariadb -u root -e "GRANT ALL PRIVILEGES ON *.* TO '$PHPMYADMIN_USER_LOCAL'@'localhost' WITH GRANT OPTION;" || { echo "Error creating MariaDB user"; exit 1; }

    if [ "$PHPMYADMIN_SSLSTATUS" = "true" ]; then
        rm -rf /etc/nginx/sites-enabled/default
        curl -o /etc/nginx/sites-enabled/phpmyadmin.conf https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/phpmyadmin-ssl.conf || { echo "Error downloading NGINX config"; exit 1; }
        sed -i -e "s@<domain>@${PHPMYADMIN_FQDN}@g" /etc/nginx/sites-enabled/phpmyadmin.conf || { echo "Error editing NGINX config"; exit 1; }
        systemctl stop nginx || { echo "Error stopping NGINX"; exit 1; }
        certbot certonly --standalone -d $PHPMYADMIN_FQDN --staple-ocsp --no-eff-email -m $PHPMYADMIN_EMAIL --agree-tos || { echo "Error with Certbot"; exit 1; }
        systemctl start nginx || { echo "Error starting NGINX"; exit 1; }
        phpmyadmin_finish
    fi

    if [ "$PHPMYADMIN_SSLSTATUS" = "false" ]; then
        curl -o /etc/nginx/sites-enabled/phpmyadmin.conf https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/phpmyadmin.conf || { echo "Error downloading NGINX config"; exit 1; }
        sed -i -e "s@<domain>@${PHPMYADMIN_FQDN}@g" /etc/nginx/sites-enabled/phpmyadmin.conf || { echo "Error editing NGINX config"; exit 1; }
        systemctl restart nginx || { echo "Error restarting NGINX"; exit 1; }
        phpmyadmin_finish
    fi
}

phpmyadmin_fqdn() {
    send_phpmyadmin_summary
    echo "[!] Please enter FQDN. You will access PHPMyAdmin with this."
    read -r PHPMYADMIN_FQDN
    if [ -z "$PHPMYADMIN_FQDN" ]; then
        echo "FQDN can't be empty."
        exit 1
    fi

    IP=$(dig +short myip.opendns.com @resolver2.opendns.com -4)
    DOMAIN=$(dig +short "${PHPMYADMIN_FQDN}")
    
    if [ "$IP" != "$DOMAIN" ]; then
        echo ""
        echo "Your FQDN does not resolve to the IP of this machine."
        echo "Continuing anyway in 10 seconds.. CTRL+C to stop."
        sleep 10s
        phpmyadmin_ssl
    else
        phpmyadmin_ssl
    fi
}

phpmyadmininstall() {
    apt update || { echo "Error updating package list"; exit 1; }
    apt install nginx certbot -y || { echo "Error installing NGINX or Certbot"; exit 1; }
    mkdir /var/www/phpmyadmin && cd /var/www/phpmyadmin || { echo "Error creating directory"; exit 1; }
    
    if [ "$dist" = "ubuntu" ] && [[ "$version" =~ ^20\.04|22\.04|24\.04$ ]]; then
        apt -y install software-properties-common curl apt-transport-https ca-certificates gnupg || { echo "Error installing dependencies"; exit 1; }
        LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
        curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | bash || { echo "Error setting up MariaDB repo"; exit 1; }
        apt update || { echo "Error updating package list"; exit 1; }
        add-apt-repository "deb http://archive.ubuntu.com/ubuntu $(lsb_release -sc) universe" || { echo "Error adding Ubuntu repository"; exit 1; }
    fi

    if [ "$dist" = "debian" ] && [ "$version" = "11" ]; then
        apt -y install software-properties-common curl ca-certificates gnupg2 lsb-release || { echo "Error installing dependencies"; exit 1; }
        echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/sury-php.list
        curl -fsSL https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/sury-keyring.gpg || { echo "Error adding PHP repository"; exit 1; }
        apt update -y || { echo "Error updating package list"; exit 1; }
        curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | bash || { echo "Error setting up MariaDB repo"; exit 1; }
    fi

    if [ "$dist" = "debian" ] && [ "$version" = "12" ]; then
        apt -y install software-properties-common curl ca-certificates gnupg2 lsb-release || { echo "Error installing dependencies"; exit 1; }
        apt install -y apt-transport-https lsb-release ca-certificates wget || { echo "Error installing required packages"; exit 1; }
        wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg || { echo "Error downloading PHP GPG key"; exit 1; }
        echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list
        apt update -y || { echo "Error updating package list"; exit 1; }
        curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | bash || { echo "Error setting up MariaDB repo"; exit 1; }
    fi

    wget https://files.phpmyadmin.net/phpMyAdmin/5.2.1/phpMyAdmin-5.2.1-all-languages.tar.gz || { echo "Error downloading PHPMyAdmin"; exit 1; }
    tar xzf phpMyAdmin-5.2.1-all-languages.tar.gz || { echo "Error extracting PHPMyAdmin"; exit 1; }
    mv /var/www/phpmyadmin/phpMyAdmin-5.2.1-all-languages/* /var/www/phpmyadmin || { echo "Error moving PHPMyAdmin files"; exit 1; }
    chown -R www-data:www-data *
    mkdir config
    chmod o+rw config
    cp config.sample.inc.php config/config.inc.php
    chmod o+w config/config.inc.php
    rm -rf /var/www/phpmyadmin/config
    phpmyadminweb
}

phpmyadmin_summary() {
    clear
    echo ""
    echo "[!] Summary:"
    echo "    PHPMyAdmin URL: $PHPMYADMIN_FQDN"
    echo "    Preselected webserver: NGINX"
    echo "    SSL: $PHPMYADMIN_SSLSTATUS"
    echo "    User: $PHPMYADMIN_USER_LOCAL"
    echo "    Email: $PHPMYADMIN_EMAIL"
    echo ""
    echo "    These credentials have been saved in a file called"
    echo "    phpmyadmin_credentials.txt in your current directory"
    echo ""
    echo "    Do you want to start the installation? (Y/N)"
    read -r PHPMYADMIN_INSTALLATION

    if [[ "$PHPMYADMIN_INSTALLATION" =~ [Yy] ]]; then
        phpmyadmininstall
    fi

    if [[ "$PHPMYADMIN_INSTALLATION" =~ [Nn] ]]; then
        echo "[!] Installation has been aborted."
        exit 1
    fi
}

send_phpmyadmin_summary() {
    clear
    echo ""
    if [ -d "/var/www/phpmyadmin" ]; then
        echo "[!] WARNING: There seems to already be an installation of PHPMyAdmin installed! This script will fail!"
    fi
    echo ""
    echo "[!] Summary:"
    echo "    PHPMyAdmin URL: $PHPMYADMIN_FQDN"
    echo "    Preselected webserver: NGINX"
    echo "    SSL: $PHPMYADMIN_SSLSTATUS"
    echo "    User: $PHPMYADMIN_USER_LOCAL"
    echo "    Email: $PHPMYADMIN_EMAIL"
    echo ""
}

phpmyadmin_ssl() {
    send_phpmyadmin_summary
    echo "[!] Do you want to use SSL for PHPMyAdmin? This is recommended. (Y/N)"
    read -r SSL_CONFIRM

    if [[ "$SSL_CONFIRM" =~ [Yy] ]]; then
        PHPMYADMIN_SSLSTATUS=true
        phpmyadmin_email
    fi

    if [[ "$SSL_CONFIRM" =~ [Nn] ]]; then
        PHPMYADMIN_SSLSTATUS=false
        phpmyadmin_email
    fi
}

phpmyadmin_user() {
    send_phpmyadmin_summary
    echo "[!] Please enter username for admin account."
    read -r PHPMYADMIN_USER_LOCAL
    phpmyadmin_summary
}

phpmyadmin_email() {
    send_phpmyadmin_summary
    if [ "$PHPMYADMIN_SSLSTATUS" = "true" ]; then
        echo "[!] Please enter your email. It will be shared with Lets Encrypt."
        read -r PHPMYADMIN_EMAIL
        phpmyadmin_user
    fi

    if [ "$PHPMYADMIN_SSLSTATUS" = "false" ]; then
        phpmyadmin_user
        PHPMYADMIN_EMAIL="Unavailable"
    fi
}

### Removal of Wings ###

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

## PHPMyAdmin Removal ###

removephpmyadmin(){
    echo ""
    echo "[!] Do you really want to delete PHPMyAdmin? /var/www/phpmyadmin will be deleted, and cannot be recovered. (Y/N)"
    read -r UNINSTALLPHPMYADMIN

    if [[ "$UNINSTALLPHPMYADMIN" =~ [Yy] ]]; then
         rm -rf /var/www/phpmyadmin || exit || warning "PHPMyAdmin is not installed!" # Removes PHPMyAdmin files
         echo "[!] PHPMyAdmin has been removed."
    fi
    if [[ "$UNINSTALLPHPMYADMIN" =~ [Nn] ]]; then
        echo "[!] Removal aborted."
    fi
}

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

        # Remove database
        mysql -u root -e "DROP DATABASE IF EXISTS panel;" || { echo "Error: Failed to drop the panel database."; exit 1; }

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

### Switching Domains ###

switch(){
    if  [ "$SSLSWITCH" =  "true" ]; then
        echo ""
        echo "[!] Change domains"
        echo ""
        echo "    The script is now changing your Pterodactyl Domain."
        echo "      This may take a couple seconds for the SSL part, as SSL certificates are being generated."
        rm /etc/nginx/sites-enabled/pterodactyl.conf
        curl -o /etc/nginx/sites-enabled/pterodactyl.conf https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/pterodactyl-nginx-ssl.conf || exit || warning "Pterodactyl Panel not installed!"
        sed -i -e "s@<domain>@${DOMAINSWITCH}@g" /etc/nginx/sites-enabled/pterodactyl.conf
        systemctl stop nginx
        certbot certonly --standalone -d $DOMAINSWITCH --staple-ocsp --no-eff-email -m $EMAILSWITCHDOMAINS --agree-tos || exit || warning "Errors accured."
        systemctl start nginx
        echo ""
        echo "[!] Change domains"
        echo ""
        echo "    Your domain has been switched to $DOMAINSWITCH"
        echo "    This script does not update your APP URL, you can"
        echo "    update it in /var/www/pterodactyl/.env"
        echo ""
        echo "    If using Cloudflare certifiates for your Panel, please read this:"
        echo "    The script uses Lets Encrypt to complete the change of your domain,"
        echo "    if you normally use Cloudflare Certificates,"
        echo "    you can change it manually in its config which is in the same place as before."
        echo ""
        fi
    if  [ "$SSLSWITCH" =  "false" ]; then
        echo "[!] Switching your domain.. This wont take long!"
        rm /etc/nginx/sites-enabled/pterodactyl.conf || exit || echo "An error occurred. Could not delete file." || exit
        curl -o /etc/nginx/sites-enabled/pterodactyl.conf https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/pterodactyl-nginx.conf || exit || warning "Pterodactyl Panel not installed!"
        sed -i -e "s@<domain>@${DOMAINSWITCH}@g" /etc/nginx/sites-enabled/pterodactyl.conf
        systemctl restart nginx
        echo ""
        echo "[!] Change domains"
        echo ""
        echo "    Your domain has been switched to $DOMAINSWITCH"
        echo "    This script does not update your APP URL, you can"
        echo "    update it in /var/www/pterodactyl/.env"
        fi
}

switchemail(){
    echo ""
    echo "[!] Change domains"
    echo "    To install your new domain certificate to your Panel, your email address must be shared with Let's Encrypt."
    echo "    They will send you an email when your certificate is about to expire. A certificate lasts 90 days at a time and you can renew your certificates for free and easily, even with this script."
    echo ""
    echo "    When you created your certificate for your panel before, they also asked you for your email address. It's the exact same thing here, with your new domain."
    echo "    Therefore, enter your email. If you do not feel like giving your email, then the script can not continue. Press CTRL + C to exit."
    echo ""
    echo "      Please enter your email"

    read -r EMAILSWITCHDOMAINS
    switch
}

switchssl(){
    echo "[!] Select the one that describes your situation best"
    warning "   [1] I want SSL on my Panel on my new domain"
    warning "   [2] I don't want SSL on my Panel on my new domain"
    read -r option
    case $option in
        1 ) option=1
            SSLSWITCH=true
            switchemail
            ;;
        2 ) option=2
            SSLSWITCH=false
            switch
            ;;
        * ) echo ""
            echo "Please enter a valid option."
    esac
}

switchdomains(){
    echo ""
    echo "[!] Change domains"
    echo "    Please enter the domain (panel.mydomain.ltd) you want to switch to."
    read -r DOMAINSWITCH
    switchssl
}

### OS Check ###

oscheck(){
    echo "Checking your OS.."
    if { [ "$dist" = "ubuntu" ] && [ "$version" = "18.04" ] || [ "$version" = "20.04" ] || [ "$version" = "22.04" ] || [ "$version" = "24.04" ]; } || { [ "$dist" = "debian" ] && [ "$version" = "11" ] || [ "$version" = "12" ]; }; then
        echo "Your OS, $dist $version, is supported"
        echo ""  
        options
    else
        echo "Your OS, $dist $version, is not supported"
        exit 1
    fi
}

### Options ###

options(){
    echo "What would you like to do?"
    echo "[1] Install Panel"
    echo "[2] Install Wings"
    echo "[3] Panel & Wings"
    echo "[4] Install PHPMyAdmin"
    echo "[5] Remove PHPMyAdmin"
    echo "[6] Remove Wings"
    echo "[7] Remove Panel"
    echo "[8] Switch Pterodactyl Domain"
    echo "Input 1-8"
    read -r option
    case $option in
        1 ) option=1
            INSTALLBOTH=false
            panel
            ;;
        2 ) option=2
            INSTALLBOTH=false
            wings
            ;;
        3 ) option=3
            INSTALLBOTH=true
            panel
            ;;
        4 ) option=4
            phpmyadmin
            ;;
        5 ) option=5
            removephpmyadmin
            ;;
        6 ) option=6
            wings_remove
            ;;
        7 ) option=7
            uninstallpanel
            ;;
        8 ) option=8
            switchdomains
            ;;
        * ) echo ""
            echo "Please enter a valid option from 1-8"
            options
    esac
}

### Start ###

clear
echo ""
echo "-------------------------------------------------------------------"
echo ""
echo "Pterodactyl Installer @ v3.0"
echo "Copyright 2025, Malthe K, <me@malthe.cc>"
echo "https://github.com/guldkage/Pterodactyl-Installer"
echo ""
echo "Security notice:"
echo "This script connects to ipinfo.io to check IP address organization."
echo ""
echo "This script is not associated with the official Pterodactyl Panel."
echo ""
oscheck

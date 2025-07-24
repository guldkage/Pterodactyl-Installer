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
CUSTOMSSL=false
WEBSERVER="NGINX"
for var in FQDN PHPMYADMIN_EMAIL PHPMYADMIN_SSLSTATUS PHPMYADMIN_USER_LOCAL; do
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

### PHPMyAdmin Installation ###

phpmyadmin() {
    apt install dnsutils -y || { echo "Error installing dnsutils"; exit 1; }
    echo ""
    echo "[!] Before installation, we need some information."
    echo ""
    FQDN
}

phpmyadmin_finish() {
    cd || { echo "Error accessing the home directory"; exit 1; }
    echo -e "PHPMyAdmin Installation\n\nSummary of the installation\n\nPHPMyAdmin URL: $FQDN\nPreselected webserver: NGINX\nSSL: $PHPMYADMIN_SSLSTATUS\nUser: $PHPMYADMIN_USER_LOCAL\nPassword: $PHPMYADMIN_PASSWORD\nEmail: $PHPMYADMIN_EMAIL" > phpmyadmin_credentials.txt
    clear
    echo "[!] Installation of PHPMyAdmin done"
    echo ""
    echo "    Summary of the installation"
    echo "    PHPMyAdmin URL: $FQDN"
    echo "    Preselected webserver: NGINX"
    echo "    SSL: $PHPMYADMIN_SSLSTATUS"
    echo "    User: $PHPMYADMIN_USER_LOCAL"
    echo "    Password: $PHPMYADMIN_PASSWORD"
    echo "    Email: $PHPMYADMIN_EMAIL"
    echo ""
    echo "    These credentials have been saved in a file called"
    echo "    phpmyadmin_credentials.txt in your current directory"
    echo ""

    echo "[!] Checking if PHPMyAdmin is accessible..."
    HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}" "https://$FQDN")

    if [ "$HTTP_STATUS" == "502" ]; then
        echo "[!] Bad Gateway detected! Restarting php8.3-fpm..."
        systemctl restart php8.3-fpm
        sleep 5
        HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}" "https://$FQDN")
    fi

    if [[ "$HTTP_STATUS" != "200" ]]; then
        echo "[!] PHPMyAdmin is still not accessible. Restarting webserver..."
        if [[ "$WEBSERVER" == "NGINX" ]]; then
            systemctl restart nginx
        fi
        sleep 5
        HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}" "https://$FQDN")
    fi

    if [[ "$HTTP_STATUS" == "200" ]]; then
        echo "[✔] PHPMyAdmin is accessible!"
    else
        echo "[✖] PHPMyAdmin is still not accessible. Please check logs"
        if [[ "$WEBSERVER" == "NGINX" ]]; then
            journalctl -u nginx --no-pager | tail -n 10
        exit 1
        fi
    fi

}

phpmyadminweb() {
    if [ -e /etc/nginx/sites-enabled/default ]; then
        rm -rf /etc/nginx/sites-enabled/default || { echo "Error removing default NGINX config"; exit 1; }
    fi

    if ! dpkg -s mariadb-server >/dev/null 2>&1; then
        apt update
        apt install mariadb-server -y || { echo "Error installing MariaDB"; exit 1; }
    else
        echo "MariaDB is already installed, skipping."
    fi

    PHPMYADMIN_PASSWORD=$(head -c 64 /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 16)
    mariadb -u root -e "CREATE USER '$PHPMYADMIN_USER_LOCAL'@'localhost' IDENTIFIED BY '$PHPMYADMIN_PASSWORD';" \
    && mariadb -u root -e "GRANT ALL PRIVILEGES ON *.* TO '$PHPMYADMIN_USER_LOCAL'@'localhost' WITH GRANT OPTION;" \
    || { echo "Error creating MariaDB user"; exit 1; }

    curl -o /etc/nginx/sites-enabled/phpmyadmin.conf \
        https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/phpmyadmin-dummy.conf \
        || { echo "Error downloading dummy config"; exit 1; }

    sed -i "s@<domain>@${FQDN}@g" /etc/nginx/sites-enabled/phpmyadmin.conf
    systemctl restart nginx || { echo "Error restarting NGINX with dummy config"; exit 1; }

    if [ "$PHPMYADMIN_SSLSTATUS" = "true" ]; then
        if [ "$CUSTOMSSL" == false ] && [ "$WEBSERVER" == "NGINX" ]; then
            warning "ACTION REQUIRED"
            echo "[!] How do you want to request the SSL certificate?"
            echo "    1) Webserver mode (recommended, requires ports 80/443 open)"
            echo "    2) DNS challenge (manual DNS setup required)"
            read -rp "[1/2]: " SSL_MODE

            apt install -y python3-certbot-nginx certbot

            if [[ "$SSL_MODE" != "2" ]]; then
                for attempt in {1..2}; do
                    echo "Attempt $attempt to obtain Let's Encrypt certificate..."
                    certbot --nginx --redirect --no-eff-email --email "$PHPMYADMIN_EMAIL" -d "$FQDN" \
                        && FAIL=false || FAIL=true

                    if [ "$FAIL" = false ] && [ -d "/etc/letsencrypt/live/$FQDN/" ]; then
                        break
                    elif [ "$attempt" -lt 2 ]; then
                        echo "[!] Certbot attempt failed. Try again? (Y/N)"
                        read -r TRY_AGAIN
                        [[ ! "$TRY_AGAIN" =~ ^[Yy]$ ]] && break
                    fi
                done
            else
                echo "[!] You selected DNS challenge mode."
                echo "[!] When prompted, you will need to create TXT records in your DNS panel."
                echo "[!] Please create the records, wait at least 2-5 minutes then press enter."
                echo "[!] If you normally use CTRL+C to copy text in terminal, please use SHIFT+CTRL+C or else you will stop the script."
                read -r
                certbot certonly --manual --preferred-challenges dns --email "$PHPMYADMIN_EMAIL" -d "$FQDN" \
                    && FAIL=false || FAIL=true
            fi

            if [ "$FAIL" = true ]; then
                echo "[!] Let's Encrypt certificate failed."
                echo "Do you want to continue without SSL? (Y/N)"
                read -r CONTINUE_NO_SSL
                if [[ "$CONTINUE_NO_SSL" =~ ^[Yy]$ ]]; then
                    echo "Continuing with HTTP only setup."
                    phpmyadmin_finish
                    return
                else
                    echo "[!] Installation aborted."
                    exit 1
                fi
            fi

            curl -o /etc/nginx/sites-enabled/phpmyadmin.conf \
                https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/phpmyadmin-ssl.conf \
                || { echo "Error downloading real SSL config"; exit 1; }

            sed -i "s@<domain>@${FQDN}@g" /etc/nginx/sites-enabled/phpmyadmin.conf
            systemctl restart nginx || { echo "Error restarting NGINX with SSL config"; exit 1; }

            echo "[✓] SSL configured successfully!"
            phpmyadmin_finish
            return
        fi
    fi

    if [ "$PHPMYADMIN_SSLSTATUS" = "false" ]; then
        phpmyadmin_finish
    fi
}


FQDN() {
    send_phpmyadmin_summary
    echo "[!] Please enter FQDN. You will access PHPMyAdmin with this."
    echo "[!] Example: pma.yourdomain.dk."
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
    
    IP_CHECK=$(curl -s -4 https://api.malthe.cc/checkip || curl -s -4 https://ipinfo.io/ip)
    IPV6_CHECK=$(curl -s -6 https://api.malthe.cc/checkip || curl -s -6 https://v6.ipinfo.io/ip)

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

    phpmyadmin_ssl
}

phpmyadmininstall() {
    apt update || { echo "Error updating package list"; exit 1; }
    apt install nginx certbot -y || { echo "Error installing NGINX or Certbot"; exit 1; }
    mkdir /var/www/phpmyadmin && cd /var/www/phpmyadmin || { echo "Error creating directory"; exit 1; }
    
    if [ "$dist" = "ubuntu" ] && [[ "$version" =~ ^20\.04|22\.04|24\.04$ ]]; then
        apt -y install software-properties-common curl apt-transport-https ca-certificates gnupg || { echo "Error installing dependencies"; exit 1; }
        LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
        apt update || { echo "Error updating package list"; exit 1; }
        add-apt-repository "deb http://archive.ubuntu.com/ubuntu $(lsb_release -sc) universe" || { echo "Error adding Ubuntu repository"; exit 1; }
    fi

    if [ "$dist" = "debian" ] && [ "$version" = "11" ]; then
        apt -y install software-properties-common curl ca-certificates gnupg2 lsb-release || { echo "Error installing dependencies"; exit 1; }
        echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/sury-php.list
        curl -fsSL https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/sury-keyring.gpg || { echo "Error adding PHP repository"; exit 1; }
        apt update -y || { echo "Error updating package list"; exit 1; }
    fi

    if [ "$dist" = "debian" ] && [ "$version" = "12" ]; then
        apt -y install software-properties-common curl ca-certificates gnupg2 lsb-release || { echo "Error installing dependencies"; exit 1; }
        apt install -y apt-transport-https lsb-release ca-certificates wget || { echo "Error installing required packages"; exit 1; }
        wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg || { echo "Error downloading PHP GPG key"; exit 1; }
        echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list
        apt update -y || { echo "Error updating package list"; exit 1; }
    fi

    apt install php8.3 php8.3-{cli,gd,mysql,pdo,mbstring,tokenizer,bcmath,xml,fpm,curl,zip} -y

    wget https://files.phpmyadmin.net/phpMyAdmin/5.2.2/phpMyAdmin-5.2.2-all-languages.tar.gz || { echo "Error downloading PHPMyAdmin"; exit 1; }
    tar xzf phpMyAdmin-5.2.2-all-languages.tar.gz || { echo "Error extracting PHPMyAdmin"; exit 1; }
    mv /var/www/phpmyadmin/phpMyAdmin-5.2.2-all-languages/* /var/www/phpmyadmin || { echo "Error moving PHPMyAdmin files"; exit 1; }
    cp config.sample.inc.php config.inc.php
    mkdir -p /var/www/phpmyadmin/tmp/
    chown -R www-data:www-data *
    rm -rf /var/www/phpmyadmin/config

    SECRET=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)
    if grep -q "^\s*\$cfg\['blowfish_secret'\]" config.inc.php; then
        sed -i "s|^\s*\$cfg\['blowfish_secret'\].*|\$cfg['blowfish_secret'] = '$SECRET';|" config.inc.php
        echo "Updated blowfish_secret in config.inc.php"
    else
        echo "\$cfg['blowfish_secret'] = '$SECRET';" >> config.inc.php
        echo "Updated blowfish_secret in config.inc.php"
    fi
    phpmyadminweb
}

phpmyadmin_summary() {
    clear
    echo ""
    echo "[!] Summary:"
    echo "    PHPMyAdmin URL: $FQDN"
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
    echo "    PHPMyAdmin URL: $FQDN"
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
    while true; do
        echo "[!] Please enter username for admin account (a–z, 0–9, max 16 chars, no special chars):"
        read -r PHPMYADMIN_USER_LOCAL

        PHPMYADMIN_USER_LOCAL=$(echo "$PHPMYADMIN_USER_LOCAL" | tr '[:upper:]' '[:lower:]')

        if [[ "$PHPMYADMIN_USER_LOCAL" =~ ^[a-z0-9]{1,16}$ ]]; then
            break
        else
            echo "[!] Invalid username. Only lowercase letters and numbers allowed, max 16 characters. Try again."
        fi
    done

    phpmyadmin_summary
}

phpmyadmin_email() {
    send_phpmyadmin_summary

    if [ "$PHPMYADMIN_SSLSTATUS" = "true" ]; then
        while true; do
            echo "[!] Please enter your email. It will be shared with Let's Encrypt:"
            read -r PHPMYADMIN_EMAIL

            if [[ "$PHPMYADMIN_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
                break
            else
                echo "[!] Invalid email format. Try again."
            fi
        done
    else
        PHPMYADMIN_EMAIL="Unavailable"
    fi

    phpmyadmin_user
}

phpmyadmin
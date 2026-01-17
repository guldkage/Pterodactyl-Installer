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

### VARIABLES ###
dist="$(. /etc/os-release && echo "$ID")"
version="$(. /etc/os-release && echo "$VERSION_ID")"
PANEL_PATH="/var/www/pterodactyl"

### OUTPUTS ###
function trap_ctrlc () {
    echo -e "\nBye!"
    exit 2
}
trap "trap_ctrlc" 2

warning(){
    echo -e '\e[31m'"$1"'\e[0m';
}

### CHECKS ###
if [[ $EUID -ne 0 ]]; then
    echo -e "\n[!] Sorry, but you need to be root to run this script."
    exit 1
fi

if ! [ -x "$(command -v nginx)" ]; then
    echo ""
    warning "[✖] Nginx is not installed or not found."
    echo "The Change Domain function only supports Nginx."
    exit 1
fi

for tool in curl dig sed awk grep; do
    if ! [ -x "$(command -v $tool)" ]; then
        echo "[!] $tool is required. Please install it to proceed."
        exit 1
    fi
done

### HELPER FUNCTIONS ###

check_panel_access() {
    local url=$1
    echo "[!] Checking if the panel is accessible at $url..."
    
    HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}" --connect-timeout 10 --max-time 15 "$url")
    
    if [[ "$HTTP_STATUS" == "502" || "$HTTP_STATUS" == "504" || "$HTTP_STATUS" == "000" ]]; then
        echo "[!] Connection issue ($HTTP_STATUS). Attempting service restart..."
        systemctl restart php8.3-fpm
        sleep 5
        HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}" --connect-timeout 10 "$url")
    fi

    if [[ "$HTTP_STATUS" == "200" ]]; then
        echo "[✔] Panel is accessible!"
        return 0
    else
        echo "[✖] Panel is inaccessible. Status: $HTTP_STATUS"
        echo "--- Last 10 lines of Nginx error log ---"
        tail -n 10 /var/log/nginx/error.log
        return 1
    fi
}

### Switching Domains ###

switch(){
    if [ ! -d "$PANEL_PATH" ] || [ ! -f "$PANEL_PATH/.env" ]; then
        warning "[✖] Pterodactyl Panel not found in $PANEL_PATH"
        exit 1
    fi

    if [ "$SSLSWITCH" = "true" ]; then
        NEW_URL="https://${DOMAINSWITCH}"
        CONF_URL="https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/pterodactyl-nginx-ssl.conf"
    else
        NEW_URL="http://${DOMAINSWITCH}"
        CONF_URL="https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/pterodactyl-nginx.conf"
    fi

    echo "[!] Target URL: $NEW_URL"
    echo "[!] Creating .env backup..."
    cp "$PANEL_PATH/.env" "$PANEL_PATH/.env.bak"

    echo "[!] Updating Nginx configuration..."
    rm -f /etc/nginx/sites-enabled/pterodactyl.conf
    if ! curl -s -o /etc/nginx/sites-enabled/pterodactyl.conf "$CONF_URL"; then
        warning "[✖] Failed to download Nginx config."
        exit 1
    fi
    sed -i "s@<domain>@${DOMAINSWITCH}@g" /etc/nginx/sites-enabled/pterodactyl.conf

    if grep -q "server_tokens off" /etc/nginx/nginx.conf; then
        echo "[!] server_tokens off detected in nginx.conf. Removing from pterodactyl.conf to avoid duplicates..."
        sed -i '/server_tokens off;/d' /etc/nginx/sites-enabled/pterodactyl.conf
    fi

    if [ "$SSLSWITCH" = "true" ]; then
        echo "[!] Generating SSL via Let's Encrypt..."
        systemctl stop nginx
        if ! certbot certonly --standalone -d "$DOMAINSWITCH" --staple-ocsp --no-eff-email -m "$EMAILSWITCHDOMAINS" --agree-tos; then
            warning "[✖] Certbot failed. Starting Nginx and aborting."
            systemctl start nginx
            exit 1
        fi
        systemctl start nginx
    else
        systemctl restart nginx
    fi

    echo "[!] Updating APP_URL in .env..."
    sed -i "s|^APP_URL=.*|APP_URL=$NEW_URL|g" "$PANEL_PATH/.env"
    
    cd "$PANEL_PATH" && php artisan config:clear

    if check_panel_access "$NEW_URL"; then
        echo -e "\n[✔] Domain switched successfully to $DOMAINSWITCH"
        echo "[!] A backup of your old .env has been saved as $PANEL_PATH/.env.bak"
    else
        warning "[!] Process finished, but panel is not responding with 200 OK."
    fi
}

switchemail(){
    echo -e "\n[!] Please enter your email for Let's Encrypt notifications:"
    read -r EMAILSWITCHDOMAINS
    [ -z "$EMAILSWITCHDOMAINS" ] && warning "Email cannot be empty." && exit 1
    switch
}

switchssl(){
    echo -e "\n[!] Select SSL Option:"
    echo "    [1] I want SSL on my Panel on my new domain"
    echo "    [2] I don't want SSL on my Panel on my new domain"
    read -r option
    case $option in
        1 ) SSLSWITCH=true; switchemail ;;
        2 ) SSLSWITCH=false; switch ;;
        * ) echo "Please enter a valid option."; switchssl ;;
    esac
}

panel_fqdn(){
    echo -e "\n[!] Please enter the new FQDN (panel.domain.tld) you want to switch to:"
    read -r DOMAINSWITCH
    DOMAINSWITCH=$(echo "$DOMAINSWITCH" | tr '[:upper:]' '[:lower:]')

    if [[ -z "$DOMAINSWITCH" || "$DOMAINSWITCH" == "localhost" || "$DOMAINSWITCH" == "127.0.0.1" ]]; then
        warning "Invalid FQDN entered."
        return 1
    fi

    echo "[+] Fetching public IP..."
    IP_CHECK=$(curl -4 -s --max-time 5 "https://api.malthe.cc/checkip" || curl -4 -s --max-time 5 "https://ifconfig.me/ip")
    
    if [ -z "$IP_CHECK" ]; then
        warning "[!] Could not detect public IP. DNS verification skipped."
    else
        echo "[+] Detected Public IP: $IP_CHECK"
        echo "[+] Verifying DNS for $DOMAINSWITCH..."
        DOMAIN_RESOLVE=$(dig +short "$DOMAINSWITCH" | head -n 1)

        if [ -z "$DOMAIN_RESOLVE" ]; then
            warning "[!] Could not resolve $DOMAINSWITCH. Ensure DNS is set up."
            echo "    Proceeding in 10 seconds..."
            sleep 10
        elif [ "$DOMAIN_RESOLVE" != "$IP_CHECK" ]; then
            warning "[!] DNS Mismatch! $DOMAINSWITCH -> $DOMAIN_RESOLVE (Expected: $IP_CHECK)"
            echo "    This will cause SSL/Certbot to fail. Proceeding in 10 seconds..."
            sleep 10
        else
            echo "[✔] DNS Verified: $DOMAINSWITCH points to $IP_CHECK"
        fi
    fi

    switchssl
}

panel_fqdn

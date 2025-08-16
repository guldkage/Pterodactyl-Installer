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
        wings_fqdn
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

wings_fqdnask

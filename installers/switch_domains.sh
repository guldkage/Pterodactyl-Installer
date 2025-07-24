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

switchdomains
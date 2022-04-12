#!/bin/bash

########################################################################
#                                                                      #
# Pterodactyl Installer #                         #
#                                                                      #
# This script is not associated with the official Pterodactyl Panel.   #
#                                                                      #
########################################################################


SSL_CONFIRM=""
SSLCONFIRM=""
SSLSTATUS=""
FQDN=""
AGREE=""
LASTNAME=""
FIRSTNAME=""
USERNAME=""
PASSWORD=""
DATABASE_PASSWORD=""
WEBSERVER="" 

output(){
    echo -e '\e[36m'"$1"'\e[0m';
}

warning(){
    echo -e '\e[31m'"$1"'\e[0m';
}

command 1> /dev/null

if [[ $EUID -ne 0 ]]; then
  echo "* Sorry, but you need to be root to run this script."
  exit 1
fi

if [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ] || [ "$lsb_dist" = "rocky" ] || [ "$lsb_dist" = "almalinux" ]; then
    output "* Your OS is not supported."
    exit 1
fi

if ! [ -x "$(command -v curl)" ]; then
  echo "* cURL is required to run this script."
  exit 1
fi



finish(){
    output ""
    output "Thank you for using the script. Remember to give it a star."
    output "The script has ended. https://$appurl to go to your Panel."
    output ""
}

apachewebserver(){
    if  [ "$webserv" = "apache" ]; then
        if  [ "$SSLSTATUS" =  "true" ]; then
            a2dissite 000-default.conf
            output "Configuring webserver..."
            curl -o /etc/apache2/sites-enabled/pterodactyl.conf https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/pterodactyl-apache-ssl.conf
            sed -i -e "s@<domain>@${FQDN}@g" /etc/apache2/sites-enabled/pterodactyl.conf
            certbot certonly --no-eff-email --email "$EMAIL" -d "$FQDN" || exit
            apt install libapache2-mod-php -y
            sudo a2enmod rewrite
            systemctl restart apache2
            finish
            fi
        if  [ "$SSLSTATUS" =  "false" ]; then
            a2dissite 000-default.conf
            output "Configuring webserver..."
            curl -o /etc/apache2/sites-enabled/pterodactyl.conf https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/pterodactyl-apache.conf
            sed -i -e "s@<domain>@${FQDN}@g" /etc/apache2/sites-enabled/pterodactyl.conf
            apt install libapache2-mod-php -y
            sudo a2enmod rewrite
            systemctl restart apache2
            finish
            fi
}

start(){
    output "The script will install Pterodactyl Panel, you will be asked for several things before installation."
    output "Do you agree to this?"
    output "(Y/N):"
    read -r AGREE

    if [[ "$AGREE" =~ [Yy] ]]; then
        AGREE=yes
        web
    fi
}

webserver(){
    apachewebserver
    if  [ "$webserv" = "nginx" ]; then
        if  [ "$SSLSTATUS" =  "true" ]; then
            rm -rf /etc/nginx/sites-enabled/default
            output "Configuring webserver..."
            curl -o /etc/nginx/sites-enabled/pterodactyl.conf https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/pterodactyl-nginx-ssl.conf
            sed -i -e "s@<domain>@${FQDN}@g" /etc/nginx/sites-enabled/pterodactyl.conf
            certbot certonly --no-eff-email --email "$EMAIL" -d "$FQDN" || exit
            systemctl restart nginx
            fi
        if  [ "$SSLSTATUS" = "false" ]; then
            rm -rf /etc/nginx/sites-enabled/default
            output "Configuring webserver..."
            curl -o /etc/nginx/sites-enabled/pterodactyl.conf https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/pterodactyl-nginx.conf
            sed -i -e "s@<domain>@${FQDN}@g" /etc/nginx/sites-enabled/pterodactyl.conf
            systemctl restart nginx
            fi
}

extra(){
    output "Changing permissions..."
    chown -R www-data:www-data /var/www/pterodactyl/*
    curl -o /etc/systemd/system/pteroq.service https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/pteroq.service
    (crontab -l ; echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1")| crontab -
    sed -i -e "s@<user>@www-data@g" /etc/systemd/system/pteroq.service
    sudo systemctl enable --now redis-server
    sudo systemctl enable --now pteroq.service
    webserver
}

configuration(){
    output "Setting up the Panel..."
    [ "$SSL_CONFIRM" == true ] && appurl="https://$FQDN"
    [ "$SSL_CONFIRM" == false ] && appurl="http://$FQDN"

    php artisan p:environment:setup --author="$EMAIL" --url="$appurl" --timezone="America/New_York" --cache="redis" --session="redis" --queue="redis" --redis-host="localhost" --redis-pass="null" --redis-port="6379" --settings-ui=true

    php artisan p:environment:database --host="127.0.0.1" --port="3306" --database="panel" --username="pterodactyl" --password="$DATABASE_PASSWORD"

    php artisan migrate --seed --force
    php artisan p:user:make --email="$EMAIL" --username="$USERNAME" --name-first="$FIRSTNAME" --name-last="$LASTNAME" --password="$PASSWORD" --admin=1
    extra
}

composer(){
    output "Installing composer.."
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
    output "Finished installing composer"
    files
}

files(){
    output "Downloading files... "
    mkdir -p /var/www/pterodactyl
    cd /var/www/pterodactyl || exit
    curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
    tar -xzvf panel.tar.gz
    chmod -R 755 storage/* bootstrap/cache/
    cp .env.example .env
    command composer install --no-dev --optimize-autoloader --no-interaction
    php artisan key:generate --force
    output "Finished downloading files"
    configuration
}

database(){
    warning ""
    output "Let's set up your database connection."
    output "Generating a password for you..."
    warning ""
    DATABASE_PASSWORD=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1`
    mysql -u root -e "CREATE USER 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '$DATABASE_PASSWORD';"
    mysql -u root -e "CREATE DATABASE panel;"
    mysql -u root -e "GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'127.0.0.1' WITH GRANT OPTION;"
    mysql -u root -e "FLUSH PRIVILEGES;"
    firstname
}

required(){
    output ""
    output "Installing packages..."
    output ""
    apt -y install software-properties-common curl apt-transport-https ca-certificates gnupg
    LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
    add-apt-repository -y ppa:chris-lea/redis-server
    curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash
    apt update
    apt-add-repository universe
    apt install certbot -y
    apt -y install php8.0 php8.0-{cli,gd,mysql,pdo,mbstring,tokenizer,bcmath,xml,fpm,curl,zip} mariadb-server nginx tar unzip git redis-server
    database
}

begin(){
    output ""
    output "Let's begin the installation! Are you ready?"
    output "Continuing in 5 seconds.."
    sleep 5s
    composer
}

password(){
    output ""
    output "Please enter password for account"
    read -r PASSWORD
    begin
}


username(){
    output ""
    output "Please enter username for account"
    read -r USERNAME
    password
}


lastname(){
    output ""
    output "Please enter last name for account"
    read -r LASTNAME
    username
}

firstname(){
    output "In order to create an account on the Panel, we need some more information."
    output "You do not need to type in real first and last name."
    output ""
    output "Please enter first name for account"
    read -r FIRSTNAME
    lastname
}

fqdn(){
    output ""
    output "Enter your FQDN or IP"
    read -r FQDN
    required
}

ssl(){
    output ""
    output "Do you want to use SSL? This requires a domain."
    output "(Y/N):"
    read -r SSL_CONFIRM

    if [[ "$SSL_CONFIRM" =~ [Yy] ]]; then
        SSLSTATUS=true
        emailsslyes
    fi
    if [[ "$SSL_CONFIRM" =~ [Nn] ]]; then
        emailsslno
        SSLSTATUS=false
    fi
}

emailsslyes(){
    warning ""
    warning "Read:"
    output "The script now asks for your email. It will be shared with Lets Encrypt to complete the SSL. It will also be used to setup the Panel."
    output "If you do not agree, stop the script."
    warning ""
    output "Please enter your email"
    read -r EMAIL
    fqdn
}

emailsslno(){
    warning ""
    warning "Read:"
    output "The script now asks for your email. It will be used to setup the Panel."
    output "If you do not agree, stop the script."
    warning ""
    output "Please enter your email"
    read -r EMAIL
    fqdn
}

web(){
    output ""
    output "What webserver would you like to use?"
    output "[1] NGINX"
    output "[2] Apache"
    output ""
    read -r option
    case $option in
        1 ) option=1
            webserv="nginx"
            output "Selected: NGINX"
            ssl
            ;;
        2 ) option=2
            webserv="apache"
            output "Selected: Apache"
            ssl
            ;;
        * ) output ""
            warning "Script will exit. Unexpected output."
            sleep 1s
            options
    esac
}

updatepanel(){
    cd /var/www/pterodactyl || exit || output "Pterodactyl Directory (/var/www/pterodactyl) does not exist." || exit
    php artisan down
    curl -L https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz | tar -xzv
    chmod -R 755 storage/* bootstrap/cache
    composer install --no-dev --optimize-autoloader -n
    chown -R www-data:www-data /var/www/pterodactyl/*
    php artisan view:clear
    php artisan config:clear
    php artisan migrate --force
    php artisan db:seed --force
    php artisan up
    php artisan queue:restart
    output ""
    output "Pterodactyl Panel has successfully updated."
}

updatewings(){
    if ! [ -x "$(command -v wings)" ]; then
        echo "Wings is required to update both."
    fi
    curl -L -o /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64
    chmod u+x /usr/local/bin/wings
    systemctl restart wings
    output ""
    output "Wings has successfully updated."
}

updateboth(){
    if ! [ -x "$(command -v wings)" ]; then
        echo "Wings is required to update both."
    fi
    cd /var/www/pterodactyl || exit || warning "[!] Pterodactyl Directory (/var/www/pterodactyl) does not exist! Exitting..."
    php artisan down
    curl -L https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz | tar -xzv
    chmod -R 755 storage/* bootstrap/cache
    composer install --no-dev --optimize-autoloader -n
    chown -R www-data:www-data /var/www/pterodactyl/*
    php artisan view:clear
    php artisan config:clear
    php artisan migrate --force
    php artisan db:seed --force
    php artisan up
    php artisan queue:restart
    curl -L -o /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64
    chmod u+x /usr/local/bin/wings
    systemctl restart wings
    output ""
    output "Pterodactyl Panel and Wings has successfully updated."
}

uninstallpanel(){
    output ""
    output "Do you really want to delete Pterodactyl Panel? All files & configurations will be deleted. You CANNOT get your files back."
    output "(Y/N):"
    read -r UNINSTALLPANEL

    if [[ "$UNINSTALLPANEL" =~ [Yy] ]]; then
        sudo rm -rf /var/www/pterodactyl # Removes panel files
        sudo rm /etc/systemd/system/pteroq.service # Removes pteroq service worker
        sudo unlink /etc/nginx/sites-enabled/pterodactyl.conf # Removes nginx config (if using nginx)
        sudo unlink /etc/apache2/sites-enabled/pterodactyl.conf # Removes Apache config (if using apache)
        sudo rm -rf /var/www/pterodactyl # Removing panel files
        output ""
        output "Your panel has been removed. You are now left with your database and web server."
        output "If you want to delete your database, simply go into MySQL and type DROP DATABASE (database name);"
        output "Pterodactyl Panel has successfully been removed."
    fi
}

uninstallwings(){
    output ""
    output "Do you really want to delete Pterodactyl Wings? All game servers & configurations will be deleted. You CANNOT get your files back."
    output "(Y/N):"
    read -r UNINSTALLWINGS

    if [[ "$UNINSTALLWINGS" =~ [Yy] ]]; then
        sudo systemctl stop wings # Stops wings
        sudo rm -rf /var/lib/pterodactyl # Removes game servers and backup files
        sudo rm -rf /etc/pterodactyl # Removes wings config
        sudo rm /usr/local/bin/wings # Removes wings
        sudo rm /etc/systemd/system/wings.service # Removes wings service file
        output "[!] Wings has been removed."
    fi
}

options(){
    output "Please select your installation option:"
    output "[1] Install Panel. | Installs latest version of Pterodactyl Panel"
    output "[2] Update Panel. | Updates your Panel to the latest version. May remove addons and themes."
    output "[3] Update Wings. | Updates your Wings to the latest version."
    output "[4] Update Both. | Updates your Panel and Wings to the latest versions."
    output ""
    output "[5] Uninstall Wings. | Uninstalls your Wings. This will also remove all of your game servers."
    output "[6] Uninstall Panel. | Uninstalls your Panel. You will only be left with your database and web server."
    output ""
    read -r option
    case $option in
        1 ) option=1
            start
            ;;
        1 ) option=2
            updatepanel
            ;;
        2 ) option=3
            updatewings
            ;;
        3 ) option=4
            updateboth
            ;;
        4 ) option=5
            uninstallwings
            ;;
        5 ) option=6
            uninstallpanel
            ;;
        * ) output ""
            output "Please enter a valid option."
    esac
}

clear
output ""
warning "Pterodactyl Installer @ v1.0"
warning "https://github.com/guldkage/Pterodactyl-Installer"
output ""
output "This script is not resposible for any damages. The script has been tested several times without issues."
output "Support is not given."
output "This script will only work on a fresh installation. Proceed with caution if not having a fresh installation"
output ""
sleep 3s
options
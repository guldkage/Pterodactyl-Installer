#!/bin/bash
#!/usr/bin/env bash

########################################################################
#                                                                      #
#            Pterodactyl Installer, Updater, Remover and More          #
#            Copyright 2022, Malthe K, <me@malthe.cc> hej              # 
# https://github.com/guldkage/Pterodactyl-Installer/blob/main/LICENSE  #
#                                                                      #
#  This script is not associated with the official Pterodactyl Panel.  #
#  You may not remove this line                                        #
#                                                                      #
########################################################################

### VARIABLES ###

SSL_CONFIRM=""
AGREEWINGS=""
SSLCONFIRM=""
SSLSTATUS=""
SSLSWITCH=""
EMAILSWITCHDOMAINS=""
FQDN=""
UFW=""
AGREE=""
PANELUPDATE=""
LASTNAME=""
FIRSTNAME=""
USERNAME=""
PASSWORD=""
WEBSERVER=""
SSLSTATUSPHPMYADMIN=""
FQDNPHPMYADMIN=""
SSL_CONFIRM_PHPMYADMIN=""
AGREEPHPMYADMIN=""
PHPMYADMINEMAIL=""
DOMAINSWITCH=""
SSLSWTICH=""
IP=""
DOMAIN=""
dist="$(. /etc/os-release && echo "$ID")"

WINGSFQDN=""
WINGSEMAIL=""

### OUTPUTS ###

output(){
    echo -e '\e[36m'"$1"'\e[0m';
}

function trap_ctrlc ()
{
    output "Bye!"
    exit 2
}
trap "trap_ctrlc" 2

warning(){
    echo -e '\e[31m'"$1"'\e[0m';
}

### CHECKS ###

if [[ $EUID -ne 0 ]]; then
    output ""
    output "* ERROR *"
    output ""
    output "* Sorry, but you need to be root to run this script."
    output "* Most of the time this can be done by typing sudo su in your terminal"
    exit 1
fi

if ! [ -x "$(command -v curl)" ]; then
    output ""
    output "* ERROR *"
    output ""
    output "cURL is required to run this script."
    output "To proceed, please install cURL on your machine."
    output ""
    output "Debian based systems: apt install curl"
    output "CentOS: yum install curl"
    exit 1
fi

### PHPMyAdmin Install Complete ###

phpmyadminweb(){
    if  [ "$SSLSTATUSPHPMYADMIN" =  "true" ]; then
        rm -rf /etc/nginx/sites-enabled/default
        curl -o /etc/nginx/sites-enabled/phpmyadmin.conf https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/phpmyadmin-ssl.conf
        sed -i -e "s@<domain>@${FQDNPHPMYADMIN}@g" /etc/nginx/sites-enabled/phpmyadmin.conf
        systemctl stop nginx || exit || output "An error occurred. NGINX is not installed." || exit
        certbot certonly --standalone -d $FQDNPHPMYADMIN --staple-ocsp --no-eff-email -m $PHPMYADMINEMAIL --agree-tos || exit || output "An error occurred. Certbot not installed." || exit
        systemctl start nginx || exit || output "An error occurred. NGINX is not installed." || exit

        apt install mariadb-server
        PHPMYADMIN_USER=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1`
        mysql -u root -e "CREATE USER 'admin'@'localhost' IDENTIFIED BY '$PHPMYADMIN_USER';" && mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO 'admin'@'localhost' WITH GRANT OPTION;"

        clear
        output ""
        output "* PHPMYADMIN SUCCESSFULLY INSTALLED *"
        output ""
        output "Thank you for using the script. Remember to give it a star."
        output "URL: https://$FQDNPHPMYADMIN"
        output ""
        output "Details for admin account:"
        output "Username: admin"
        output "Password: $PHPMYADMIN_USER"
        fi
    if  [ "$SSLSTATUSPHPMYADMIN" =  "false" ]; then
        rm -rf /etc/nginx/sites-enabled/default || exit || output "An error occurred. NGINX is not installed." || exit
        curl -o /etc/nginx/sites-enabled/phpmyadmin.conf https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/phpmyadmin.conf || exit || output "An error occurred. cURL is not installed." || exit
        sed -i -e "s@<domain>@${FQDNPHPMYADMIN}@g" /etc/nginx/sites-enabled/phpmyadmin.conf || exit || output "An error occurred. NGINX is not installed." || exit
        systemctl restart nginx || exit || output "An error occurred. NGINX is not installed." || exit

        apt install mariadb-server
        PHPMYADMIN_USER=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1`
        mysql -u root -e "CREATE USER 'admin'@'localhost' IDENTIFIED BY '$PHPMYADMIN_USER';" && mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO 'admin'@'localhost' WITH GRANT OPTION;"

        clear
        output ""
        output "* PHPMYADMIN SUCCESSFULLY INSTALLED *"
        output ""
        output "Thank you for using the script. Remember to give it a star."
        output "URL: http://$FQDNPHPMYADMIN"
        output ""
        output "Details for admin account:"
        output "Username: admin"
        output "Password: $PHPMYADMIN_USER"
        fi
}

### PHPMyAdmin Install ###

phpmyadmininstall(){
    output ""
    output "Starting the installation of PHPMyAdmin"
    output "While the script is doing its work, please do not abort the installation. This can lead to issues on your machine."
    output "Instead, let the script install PHPMyAdmin. Then uninstall it after if you have changed your mind."
    sleep 1s
    if  [ "$dist" =  "ubuntu" ]; then
        apt install nginx certbot -y
        mkdir /var/www/phpmyadmin && cd /var/www/phpmyadmin || exit || output "An error occurred. Could not create directory." || exit
        LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
        apt -y install php8.1 php8.1-{cli,gd,mysql,pdo,mbstring,tokenizer,bcmath,xml,fpm,curl,zip}
        wget https://files.phpmyadmin.net/phpMyAdmin/5.2.0/phpMyAdmin-5.2.0-all-languages.tar.gz
        tar xzf phpMyAdmin-5.2.0-all-languages.tar.gz
        mv /var/www/phpmyadmin/phpMyAdmin-5.2.0-all-languages/* /var/www/phpmyadmin
        chown -R www-data:www-data *
        mkdir config
        chmod o+rw config
        cp config.sample.inc.php config/config.inc.php
        chmod o+w config/config.inc.php
        rm -rf /var/www/phpmyadmin/config
        phpmyadminweb
        fi
    if  [ "$dist" =  "debian" ]; then
        apt install nginx certbot -y
        mkdir /var/www/phpmyadmin && cd /var/www/phpmyadmin || exit || output "An error occurred. Could not create directory." || exit
        echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/sury-php.list
        curl -fsSL  https://packages.sury.org/php/apt.gpg | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/sury-keyring.gpg
        apt update -y

        apt-get update
        apt -y install software-properties-common curl ca-certificates gnupg2 sudo lsb-release
        apt-add-repository universe
        apt install -y php8.1 php8.1-{common,cli,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip}

        wget https://files.phpmyadmin.net/phpMyAdmin/5.2.0/phpMyAdmin-5.2.0-all-languages.tar.gz
        tar xzf phpMyAdmin-5.2.0-all-languages.tar.gz
        mv /var/www/phpmyadmin/phpMyAdmin-5.2.0-all-languages/* /var/www/phpmyadmin
        chown -R www-data:www-data *
        mkdir config
        chmod o+rw config
        cp config.sample.inc.php config/config.inc.php
        chmod o+w config/config.inc.php
        rm -rf /var/www/phpmyadmin/config
        phpmyadminweb
        fi
}

continueanywayphpmyadmin(){
    output ""
    output "Do you want to continue anyway?"
    output "(Y/N):"
    read -r CONTINUE_ANYWAY_PHPMYADMIN

    if [[ "$CONTINUE_ANYWAY_PHPMYADMIN" =~ [Yy] ]]; then
        phpmyadmininstall
    fi
    if [[ "$CONTINUE_ANYWAY_PHPMYADMIN" =~ [Nn] ]]; then
        exit 1
    fi
}

fqdnphpmyadmin(){
    output ""
    output "* PHPMYADMIN URL * "
    output ""
    output "Enter your FQDN or IP"
    output "Make sure that your FQDN is pointed to your IP with an A record. If not the script will not be able to provide the webpage."
    read -r FQDNPHPMYADMIN
    [ -z "$FQDNPHPMYADMIN" ] && output "FQDN can't be empty."
    IP=$(dig +short myip.opendns.com @resolver2.opendns.com -4)
    DOMAIN=$(dig +short ${FQDNPHPMYADMIN})
    if [ "${IP}" != "${DOMAIN}" ]; then
        output ""
        output "Your FQDN does not resolve to the IP of current server."
        output "Please point your servers IP to your FQDN."
        continueanywayphpmyadmin
    else
        output "Your FQDN is pointed correctly. Continuing."
        phpmyadmininstall
    fi
}

phpmyadminemailsslyes(){
    output ""
    output "* EMAIL *"
    output ""
    warning "Read:"
    output "The script now asks for your email. It will be shared with Lets Encrypt to complete the SSL."
    output "If you do not agree, stop the script."
    warning ""
    output "Please enter your email"
    read -r PHPMYADMINEMAIL
    fqdnphpmyadmin
}

phpmyadminssl(){
    output ""
    output "* SSL * "
    output ""
    output "Do you want to use SSL for PHPMyAdmin? This requires a domain."
    output "(Y/N):"
    read -r SSL_CONFIRM_PHPMYADMIN

    if [[ "$SSL_CONFIRM_PHPMYADMIN" =~ [Yy] ]]; then
        SSLSTATUSPHPMYADMIN=true
        phpmyadminemailsslyes
        fi
    if [[ "$SSL_CONFIRM_PHPMYADMIN" =~ [Nn] ]]; then
        fqdnphpmyadmin
        SSLSTATUSPHPMYADMIN=false
        fi
}


startphpmyadmin(){
    output ""
    output "* AGREEMENT *"
    output ""
    output "The script will install PHPMYAdmin with the webserver NGINX."
    output "Do you want to continue?"
    output "(Y/N):"
    read -r AGREEPHPMYADMIN

    if [[ "$AGREEPHPMYADMIN" =~ [Yy] ]]; then
        phpmyadminssl
    fi
}

### Finish Panel Installation ###

finish(){
    clear
    warning ""
    warning "* PANEL SUCCESSFULLY INSTALLED *"
    warning ""
    warning "Thank you for using the script. Remember to give it a star."
    warning "The script has ended."
    warning "https://$FQDN or http://$FQDN to go to your Panel."
    warning ""
    warning "I hope you enjoy your new panel!"
    warning "Your login information for your new Panel:"
    warning ""
    warning "Email: $EMAIL"
    warning "Username: $USERNAME"
    warning "First Name: $FIRSTNAME"
    warning "Last Name: $LASTNAME"
    warning "Password: $USERPASSWORD"
    warning ""
    warning "You do not need to copy the password under here."
    warning "This password can also be seen in /var/www/pterodactyl/.env"
    warning "You will not use this password in your daily use,"
    warning "this script already configured it for you."
    warning ""
    warning "Database password: $DBPASSWORD"
    warning ""
    warning "Database Host for Nodes. If a server on your panel needs a database,"
    warning "it can be easily created through a database host"
    warning ""
    warning "Host: 127.0.0.1"
    warning "User: pterodactyluser"
    warning "Password: $DBPASSWORDHOST"
    warning ""
    warning "If you want to create databases on your Panel,"
    warning "you will need to insert this information into"
    warning "Your Admin Panel then Databases -> Create new"
    warning ""
    warning "Firewall:"
    warning "The Panel may not load if port 80 and 443 is not open."
    warning "Please check your firewall or rerun this script"
    warning "and select Firewall Configuration."
}

start(){
    output ""
    output "* AGREEMENT *"
    output ""
    output "The script will install Pterodactyl Panel, you will be asked for several things before installation."
    output "Do you agree to this?"
    output "(Y/N):"
    read -r AGREE

    if [[ "$AGREE" =~ [Yy] ]]; then
        AGREE=yes
        web
    fi
}

### WINGS ###

startwings(){
    output ""
    output "* AGREEMENT *"
    output ""
    output "The script will install Pterodactyl Wings."
    output "Do you want to continue?"
    output "(Y/N):"
    read -r AGREEWINGS

    if [[ "$AGREEWINGS" =~ [Yy] ]]; then
        AGREEWINGS=yes
        wingsfqdn
    fi
}

wingsfqdn(){
    output ""
    output "* FQDN *"
    output ""
    output "Would you like to install a SSL certificate for a FQDN?"
    output "(Y/N):"
    read -r WINGSFQDN

    if [[ "$WINGSFQDN" =~ [Yy] ]]; then
        WINGSFQDN=yes
        wingsemail
    fi
    if [[ "$WINGSFQDN" =~ [Nn] ]]; then
        WINGSFQDN=no
        wingsinstall
    fi
}

wingsemail(){
    output ""
    output "* EMAIL *"
    output ""
    warning "Read:"
    output "To generate your new FQDN certificate for Wings, your email address must be shared with Let's Encrypt."
    output "They will send you an email when your certificate is about to expire. A certificate lasts 90 days at a time and you can renew your certificates for free and easily, even with this script."
    output ""
    output "Therefore, enter your email. If you do not feel like giving your email, then the script can not continue. Press CTRL + C to exit."
    read -r WINGSEMAIL
    wingsfqdn-ask
}

wingsfqdn-ask(){
    output ""
    output "* Wings FQDN * "
    output ""
    output "Enter FQDN for Wings."
    output "Make sure that your FQDN is pointed to your IP with an A record. If not the script will not be able to provide the service."
    read -r FQDNwingsurl
    [ -z "$FQDNwingsurl" ] && output "FQDN can't be empty."
    IP=$(dig +short myip.opendns.com @resolver2.opendns.com -4)
    DOMAIN=$(dig +short ${FQDNwingsurl})
    if [ "${IP}" != "${DOMAIN}" ]; then
        output ""
        output "Your FQDN does not resolve to the IP of current server."
        output "Please point your servers IP to your FQDN."
        output ""
        output "This error can be false positive. The script is continuing in 10 seconds.."
        sleep 10s
        apt install certbot
        systemctl stop nginx
        certbot certonly --standalone -d $FQDNwingsurl --staple-ocsp --no-eff-email -m $WINGSEMAIL --agree-tos
        systemctl start nginx
        wingsinstall
    else
        output "Your FQDN is pointed correctly. Continuing."
        apt install certbot
        systemctl stop nginx
        certbot certonly --standalone -d $FQDNwingsurl --staple-ocsp --no-eff-email -m $WINGSEMAIL --agree-tos
        systemctl start nginx
        wingsinstall
    fi
}

wingsinstall(){
    output "Installing..."
    if  [ "$dist" =  "ubuntu" ] || [ "$dist" =  "debian" ]; then
        curl -sSL https://get.docker.com/ | CHANNEL=stable bash
        systemctl enable --now docker

        mkdir -p /etc/pterodactyl || exit || output "An error occurred. Could not create directory." || exit
        apt-get -y install curl tar unzip
        curl -L -o /usr/local/bin/wings "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_$([[ "$(uname -m)" == "x86_64" ]] && echo "amd64" || echo "arm64")"
        curl -o /etc/systemd/system/wings.service https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/wings.service
        chmod u+x /usr/local/bin/wings
        clear
        output ""
        output "* WINGS SUCCESSFULLY INSTALLED *"
        output ""
        output "Thank you for using the script. Remember to give it a star."
        output "All you need is to set up Wings."
        output "To do this, create the node on your Panel, then press under Configuration,"
        output "press Generate Token, paste it on your server and then type systemctl enable wings --now"
        output ""
    fi
}

### Webserver ###

webserver(){
    if  [ "$SSLSTATUS" =  "true" ]; then
        command 1> /dev/null
        rm -rf /etc/nginx/sites-enabled/default
        output "Configuring webserver..."
        curl -o /etc/nginx/sites-enabled/pterodactyl.conf https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/pterodactyl-nginx-ssl.conf
        sed -i -e "s@<domain>@${FQDN}@g" /etc/nginx/sites-enabled/pterodactyl.conf
        systemctl stop nginx
        certbot certonly --standalone -d $FQDN --staple-ocsp --no-eff-email -m $EMAIL --agree-tos
        systemctl start nginx
        finish
        fi
    if  [ "$SSLSTATUS" =  "false" ]; then
        command 1> /dev/null
        rm -rf /etc/nginx/sites-enabled/default
        output "Configuring webserver..."
        curl -o /etc/nginx/sites-enabled/pterodactyl.conf https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/pterodactyl-nginx.conf
        sed -i -e "s@<domain>@${FQDN}@g" /etc/nginx/sites-enabled/pterodactyl.conf
        systemctl restart nginx
        finish
        fi
}

### Permissions ###

extra(){
    output "Changing permissions..."
    if  [ "$dist" =  "ubuntu" ] || [ "$dist" =  "debian" ]; then
        chown -R www-data:www-data /var/www/pterodactyl/*
        curl -o /etc/systemd/system/pteroq.service https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/pteroq.service
        (crontab -l ; echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1")| crontab -
        sudo systemctl enable --now redis-server
        sudo systemctl enable --now pteroq.service
        webserver
    elif  [ "$dist" =  "fedora" ] ||  [ "$dist" =  "centos" ] || [ "$dist" =  "rhel" ] || [ "$dist" =  "rocky" ] || [ "$dist" = "almalinux" ]; then
        chown -R nginx:nginx /var/www/pterodactyl/*
        curl -o /etc/systemd/system/pteroq.service https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/pteroq-centos.service
        (crontab -l ; echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1")| crontab -
        sudo systemctl enable --now redis-server
        sudo systemctl enable --now pteroq.service
        webserver
    fi
}

### Confiration of the Panel ###

configuration(){
    output "Setting up the Panel... Can be a long process."
    sleep 1s
    [ "$SSLSTATUS" == true ] && appurl="https://$FQDN"
    [ "$SSLSTATUS" == false ] && appurl="http://$FQDN"
    DBPASSWORD=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1`
    USERPASSWORD=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1`
    DBPASSWORDHOST=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1`
    mysql -u root -e "CREATE USER 'pterodactyluser'@'127.0.0.1' IDENTIFIED BY '$DBPASSWORDHOST';" && mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO 'pterodactyluser'@'127.0.0.1' WITH GRANT OPTION;"
    mysql -u root -e "CREATE USER 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '$DBPASSWORD';" && mysql -u root -e "CREATE DATABASE panel;" &&mysql -u root -e "GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'127.0.0.1' WITH GRANT OPTION;" && mysql -u root -e "FLUSH PRIVILEGES;"
    php artisan p:environment:setup --author="$EMAIL" --url="$appurl" --timezone="America/New_York" --cache="redis" --session="redis" --queue="redis" --redis-host="localhost" --redis-pass="null" --redis-port="6379" --settings-ui=true
    php artisan p:environment:database --host="127.0.0.1" --port="3306" --database="panel" --username="pterodactyl" --password="$DBPASSWORD"
    output "Migrating database.. this may take some time."
    php artisan migrate --seed --force
    php artisan p:user:make --email="$EMAIL" --username="$USERNAME" --name-first="$FIRSTNAME" --name-last="$LASTNAME" --password="$USERPASSWORD" --admin=1
    extra
}

composer(){
    output ""
    output "* INSTALLATION * "
    output ""
    output "Installing Composer.. This is used to operate the Panel."
    if  [ "$dist" =  "ubuntu" ] || [ "$dist" =  "debian" ]; then
        curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
        files
    elif  [ "$dist" =  "fedora" ] ||  [ "$dist" =  "centos" ] || [ "$dist" =  "rhel" ] || [ "$dist" =  "rocky" ] || [ "$dist" = "almalinux" ]; then
        files
    fi
}

### Downloading files for Pterodactyl ###

files(){
    output "Downloading required files for Pterodactyl.."
    sleep 1s
    mkdir /var/www/pterodactyl
    cd /var/www/pterodactyl
    curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
    tar -xzvf panel.tar.gz
    chmod -R 755 storage/* bootstrap/cache/
    cp .env.example .env
    command composer install --no-dev --optimize-autoloader --no-interaction
    php artisan key:generate --force
    configuration
}

### haven't changed yet ###

database(){
    firstname
}

### Installing required Packages for Pterodactyl ###

required(){
    output ""
    output "* INSTALLATION * "
    output ""
    output "Installing packages..."
    output "This may take a while."
    output ""
    if  [ "$dist" =  "ubuntu" ]; then
        apt-get update
        apt -y install software-properties-common curl apt-transport-https ca-certificates gnupg
        output "Installing dependencies"
        sleep 1s
        LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
        curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor --batch --yes -o /usr/share/keyrings/redis-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list
        
        curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash
        apt update
        apt-add-repository universe
        apt install certbot python3-certbot-nginx -y
        output "Installing PHP, MariaDB and NGINX"
        sleep 1s
        apt -y install php8.1 php8.1-{cli,gd,mysql,pdo,mbstring,tokenizer,bcmath,xml,fpm,curl,zip} mariadb-server nginx tar unzip git redis-server
        database
    elif  [ "$dist" =  "debian" ]; then
        apt-get update
        apt -y install software-properties-common curl ca-certificates gnupg2 sudo lsb-release
        output "Installing dependencies"
        sleep 1s
        echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/sury-php.list
        curl -fsSL  https://packages.sury.org/php/apt.gpg | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/sury-keyring.gpg
        curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list
        apt update -y
        
        apt-add-repository universe
        apt install certbot python3-certbot-nginx -y
        output "Installing PHP, MariaDB and NGINX"
        sleep 1s
        curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bas
        apt install -y php8.1 php8.1-{common,cli,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip} mariadb-server nginx tar unzip git redis-server
        database
    fi
}

begin(){
    output ""
    output "* INSTALLATION * "
    output ""
    output "Let's begin the installation!"
    output "Continuing in 3 seconds.."
    output 
    sleep 3s
    composer
}

### Pterodactyl Admin User ###

password(){
    begin
}


username(){
    output ""
    output "Please enter username for Admin Account."
    output "You will login with either username or your email."
    read -r USERNAME
    password
}


lastname(){
    output ""
    output "Please enter last name for Admin Account."
    read -r LASTNAME
    username
}

firstname(){
    output ""
    output "* ACCOUNT CREATION * "
    output ""
    output "In order to create an account on the Panel, we need some more information."
    output "You do not need to type in real first and last name."
    output ""
    output "Please enter first name for Admin Account."
    read -r FIRSTNAME
    lastname
}

### FQDN ###

continueanyway(){
    output ""
    output "This error can sometimes be false positive."
    output "Do you want to continue anyway?"
    output "(Y/N):"
    read -r CONTINUE_ANYWAY

    if [[ "$CONTINUE_ANYWAY" =~ [Yy] ]]; then
        required
    fi
    if [[ "$CONTINUE_ANYWAY" =~ [Nn] ]]; then
        exit 1
    fi
}

fqdn(){
    output ""
    output "* PANEL URL * "
    output ""
    output "Enter your FQDN or IP for your Panel. You will access the Panel with this."
    output "Make sure that your FQDN is pointed to your IP with an A record. If not the script will not be able to provide the webpage."
    read -r FQDN
    [ -z "$FQDN" ] && output "FQDN can't be empty."
    IP=$(dig +short myip.opendns.com @resolver2.opendns.com -4)
    DOMAIN=$(dig +short ${FQDN})
    if [ "${IP}" != "${DOMAIN}" ]; then
        output ""
        output "Your FQDN does not resolve to the IP of current server."
        output "Please point your servers IP to your FQDN."
        continueanyway
    else
        output "Your FQDN is pointed correctly. Continuing."
        required
    fi
}

### SSL ###

ssl(){
    output ""
    output "* SSL * "
    output ""
    output "Do you want to use SSL? It requires a domain."
    output "SSL encrypts all data compared to HTTP which does not. SSL is always recommended."
    output "If you do not have a domain and want to use an IP to access, please type N, as you can not have SSL on a IP this easy."
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

### SSL select yes ##

emailsslyes(){
    output ""
    output "* EMAIL *"
    output ""
    warning "Read:"
    output "The script now asks for your email. It will be shared with Lets Encrypt to complete the SSL. It will also be used to setup the Panel."
    output "If you do not agree, stop the script."
    warning ""
    output "Please enter your email"
    read -r EMAIL
    fqdn
}

### SSL select no ###

emailsslno(){
    output ""
    output "* EMAIL *"
    output ""
    warning "Read:"
    output "The script now asks for your email. It will be used to setup the Panel."
    output "If you do not agree, stop the script."
    warning ""
    output "Please enter your email"
    read -r EMAIL
    fqdn
}

### Webserver selection ###

web(){
    output ""
    output "* WEBSERVER * "
    output ""
    output "What webserver would you like to use?"
    output "[1] NGINX"
    output ""
    read -r option
    case $option in
        1 ) option=1
            output "Selected: NGINX"
            ssl
            ;;
        * ) output ""
            warning "Script will exit. Unexpected output."
            sleep 1s
            options
    esac
}

### Update Panel ###

updatepanel(){
    output ""
    output "* UPDATE PANEL *"
    output ""
    output "Please use the official Docs instead"
}

confirmupdatepanel(){
    cd /var/www/pterodactyl || exit || output "Pterodactyl Directory (/var/www/pterodactyl) does not exist." || exit
    php artisan down || exit || output "WARNING! The script ran into an error and stopped the script for security. The script is not responsible for any damage." || exit
    curl -L https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz | tar -xzv || exit || output "WARNING! The script ran into an error and stopped the script for security. The script is not responsible for any damage." || exit
    chmod -R 755 storage/* bootstrap/cache || exit || output "WARNING! The script ran into an error and stopped the script for security. The script is not responsible for any damage." || exit
    composer install --no-dev --optimize-autoloader -n || exit || output "WARNING! The script ran into an error and stopped the script for security. The script is not responsible for any damage." || exit
    php artisan view:clear || exit || output "WARNING! The script ran into an error and stopped the script for security. The script is not responsible for any damage." || exit
    php artisan config:clear || exit || output "WARNING! The script ran into an error and stopped the script for security. The script is not responsible for any damage." || exit
    php artisan migrate --force || exit || output "WARNING! The script ran into an error and stopped the script for security. The script is not responsible for any damage." || exit
    chown -R www-data:www-data /var/www/pterodactyl/* || exit || output "WARNING! The script ran into an error and stopped the script for security. The script is not responsible for any damage." || exit
    php artisan queue:restart || exit || output "WARNING! The script ran into an error and stopped the script for security. The script is not responsible for any damage." || exit
    php artisan up || exit || output "WARNING! The script ran into an error and stopped the script for security. The script is not responsible for any damage." || exit
    output ""
    output "* SUCCESSFULLY UPDATED *"
    output ""
    output "Pterodactyl Panel has successfully updated."
}

### Update Wings ###

updatewings(){
    if ! [ -x "$(command -v wings)" ]; then
        echo "Wings is required to update both."
    fi
    curl -L -o /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64
    chmod u+x /usr/local/bin/wings
    systemctl restart wings
    output ""
    output "* SUCCESSFULLY UPDATED *"
    output ""
    output "Wings has successfully updated."
}

### Update Pterodactyl and Wings ###

updateboth(){
    if ! [ -x "$(command -v wings)" ]; then
        echo "Wings is required to update both."
    fi
    cd /var/www/pterodactyl || exit || warning "Pterodactyl Directory (/var/www/pterodactyl) does not exist!"
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
    output "* SUCCESSFULLY UPDATED *"
    output ""
    output "Pterodactyl Panel and Wings has successfully updated."
}

### Uninstall Panel ###

uninstallpanel(){
    output ""
    output "Do you really want to delete Pterodactyl Panel? All files & configurations will be deleted. You CANNOT get your files back."
    output "(Y/N):"
    read -r UNINSTALLPANEL

    if [[ "$UNINSTALLPANEL" =~ [Yy] ]]; then
        sudo rm -rf /var/www/pterodactyl || exit || warning "Panel is not installed!" # Removes panel files
        sudo rm /etc/systemd/system/pteroq.service # Removes pteroq service worker
        sudo unlink /etc/nginx/sites-enabled/pterodactyl.conf # Removes nginx config (if using nginx)
        sudo unlink /etc/apache2/sites-enabled/pterodactyl.conf # Removes Apache config (if using apache)
        sudo rm -rf /var/www/pterodactyl # Removing panel files
        systemctl restart nginx && systemctl restart apache2
        output ""
        output "* PANEL SUCCESSFULLY UNINSTALLED *"
        output ""
        output "Your panel has been removed. You are now left with your database and web server."
        output "If you want to delete your database, simply go into MySQL and type DROP DATABASE (database name);"
        output "Pterodactyl Panel has successfully been removed."
    fi
}

### Uninstall Wings ###

uninstallwings(){
    output ""
    output "Do you really want to delete Pterodactyl Wings? All game servers & configurations will be deleted. You CANNOT get your files back."
    output "(Y/N):"
    read -r UNINSTALLWINGS

    if [[ "$UNINSTALLWINGS" =~ [Yy] ]]; then
        {
        sudo systemctl stop wings # Stops wings
        sudo rm -rf /var/lib/pterodactyl # Removes game servers and backup files
        sudo rm -rf /etc/pterodactyl  || exit || warning "Pterodactyl Wings not installed!"
        sudo rm /usr/local/bin/wings || exit || warning "Wings is not installed!" # Removes wings
        sudo rm /etc/systemd/system/wings.service # Removes wings service file
        } &> /dev/null
        output ""
        output "* WINGS SUCCESSFULLY UNINSTALLED *"
        output ""
        output "Wings has been removed."
        output ""
    fi
}

### Firewall ###

http(){
    output ""
    output "* FIREWALL CONFIGURATION * "
    output ""
    output "HTTP & HTTPS firewall rule has been applied."
    if  [ "$dist" =  "ubuntu" ] ||  [ "$dist" =  "debian" ]; then
        apt install ufw -Y
        ufw allow 80
        ufw allow 443
    fi
}

pterodactylports(){
    output ""
    output "* FIREWALL CONFIGURATION * "
    output ""
    output "All Pterodactyl Ports firewall rule has been applied."
    if  [ "$dist" =  "ubuntu" ] ||  [ "$dist" =  "debian" ]; then
        apt install ufw -y
        ufw allow 80
        ufw allow 443
        ufw allow 8080
        ufw allow 2022
    fi
}

mainmysql(){
    output ""
    output "* FIREWALL CONFIGURATION * "
    output ""
    output "MySQL firewall rule has been applied."
    if  [ "$dist" =  "ubuntu" ] ||  [ "$dist" =  "debian" ]; then
        apt install ufw -y
        ufw alllow 3306
    fi
}

allfirewall(){
    output ""
    output "* FIREWALL CONFIGURATION * "
    output ""
    output "All of them firewall rule has been applied."
    if  [ "$dist" =  "ubuntu" ] ||  [ "$dist" =  "debian" ]; then
        apt install ufw -y
        ufw allow 80
        ufw allow 443
        ufw allow 8080
        ufw allow 2022
        ufw allow 3306
    fi
}

### Switch Domains ###

switch(){
    if  [ "$SSLSWITCH" =  "true" ]; then
        output ""
        output "* SWITCH DOMAINS * "
        output ""
        output "The script is now changing your Pterodactyl Domain. This may take a couple seconds for the SSL part, as SSL certificates are being generated."
        rm /etc/nginx/sites-enabled/pterodactyl.conf
        curl -o /etc/nginx/sites-enabled/pterodactyl.conf https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/pterodactyl-nginx-ssl.conf || exit || warning "Pterodactyl Panel not installed!"
        sed -i -e "s@<domain>@${DOMAINSWITCH}@g" /etc/nginx/sites-enabled/pterodactyl.conf
        systemctl stop nginx
        certbot certonly --standalone -d $DOMAINSWITCH --staple-ocsp --no-eff-email -m $EMAILSWITCHDOMAINS --agree-tos || exit || warning "Errors accured."
        systemctl start nginx
        output ""
        output ""
        output "* SWITCH DOMAINS * "
        output ""
        output "Your domain has been switched to $DOMAINSWITCH"
        output "This script does not update your APP URL, you can"
        output "update it in /var/www/pterodactyl/.env"
        output ""
        output "If using Cloudflare certifiates for your Panel, please read this:"
        output "The script uses Lets Encrypt to complete the change of your domain,"
        output "if you normally use Cloudflare Certificates,"
        output "you can change it manually in its config which is in the same place as before."
        output ""
        fi
    if  [ "$SSLSWITCH" =  "false" ]; then
        output ""
        output "* SWITCH DOMAINS * "
        output ""
        output "Switching your domain.. This wont take long!"
        rm /etc/nginx/sites-enabled/pterodactyl.conf || exit || output "An error occurred. Could not delete file." || exit
        curl -o /etc/nginx/sites-enabled/pterodactyl.conf https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/pterodactyl-nginx.conf || exit || warning "Pterodactyl Panel not installed!"
        sed -i -e "s@<domain>@${DOMAINSWITCH}@g" /etc/nginx/sites-enabled/pterodactyl.conf
        systemctl restart nginx
        output ""
        output ""
        output "* SWITCH DOMAINS * "
        output ""
        output "Your domain has been switched to $DOMAINSWITCH"
        output "This script does not update your APP URL, you can"
        output "update it in /var/www/pterodactyl/.env"
        fi
}

switchemail(){
    output ""
    output "* EMAIL *"
    output ""
    warning "Read:"
    output "To install your new domain certificate to your Panel, your email address must be shared with Let's Encrypt."
    output "They will send you an email when your certificate is about to expire. A certificate lasts 90 days at a time and you can renew your certificates for free and easily, even with this script."
    output ""
    output "When you created your certificate for your panel before, they also asked you for your email address. It's the exact same thing here, with your new domain."
    output "Therefore, enter your email. If you do not feel like giving your email, then the script can not continue. Press CTRL + C to exit."
    output ""
    warning "Please enter your email"

    read -r EMAILSWITCHDOMAINS
    switch
}

switchssl(){
    output ""
    output "* SWITCH DOMAINS * "
    output ""
    output "Select the one that describes your panel:"
    warning "[1] I have a Panel with SSL"
    warning "[2] I do not have a Panel with SSL"
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
        * ) output ""
            output "Please enter a valid option."
    esac
}

switchdomains(){
    output ""
    output "* SWITCH DOMAINS * "
    output ""
    output "Please enter the domain (panel.mydomain.ltd) you want to switch to."
    read -r DOMAINSWITCH
    switchssl
}

### Renews certificates ###

rewnewcertificates(){
    {
    sudo certbot renew
    } &> /dev/null
    output ""
    output "* RENEW CERTIFICATES * "
    output ""
    output "All Let's Encrypt certificates that were ready to be renewed have been renewed."
}

### Firewall options ###

configureufw(){
    output ""
    output "* FIREWALL CONFIGURATION * "
    output ""
    output "Available firewall configurations:"
    warning "[1] HTTP & HTTPS"
    warning "[2] All Pterodactyl Ports"
    warning "[3] MySQL"
    warning "[4] All of them"
    read -r ufw
    case $ufw in
        1 ) ufw=1
            http
            ;;
        2 ) ufw=2
            pterodactlports
            ;;
        3 ) ufw=3
            mainmysql
            ;;
        4 ) ufw=4
            allfirewall
            ;;
        * ) output ""
            output "Please enter a valid option."
    esac
}

### OS Check ###

oscheck(){
    output "* Checking your OS.."
    if  [ "$dist" =  "ubuntu" ] ||  [ "$dist" =  "debian" ]; then
        output "* Your OS, $dist, is fully supported. Continuing.."
        output ""
        options
    else
        output "* Your OS, $dist, is not supported!"
        output "* Exiting..."
        exit 1
    fi
}

### Options ###

options(){
    output "Please select your installation option:"
    warning "[1] Install Panel. | Installs latest version of Pterodactyl Panel"
    warning "[2] Install Wings. | Installs latest version of Pterodactyl Wings."
    warning "[3] Install PHPMyAdmin. | Installs PHPMyAdmin. (Installs using NGINX)"
    warning ""
    warning "[4] Update Panel. | Updates your Panel to the latest version. May remove addons and themes."
    warning "[5] Update Wings. | Updates your Wings to the latest version."
    warning ""
    warning "[6] Uninstall Wings. | Uninstalls your Wings. This will also remove all of your game servers."
    warning "[7] Uninstall Panel. | Uninstalls your Panel. You will only be left with your database and web server."
    warning ""
    warning "[8] Renew Certificates | Renews all Lets Encrypt certificates on this machine."
    warning "[9] Configure Firewall | Configure UFW to your liking."
    warning "[10] Switch Pterodactyl Domain | Changes your Pterodactyl Domain."
    read -r option
    case $option in
        1 ) option=1
            start
            ;;
        2 ) option=2
            startwings
            ;;
        3 ) option=3
            startphpmyadmin
            ;;
        4 ) option=4
            updatepanel
            ;;
        5 ) option=5
            updatewings
            ;;
        6 ) option=6
            uninstallwings
            ;;
        7 ) option=7
            uninstallpanel
            ;;
        8 ) option=8
            renewcertificates
            ;;
        9 ) option=9
            configureufw
            ;;
        10 ) option=10
            switchdomains
            ;;
        * ) output ""
            output "Please enter a valid option from 1-10"
    esac
}

### Start ###

clear
output ""
warning "Pterodactyl Installer @ v2.0"
warning "Copyright 2022, Malthe K, <me@malthe.cc>"
warning "https://github.com/guldkage/Pterodactyl-Installer"
warning ""
warning "This script is not responsible for any damages. The script has been tested several times without issues."
warning "Support is not given."
warning "This script will only work on a fresh installation. Proceed with caution if not having a fresh installation"
warning ""
warning "You are very welcome to report errors or bugs about this script. These can be reported on GitHub."
warning "Thanks in advance!"
warning ""
oscheck

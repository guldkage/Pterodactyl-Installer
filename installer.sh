

#!/bin/bash
#!/usr/bin/env bash

########################################################################
#                                                                      #
#            Pterodactyl Installer, Updater, Remover and More          #
#            Copyright 2023, Malthe K, <me@malthe.cc> hej              # 
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
    echo "Debian based systems: apt install curl"
    echo "CentOS: yum install curl"
    exit 1
fi

### Pterodactyl Panel Installation ###

send_summary() {
    clear
    echo ""
    
    if [ -d "/var/www/pterodactyl" ]; then
        warning "[!] WARNING: Pterodactyl is already installed. This script will fail!"
    fi

    echo ""
    echo "[!] Summary:"
    echo "    Panel URL: $FQDN"
    echo "    Webserver: $WEBSERVER"
    echo "    Email: $EMAIL"
    echo "    SSL: $SSLSTATUS"
    echo "    Username: $USERNAME"
    echo "    First name: $FIRSTNAME"
    echo "    Last name: $LASTNAME"
    if [ -n "$USERPASSWORD" ]; then
    echo "    Password: $(printf "%0.s*" $(seq 1 ${#USERPASSWORD}))"
    else
        echo "    Password:"
    fi
    echo ""
    
    if [ "$dist" = "centos" ] && [ "$version" = "7" ]; then
        echo "    You are running CentOS 7. NGINX will be selected as the webserver."
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
    echo "    Panel URL: $FQDN"
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
    echo "    These credentials has been saved in a file called" 
    echo "    panel_credentials.txt in your current directory"
    echo ""

    if [ "$INSTALLBOTH" = "true" ]; then
        WINGSNOQUESTIONS=true
        wings
    fi

    if [ "$INSTALLBOTH" = "false" ]; then
        WINGSNOQUESTIONS=false
        echo "    Would you like to install Wings too? (Y/N)"
        read -r -p "Do you want to install Wings? [Y/n]: " WINGS_ON_PANEL

        if [[ "$WINGS_ON_PANEL" =~ [Yy] ]]; then
            wings
        fi
        
        if [[ "$WINGS_ON_PANEL" =~ [Nn] ]]; then
            echo "Bye!"
            exit 0
        fi
    fi
}

panel_webserver(){
    send_summary
    echo "[!] Select Webserver"
    echo "    (1) NGINX"
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
    esac
}

panel_conf(){
    [ "$SSLSTATUS" == true ] && appurl="https://$FQDN"
    [ "$SSLSTATUS" == false ] && appurl="http://$FQDN"
    mariadb -u root -e "CREATE USER 'pterodactyluser'@'127.0.0.1' IDENTIFIED BY '$DBPASSWORDHOST';" && mariadb -u root -e "GRANT ALL PRIVILEGES ON *.* TO 'pterodactyluser'@'127.0.0.1' WITH GRANT OPTION;"
    mariadb -u root -e "CREATE USER 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '$DBPASSWORD';" && mariadb -u root -e "CREATE DATABASE panel;" && mariadb -u root -e "GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'127.0.0.1' WITH GRANT OPTION;" && mariadb -u root -e "FLUSH PRIVILEGES;"
    php artisan p:environment:setup --author="$EMAIL" --url="$appurl" --timezone="CET" --telemetry=false --cache="redis" --session="redis" --queue="redis" --redis-host="localhost" --redis-pass="null" --redis-port="6379" --settings-ui=true
    php artisan p:environment:database --host="127.0.0.1" --port="3306" --database="panel" --username="pterodactyl" --password="$DBPASSWORD"
    php artisan migrate --seed --force
    php artisan p:user:make --email="$EMAIL" --username="$USERNAME" --name-first="$FIRSTNAME" --name-last="$LASTNAME" --password="$USERPASSWORD" --admin=1
    chown -R www-data:www-data /var/www/pterodactyl/*
    if [ "$dist" = "centos" ]; then
        chown -R nginx:nginx /var/www/pterodactyl/*
         systemctl enable --now redis
        fi
    curl -o /etc/systemd/system/pteroq.service https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/pteroq.service
    (crontab -l ; echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1")| crontab -
     systemctl enable --now redis-server
     systemctl enable --now pteroq.service

    if [ "$dist" = "centos" ] && { [ "$version" = "7" ] || [ "$SSLSTATUS" = "true" ]; }; then
         yum install epel-release -y
         yum install certbot -y
        curl -o /etc/nginx/conf.d/pterodactyl.conf https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/pterodactyl-nginx-ssl.conf
        sed -i -e "s@<domain>@${FQDN}@g" /etc/nginx/conf.d/pterodactyl.conf
        sed -i -e "s@/run/php/php8.1-fpm.sock@/var/run/php-fpm/pterodactyl.sock@g" /etc/nginx/conf.d/pterodactyl.conf
        systemctl stop nginx
        certbot certonly --standalone -d $FQDN --staple-ocsp --no-eff-email -m $EMAIL --agree-tos
        systemctl start nginx
        finish
        fi
    if [ "$dist" = "centos" ] && { [ "$version" = "7" ] || [ "$SSLSTATUS" = "false" ]; }; then
        curl -o /etc/nginx/conf.d/pterodactyl.conf https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/pterodactyl-nginx.conf
        sed -i -e "s@<domain>@${FQDN}@g" /etc/nginx/conf.d/pterodactyl.conf
        sed -i -e "s@/run/php/php8.1-fpm.sock@/var/run/php-fpm/pterodactyl.sock@g" /etc/nginx/conf.d/pterodactyl.conf
        systemctl restart nginx
        finish
        fi
    if [ "$SSLSTATUS" = "true" ] && [ "$WEBSERVER" = "NGINX" ]; then
        rm -rf /etc/nginx/sites-enabled/default
        curl -o /etc/nginx/sites-enabled/pterodactyl.conf https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/pterodactyl-nginx-ssl.conf
        sed -i -e "s@<domain>@${FQDN}@g" /etc/nginx/sites-enabled/pterodactyl.conf

        systemctl stop nginx
        certbot certonly --standalone -d $FQDN --staple-ocsp --no-eff-email -m $EMAIL --agree-tos
        systemctl start nginx
        finish
        fi
    if [ "$SSLSTATUS" = "true" ] && [ "$WEBSERVER" = "Apache" ]; then
        a2dissite 000-default.conf && systemctl reload apache2
        curl -o /etc/apache2/sites-enabled/pterodactyl.conf https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/pterodactyl-apache-ssl.conf
        sed -i -e "s@<domain>@${FQDN}@g" /etc/apache2/sites-enabled/pterodactyl.conf
        apt install libapache2-mod-php
         a2enmod rewrite
         a2enmod ssl
        systemctl stop apache2
        certbot certonly --standalone -d $FQDN --staple-ocsp --no-eff-email -m $EMAIL --agree-tos
        systemctl start apache2
        finish
        fi
    if [ "$SSLSTATUS" = "false" ] && [ "$WEBSERVER" = "NGINX" ]; then
        rm -rf /etc/nginx/sites-enabled/default
        curl -o /etc/nginx/sites-enabled/pterodactyl.conf https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/pterodactyl-nginx.conf
        sed -i -e "s@<domain>@${FQDN}@g" /etc/nginx/sites-enabled/pterodactyl.conf
        systemctl restart nginx
        finish
        fi
    if [ "$SSLSTATUS" = "false" ] && [ "$WEBSERVER" = "Apache" ]; then
        a2dissite 000-default.conf && systemctl reload apache2
        curl -o /etc/apache2/sites-enabled/pterodactyl.conf https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/pterodactyl-apache.conf
        sed -i -e "s@<domain>@${FQDN}@g" /etc/apache2/sites-enabled/pterodactyl.conf
         a2enmod rewrite
        systemctl stop apache2
        systemctl start apache2
        finish
        fi
}

panel_install(){
    echo "" 
    if  [ "$dist" =  "ubuntu" ] && [ "$version" = "20.04" ]; then
        apt update
        apt -y install software-properties-common curl apt-transport-https ca-certificates gnupg
        LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
        curl -fsSL https://packages.redis.io/gpg |  gpg --dearmor --batch --yes -o /usr/share/keyrings/redis-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" |  tee /etc/apt/sources.list.d/redis.list
        curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup |  bash
        apt update
         add-apt-repository "deb http://archive.ubuntu.com/ubuntu $(lsb_release -sc) universe"
    fi
    if [ "$dist" = "debian" ] && [ "$version" = "11" ]; then
        apt update
        apt -y install software-properties-common curl ca-certificates gnupg2  lsb-release
        echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" |  tee /etc/apt/sources.list.d/sury-php.list
        curl -fsSL  https://packages.sury.org/php/apt.gpg |  gpg --dearmor -o /etc/apt/trusted.gpg.d/sury-keyring.gpg
        curl -fsSL https://packages.redis.io/gpg |  gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" |  tee /etc/apt/sources.list.d/redis.list
        apt update -y
        curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup |  bash
    fi
    if [ "$dist" = "debian" ] && [ "$version" = "12" ]; then
        apt update
        apt -y install software-properties-common curl ca-certificates gnupg2  lsb-release
         apt install -y apt-transport-https lsb-release ca-certificates wget
        wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
        echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" |  tee /etc/apt/sources.list.d/php.list
        curl -fsSL https://packages.redis.io/gpg |  gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" |  tee /etc/apt/sources.list.d/redis.list
        apt update -y
        curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup |  bash
    fi
    if [ "$dist" = "centos" ] && [ "$version" = "7" ]; then
        yum update -y
        yum install -y policycoreutils policycoreutils-python selinux-policy selinux-policy-targeted libselinux-utils setroubleshoot-server setools setools-console mcstrans -y

        curl -o /etc/yum.repos.d/mariadb.repo https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/mariadb.repo

        yum update -y
        yum install -y mariadb-server
        sed -i 's/character-set-collations = utf8mb4=uca1400_ai_ci/character-set-collations = utf8mb4=utf8mb4_general_ci/' /etc/mysql/mariadb.conf.d/50-server.cnf
        systemctl start mariadb
        systemctl enable mariadb
        systemctl restart mariadb

        yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
        yum -y install https://rpms.remirepo.net/enterprise/remi-release-7.rpm
        yum install -y yum-utils
        yum-config-manager --disable 'remi-php*'
        yum-config-manager --enable remi-php81

        yum update -y
        yum install -y php php-{common,fpm,cli,json,mysqlnd,mcrypt,gd,mbstring,pdo,zip,bcmath,dom,opcache}

        yum install -y zip unzip
        curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
        yum install -y nginx

        yum install -y --enablerepo=remi redis
        systemctl start redis
        systemctl enable redis

        setsebool -P httpd_can_network_connect 1
        setsebool -P httpd_execmem 1
        setsebool -P httpd_unified 1

        curl -o /etc/php-fpm.d/www-pterodactyl.conf https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/www-pterodactyl.conf
        systemctl enable php-fpm
        systemctl start php-fpm

        pause 0.5s
        mkdir /var
        mkdir /var/www
        mkdir /var/www/pterodactyl
        cd /var/www/pterodactyl
        curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/download/v1.11.5/panel.tar.gz
        tar -xzvf panel.tar.gz
        chmod -R 755 storage/* bootstrap/cache/
        cp .env.example .env
        command composer install --no-dev --optimize-autoloader --no-interaction --ignore-platform-reqs
        php artisan key:generate --force

        WEBSERVER=NGINX
        panel_conf
        fi

    apt update
    apt install certbot -y

    apt install -y mariadb-server tar unzip git redis-server
    sed -i 's/character-set-collations = utf8mb4=uca1400_ai_ci/character-set-collations = utf8mb4=utf8mb4_general_ci/' /etc/mysql/mariadb.conf.d/50-server.cnf
    systemctl restart mariadb
    apt -y install php8.1 php8.1-{cli,gd,mysql,pdo,mbstring,tokenizer,bcmath,xml,fpm,curl,zip}
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
    pause 0.5s
    mkdir /var
    mkdir /var/www
    mkdir /var/www/pterodactyl
    cd /var/www/pterodactyl
    curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/download/v1.11.5/panel.tar.gz
    tar -xzvf panel.tar.gz
    chmod -R 755 storage/* bootstrap/cache/
    cp .env.example .env
    command composer install --no-dev --optimize-autoloader --no-interaction
    php artisan key:generate --force
    if  [ "$WEBSERVER" =  "NGINX" ]; then
        apt install nginx -y
        panel_conf
    fi
    if  [ "$WEBSERVER" =  "Apache" ]; then
        apt install apache2 libapache2-mod-php8.1 -y
        panel_conf
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

panel_fqdn(){
    send_summary
    echo "[!] Please enter FQDN. You will access Panel with this."
    echo "[!] Example: panel.yourdomain.dk."
    read -r FQDN
    [ -z "$FQDN" ] && echo "FQDN can't be empty."
    IP=$(dig +short myip.opendns.com @resolver2.opendns.com -4)
    DOMAIN=$(dig +short ${FQDN})
    if [ "${IP}" != "${DOMAIN}" ]; then
        echo ""
        echo "Your FQDN does not resolve to the IP of this machine."
        echo "Continuing anyway in 10 seconds.. CTRL+C to stop."
        sleep 10s
        panel_ssl
    else
        panel_ssl
    fi
}

panel_ssl(){
    send_summary
    echo "[!] Do you want to use SSL for your Panel? This is recommended. (Y/N)"
    echo "[!] SSL is recommended for every panel."
    read -r SSL_CONFIRM

    if [[ "$SSL_CONFIRM" =~ [Yy] ]]; then
        SSLSTATUS=true
        panel_email
    fi
    if [[ "$SSL_CONFIRM" =~ [Nn] ]]; then
        SSLSTATUS=false
        panel_email
    fi
}

panel_email(){
    send_summary
    if  [ "$SSLSTATUS" =  "true" ]; then
        echo "[!] Please enter your email. It will be shared with Lets Encrypt and being used to setup this Panel."
        fi
    if  [ "$SSLSTATUS" =  "false" ]; then
        echo "[!] Please enter your email. It will used to setup this Panel."
        fi
    read -r EMAIL
    panel_username
}

panel_username(){
    send_summary
    echo "[!] Please enter username for admin account. You can use your username to login to your Pterodactyl Account."
    read -r USERNAME
    panel_firstname
}
panel_firstname(){
    send_summary
    echo "[!] Please enter first name for admin account."
    read -r FIRSTNAME
    panel_lastname
}

panel_lastname(){
    send_summary
    echo "[!] Please enter last name for admin account."
    read -r LASTNAME
    panel_password
}

panel_password(){
    send_summary
    echo "[!] Please enter password for admin account."
    local USERPASSWORD=""
    while IFS= read -r -s -n 1 char; do
        if [[ $char == $'\0' ]]; then
            break
        elif [[ $char == $'\177' ]]; then
            if [ -n "$USERPASSWORD" ]; then
                USERPASSWORD="${USERPASSWORD%?}"
                echo -en "\b \b"
            fi
        else
            echo -n '*'
            USERPASSWORD+="$char"
        fi
    done
    echo
    panel_summary
}




### Pterodactyl Wings Installation ###

wings(){
    if [ "$dist" = "debian" ] || [ "$dist" = "ubuntu" ]; then
         apt install dnsutils certbot curl tar unzip -y
    elif [ "$dist" = "centos" ]; then
         yum install bind-utils certbot policycoreutils policycoreutils-python selinux-policy selinux-policy-targeted libselinux-utils setroubleshoot-server setools setools-console mcstrans tar unzip zip -y
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
    echo "[!] Please enter your FQDN if you want to install a SSL certificate. If not, press enter and leave this blank."
    read -r WINGS_FQDN
    IP=$(dig +short myip.opendns.com @resolver2.opendns.com -4)
    DOMAIN=$(dig +short ${WINGS_FQDN})
    if [ "${IP}" != "${DOMAIN}" ]; then
        echo ""
        echo "FQDN canceled. Either FQDN is incorrect or you left this blank."
        WINGS_FQDN_STATUS=false
        wings_full
    else
        WINGS_FQDN_STATUS=true
        wings_full
    fi
}

### PHPMyAdmin Installation ###

phpmyadmin(){
    apt install dnsutils -y
    echo ""
    echo "[!] Before installation, we need some information."
    echo ""
    phpmyadmin_fqdn
}

phpmyadmin_finish(){
    cd
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
    echo "    These credentials will has been saved in a file called" 
    echo "    phpmyadmin_credentials.txt in your current directory"
    echo ""
}


phpmyadminweb(){
    rm -rf /etc/nginx/sites-enabled/default || exit || echo "An error occurred. NGINX is not installed." || exit
    apt install mariadb-server -y
    PHPMYADMIN_PASSWORD=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1`
    mariadb -u root -e "CREATE USER '$PHPMYADMIN_USER_LOCAL'@'localhost' IDENTIFIED BY '$PHPMYADMIN_PASSWORD';" && mariadb -u root -e "GRANT ALL PRIVILEGES ON *.* TO '$PHPMYADMIN_USER_LOCAL'@'localhost' WITH GRANT OPTION;"
    
    if  [ "$PHPMYADMIN_SSLSTATUS" =  "true" ]; then
        rm -rf /etc/nginx/sites-enabled/default
        curl -o /etc/nginx/sites-enabled/phpmyadmin.conf https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/phpmyadmin-ssl.conf
        sed -i -e "s@<domain>@${PHPMYADMIN_FQDN}@g" /etc/nginx/sites-enabled/phpmyadmin.conf
        systemctl stop nginx || exit || echo "An error occurred. NGINX is not installed." || exit
        certbot certonly --standalone -d $PHPMYADMIN_FQDN --staple-ocsp --no-eff-email -m $PHPMYADMIN_EMAIL --agree-tos || exit || echo "An error occurred. Certbot not installed." || exit
        systemctl start nginx || exit || echo "An error occurred. NGINX is not installed." || exit
        phpmyadmin_finish
        fi
    if  [ "$PHPMYADMIN_SSLSTATUS" =  "false" ]; then
        curl -o /etc/nginx/sites-enabled/phpmyadmin.conf https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/phpmyadmin.conf || exit || echo "An error occurred. cURL is not installed." || exit
        sed -i -e "s@<domain>@${PHPMYADMIN_FQDN}@g" /etc/nginx/sites-enabled/phpmyadmin.conf || exit || echo "An error occurred. NGINX is not installed." || exit
        systemctl restart nginx || exit || echo "An error occurred. NGINX is not installed." || exit
        phpmyadmin_finish
        fi
}

phpmyadmin_fqdn(){
    send_phpmyadmin_summary
    echo "[!] Please enter FQDN. You will access PHPMyAdmin with this."
    read -r PHPMYADMIN_FQDN
    [ -z "$PHPMYADMIN_FQDN" ] && echo "FQDN can't be empty."
    IP=$(dig +short myip.opendns.com @resolver2.opendns.com -4)
    DOMAIN=$(dig +short ${PHPMYADMIN_FQDN})
    if [ "${IP}" != "${DOMAIN}" ]; then
        echo ""
        echo "Your FQDN does not resolve to the IP of this machine."
        echo "Continuing anyway in 10 seconds.. CTRL+C to stop."
        sleep 10s
        phpmyadmin_ssl
    else
        phpmyadmin_ssl
    fi
}

phpmyadmininstall(){
    apt update
    apt install nginx certbot -y
    mkdir /var/www/phpmyadmin && cd /var/www/phpmyadmin || exit || echo "An error occurred. Could not create directory." || exit
    cd /var/www/phpmyadmin
    if  [ "$dist" =  "ubuntu" ] && [ "$version" = "20.04" ]; then
        apt -y install software-properties-common curl apt-transport-https ca-certificates gnupg
        LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
        curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup |  bash
        apt update
         add-apt-repository "deb http://archive.ubuntu.com/ubuntu $(lsb_release -sc) universe"
    fi
    if [ "$dist" = "debian" ] && [ "$version" = "11" ]; then
        apt -y install software-properties-common curl ca-certificates gnupg2  lsb-release
        echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" |  tee /etc/apt/sources.list.d/sury-php.list
        curl -fsSL  https://packages.sury.org/php/apt.gpg |  gpg --dearmor -o /etc/apt/trusted.gpg.d/sury-keyring.gpg
        apt update -y
        curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup |  bash
    fi
    if [ "$dist" = "debian" ] && [ "$version" = "12" ]; then
        apt -y install software-properties-common curl ca-certificates gnupg2  lsb-release
         apt install -y apt-transport-https lsb-release ca-certificates wget
        wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
        echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" |  tee /etc/apt/sources.list.d/php.list
        apt update -y
        curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup |  bash
    fi
    
    wget https://files.phpmyadmin.net/phpMyAdmin/5.2.1/phpMyAdmin-5.2.1-all-languages.tar.gz
    tar xzf phpMyAdmin-5.2.1-all-languages.tar.gz
    mv /var/www/phpmyadmin/phpMyAdmin-5.2.1-all-languages/* /var/www/phpmyadmin
    chown -R www-data:www-data *
    mkdir config
    chmod o+rw config
    cp config.sample.inc.php config/config.inc.php
    chmod o+w config/config.inc.php
    rm -rf /var/www/phpmyadmin/config
    phpmyadminweb
}


phpmyadmin_summary(){
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

send_phpmyadmin_summary(){
    clear
    echo ""
    if [ -d "/var/www/phpymyadmin" ]; then
        warning "[!] WARNING: There seems to already be an installation of PHPMyAdmin installed! This script will fail!"
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

phpmyadmin_ssl(){
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

phpmyadmin_user(){
    send_phpmyadmin_summary
    echo "[!] Please enter username for admin account."
    read -r PHPMYADMIN_USER_LOCAL
    phpmyadmin_summary
}

phpmyadmin_email(){
    send_phpmyadmin_summary
    if  [ "$PHPMYADMIN_SSLSTATUS" =  "true" ]; then
        echo "[!] Please enter your email. It will be shared with Lets Encrypt."
        read -r PHPMYADMIN_EMAIL
        phpmyadmin_user
        fi
    if  [ "$PHPMYADMIN_SSLSTATUS" =  "false" ]; then
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

    if [[ "$UNINSTALLPANEL" =~ [Yy] ]]; then
        uninstallpanel_backup
    fi
    if [[ "$UNINSTALLPANEL" =~ [Nn] ]]; then
        echo "[!] Removal aborted."
    fi
}

uninstallpanel_backup(){
    echo ""
    echo "[!] Do you want to keep your database and backup your .env file? (Y/N)"
    read -r UNINSTALLPANEL_CHANGE

    if [[ "$UNINSTALLPANEL_CHANGE" =~ [Yy] ]]; then
        BACKUPPANEL=true
        uninstallpanel_confirm
    fi
    if [[ "$UNINSTALLPANEL_CHANGE" =~ [Nn] ]]; then
        BACKUPPANEL=false
        uninstallpanel_confirm
    fi
}

uninstallpanel_confirm(){
    if  [ "$BACKUPPANEL" =  "true" ]; then
        mv /var/www/pterodactyl/.env .
         rm -rf /var/www/pterodactyl || exit || warning "Panel is not installed!" # Removes panel files
         rm /etc/systemd/system/pteroq.service # Removes pteroq service worker
         unlink /etc/nginx/sites-enabled/pterodactyl.conf # Removes nginx config (if using nginx)
         unlink /etc/apache2/sites-enabled/pterodactyl.conf # Removes Apache config (if using apache)
         rm -rf /var/www/pterodactyl # Removing panel files
        systemctl restart nginx
        clear
        echo ""
        echo "[!] Pterodactyl Panel has been uninstalled."
        echo "    Your Panel database has not been deleted"
        echo "    and your .env file is in your current directory."
        echo ""
        fi
    if  [ "$BACKUPPANEL" =  "false" ]; then
         rm -rf /var/www/pterodactyl || exit || warning "Panel is not installed!" # Removes panel files
         rm /etc/systemd/system/pteroq.service # Removes pteroq service worker
         unlink /etc/nginx/sites-enabled/pterodactyl.conf # Removes nginx config (if using nginx)
         unlink /etc/apache2/sites-enabled/pterodactyl.conf # Removes Apache config (if using apache)
         rm -rf /var/www/pterodactyl # Removing panel files
        mariadb -u root -e "DROP DATABASE panel;" # Remove panel database
        mysql -u root -e "DROP DATABASE panel;" # Remove panel database
        systemctl restart nginx
        clear
        echo ""
        echo "[!] Pterodactyl Panel has been uninstalled."
        echo "    Files, services, configs and your database has been deleted."
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
    if { [ "$dist" = "ubuntu" ] && [ "$version" = "18.04" ] || [ "$version" = "20.04" ] || [ "$version" = "22.04" ]; } || { [ "$dist" = "centos" ] && [ "$version" = "7" ]; } || { [ "$dist" = "debian" ] && [ "$version" = "11" ] || [ "$version" = "12" ]; }; then
        options
    else
        echo "Your OS, $dist $version, is not supported"
        exit 1
    fi
}

### Options ###

options(){
    if [ "$dist" = "centos" ] && { [ "$version" = "7" ]; }; then
        echo "Your opportunities has been limited due to CentOS 7."
        echo ""
        echo "What would you like to do?"
        echo "[1] Install Panel."
        echo "[2] Install Wings."
        echo "[3] Remove Panel."
        echo "[4] Remove Wings."
        echo "Input 1-4"
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
            2 ) option=3
                uninstallpanel
                ;;
            2 ) option=4
                wings_remove
                ;;
            * ) echo ""
                echo "Please enter a valid option from 1-4"
        esac
    else
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
        esac
    fi
}

### Start ###

clear
echo ""
echo "Pterodactyl Installer @ v2.1"
echo "Copyright 2024, Malthe K, <me@malthe.cc>"
echo "https://github.com/guldkage/Pterodactyl-Installer"
echo ""
echo "This script is not associated with the official Pterodactyl Panel."
echo ""
oscheck

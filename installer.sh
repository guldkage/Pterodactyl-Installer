#!/bin/bash
#!/usr/bin/env bash

########################################################################
#                                                                      #
#               Pterodactyl Installer, Updater & Remover               #
#                                                                      #
#  This script is not associated with the official Pterodactyl Panel.  #
#                                                                      #
########################################################################


SSL_CONFIRM=""
AGREEWINGS=""
SSLCONFIRM=""
SSLSTATUS=""
FQDN=""
AGREE=""
LASTNAME=""
FIRSTNAME=""
USERNAME=""
PASSWORD=""
DBPASSWORD=""
WEBSERVER=""
SSLSTATUSPHPMYADMIN=""
FQDNPHPMYADMIN=""
SSL_CONFIRM_PHPMYADMIN=""
AGREEPHPMYADMIN=""
PHPMYADMINEMAIL=""
DOMAINSWITCH=""
SSLSWTICH=""
lsb_dist="$(. /etc/os-release && echo "$ID")"


output(){
    echo -e '\e[36m'"$1"'\e[0m';
}

warning(){
    echo -e '\e[31m'"$1"'\e[0m';
}

if [[ $EUID -ne 0 ]]; then
    output ""
    output "* ERROR *"
    output ""
    output "* Sorry, but you need to be root to run this script."
    exit 1
fi

if ! [ -x "$(command -v curl)" ]; then
    output ""
    output "* ERROR *"
    output ""
    output "cURL is required to run this script."
    exit 1
fi

phpmyadminweb(){
    if  [ "$SSLSTATUSPHPMYADMIN" =  "true" ]; then
        rm -rf /etc/nginx/sites-enabled/default
        {
        curl -o /etc/nginx/sites-enabled/phpmyadmin.conf https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/phpmyadmin-ssl.conf
        sed -i -e "s@<domain>@${FQDNPHPMYADMIN}@g" /etc/nginx/sites-enabled/phpmyadmin.conf
        systemctl stop nginx
        certbot certonly --standalone -d $FQDNPHPMYADMIN --staple-ocsp --no-eff-email -m $PHPMYADMINEMAIL --agree-tos
        systemctl start nginx
        } &> /dev/null
        clear
        output ""
        output "* PHPMYADMIN SUCCESSFULLY INSTALLED *"
        output ""
        output "Thank you for using the script. Remember to give it a star."
        output "You may still need to create a admin account for PHPMYAdmin."
        output "URL: https://$FQDNPHPMYADMIN"
        fi
    if  [ "$SSLSTATUSPHPMYADMIN" =  "false" ]; then
        rm -rf /etc/nginx/sites-enabled/default
        {
        curl -o /etc/nginx/sites-enabled/phpmyadmin.conf https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/phpmyadmin.conf
        sed -i -e "s@<domain>@${FQDNPHPMYADMIN}@g" /etc/nginx/sites-enabled/phpmyadmin.conf
        systemctl restart nginx
        } &> /dev/null
        clear
        output ""
        output "* PHPMYADMIN SUCCESSFULLY INSTALLED *"
        output ""
        output "Thank you for using the script. Remember to give it a star."
        output "You may still need to create a admin account for PHPMYAdmin."
        output "URL: http://$FQDNPHPMYADMIN"
        fi
}

phpmyadmininstall(){
    output ""
    output "Installing PHPMyAdmin..."
    if  [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        {
        mkdir /var/www/phpmyadmin && cd /var/www/phpmyadmin
        sudo mkdir /var/www/phpmyadmin && cd /var/www/phpmyadmin
        apt install nginx -y
        apt install certbot -y
        LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
        apt -y install php8.0 php8.0-{cli,gd,mysql,pdo,mbstring,tokenizer,bcmath,xml,fpm,curl,zip}
        wget https://files.phpmyadmin.net/phpMyAdmin/5.1.3/phpMyAdmin-5.1.3-english.tar.gz
        tar xvzf phpMyAdmin-5.1.3-english.tar.gz
        mv /var/www/phpmyadmin/phpMyAdmin-5.1.3-english/* /var/www/phpmyadmin
        chown -R www-data:www-data *
        mkdir config
        chmod o+rw config
        cp config.sample.inc.php config/config.inc.php
        chmod o+w config/config.inc.php
        rm -rf /var/www/phpmyadmin/config
        } &> /dev/null
        phpmyadminweb
    elif  [ "$lsb_dist" =  "fedora" ] ||  [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ] || [ "$lsb_dist" =  "rocky" ] || [ "$lsb_dist" = "almalinux" ]; then
        {
        mkdir /var/www/phpmyadmin && cd /var/www/phpmyadmin
        sudo mkdir /var/www/phpmyadmin && cd /var/www/phpmyadmin
        yum install nginx -y
        yum install certbot -y
        yum install -y epel-release http://rpms.remirepo.net/enterprise/remi-release-8.rpm
        yum install -y yum-utils
        yum-config-manager --disable remi-php54
        yum-config-manager --enable remi-php80
        yum update -y
        yum install -y php php-{common,fpm,cli,json,mysqlnd,mcrypt,gd,mbstring,pdo,zip,bcmath,dom,opcache}
        wget https://files.phpmyadmin.net/phpMyAdmin/5.1.3/phpMyAdmin-5.1.3-english.tar.gz
        tar xvzf phpMyAdmin-5.1.3-english.tar.gz
        mv /var/www/phpmyadmin/phpMyAdmin-5.1.3-english/* /var/www/phpmyadmin
        chown -R www-data:www-data *
        mkdir config
        chmod o+rw config
        cp config.sample.inc.php config/config.inc.php
        chmod o+w config/config.inc.php
        rm -rf /var/www/phpmyadmin/config
        } &> /dev/null
        phpmyadminweb
    fi
}

fqdnphpmyadmin(){
    output ""
    output "* PHPMYADMIN URL * "
    output ""
    output "Enter your FQDN or IP"
    output "Make sure that your FQDN is pointed to your IP with an A record. If not the script will not be able to provide the webpage."
    mkdir /var/www/phpmyadmin && cd /var/www/phpmyadmin
    read -r FQDNPHPMYADMIN
    phpmyadmininstall
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

finish(){
    if  [ "$SSLSTATUS" =  "true" ]; then
        clear
        output ""
        output "* PANEL SUCCESSFULLY INSTALLED *"
        output ""
        warning "Thank you for using the script. Remember to give it a star."
        warning "The script has ended. https://$FQDN or http://$FQDN to go to your Panel."
        output ""
        output "Details:"
        warning "Email: $EMAIL"
        warning "First Name: $FIRSTNAME"
        warning "Last Name: $LASTNAME"
        warning "Password: (Censored)"
        output ""
    fi
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
        wingsdocker
    fi
}

wingsfiles(){
    output "Installing Files..."
    if  [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        {
        mkdir -p /etc/pterodactyl
        apt-get -y install curl tar unzip
        curl -L -o /usr/local/bin/wings "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_$([[ "$(uname -m)" == "x86_64" ]] && echo "amd64" || echo "arm64")"
        curl -o /etc/systemd/system/wings.service https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/wings.service
        chmod u+x /usr/local/bin/wings
        } &> /dev/null
        clear
        output ""
        output "* WINGS SUCCESSFULLY INSTALLED *"
        output ""
        output "Thank you for using the script. Remember to give it a star."
        output "All you need is to set up Wings."
        output "To do this, create the node on your Panel, then press under Configuration,"
        output "press Generate Token, paste it on your server and then type systemctl enable wings --now"
        output ""
    elif  [ "$lsb_dist" =  "fedora" ] ||  [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ] || [ "$lsb_dist" =  "rocky" ] || [ "$lsb_dist" = "almalinux" ]; then
        {
        mkdir -p /etc/pterodactyl
        yum -y install curl tar unzip
        curl -L -o /usr/local/bin/wings "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_$([[ "$(uname -m)" == "x86_64" ]] && echo "amd64" || echo "arm64")"
        curl -o /etc/systemd/system/wings.service https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/wings.service
        chmod u+x /usr/local/bin/wings
        } &> /dev/null
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

wingsdocker(){
    output ""
    output "Installing Docker..."
    if  [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        {
        curl -sSL https://get.docker.com/ | CHANNEL=stable bash
        systemctl enable --now docker
        } &> /dev/null
        wingsfiles
    elif  [ "$lsb_dist" =  "fedora" ] ||  [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ] || [ "$lsb_dist" =  "rocky" ] || [ "$lsb_dist" = "almalinux" ]; then
        {
        dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        dnf -y install docker-ce --allowerasing
        systemctl enable --now docker
        } &> /dev/null
        wingsfiles
    fi
}

webserver(){
    if  [ "$SSLSTATUS" =  "true" ]; then
        command 1> /dev/null
        rm -rf /etc/nginx/sites-enabled/default
        output "Configuring webserver..."
        {
        curl -o /etc/nginx/sites-enabled/pterodactyl.conf https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/pterodactyl-nginx-ssl.conf
        sed -i -e "s@<domain>@${FQDN}@g" /etc/nginx/sites-enabled/pterodactyl.conf
        systemctl stop nginx
        certbot certonly --standalone -d $FQDN --staple-ocsp --no-eff-email -m $EMAIL --agree-tos
        systemctl start nginx
        } &> /dev/null
        finish
        fi
    if  [ "$SSLSTATUS" =  "false" ]; then
        command 1> /dev/null
        rm -rf /etc/nginx/sites-enabled/default
        output "Configuring webserver..."
        {
        curl -o /etc/nginx/sites-enabled/pterodactyl.conf https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/pterodactyl-nginx.conf
        sed -i -e "s@<domain>@${FQDN}@g" /etc/nginx/sites-enabled/pterodactyl.conf
        systemctl restart nginx
        } &> /dev/null
        finish
        fi
}

extra(){
    output "Changing permissions..."
    if  [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        {
        chown -R www-data:www-data /var/www/pterodactyl/*
        curl -o /etc/systemd/system/pteroq.service https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/pteroq.service
        (crontab -l ; echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1")| crontab -
        sed -i -e "s@<user>@www-data@g" /etc/systemd/system/pteroq.service
        sudo systemctl enable --now redis-server
        sudo systemctl enable --now pteroq.service
        } &> /dev/null
        webserver
    elif  [ "$lsb_dist" =  "fedora" ] ||  [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ] || [ "$lsb_dist" =  "rocky" ] || [ "$lsb_dist" = "almalinux" ]; then
        {
        chown -R nginx:nginx /var/www/pterodactyl/*
        curl -o /etc/systemd/system/pteroq.service https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/pteroq-centos.service
        (crontab -l ; echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1")| crontab -
        sed -i -e "s@<user>@www-data@g" /etc/systemd/system/pteroq.service
        sudo systemctl enable --now redis-server
        sudo systemctl enable --now pteroq.service
        } &> /dev/null
        webserver
    fi
}

configuration(){
    output "Setting up the Panel..."
    {
    [ "$SSL_CONFIRM" == true ] && appurl="https://$FQDN"
    [ "$SSL_CONFIRM" == false ] && appurl="http://$FQDN"

    php artisan p:environment:setup --author="$EMAIL" --url="$appurl" --timezone="America/New_York" --cache="redis" --session="redis" --queue="redis" --redis-host="localhost" --redis-pass="null" --redis-port="6379" --settings-ui=true
    php artisan p:environment:database --host="127.0.0.1" --port="3306" --database="panel" --username="pterodactyl" --password="$DBPASSWORD"
    php artisan migrate --seed --force
    php artisan p:user:make --email="$EMAIL" --username="$USERNAME" --name-first="$FIRSTNAME" --name-last="$LASTNAME" --password="$PASSWORD" --admin=1
    } &> /dev/null
    extra
}

composer(){
    output ""
    output "* INSTALLATION * "
    output ""
    output "Installing composer.."
    if  [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        {
        curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
        } &> /dev/null
        files
    elif  [ "$lsb_dist" =  "fedora" ] ||  [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ] || [ "$lsb_dist" =  "rocky" ] || [ "$lsb_dist" = "almalinux" ]; then
        files
    fi
}

files(){
    output "Downloading files... "
    {
    mkdir -p /var/www/pterodactyl
    cd /var/www/pterodactyl || exit
    curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
    tar -xzvf panel.tar.gz
    chmod -R 755 storage/* bootstrap/cache/
    cp .env.example .env
    command composer install --no-dev --optimize-autoloader --no-interaction
    php artisan key:generate --force
    } &> /dev/null
    configuration
}

database(){
    output ""
    output "* INSTALLATION * "
    output ""
    command 1> /dev/null
    output "Let's set up your database connection."
    output "Generating a password for you..."
    warning ""
    DBPASSWORD=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
    mysql -u root -e "CREATE USER 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '$DBPASSWORD';"
    mysql -u root -e "CREATE DATABASE panel;"
    mysql -u root -e "GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'127.0.0.1' WITH GRANT OPTION;"
    mysql -u root -e "FLUSH PRIVILEGES;"
    firstname
}

required(){
    output ""
    output "* INSTALLATION * "
    output ""
    output "Installing packages..."
    output "This may take a while."
    output ""
    if  [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        {
        apt -y install software-properties-common curl apt-transport-https ca-certificates gnupg
        LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
        add-apt-repository -y ppa:chris-lea/redis-server
        curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash
        apt update
        apt-add-repository universe
        apt install certbot python3-certbot-nginx -y
        apt -y install php8.0 php8.0-{cli,gd,mysql,pdo,mbstring,tokenizer,bcmath,xml,fpm,curl,zip} mariadb-server nginx tar unzip git redis-server
        } &> /dev/null
        database
    elif  [ "$lsb_dist" =  "fedora" ] ||  [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ] || [ "$lsb_dist" =  "rocky" ] || [ "$lsb_dist" = "almalinux" ]; then
        {
        yum install -y policycoreutils policycoreutils-python selinux-policy selinux-policy-targeted libselinux-utils setroubleshoot-server setools setools-console mcstrans

        yum update -y
        yum install -y MariaDB-common MariaDB-server
        systemctl start mariadb
        systemctl enable mariadb
        yum install -y epel-release http://rpms.remirepo.net/enterprise/remi-release-8.rpm
        yum install -y yum-utils
        yum-config-manager --disable remi-php54
        yum-config-manager --enable remi-php80
        yum update -y
        yum install -y php php-{common,fpm,cli,json,mysqlnd,mcrypt,gd,mbstring,pdo,zip,bcmath,dom,opcache}
        yum install -y zip unzip
        yum install -y nginx
        firewall-cmd --add-service=http --permanent
        firewall-cmd --add-service=https --permanent 
        firewall-cmd --reload
        yum install -y --enablerepo=remi redis
        setsebool -P httpd_can_network_connect 1
        setsebool -P httpd_execmem 1
        setsebool -P httpd_unified 1
        systemctl start redis
        systemctl enable redis
        curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
        yum install certbot -y
        curl -o /etc/php-fpm.d/www-pterodactyl.conf https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/www-pterodactyl.conf
        systemctl enable php-fpm
        systemctl start php-fpm
        } &> /dev/null
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

password(){
    output ""
    output "* ACCOUNT CREATION * "
    output ""
    output "Please enter password for account"
    read -r PASSWORD
    begin
}


username(){
    output ""
    output "* ACCOUNT CREATION * "
    output ""
    output "Please enter username for account"
    read -r USERNAME
    password
}


lastname(){
    output ""
    output "* ACCOUNT CREATION * "
    output ""
    output "Please enter last name for account"
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
    output "Please enter first name for account"
    read -r FIRSTNAME
    lastname
}

fqdn(){
    output ""
    output "* PANEL URL * "
    output ""
    output "Enter your FQDN or IP"
    output "Make sure that your FQDN is pointed to your IP with an A record. If not the script will not be able to provide the webpage."
    read -r FQDN
    required
}

ssl(){
    output ""
    output "* SSL * "
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

updatepanel(){
    cd /var/www/pterodactyl || exit || output "Pterodactyl Directory (/var/www/pterodactyl) does not exist." || exit
    {
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
    } &> /dev/null
    output ""
    output "* SUCCESSFULLY UPDATED *"
    output ""
    output "Pterodactyl Panel has successfully updated."
}

updatewings(){
    if ! [ -x "$(command -v wings)" ]; then
        echo "Wings is required to update both."
    fi
    {
    curl -L -o /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64
    chmod u+x /usr/local/bin/wings
    systemctl restart wings
    } &> /dev/null
    output ""
    output "* SUCCESSFULLY UPDATED *"
    output ""
    output "Wings has successfully updated."
}

updateboth(){
    if ! [ -x "$(command -v wings)" ]; then
        echo "Wings is required to update both."
    fi
    cd /var/www/pterodactyl || exit || warning "[!] Pterodactyl Directory (/var/www/pterodactyl) does not exist! Exitting..."
    {
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
    } &> /dev/null
    output ""
    output "* SUCCESSFULLY UPDATED *"
    output ""
    output "Pterodactyl Panel and Wings has successfully updated."
}

uninstallpanel(){
    output ""
    output "Do you really want to delete Pterodactyl Panel? All files & configurations will be deleted. You CANNOT get your files back."
    output "(Y/N):"
    read -r UNINSTALLPANEL

    if [[ "$UNINSTALLPANEL" =~ [Yy] ]]; then
        {
        sudo rm -rf /var/www/pterodactyl || exit || warning "Panel is not installed!" # Removes panel files
        sudo rm /etc/systemd/system/pteroq.service # Removes pteroq service worker
        sudo unlink /etc/nginx/sites-enabled/pterodactyl.conf # Removes nginx config (if using nginx)
        sudo unlink /etc/apache2/sites-enabled/pterodactyl.conf # Removes Apache config (if using apache)
        sudo rm -rf /var/www/pterodactyl # Removing panel files
        } &> /dev/null
        output ""
        output "* PANEL SUCCESSFULLY UNINSTALLED *"
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

http(){
    output ""
    output "* FIREWALL CONFIGURATION * "
    output ""
    output "HTTP & HTTPS firewall rule has been applied."
    if  [ "$lsb_dist" =  "ubuntu" ] ||  [ "$lsb_dist" =  "debian" ]; then
        {
        apt install ufw -Y
        ufw allow 80
        ufw alllow 443
        } &> /dev/null
    elif  [ "$lsb_dist" =  "fedora" ] ||  [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ] || [ "$lsb_dist" =  "rocky" ] || [ "$lsb_dist" = "almalinux" ]; then
        {
        firewall-cmd --add-service=http --permanent
        firewall-cmd --add-service=https --permanent
        } &> /dev/null
    fi
}

pterodactylports(){
    output ""
    output "* FIREWALL CONFIGURATION * "
    output ""
    output "All Pterodactyl Ports firewall rule has been applied."
    if  [ "$lsb_dist" =  "ubuntu" ] ||  [ "$lsb_dist" =  "debian" ]; then
        {
        apt install ufw -Y
        ufw allow 80
        ufw alllow 443
        ufw allow 8080
        ufw allow 2022
        } &> /dev/null
    elif  [ "$lsb_dist" =  "fedora" ] ||  [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ] || [ "$lsb_dist" =  "rocky" ] || [ "$lsb_dist" = "almalinux" ]; then
        {
        firewall-cmd --add-service=http --permanent
        firewall-cmd --add-service=https --permanent
        firewall-cmd --permanent --add-port=8080/tcp
        firewall-cmd --permanent --add-port=2022/tcp
        } &> /dev/null
    fi
}

mysql(){
    output ""
    output "* FIREWALL CONFIGURATION * "
    output ""
    output "MySQL firewall rule has been applied."
    if  [ "$lsb_dist" =  "ubuntu" ] ||  [ "$lsb_dist" =  "debian" ]; then
        {
        apt install ufw -Y
        ufw alllow 3306
        } &> /dev/null
    elif  [ "$lsb_dist" =  "fedora" ] ||  [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ] || [ "$lsb_dist" =  "rocky" ] || [ "$lsb_dist" = "almalinux" ]; then
        {
        firewall-cmd --add-service=mysql --permanent
        } &> /dev/null
    fi
}

allfirewall(){
    output ""
    output "* FIREWALL CONFIGURATION * "
    output ""
    output "All of them firewall rule has been applied."
    if  [ "$lsb_dist" =  "ubuntu" ] ||  [ "$lsb_dist" =  "debian" ]; then
        {
        apt install ufw -Y
        ufw allow 80
        ufw alllow 443
        ufw allow 8080
        ufw allow 2022
        ufw alllow 3306
        } &> /dev/null
    elif  [ "$lsb_dist" =  "fedora" ] ||  [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ] || [ "$lsb_dist" =  "rocky" ] || [ "$lsb_dist" = "almalinux" ]; then
        {
        firewall-cmd --add-service=http --permanent
        firewall-cmd --add-service=https --permanent
        firewall-cmd --permanent --add-port=8080/tcp
        firewall-cmd --permanent --add-port=2022/tcp
        firewall-cmd --add-service=mysql --permanent
        } &> /dev/null
    fi
}

switch(){
    if  [ "$SSLSWITCH" =  "true" ]; then
        {
        curl -o /etc/nginx/sites-enabled/pterodactyl.conf https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/pterodactyl-nginx-ssl.conf || exit || warning "Pterodactyl Panel not installed!"
        sed -i -e "s@<domain>@${DOMAINSWITCH}@g" /etc/nginx/sites-enabled/pterodactyl.conf
        systemctl restart nginx
        } &> /dev/null
        output ""
        output "* SWITCH DOMAINS * "
        output ""
        output "Your domain has been switched to $DOMAINSWITCH"
        fi
    if  [ "$SSLSWITCH" =  "false" ]; then
        {
        curl -o /etc/nginx/sites-enabled/pterodactyl.conf https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/pterodactyl-nginx.conf || exit || warning "Pterodactyl Panel not installed!"
        sed -i -e "s@<domain>@${DOMAINSWITCH}@g" /etc/nginx/sites-enabled/pterodactyl.conf
        systemctl restart nginx
        } &> /dev/null
        output ""
        output "* SWITCH DOMAINS * "
        output ""
        output "Your domain has been switched to $DOMAINSWITCH"
        fi
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
            sslswitch=true
            switch
            ;;
        2 ) option=2
            sslswitch=false
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

rewnewcertificates(){
    {
    sudo certbot renew
    } &> /dev/null
    output ""
    output "* RENEW CERTIFICATES * "
    output ""
    output "All Let's Encrypt certificates that were ready to be renewed have been renewed."
}

options(){
    output ""
    output "* FIREWALL CONFIGURATION * "
    output ""
    output "Available firewall configurations:"
    warning "[1] HTTP & HTTPS"
    warning "[2] All Pterodactyl Ports"
    warning "[3] MySQL"
    warning "[4] All of them"
    read -r option
    case $option in
        1 ) option=1
            http
            ;;
        2 ) option=2
            pterodactlports
            ;;
        3 ) option=3
            mysql
            ;;
        4 ) option=4
            allfirewall
            ;;
        * ) output ""
            output "Please enter a valid option."
    esac
}

oscheck(){
    output "* Checking your OS.."
    sleep 1s
    if  [ "$lsb_dist" =  "ubuntu" ] ||  [ "$lsb_dist" =  "debian" ]; then
        output "* Your OS, $lsb_dist, is fully supported. Continuing.."
        output ""
        sleep 1s
        options
    elif  [ "$lsb_dist" =  "fedora" ] ||  [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ] || [ "$lsb_dist" =  "rocky" ] || [ "$lsb_dist" = "almalinux" ]; then
        output "* Your OS, $lsb_dist, is not fully supported."
        output "* Installations may work, but there is no gurrantee."
        output "* Continuing in 5 seconds. CTRL+C to stop."
        output ""
        sleep 5s
        options
    fi
}

options(){
    output "* SELECT OPTION * "
    warning "Operation System: $lsb_dist"
    output ""
    output "Please select your installation option:"
    warning "[1] Install Panel. | Installs latest version of Pterodactyl Panel"
    warning "[2] Install Wings. | Installs latest version of Pterodactyl Wings."
    warning "[3] Install PHPMyAdmin. | Installs PHPMyAdmin."
    warning ""
    warning "[4] Update Panel. | Updates your Panel to the latest version. May remove addons and themes."
    warning "[5] Update Wings. | Updates your Wings to the latest version."
    warning "[6] Update Both. | Updates your Panel and Wings to the latest versions."
    warning ""
    warning "[7] Uninstall Wings. | Uninstalls your Wings. This will also remove all of your game servers."
    warning "[8] Uninstall Panel. | Uninstalls your Panel. You will only be left with your database and web server."
    warning ""
    warning "[9] Renew Certificates | Renews all Lets Encrypt certificates on this machine."
    warning "[10] Configure Firewall | Configure UFW to your liking."
    warning "[11] Switch Pterodactyl Domain | Changes your Pterodactyl Domain."
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
            updateboth
            ;;
        7 ) option=7
            uninstallwings
            ;;
        8 ) option=8
            uninstallpanel
            ;;
        9 ) option=9
            renewcertificates
            ;;
        10 ) option=10
            configureufw
            ;;
        11 ) option=11
            switchdomains
            ;;
        * ) output ""
            output "Please enter a valid option."
    esac
}

clear
output ""
output "* WELCOME *"
output ""
warning "Pterodactyl Installer @ v1.0"
warning "https://github.com/guldkage/Pterodactyl-Installer"
output ""
output "This script is not resposible for any damages. The script has been tested several times without issues."
output "Support is not given."
output "This script will only work on a fresh installation. Proceed with caution if not having a fresh installation"
output ""
oscheck
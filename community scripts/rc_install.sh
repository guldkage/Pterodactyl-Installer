cat << EOF > /usr/local/bin/setup_pterodactyl.sh
#!/bin/bash

export HOME=/root
export COMPOSER_HOME=/root/.composer
export PATH=/usr/local/bin:/usr/bin:/bin:\$PATH

dist="$(. /etc/os-release && echo "$ID")"
version="$(. /etc/os-release && echo "$VERSION_ID")"

finish() {
    clear
    echo ""
    echo "[!] Panel installed."
    echo ""
}

panel_conf() {
    cd /var/www/pterodactyl || exit 1

    [ "\$SSL" == true ] && appurl="https://\$FQDN"
    [ "\$SSL" == false ] && appurl="http://\$FQDN"

    DBPASSWORD=$(openssl rand -base64 12 | tr -dc 'A-Za-z0-9')

    mariadb -u root -e "CREATE USER 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '\$DBPASSWORD';"
    mariadb -u root -e "CREATE DATABASE panel;"
    mariadb -u root -e "GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'127.0.0.1' WITH GRANT OPTION;"
    mariadb -u root -e "FLUSH PRIVILEGES;"

    # Environment setup
    /usr/bin/php artisan p:environment:setup --author="\$EMAIL" --url="\$appurl" --timezone="CET" --telemetry=false --cache="redis" --session="redis" --queue="redis" --redis-host="localhost" --redis-pass="null" --redis-port="6379" --settings-ui=true

    /usr/bin/php artisan p:environment:database --host="127.0.0.1" --port="3306" --database="panel" --username="pterodactyl" --password="\$DBPASSWORD"

    until mysqladmin ping -h 127.0.0.1 -u root >/dev/null 2>&1; do
        echo "Waiting for MariaDB..."
        sleep 3
    done

    /usr/bin/php artisan migrate --seed --force
    /usr/bin/php artisan p:user:make --email="\$EMAIL" --username="\$USERNAME" --name-first="\$FIRSTNAME" --name-last="\$LASTNAME" --password="\$PASSWORD" --admin=1

    chown -R www-data:www-data /var/www/pterodactyl/*

    curl -o /etc/nginx/sites-enabled/pterodactyl.conf https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/pterodactyl-nginx.conf
    sed -i -e "s@<domain>@\${FQDN}@g" /etc/nginx/sites-enabled/pterodactyl.conf
    systemctl restart nginx

    finish
}

panel_install() {
    echo ""
    echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/redis.list
    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/sury-php.list
    apt install -y gnupg
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys B188E2B695BD4743
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 5F4349D6BF53AA0C
    apt update -y
    apt install -y curl mariadb-server redis-server nginx php8.3 php8.3-{cli,gd,mysql,pdo,mbstring,tokenizer,bcmath,xml,fpm,curl,zip} unzip tar git certbot

    systemctl restart mariadb

    # Composer installieren
    curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php
/usr/bin/php /tmp/composer-setup.php -- --install-dir=/usr/local/bin --filename=composer
rm /tmp/composer-setup.php

if [ ! -f /usr/local/bin/composer ]; then
    echo "Composer installation failed!" >> /var/log/post-install.log
    exit 1
fi

    # Panel vorbereiten
    mkdir -p /var/www/pterodactyl
    cd /var/www/pterodactyl || exit 1
    curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
    tar -xzvf panel.tar.gz
    chmod -R 755 storage/* bootstrap/cache/
    cp .env.example .env
    /usr/local/bin/composer install --no-dev --optimize-autoloader --no-interaction
    /usr/bin/php artisan key:generate --force

    panel_conf
}

# ===============================
# Script Parameter
# ===============================
FQDN=\$1
SSL=\$2
EMAIL=\$3
USERNAME=\$4
FIRSTNAME=\$5
LASTNAME=\$6
PASSWORD=\$7

if [ -z "\$FQDN" ] || [ -z "\$SSL" ] || [ -z "\$EMAIL" ] || [ -z "\$USERNAME" ] || [ -z "\$FIRSTNAME" ] || [ -z "\$LASTNAME" ] || [ -z "\$PASSWORD" ]; then
    echo "Error! Incorrect usage."
    exit 1
fi

echo "Checking your OS..."
if { [ "\$dist" = "ubuntu" ] && [ "\$version" = "20.04" ]; } || { [ "\$dist" = "debian" ] && { [ "\$version" = "11" ] || [ "\$version" = "12" ]; }; }; then
    echo "Welcome to Pterodactyl Auto Installer"
    echo "Starting automatic installation in 5 seconds..."
    sleep 5s
    panel_install
else
    echo "Your OS, \$dist \$version, is not supported"
    exit 1
fi
exit 0
EOF


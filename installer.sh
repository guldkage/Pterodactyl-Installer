#!/bin/bash

########################################################################
#                                                                      #
#            Pterodactyl Installer, Updater, Remover and More          #
#            Copyright 2024, Malthe K, <me@malthe.cc> hej              # 
#  https://github.com/guldkage/Pterodactyl-Installer/blob/main/LICENSE #
#                                                                      #
#  This script is not associated with the official Pterodactyl Panel.  #
#  You may not remove this line                                        #
#                                                                      #
########################################################################

### VARIABLES ###
dist="$(. /etc/os-release && echo "$ID")"
version="$(. /etc/os-release && echo "$VERSION_ID")"
LOGFILE="installer.log"

### LOGGING AND OUTPUT ###
log_info() {
    echo -e "\e[32m[INFO] $1\e[0m" | tee -a "$LOGFILE"
}

log_error() {
    echo -e "\e[31m[ERROR] $1\e[0m" | tee -a "$LOGFILE"
}

trap "echo -e '\n[!] Exiting.'; exit 1" SIGINT SIGTERM

### OS CHECK ###
check_os() {
    log_info "Checking your operating system..."
    SUPPORTED=false

    case "$dist-$version" in
        ubuntu-20.04|ubuntu-22.04|debian-11|debian-12|centos-7)
            SUPPORTED=true
            ;;
    esac

    if [ "$SUPPORTED" = true ]; then
        log_info "OS $dist $version is supported!"
    else
        log_error "Your OS ($dist $version) is not supported. Exiting."
        exit 1
    fi
}

### DEPENDENCY INSTALLATION ###
install_dependencies() {
    log_info "Installing required dependencies for $dist $version..."

    case "$dist" in
        ubuntu|debian)
            apt update && apt install -y curl tar unzip certbot redis-server mariadb-server nginx php php-cli php-fpm php-mysql php-bcmath php-curl php-mbstring php-xml composer
            ;;
        centos)
            yum update -y && yum install -y curl tar unzip epel-release mariadb-server nginx php php-cli php-fpm php-mysqlnd php-bcmath php-curl php-mbstring php-xml composer
            ;;
        *)
            log_error "Unsupported OS for dependency installation!"
            exit 1
            ;;
    esac

    log_info "Dependencies installed successfully."
}

### PANEL INSTALLATION ###
install_panel() {
    log_info "Starting Pterodactyl Panel installation..."

    # Prompt for required inputs
    DEFAULT_FQDN="panel.example.com"
    read -p "Enter Panel FQDN (default: $DEFAULT_FQDN): " FQDN
    FQDN="${FQDN:-$DEFAULT_FQDN}"

    DEFAULT_EMAIL="admin@example.com"
    read -p "Enter Admin Email (default: $DEFAULT_EMAIL): " EMAIL
    EMAIL="${EMAIL:-$DEFAULT_EMAIL}"

    DB_PASSWORD=$(openssl rand -base64 12)

    # Set up directories and download panel
    mkdir -p /var/www/pterodactyl
    cd /var/www/pterodactyl || exit
    curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
    tar -xzvf panel.tar.gz
    chmod -R 755 storage/* bootstrap/cache/
    cp .env.example .env

    # Install dependencies
    install_dependencies

    # Run composer
    composer install --no-dev --optimize-autoloader --no-interaction
    php artisan key:generate --force

    # Database setup
    mariadb -u root -e "CREATE DATABASE panel;"
    mariadb -u root -e "CREATE USER 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '$DB_PASSWORD';"
    mariadb -u root -e "GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'127.0.0.1';"
    mariadb -u root -e "FLUSH PRIVILEGES;"

    # Configure panel
    php artisan p:environment:setup --author="$EMAIL" --url="https://$FQDN" --cache=redis --session=redis --queue=redis
    php artisan p:environment:database --host=127.0.0.1 --port=3306 --database=panel --username=pterodactyl --password="$DB_PASSWORD"
    php artisan migrate --seed --force

    log_info "Panel installation completed."

    echo "Panel URL: https://$FQDN" >> panel_credentials.txt
    echo "Database Password: $DB_PASSWORD" >> panel_credentials.txt
    log_info "Credentials saved in panel_credentials.txt."
}

### WINGS INSTALLATION ###
install_wings() {
    log_info "Starting Pterodactyl Wings installation..."

    # Install Docker if not present
    if ! command -v docker &> /dev/null; then
        curl -sSL https://get.docker.com/ | bash
        systemctl enable --now docker
    fi

    mkdir -p /etc/pterodactyl
    curl -Lo /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_$(uname -m | grep -q 64 && echo amd64 || echo arm64)
    chmod u+x /usr/local/bin/wings

    curl -o /etc/systemd/system/wings.service https://raw.githubusercontent.com/pterodactyl/wings/master/install/wings.service
    systemctl enable --now wings

    log_info "Wings installed successfully. Configure it via the Panel."
}

### REMOVAL FUNCTIONS ###
remove_panel() {
    log_info "Removing Pterodactyl Panel..."
    rm -rf /var/www/pterodactyl
    rm -f /etc/nginx/sites-enabled/pterodactyl.conf
    mariadb -u root -e "DROP DATABASE panel;"
    mariadb -u root -e "DROP USER 'pterodactyl'@'127.0.0.1';"
    systemctl restart nginx
    log_info "Panel removed successfully."
}

remove_wings() {
    log_info "Removing Pterodactyl Wings..."
    systemctl stop wings
    rm -f /usr/local/bin/wings
    rm -rf /etc/pterodactyl
    rm -f /etc/systemd/system/wings.service
    log_info "Wings removed successfully."
}

### MENU OPTIONS ###
main_menu() {
    clear
    echo "Pterodactyl Installer @ v2.1"
    echo "---------------------------------------"
    echo "1. Install Panel"
    echo "2. Install Wings"
    echo "3. Remove Panel"
    echo "4. Remove Wings"
    echo "5. Exit"
    echo "---------------------------------------"
    read -p "Choose an option: " option

    case "$option" in
        1) install_panel ;;
        2) install_wings ;;
        3) remove_panel ;;
        4) remove_wings ;;
        5) exit 0 ;;
        *) echo "Invalid option."; main_menu ;;
    esac
}

### START SCRIPT ###
log_info "Starting Pterodactyl Installer"
check_os
main_menu

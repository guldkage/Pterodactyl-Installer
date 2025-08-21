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
source /etc/os-release
dist="$ID"
version="$VERSION_ID"

trap_ctrlc() {
    echo -e "\n[!] Installation interrupted. Exiting."
    exit 2
}

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

required_cmds=(curl dig iptables systemctl)
for cmd in "${required_cmds[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "[!] Missing required command: $cmd"
        echo "[!] Please install it using APT"
        exit 1
    fi
done

### OS Check ###

oscheck() {
    echo "Checking your OS..."

    case "$dist" in
        ubuntu)
            case "$version" in
                22.04|24.04)
                    echo "Your OS, $dist $version, is supported"
                    echo ""
                    options
                    return
                    ;;
            esac
            ;;
        debian)
            case "$version" in
                11|12|13)
                    echo "Your OS, $dist $version, is supported"
                    echo ""
                    options
                    return
                    ;;
            esac
            ;;
    esac

    echo "Your OS, $dist $version, is not supported"
    exit 1
}

### Options ###

options() {
    echo "If you want to install panel and wings, select panel then say yes when prompted in the end of installation."
    echo ""
    echo "What would you like to do?"
    PS3="Enter choice [1-8]: "
    select opt in \
        "Install Panel" "Install Wings" \
        "Install PHPMyAdmin" "Remove PHPMyAdmin" \
        "Remove Wings" "Remove Panel" "Switch Domain"; do
        case $REPLY in
            1) bash <(curl -s https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/refs/heads/main/installers/panel.sh); return ;;
            2) bash <(curl -s https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/refs/heads/main/installers/wings.sh); return ;;
            3) bash <(curl -s https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/refs/heads/main/installers/phpmyadmin.sh); return ;;
            4) bash <(curl -s https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/refs/heads/main/installers/remove_phpmyadmin.sh); return ;;
            5) bash <(curl -s https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/refs/heads/main/installers/remove_wings.sh); return ;;
            6) bash <(curl -s https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/refs/heads/main/installers/remove_panel.sh); return ;;
            7) bash <(curl -s https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/refs/heads/main/installers/switch_domains.sh); return ;;
            *) echo "Invalid option, try again." ;;
        esac
    done
}

### Start ###

clear
cat <<EOF

-------------------------------------------------------------------
               Pterodactyl Installer @ v4.0
         Copyright 2025, Malthe Kragh <me@malthe.cc>
 https://github.com/guldkage/Pterodactyl-Installer

 This script is not associated with the official Pterodactyl Panel.

 Security notice:
 This script sends requests to
 api.malthe.cc/checkip and ipinfo.io for IP check
-------------------------------------------------------------------

EOF
oscheck

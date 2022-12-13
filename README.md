![Logo Image](https://github.com/guldkage/Pterodactyl-Installer/blob/main/configs/installer.png?raw=true)


# Pterodactyl Installer

With this script you can easily install, update or delete Pterodactyl Panel. Everything is gathered in one script.
Use this script if you want to install, update or delete your services quickly. The things that are being done are already listed on [Pterodactyl](https://pterodactyl.io/), but this clearly makes it faster since it is automatic.

Please note that this script is made to work on a fresh installation. There is a good chance that it will fail if it is not a fresh installation.
The script must be run as root.

If you find any errors, things you would like changed or queries for things in the future for this script, please write an "Issue".
Read about [Pterodactyl](https://pterodactyl.io/) here. This script is not associated with the official Pterodactyl Project.

## Features
This script is one of the only ones that has a well-functioning Switch Domains feature.

- Install Panel
- Install Wings
- Install PHPMyAdmin
- Switch Pterodactyl Domains
- Update Panel
- Update Wings
- Uninstall Panel
- Uninstall Wings

## Supported OS & Webserver
Supported operating systems.

| Operating System | Version               | Supported          |
| ---------------- | ----------------------| ------------------ |
| Ubuntu           | from 18.04 to 22.04   | :white_check_mark: |
| Debian           | from 10 to 11         | :white_check_mark: |
| CentOS           | no supported versions | :x:            |
| Rocky Linux      | no supported versions | :x:       |

| Webserver | Supported          |
| --------- | ------------------ |
| NGINX     | :white_check_mark: |
| Apache    | :x:                |
| LiteSpeed | :x:                |
| Caddy     | :x:                |

## Copyright
Please do not say you created this script. You may create a fork for this Pterodactyl-Installer, but I would appreciate this github being linked to.
Also, please not remove my copyright at the top of the Pterodactyl-Installer script.

## Support
No support is offered for this script.
The script has been tested many times without any bug fixes, however they can still occur.
If you find errors, feel free to open an "Issue" on GitHub.

# Run the script
Debian based systems only.
```bash
bash <(curl -s https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/installer.sh)
```

### Raspbian
Only for raspbian users. They might need a extra < in the beginning.
```bash
bash < <(curl -s https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/installer.sh)
```

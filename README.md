<h1 align="center"><strong>Pterodactyl Installer</strong></h1>

With this script you can easily install, update or delete Pterodactyl Panel. Everything is gathered in one script.

Please note that this script is made to work on a fresh installation.
There is a good chance that it will fail if it is not a fresh installation.
The script must be run as root.

Read about [Pterodactyl](https://pterodactyl.io/) here. This script is not associated with the official Pterodactyl Project.

# Features
Supports newest version of Pterodactyl! This script is one of the only ones that has a well-functioning Switch Domains feature.

- Install Panel
- Install Wings
- Install Panel & Wings
- Install PHPMyAdmin
- Uninstall PHPMyAdmin
- Switch Pterodactyl Domains
- Uninstall Panel
- Uninstall Wings
- Autoinstall [ONLY NGINX & BETA]

# Support
I have created a channel on my Discord Server where you can get support.
https://discord.gg/3UUrgEhvJ2

# Supported OS & Webserver
Supported operating systems.

| Operating System | Version               | Supported                          |   PHP |
| ---------------- | ----------------------| ---------------------------------- | ----- |
| Ubuntu           | from 20.04 to 24.04   | :white_check_mark:                 | 8.3   |
| Debian           | from 11 to 12         | :white_check_mark:                 | 8.3   |

| Webserver        | Supported           |
| ---------------- | --------------------| 
| NGINX            | :white_check_mark:  |
| Apache           | :white_check_mark:  |

# Contributors
Copyright 2022-2025, [Malthe K](https://github.com/guldkage), me@malthe.cc
<br>
Created and maintained by [Malthe K.](https://github.com/guldkage)

# Support
The script has been tested many times without any bug fixes, however they can still occur.
<br>
If you find errors, feel free to open an "Issue" on GitHub.

# Interactive/Normal installation
The recommended way to use this script.
```bash
bash <(curl -s https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/installer.sh)
```

### Raspbian
Only for raspbian users. They might need a extra < in the beginning.
```bash
bash < <(curl -s https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/installer.sh)
```

# Autoinstall / Developer Installation
Only use this if you know what you are doing!
You can now install Pterodactyl using 1 command without having to manually type anything after running the command.

### [BETA] Generate Autoinstall Command
You can use my [autoinstall command generator](https://malthe.cc/api/autoinstall/) to install Pterodactyl and Wings with 1 command.

### Required fields
```
<fqdn> = What you want to access your panel with. Eg. panel.domain.ltd
<ssl> = Whether to use SSL. Options are true or false.
<email> = Your email. If you choose SSL, it will be shared with Lets Encrypt.
<username> = Username for admin account on Pterodactyl
<firstname> = First name for admin account on Pterodactyl
<lastname> = Lastname for admin account on Pterodactyl
<password> = The password for the admin account on Pterodactyl
<wings> = Whether you want to have Wings installed automatically as well. Options are true or false.
```

You must be precise when using this script. 1 typo and everything can go wrong.
It also needs to be run on a fresh version of Ubuntu or Debian.

```bash
bash <(curl -s https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/autoinstall.sh)  <fqdn> <ssl> <email> <username> <firstname <lastname> <password> <wings>
```

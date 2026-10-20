How to Install the Platform on Linux
The platform runs on Linux using Wine. Wine is a free compatibility layer that allows application software developed for Microsoft Windows to run on Unix-like operating systems.

We have prepared a special script to make the installation process as simple as possible. The script will automatically detect your system version, it supports Ubuntu, Debian, Linux Mint and Fedora distributions. Based on it, it will download and install the appropriate Wine package. After that, it will download and run the platform installer.

To start the installation, open the command line (Terminal) without the administrator privileges (no sudo) and specify the relevant command:

wget https://download.terminal.free/cdn/web/metaquotes.software.corp/mt5/mt5linux.sh ; chmod +x mt5linux.sh ; ./mt5linux.sh
This command downloads the script, makes it executable and runs it. You only need to enter your account password to allow installation.

Installing Wine and the platform with a single command

If you are prompted to install additional Wine packages (Mono, Gecko), please agree, as these packages are required for platform operation. The MetaTrader 5 installer will launch after that, proceed with the standard steps. Once the installation is complete, restart your operating system, and the platform is ready to go.
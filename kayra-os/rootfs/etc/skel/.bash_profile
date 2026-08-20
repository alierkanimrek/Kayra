if [ -z "$INSTALLER_STARTED" ] && [ "$(tty)" = "/dev/tty1" ]; then
    export INSTALLER_STARTED=1
    clear
    sudo void-installer
fi

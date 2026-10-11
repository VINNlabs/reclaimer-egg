#!/bin/bash
# Pelican entrypoint for the Project Reclaimer Wine image.
# Wings mounts the server volume at /home/container and passes the egg's
# startup command in $STARTUP, along with every egg variable as an env var.

cd /home/container || exit 1

export HOME=/home/container
export WINEPREFIX=/home/container/.wine
export WINEDEBUG="${WINEDEBUG:--all}"
export WINEDLLOVERRIDES="${WINEDLLOVERRIDES:-mscoree,mshtml=}"

INTERNAL_IP=$(ip route get 1 2>/dev/null | awk '{print $(NF-2); exit}')
export INTERNAL_IP

echo "Wine: $(wine --version 2>/dev/null)"

# First start (or after deleting .wine in the file manager): copy the
# prebuilt prefix with the VC++ runtime from the image into the volume.
# Copying makes it owned by whatever uid Wings runs us as, which Wine needs.
if [ ! -f "${WINEPREFIX}/system.reg" ]; then
    echo "Setting up the Wine prefix from the image template..."
    rm -rf "${WINEPREFIX}"
    cp -a --no-preserve=ownership /opt/wineprefix-template "${WINEPREFIX}" || {
        echo "Could not copy the Wine prefix template into ${WINEPREFIX}."
        exit 1
    }
fi

# Headless display for Wine. XVFB=0 in the egg turns it off.
if [ "${XVFB:-1}" = "1" ]; then
    rm -f /tmp/.X0-lock /tmp/.X11-unix/X0 2>/dev/null
    Xvfb :0 -screen 0 1024x768x16 -nolisten tcp >/dev/null 2>&1 &
    export DISPLAY=:0
fi

# Replace {{VAR}} placeholders in the startup command, as Pelican's yolks do.
MODIFIED_STARTUP=$(echo "${STARTUP}" | sed -e 's/{{/${/g' -e 's/}}/}/g')
echo ":/home/container$ ${MODIFIED_STARTUP}"

eval "${MODIFIED_STARTUP}"

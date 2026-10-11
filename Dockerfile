# Wine runtime image for Project Reclaimer dedicated servers on Pelican.
#
# Contains Debian, WineHQ stable, Xvfb and a Wine prefix template with the
# Visual C++ 2015-2022 runtime already installed. It never contains game
# files or the Reclaimer executable: the egg's installer downloads the exe
# into the server volume, and you upload Halo 3's files over SFTP.
FROM debian:13-slim

LABEL org.opencontainers.image.description="Wine runtime for Project Reclaimer dedicated servers on Pelican"

ENV DEBIAN_FRONTEND=noninteractive

# Pelican/Wings runs containers as uid 988 by default; match it so the
# template prefix is built by the same user name the server runs as.
RUN useradd -u 988 -m -d /home/container -s /bin/bash container

RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates curl wget gnupg2 tini iproute2 tzdata \
        xvfb xauth cabextract unzip \
    && mkdir -pm755 /etc/apt/keyrings \
    && wget -qO /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key \
    && wget -qNP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/debian/dists/trixie/winehq-trixie.sources \
    && apt-get update \
    && apt-get install -y --install-recommends winehq-stable \
    && rm -rf /var/lib/apt/lists/*

RUN wget -qO /usr/local/bin/winetricks https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks \
    && chmod +x /usr/local/bin/winetricks

ENV WINEDEBUG=-all \
    WINEDLLOVERRIDES="mscoree,mshtml=" \
    WINEARCH=win64

# Build the template prefix once, as the container user, with the VC++
# runtime the docs require. The entrypoint copies it into the server volume
# on first start, so nothing is downloaded when a server boots.
RUN mkdir -p /opt/wineprefix-template && chown container:container /opt/wineprefix-template
USER container
ENV HOME=/home/container
RUN export WINEPREFIX=/opt/wineprefix-template \
    && xvfb-run -a wineboot --init \
    && wineserver -w \
    && xvfb-run -a winetricks -q --unattended vcrun2022 \
    && wineserver -w \
    && grep -qx vcrun2022 /opt/wineprefix-template/winetricks.log \
    && rm -rf /home/container/.cache
USER root

COPY --chmod=755 entrypoint.sh /entrypoint.sh

USER container
ENV USER=container HOME=/home/container
WORKDIR /home/container
STOPSIGNAL SIGINT
ENTRYPOINT ["/usr/bin/tini", "-g", "--"]
CMD ["/entrypoint.sh"]

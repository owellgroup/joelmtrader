# MT5 under Wine + the Windows Python bridge, one container.
# Build on 84.8.131.140:  docker build -t mt5-bridge:latest /opt/mt5-bridge
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    DISPLAY=:99 \
    WINEPREFIX=/wine \
    WINEARCH=win64 \
    WINEDEBUG=-all \
    WINEDLLOVERRIDES="mscoree,mshtml=" \
    MALLOC_ARENA_MAX=2

RUN dpkg --add-architecture i386 \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates wget curl gnupg2 unzip cabextract procps xauth tini \
      supervisor xvfb x11vnc novnc websockify openbox \
 && mkdir -pm755 /etc/apt/keyrings \
 && wget -qO /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key \
 && wget -qNP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/jammy/winehq-jammy.sources \
 && apt-get update \
 && apt-get install -y --install-recommends winehq-stable \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY mt5_bridge.py check_mt5.py svc.sh entrypoint.sh supervisord.conf /opt/mt5/
RUN chmod +x /opt/mt5/svc.sh /opt/mt5/entrypoint.sh

WORKDIR /opt/mt5
EXPOSE 6080
STOPSIGNAL SIGTERM
ENTRYPOINT ["/usr/bin/tini", "--", "/opt/mt5/entrypoint.sh"]

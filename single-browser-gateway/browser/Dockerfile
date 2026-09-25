# Using Debian 12 (Bookworm) Slim to avoid Ubuntu 22.04's snapd dependency for Chromium
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8

# Install Chromium, virtual display, minimal window manager, and noVNC bridge
RUN apt-get update && apt-get install -y --no-install-recommends \
    chromium \
    xvfb \
    openbox \
    x11vnc \
    novnc \
    websockify \
    curl \
    ca-certificates \
    procps \
    fonts-liberation \
    fonts-noto-color-emoji \
    && rm -rf /var/lib/apt/lists/*

# Ensure noVNC has an index.html pointing to vnc.html
RUN ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/index.html

# Create profile directory for persistent browser data
RUN mkdir -p /profile && chmod 777 /profile

WORKDIR /

COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 6080

ENTRYPOINT ["/start.sh"]

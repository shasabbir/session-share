FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8

# Force HTTPS on all repositories to bypass transparent ISP port-80 HTTP proxies
RUN sed -i 's|http://|https://|g' /etc/apt/sources.list.d/ubuntu.sources 2>/dev/null || true \
    && sed -i 's|http://|https://|g' /etc/apt/sources.list 2>/dev/null || true

# 1. Install base utilities, virtual display (Xvfb), window manager (Openbox), and noVNC
RUN apt-get update && apt-get install -y --no-install-recommends \
    xvfb \
    openbox \
    x11vnc \
    novnc \
    websockify \
    curl \
    wget \
    ca-certificates \
    procps \
    gnupg \
    fonts-liberation \
    fonts-noto-color-emoji \
    && rm -rf /var/lib/apt/lists/*

# 2. Install official Google Chrome (bypasses Ubuntu snapd)
RUN ARCH=$(dpkg --print-architecture) \
    && if [ "$ARCH" = "amd64" ]; then \
        echo "Installing official Google Chrome for amd64..." \
        && curl -fsSL https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -o /tmp/chrome.deb \
        && apt-get update \
        && apt-get install -y --no-install-recommends /tmp/chrome.deb \
        && rm -f /tmp/chrome.deb \
        && ln -sf /usr/bin/google-chrome-stable /usr/bin/chromium; \
    else \
        echo "Installing distribution browser for $ARCH..." \
        && apt-get update && apt-get install -y --no-install-recommends chromium; \
    fi \
    && rm -rf /var/lib/apt/lists/*

# 3. Ensure noVNC root index points to vnc.html
RUN ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/index.html

# 4. Create persistent profile mount point
RUN mkdir -p /profile && chmod 777 /profile

WORKDIR /

COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 6080

ENTRYPOINT ["/start.sh"]

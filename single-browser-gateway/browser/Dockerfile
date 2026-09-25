FROM alpine:3.20

# 1. Enable official Alpine HTTPS repositories (Cloudflare CDN - immune to ISP port 80 proxy blocks)
RUN echo "https://dl-cdn.alpinelinux.org/alpine/v3.20/main" > /etc/apk/repositories \
    && echo "https://dl-cdn.alpinelinux.org/alpine/v3.20/community" >> /etc/apk/repositories

# 2. Install Chromium, Xvfb virtual display, Openbox, x11vnc, and noVNC
RUN apk update && apk add --no-cache \
    chromium \
    xvfb \
    openbox \
    x11vnc \
    novnc \
    websockify \
    bash \
    curl \
    ca-certificates \
    font-noto \
    font-noto-emoji \
    && ln -sf /usr/bin/chromium-browser /usr/bin/chromium 2>/dev/null || true

# 3. Ensure noVNC root index points to vnc.html
RUN ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/index.html

# 4. Create persistent profile mount point
RUN mkdir -p /profile && chmod 777 /profile

WORKDIR /

COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 6080

ENTRYPOINT ["/start.sh"]

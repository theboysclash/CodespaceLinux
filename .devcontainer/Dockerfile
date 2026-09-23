FROM mcr.microsoft.com/devcontainers/base:ubuntu

USER root

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    DISPLAY=:1 \
    VNC_RESOLUTION=1600x900x24

# One install layer: XFCE core only (no linux-lite-desktop meta-package),
# virtual display, and the VNC bridge. Recommends are skipped so office
# apps, games, and extra XFCE goodies stay out. Apt lists are removed
# before the layer is committed.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      xfce4 \
      xfce4-terminal \
      xfce4-whiskermenu-plugin \
      dbus-x11 \
      xvfb \
      x11vnc \
      websockify \
      python3 \
      fonts-dejavu-core \
      xfonts-base \
      x11-utils \
      x11-xserver-utils \
      elementary-xfce-icon-theme \
      hicolor-icon-theme \
      gtk2-engines-murrine \
      gtk2-engines-pixbuf \
      librsvg2-common \
      ca-certificates \
      git \
 && git clone --filter=blob:none --sparse --depth 1 https://github.com/ralphys/litethemes.git /tmp/litethemes \
 && git -C /tmp/litethemes fetch --depth 1 origin fe90abb579b5d2ff6924ab9bba01c54ad8f19861 \
 && git -C /tmp/litethemes checkout --detach FETCH_HEAD \
 && git -C /tmp/litethemes sparse-checkout set --skip-checks \
      usr/share/themes/Arc/gtk-2.0 \
      usr/share/themes/Arc/gtk-3.0 \
      usr/share/themes/Arc/xfwm4 \
      usr/share/themes/Arc/index.theme \
      usr/share/backgrounds/xfce/LinuxLite.png \
 && mkdir -p /usr/share/themes/Arc /usr/share/backgrounds/linuxlite \
 && cp -a /tmp/litethemes/usr/share/themes/Arc/gtk-2.0 \
          /tmp/litethemes/usr/share/themes/Arc/gtk-3.0 \
          /tmp/litethemes/usr/share/themes/Arc/xfwm4 \
          /usr/share/themes/Arc/ \
 && cp -a /tmp/litethemes/usr/share/themes/Arc/index.theme /usr/share/themes/Arc/index.theme \
 && cp /tmp/litethemes/usr/share/backgrounds/xfce/LinuxLite.png \
       /usr/share/backgrounds/linuxlite/LinuxLite.png \
 && rm -rf /tmp/litethemes \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

COPY web /opt/linuxlite-desktop/web
COPY .devcontainer/start-desktop.sh /opt/linuxlite-desktop/start-desktop.sh
COPY .devcontainer/xfce/ /opt/linuxlite-desktop/xfce/
COPY .devcontainer/linuxlite-look.desktop /etc/xdg/autostart/linuxlite-look.desktop

RUN chmod 755 /opt/linuxlite-desktop/start-desktop.sh \
 && printf '%s\n' 'window.__VNC_PASSWORD__ = "";' > /opt/linuxlite-desktop/web/vnc-auth.js \
 && chown -R vscode:vscode /opt/linuxlite-desktop \
 && chmod 755 /opt/linuxlite-desktop /opt/linuxlite-desktop/web /opt/linuxlite-desktop/xfce

USER vscode

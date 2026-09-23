# CodespaceLinux

XFCE desktop in a GitHub Codespace, streamed to a browser tab. Codespaces cannot boot a Linux Lite ISO (there is no nested virtualization), so this runs the same desktop Linux Lite is built on — Ubuntu plus XFCE — inside the container and serves it with noVNC.

The page is only the desktop. It loads noVNC's RFB client and does not ship the control bar from `vnc.html`.

## Open the desktop

Rebuild the codespace so `.devcontainer` is applied. On each start, `start-desktop.sh` launches Xvfb, XFCE, x11vnc, and websockify. Open the forwarded **6080** URL. The port is private, so GitHub sign-in is what keeps it closed.

Keyboard and mouse go to the session. The framebuffer is `VNC_RESOLUTION` (default `1600x900x24`) and the browser scales it to the window. `?scale=false` shows it 1:1.

## What is installed

- `xfce4`, `xfce4-terminal`, and the Whisker menu. Not `linux-lite-desktop`, and not the office suite, games, or `xfce4-goodies`.
- The Arc GTK and xfwm theme plus the single `LinuxLite.png` wallpaper from [ralphys/litethemes](https://github.com/ralphys/litethemes) (`fe90abb`). The Faenza icon set in that repo is about 62 MB, so it is not installed. Icons are `elementary-xfce`.
- noVNC 1.6.0 `core/` and `vendor/pako` only. `app/`, `docs/`, `tests/`, and `vnc.html` are not included.

## Optional VNC password

Set `VNC_PASSWORD` in `containerEnv` (8 characters; VNC ignores the rest). The startup script writes it into `vnc-auth.js` so the page still connects with no login prompt. `?password=` overrides that value. A public port is reachable by anyone who has the URL.

To keep a home directory across rebuilds, add a mount for `/home/vscode` in `devcontainer.json`.

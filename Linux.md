# MT5 on 37.27.56.188

Use the official MetaQuotes installer from `mt5.md`:

`wget https://download.terminal.free/cdn/web/metaquotes.software.corp/mt5/mt5linux.sh`

The old `mt5-bridge` container is what kept exiting and showing the debugger message. Do not update that stack again.

You are root over SSH, so there is no password to type. The script below creates a normal user named `mt5`, lets that user install without a password, and opens the screen on port 6080.

Postgres stays on `84.8.131.140`. The site is `http://37.27.56.188:8088`.

## Install

On `37.27.56.188`:

```bash
cat > /root/mt5-official.sh
```

Paste all of `backend/mt5-official.sh`. Press Enter, then Ctrl+D.

```bash
bash /root/mt5-official.sh
```

When it prints `Screen is ready`, open http://37.27.56.188:6080/vnc.html and click **Connect**. Leave Encrypt off. There is no password.

The MetaTrader installer opens on that screen. Click **Next** until it finishes.

If the debugger message appears, click **OK** once. This script does not start the installer again.

The script is done when it prints `Official installer finished` and a path ending in `terminal64.exe`.

## Connect the Flutter app

Do not log in on the VNC screen. Leave that MetaTrader window open. The app sends the account.

```bash
cat > /root/mt5-link.sh
```

Paste all of `backend/mt5-link.sh`. Press Enter, then Ctrl+D.

```bash
bash /root/mt5-link.sh
```

When the log says `Connected to the engine`, open http://37.27.56.188:8088, sign in, and press **Connect MT5**. Type the account number, password, and server there.

# MT5 on 37.27.56.188

MetaTrader 5, the Python bridge, the Flutter app, the Java API, and the Python engine all run on **37.27.56.188** (64 GB RAM). Postgres stays on **84.8.131.140**. Do not install MetaTrader on `84.8.131.140`. That machine is ARM.

The image `mt5-bridge:latest` is built. The Portainer service `mt5-bridge_mt5` is running. Swarm does not name the container `mt5-bridge`.

`mt5.md` is the MetaQuotes download. The container downloads that installer. Do not run `mt5linux.sh` on the host.

## What to do now

On `37.27.56.188`:

```bash
sudo docker logs -f --tail 50 $(sudo docker ps -q --filter name=mt5-bridge_mt5)
```

Lines that only repeat `waiting for terminal64.exe` or `installer is still open` mean the MetaTrader setup window is waiting for a click. Open `http://37.27.56.188:6080/vnc.html`, enter `VNC_PASSWORD`, and press Next until the install finishes. Do not update the stack while that log is moving.

Wait until the log prints both of these:

```text
[provision] 4/4 done
Connected to the engine.
```

Press Ctrl+C. The container keeps running. The first install can take 5–15 minutes. Healthy in Portainer only means the container process is up. The two lines above mean MetaTrader is installed and the bridge has reached the backend.

Then run:

```bash
sudo docker exec -it $(sudo docker ps -q --filter name=mt5-bridge_mt5) /opt/mt5/svc.sh check
```

Open `http://37.27.56.188:8088` and sign in. In the app, enter the broker account number, trading password, and server name, then press **Connect MT5**. Leave `MT5_LOGIN`, `MT5_PASSWORD`, and `MT5_SERVER` empty in Portainer. A later login from the app replaces the account.

On the backend server, this must include `"connected":true`:

```bash
sudo docker exec forexbot-engine python -c "import urllib.request;print(urllib.request.urlopen('http://localhost:8000/health').read().decode())"
```

The dashboard then shows the MetaTrader balance. Use a demo account for the first **Trade Now**.

If the log is still on `[provision] downloading` or `waiting for terminal64.exe`, leave it. Do not update the stack while those lines are moving.

## Values already set in Portainer

| Value | Where it comes from |
|---|---|
| `ENGINE_API_KEY` | The same value as `ENGINE_API_KEY` in `backend/.env` on the backend |
| `VNC_PASSWORD` | The password chosen for the MetaTrader screen |
| `MT5_LOGIN`, `MT5_PASSWORD`, `MT5_SERVER` | Leave empty. The Flutter app sends them |

## The screen

`ENABLE_VNC` is `1`. Open `http://37.27.56.188:6080/vnc.html` and use `VNC_PASSWORD`.

In MetaTrader: **Tools → Options → Expert Advisors** → tick **Allow algorithmic trading**. The Algo Trading button must be green.

After that works, set `ENABLE_VNC` to `0` in Portainer and update the stack. The bridge keeps running.

## The stack

Portainer → stack `mt5-bridge`. This is the yaml that is running. Leave **Re-pull image** off. Portainer rejects `pull_policy`, `mem_limit`, and `memswap_limit`.

```yaml
services:
  mt5:
    image: mt5-bridge:latest
    container_name: mt5-bridge
    hostname: mt5-bridge
    restart: always
    environment:
      MT5_BRIDGE_URL: ${MT5_BRIDGE_URL:-ws://37.27.56.188:8088/mt5-bridge}
      ENGINE_API_KEY: ${ENGINE_API_KEY:?Set ENGINE_API_KEY to the same value as the backend}
      MT5_LOGIN: ${MT5_LOGIN:-}
      MT5_PASSWORD: ${MT5_PASSWORD:-}
      MT5_SERVER: ${MT5_SERVER:-}
      ENABLE_VNC: ${ENABLE_VNC:-1}
      VNC_PASSWORD: ${VNC_PASSWORD:-}
      TZ: Etc/UTC
    ports:
      - target: 6080
        published: 6080
        protocol: tcp
        mode: host
    volumes:
      - mt5-wine:/wine
    tmpfs:
      - /tmp:size=256m,mode=1777
    shm_size: "256m"
    oom_score_adj: 500
    healthcheck:
      test: ["CMD", "/opt/mt5/svc.sh", "health"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 900s
    stop_grace_period: 45s
    dns:
      - 1.1.1.1
      - 8.8.8.8
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
    deploy:
      resources:
        limits:
          memory: 8G
        reservations:
          memory: 2G
      restart_policy:
        condition: any
        delay: 10s
        window: 120s
volumes:
  mt5-wine:
    name: mt5-wine
```

The container may use 8 GB of the 64 GB on this server. A crash, a Docker restart, or a reboot starts it again. The broker login stays in the `mt5-wine` volume. Do not delete that volume.

## Build again only when the image changes

On `37.27.56.188`, save the file, then build:

```bash
cat > /tmp/bootstrap.sh
```

Paste `backend/mt5-linux/bootstrap.sh` from Cursor. Press Enter, then **Ctrl+D**.

```bash
bash /tmp/bootstrap.sh
sudo docker service update --force mt5-bridge_mt5
```

`IMAGE READY` and `Service mt5-bridge_mt5 converged` mean the new image is the one running. `uname -m` must print `x86_64`.

## When something is wrong

| What you see | What to do |
|---|---|
| `docker logs mt5-bridge` says no such container | Use `mt5-bridge_mt5`, as in the first command on this page |
| Log ends on `downloading` and the container exits | Build again with the current `bootstrap.sh`, then `sudo docker service update --force mt5-bridge_mt5` |
| `Not connected` or a timeout | `http://37.27.56.188:8088` must answer. Port 8088 must be open |
| websocket close `1008` | `ENGINE_API_KEY` does not match the backend |
| `svc.sh check` says account `NONE` | Press **Connect MT5** in the Flutter app |
| Orders return `10027` | Algo Trading is off. Use the screen section |

Postgres stays on `84.8.131.140`. Do not stop it, and do not install MetaTrader there.

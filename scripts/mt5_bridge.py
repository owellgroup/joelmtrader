"""RPyC bridge so the cloud Python engine can use the local MT5 desktop.

Run this on the Windows PC, with the MetaTrader 5 window already open.
Leave this process running. The engine connects to TCP port 18812.
"""
import rpyc
from rpyc.core import SlaveService
from rpyc.utils.server import ThreadedServer

PORT = 18812


def main():
    import MetaTrader5  # noqa: F401  — fails here if the package is missing

    print(f"MT5 bridge listening on 0.0.0.0:{PORT}")
    print("Keep this window open. Keep the MetaTrader 5 window open and logged in.")
    print("Algo Trading on the toolbar must stay green.")
    ThreadedServer(
        SlaveService,
        hostname="0.0.0.0",
        port=PORT,
        reuse_addr=True,
        protocol_config={
            "allow_public_attrs": True,
            "allow_pickle": True,
            "allow_all_attrs": True,
            "sync_request_timeout": 120,
        },
    ).start()


if __name__ == "__main__":
    main()

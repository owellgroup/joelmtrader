"""Linux client for the MetaTrader 5 terminal on a Windows PC.

The official MetaTrader5 package only runs on Windows, next to terminal64.exe.
On Linux the engine opens an RPyC connection to scripts/mt5_bridge.py, which
imports that package on the PC where the desktop terminal is open.
"""


_CALLABLES = {
    "function",
    "builtin_function_or_method",
    "method",
    "cython_function_or_method",
}


class RemoteMetaTrader5:
    def __init__(self, host: str, port: int):
        if not host:
            raise RuntimeError(
                "MT5_RPYC_HOST is empty. Set it to the public IP of the Windows PC "
                "that is running the MT5 desktop and scripts\\mt5-bridge-windows.bat."
            )
        import rpyc

        self._rpyc = rpyc
        self._conn = rpyc.classic.connect(
            host,
            int(port),
            config={"sync_request_timeout": 120, "allow_pickle": True},
        )
        self._conn.execute("import MetaTrader5 as mt5")

    def __getattr__(self, name: str):
        if name.startswith("_"):
            raise AttributeError(name)
        kind = self._conn.eval(f"type(getattr(mt5, {name!r})).__name__")
        if kind in _CALLABLES:
            def invoke(*args, **kwargs):
                code = f"mt5.{name}(*{args!r}, **{kwargs!r})"
                result = self._conn.eval(code)
                # Candle arrays must be real numpy objects. Account and order
                # results stay remote so their fields (login, retcode, ...) work.
                if name.startswith("copy_"):
                    return self._rpyc.classic.obtain(result)
                return result

            return invoke
        return self._rpyc.classic.obtain(self._conn.eval(f"mt5.{name}"))

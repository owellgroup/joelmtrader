import pandas as pd


class BrokerError(Exception):
    pass


class Broker:
    """Common interface. Implemented by MT5Broker (live/demo) and PaperBroker (simulation)."""
    name = "base"

    def connect(self, login=None, password=None, server=None) -> dict: raise NotImplementedError
    def status(self) -> dict: raise NotImplementedError
    def is_connected(self) -> bool: raise NotImplementedError
    def account(self) -> dict | None: raise NotImplementedError
    def symbol_info(self, symbol: str) -> dict: raise NotImplementedError
    def tick(self, symbol: str) -> dict | None: raise NotImplementedError
    def rates(self, symbol: str, tf: str, count: int) -> pd.DataFrame: raise NotImplementedError
    def positions(self) -> list: raise NotImplementedError
    def send_market(self, symbol, side, volume, sl, tp, comment="") -> dict: raise NotImplementedError
    def close_position(self, ticket) -> dict: raise NotImplementedError
    def modify_sltp(self, ticket, sl, tp) -> dict: raise NotImplementedError
    def deal_summary(self, ticket) -> dict | None: raise NotImplementedError
    def margin_required(self, symbol, side, volume) -> float: raise NotImplementedError

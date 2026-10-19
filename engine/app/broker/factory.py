from ..config import Settings

_broker = None


def get_broker():
    global _broker
    if _broker is None:
        if Settings.broker_mode == "mt5":
            from .mt5_broker import MT5Broker
            _broker = MT5Broker()
            _broker.connect()
        else:
            from .paper_broker import PaperBroker
            _broker = PaperBroker()
    return _broker

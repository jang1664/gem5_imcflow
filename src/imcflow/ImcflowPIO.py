from m5.objects.Device import PioDevice
from m5.params import Addr
from m5.SimObject import SimObject


class ImcflowPIO(PioDevice):
    type = "ImcflowPIO"
    cxx_header = "imcflow/imcflow_pio.hh"

    pio_addr = Addr(0)
    pio_size = Addr(0x20000)  # default window size; adjust in config script

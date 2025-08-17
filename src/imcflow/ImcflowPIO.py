from m5.objects.Device import BasicPioDevice
from m5.params import Addr, Param
from m5.SimObject import SimObject


class ImcflowPIO(BasicPioDevice):
    type = "ImcflowPIO"
    cxx_header = "imcflow/imcflow_pio.hh"
    cxx_class = "gem5::ImcflowPIO"
    # Size of the MMIO window; required by BasicPioDevice C++ constructor
    pio_size = Param.Addr(0x1000, "Size of address range")

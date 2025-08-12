from m5.objects.Device import BasicPioDevice
from m5.params import Addr
from m5.SimObject import SimObject


class ImcflowPIO(BasicPioDevice):
    type = "ImcflowPIO"
    cxx_header = "imcflow/imcflow_pio.hh"

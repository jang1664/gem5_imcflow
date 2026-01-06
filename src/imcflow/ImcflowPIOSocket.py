from m5.objects.Device import BasicPioDevice
from m5.params import (
    Addr,
    Param,
)
from m5.SimObject import SimObject


class ImcflowPIOSocket(BasicPioDevice):
    """Socket-based ImcflowPIO device for VCS co-simulation

    This device communicates with VCS via TCP sockets for RTL simulation.
    Use ImcflowPIO (original) for Python simulator integration.
    """

    type = "ImcflowPIOSocket"
    cxx_header = "imcflow/imcflow_pio_socket.hh"
    cxx_class = "gem5::ImcflowPIOSocket"

    # Size of the MMIO window
    pio_size = Param.Addr(0x1000, "Size of address range")

    # Socket connection parameters for VCS simulation
    vcs_host = Param.String("127.0.0.1", "VCS server host address")
    vcs_port = Param.Int(9999, "VCS server port number")

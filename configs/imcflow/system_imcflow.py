# Minimal gem5 system config that attaches ImcflowPIO to a simple system

from m5.objects import *

def make_system(imc_base=0x80000000, imc_size=0x20000, mem_size="512MB"):
    system = System()
    system.clk_domain = SrcClockDomain()
    system.clk_domain.clock = "1GHz"
    system.clk_domain.voltage_domain = VoltageDomain()

    system.mem_mode = "timing"
    system.mem_ranges = [AddrRange(mem_size)]

    system.membus = SystemXBar()

    # CPU
    system.cpu = X86TimingSimpleCPU()

    # L2-less, connect directly to membus
    system.cpu.icache_port = system.membus.cpu_side_ports
    system.cpu.dcache_port = system.membus.cpu_side_ports

    # Interrupts
    system.cpu.createInterruptController()
    system.cpu.interrupts[0].pio = system.membus.mem_side_ports
    system.cpu.interrupts[0].int_requestor = system.membus.cpu_side_ports
    system.cpu.interrupts[0].int_responder = system.membus.mem_side_ports

    # Memory controller
    system.mem_ctrl = MemCtrl()
    system.mem_ctrl.dram = DDR3_1600_8x8()
    system.mem_ctrl.dram.range = system.mem_ranges[0]
    system.mem_ctrl.port = system.membus.mem_side_ports

    # System port
    system.system_port = system.membus.cpu_side_ports

    # Imcflow PIO device
    system.imc = ImcflowPIO(pio_addr=imc_base, pio_size=imc_size)
    system.imc.pio = system.membus.mem_side_ports

    return system

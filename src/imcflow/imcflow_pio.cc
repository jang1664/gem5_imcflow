#include "imcflow/imcflow_pio.hh"

#include <pybind11/embed.h>
#include <pybind11/pybind11.h>

#include "base/logging.hh"
#include "dev/dma_device.hh"

namespace py = pybind11;

namespace gem5 {

ImcflowPIO::ImcflowPIO(const ImcflowPIO::Params &p) : PioDevice(p) {
  // Map the PIO range based on parameters
  ranges.clear();
  ranges.push_back(RangeSize(p.pio_addr, p.pio_size));
}

AddrRangeList ImcflowPIO::getAddrRanges() const { return ranges; }

static py::object get_forwarder() {
  try {
    py::module m = py::module::import("imcflow_sim.imcflow.bridge");
    return m.attr("get_or_create_forwarder")();
  } catch (const std::exception &e) {
    panic("Failed to import imcflow bridge: %s", e.what());
  }
}

Tick ImcflowPIO::read(PacketPtr pkt) {
  const Addr addr = pkt->getAddr() - ranges.front().start();
  const unsigned size = pkt->getSize();

  py::gil_scoped_acquire gil;
  auto fwd = get_forwarder();
  auto data_obj = fwd.attr("read")(py::int_(addr), py::int_(size));
  const uint64_t data = data_obj.cast<uint64_t>();

  pkt->makeResponse();
  pkt->setUintX(data, size, true);
  return pioDelay;
}

Tick ImcflowPIO::write(PacketPtr pkt) {
  const Addr addr = pkt->getAddr() - ranges.front().start();
  const unsigned size = pkt->getSize();
  uint64_t data = pkt->getUintX(size);

  py::gil_scoped_acquire gil;
  auto fwd = get_forwarder();
  // strobe: gem5 doesn't pass; set None
  fwd.attr("write")(py::int_(addr), py::int_(size), py::int_(data));

  pkt->makeResponse();
  return pioDelay;
}

}  // namespace gem5

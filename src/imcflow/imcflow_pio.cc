#include "imcflow/imcflow_pio.hh"

#include <pybind11/embed.h>
#include <pybind11/pybind11.h>

#include "base/logging.hh"

namespace py = pybind11;

namespace gem5 {

ImcflowPIO::ImcflowPIO(const ImcflowPIO::Params &p)
  : BasicPioDevice(p, p.pio_size) {
  // Initialize Python interpreter if not already done
  if (!Py_IsInitialized()) {
    py::initialize_interpreter();
  }
}

static py::object get_forwarder() {
  try {
    py::module m = py::module::import("imcflow_sim.imcflow.bridge");
    return m.attr("get_or_create_forwarder")();
  } catch (const std::exception &e) {
    panic("Failed to import imcflow bridge: %s", e.what());
  }
}

Tick ImcflowPIO::read(PacketPtr pkt) {
  const Addr addr = pkt->getAddr() - pioAddr;
  const unsigned size = pkt->getSize();

  py::gil_scoped_acquire gil;
  auto fwd = get_forwarder();
  auto data_obj = fwd.attr("read")(py::int_(addr), py::int_(size));
  const uint64_t data = data_obj.cast<uint64_t>();

  pkt->makeResponse();
  pkt->setUintX(data, ByteOrder::little);
  return pioDelay;
}

Tick ImcflowPIO::write(PacketPtr pkt) {
  const Addr addr = pkt->getAddr() - pioAddr;
  const unsigned size = pkt->getSize();
  uint64_t data = pkt->getUintX(ByteOrder::little);

  py::gil_scoped_acquire gil;
  auto fwd = get_forwarder();
  // strobe: gem5 doesn't pass; set None
  fwd.attr("write")(py::int_(addr), py::int_(size), py::int_(data));

  pkt->makeResponse();
  return pioDelay;
}

}  // namespace gem5

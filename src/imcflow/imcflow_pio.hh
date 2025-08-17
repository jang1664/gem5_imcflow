#ifndef __IMCFLOW_PIO_HH__
#define __IMCFLOW_PIO_HH__

#include <memory>

#include "dev/io_device.hh"
#include "params/ImcflowPIO.hh"

namespace gem5 {

class ImcflowPIO : public BasicPioDevice {
 public:
  using Params = ImcflowPIOParams;
  ImcflowPIO(const Params &p);

 protected:
  Tick read(PacketPtr pkt) override;
  Tick write(PacketPtr pkt) override;
};

}  // namespace gem5

#endif  // __IMCFLOW_PIO_HH__

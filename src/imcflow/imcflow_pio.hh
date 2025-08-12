#ifndef __IMCFLOW_PIO_HH__
#define __IMCFLOW_PIO_HH__

#include <memory>

#include "dev/dma_device.hh"
#include "params/ImcflowPIO.hh"

namespace gem5 {

class ImcflowPIO : public PioDevice {
 public:
  using Params = ImcflowPIOParams;
  ImcflowPIO(const Params &p);

 protected:
  AddrRangeList getAddrRanges() const override;
  Tick read(PacketPtr pkt) override;
  Tick write(PacketPtr pkt) override;

 private:
  AddrRangeList ranges;
};

}  // namespace gem5

#endif  // __IMCFLOW_PIO_HH__

#ifndef __IMCFLOW_PIO_SOCKET_HH__
#define __IMCFLOW_PIO_SOCKET_HH__

#include <string>

#include "dev/io_device.hh"
#include "params/ImcflowPIOSocket.hh"

namespace gem5 {

/**
 * Socket-based ImcflowPIO device for VCS co-simulation
 * Communicates with VCS via TCP sockets instead of Python
 */
class ImcflowPIOSocket : public BasicPioDevice
{
 public:
  using Params = ImcflowPIOSocketParams;
  ImcflowPIOSocket(const Params &p);
  ~ImcflowPIOSocket();

 protected:
  Tick read(PacketPtr pkt) override;
  Tick write(PacketPtr pkt) override;

 private:
  // Socket communication
  int socket_fd;
  std::string vcs_host;
  int vcs_port;
  bool connected;

  // Initialize socket connection to VCS
  bool initSocket();
  void closeSocket();
};

}  // namespace gem5

#endif  // __IMCFLOW_PIO_SOCKET_HH__

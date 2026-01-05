#include "imcflow/imcflow_pio_socket.hh"

#include <arpa/inet.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <sys/socket.h>
#include <unistd.h>

#include <cerrno>
#include <cstring>

#include "base/logging.hh"
#include "debug/ImcflowPIOSocket.hh"

namespace gem5 {

// Transaction structure matching VCS DPI side
// NOTE: Must NOT be packed - VCS uses natural alignment (12 bytes total)
struct Transaction
{
    uint8_t is_write;  // 1 = write, 0 = read (offset 0)
                       // 3 bytes padding by compiler (offset 1-3)
    uint32_t addr;     // Address (offset 4, aligned)
    uint32_t data;     // Data for write or response for read (offset 8)
};

ImcflowPIOSocket::ImcflowPIOSocket(const ImcflowPIOSocket::Params &p)
  : BasicPioDevice(p, p.pio_size),
    socket_fd(-1),
    vcs_host(p.vcs_host),
    vcs_port(p.vcs_port),
    connected(false) {

  DPRINTF(ImcflowPIOSocket, "Initializing ImcflowPIOSocket with connection to %s:%d\n",
          vcs_host.c_str(), vcs_port);

  // Try to connect to VCS server
  if (!initSocket()) {
    warn("ImcflowPIOSocket: Failed to connect to VCS server at %s:%d\n",
         vcs_host.c_str(), vcs_port);
    warn("ImcflowPIOSocket: Will retry on first transaction\n");
  }
}

ImcflowPIOSocket::~ImcflowPIOSocket() {
  closeSocket();
}

bool ImcflowPIOSocket::initSocket() {
  if (connected && socket_fd >= 0) {
    return true;
  }

  // Create socket
  socket_fd = socket(AF_INET, SOCK_STREAM, 0);
  if (socket_fd < 0) {
    warn("ImcflowPIOSocket: Failed to create socket: %s\n", strerror(errno));
    return false;
  }

  // Set TCP_NODELAY for lower latency
  int flag = 1;
  if (setsockopt(socket_fd, IPPROTO_TCP, TCP_NODELAY, &flag, sizeof(flag)) < 0) {
    warn("ImcflowPIOSocket: Failed to set TCP_NODELAY: %s\n", strerror(errno));
  }

  // Connect to VCS server
  struct sockaddr_in addr;
  memset(&addr, 0, sizeof(addr));
  addr.sin_family = AF_INET;
  addr.sin_port = htons(vcs_port);

  if (inet_pton(AF_INET, vcs_host.c_str(), &addr.sin_addr) <= 0) {
    warn("ImcflowPIOSocket: Invalid server address: %s\n", vcs_host.c_str());
    close(socket_fd);
    socket_fd = -1;
    return false;
  }

  if (connect(socket_fd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
    warn("ImcflowPIOSocket: Failed to connect to %s:%d: %s\n",
         vcs_host.c_str(), vcs_port, strerror(errno));
    close(socket_fd);
    socket_fd = -1;
    return false;
  }

  DPRINTF(ImcflowPIOSocket, "Successfully connected to VCS server at %s:%d\n",
          vcs_host.c_str(), vcs_port);
  connected = true;
  return true;
}

void ImcflowPIOSocket::closeSocket() {
  if (socket_fd >= 0) {
    DPRINTF(ImcflowPIOSocket, "Closing socket connection\n");
    close(socket_fd);
    socket_fd = -1;
    connected = false;
  }
}

Tick ImcflowPIOSocket::read(PacketPtr pkt) {
  const Addr addr = pkt->getAddr() - pioAddr;
  const unsigned size = pkt->getSize();
  DPRINTF(ImcflowPIOSocket, "Read request at addr: 0x%lx, size: %u\n", addr, size);

  // only supports 4-byte read
  assert(size == 4);

  // Ensure socket is connected
  if (!connected) {
    if (!initSocket()) {
      panic("ImcflowPIOSocket: Cannot connect to VCS server "
            "for read at addr 0x%lx", addr);
    }
  }

  // Send read transaction to VCS
  Transaction txn;
  txn.is_write = 0;
  txn.addr = static_cast<uint32_t>(addr);
  txn.data = 0;

  ssize_t sent = send(socket_fd, &txn, sizeof(txn), 0);
  if (sent != sizeof(txn)) {
    panic("ImcflowPIOSocket: Failed to send read transaction "
          "(sent %zd/%zu bytes): %s", sent, sizeof(txn), strerror(errno));
  }

  // Receive response
  Transaction response;
  ssize_t received = recv(socket_fd, &response, sizeof(response),
                          MSG_WAITALL);
  if (received != sizeof(response)) {
    panic("ImcflowPIOSocket: Failed to receive read response "
          "(got %zd/%zu bytes): %s",
          received, sizeof(response), strerror(errno));
  }

  const uint64_t data = response.data;

  pkt->makeResponse();
  pkt->setUintX(data, ByteOrder::little);
  DPRINTF(ImcflowPIOSocket, "Read response data: 0x%lx\n", data);
  return pioDelay;
}

Tick ImcflowPIOSocket::write(PacketPtr pkt) {
  const Addr addr = pkt->getAddr() - pioAddr;
  const unsigned size = pkt->getSize();
  uint64_t data = pkt->getUintX(ByteOrder::little);
  DPRINTF(ImcflowPIOSocket, "Write request at addr: 0x%lx, size: %u, data: 0x%lx\n",
          addr, size, data);

  // only supports 4-byte write
  assert(size == 4);

  // Ensure socket is connected
  if (!connected) {
    if (!initSocket()) {
      panic("ImcflowPIOSocket: Cannot connect to VCS server "
            "for write at addr 0x%lx", addr);
    }
  }

  // Send write transaction to VCS
  Transaction txn;
  txn.is_write = 1;
  txn.addr = static_cast<uint32_t>(addr);
  txn.data = static_cast<uint32_t>(data);

  ssize_t sent = send(socket_fd, &txn, sizeof(txn), 0);
  if (sent != sizeof(txn)) {
    panic("ImcflowPIOSocket: Failed to send write transaction "
          "(sent %zd/%zu bytes): %s", sent, sizeof(txn), strerror(errno));
  }

  pkt->makeResponse();
  return pioDelay;
}

}  // namespace gem5

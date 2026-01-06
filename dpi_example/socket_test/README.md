# Socket DPI Test - gem5 ↔ VCS Communication Proof of Concept

This directory contains a proof-of-concept demonstrating socket-based communication between two processes using SystemVerilog DPI-C.

## Architecture

```
Client Process          Server Process (VCS)
─────────────          ──────────────────────
socket_client    ←→    DPI-C Socket Server
  (C++)         TCP         (C++)
                              ↕ DPI
                        SystemVerilog TB
                              ↕
                        Memory Model
```

## Files

- **dpi_socket_server.cpp** - DPI-C socket server implementation
- **testbench_socket.sv** - SystemVerilog testbench with DPI imports
- **socket_client.cpp** - Test client (simulates gem5's role)
- **Makefile** - Build and run automation

## Transaction Protocol

Simple binary protocol over TCP:

```c
struct Transaction {
    uint8_t is_write;    // 1=write, 0=read
    uint32_t addr;       // Byte address
    uint32_t data;       // Data (write) or response (read)
};
```

### Write Transaction
```
Client → Server: {is_write=1, addr, data}
```

### Read Transaction
```
Client → Server: {is_write=0, addr, data=0}
Server → Client: {is_write=0, addr=0, data=<read_value>}
```

## Usage

### Method 1: Separate terminals

Terminal 1 (Start VCS simulation):
```bash
cd /root/dpi_example/socket_test
make compile
./simv_socket
# Waits for client connection...
```

Terminal 2 (Run client):
```bash
cd /root/dpi_example/socket_test
make client
./socket_client 9999
```

### Method 2: Automated test

```bash
cd /root/dpi_example/socket_test
make test
# Runs both simulation and client automatically
```

## How It Works

1. **VCS Simulation Startup**:
   - SystemVerilog calls `socket_server_init(9999)` to create TCP server
   - Calls `socket_server_accept()` to wait for client connection (blocking)

2. **Client Connection**:
   - Client connects to localhost:9999
   - VCS accepts connection and proceeds

3. **Transaction Loop**:
   - SystemVerilog polls `socket_has_transaction()` (non-blocking)
   - When transaction available, calls `socket_recv_transaction()`
   - Processes write/read on memory model
   - For reads, calls `socket_send_response()` to return data

4. **Cleanup**:
   - Client closes connection
   - SystemVerilog detects disconnect and exits
   - Calls `socket_server_close()` to cleanup

## Next Steps

This proof-of-concept can be extended to:

1. **gem5 Integration**: Replace `socket_client.cpp` with gem5's `ImcflowPIO` device
2. **RTL Integration**: Replace memory model with actual imcflow RTL
3. **Protocol Enhancement**: Add handshaking, error handling, multiple outstanding transactions
4. **Performance**: Add buffering, pipelining

## Key Features Demonstrated

✅ Socket server in DPI-C
✅ Non-blocking transaction checking
✅ Blocking transaction receive
✅ Read response mechanism
✅ Memory model in SystemVerilog
✅ Client-server architecture

## Testing

The client performs these tests:
1. Write 0xDEADBEEF to address 0x1000
2. Read from address 0x2000 (pre-populated with 0x12345678)
3. Multiple sequential writes to addresses 0x3000-0x300C

Monitor both terminals to see the transaction flow!

# Socket-Based gem5 ↔ VCS Co-Simulation: Feasibility and Implementation

## Executive Summary

**✅ FEASIBILITY CONFIRMED**: It is absolutely possible to replace the Python imcflow simulator with RTL running in VCS, using socket-based inter-process communication via SystemVerilog DPI-C.

## Proof-of-Concept Results

Successfully demonstrated:
- ✅ Socket server in C++ callable via SystemVerilog DPI-C
- ✅ TCP connection between separate client and VCS processes
- ✅ WRITE transactions from client to SystemVerilog memory model
- ✅ READ transactions with response data sent back to client
- ✅ Non-blocking transaction polling
- ✅ Clean connection/disconnection handling

## Architecture Comparison

### Current: gem5 → Python
```
┌─────────────┐
│ gem5::      │
│ ImcflowPIO  │
│   (C++)     │
└──────┬──────┘
       │ pybind11 (in-process)
       ↓
┌──────────────┐
│  Python GIL  │
└──────┬───────┘
       │
       ↓
┌──────────────────┐
│ Python Imcflow   │
│   Simulator      │
└──────────────────┘
```

### Proposed: gem5 → VCS via Socket
```
Process 1: gem5           Process 2: VCS
───────────────────       ──────────────────────
┌─────────────┐          ┌────────────────────┐
│ gem5::      │          │  DPI-C Socket      │
│ ImcflowPIO  │   TCP    │  Server (C++)      │
│  (modified) │◄────────►│                    │
└─────────────┘  socket  └─────────┬──────────┘
                                   │ DPI import/export
                                   ↓
                         ┌────────────────────┐
                         │  SystemVerilog TB  │
                         └─────────┬──────────┘
                                   │
                                   ↓
                         ┌────────────────────┐
                         │  RTL Design        │
                         │  (imcflow)         │
                         └────────────────────┘
```

## Transaction Protocol

### Wire Format
```c
struct Transaction {
    uint8_t  is_write;  // 1=write, 0=read
    uint32_t addr;      // Byte address
    uint32_t data;      // Write data or read response
}; // Total: 9 bytes
```

### Write Flow
```
1. gem5: send({is_write=1, addr, data}) → Socket
2. VCS: socket_recv_transaction() receives transaction
3. VCS: SystemVerilog processes write to memory/RTL
4. (No response needed for writes)
```

### Read Flow
```
1. gem5: send({is_write=0, addr, data=0}) → Socket
2. VCS: socket_recv_transaction() receives transaction
3. VCS: SystemVerilog reads from memory/RTL
4. VCS: socket_send_response(read_data) → Socket
5. gem5: recv() blocks until response received
```

## Implementation Roadmap

### Phase 1: Simple Test (✅ COMPLETED)
- [x] Create DPI-C socket server
- [x] Create SystemVerilog testbench with memory model
- [x] Create standalone C++ client
- [x] Test write transactions
- [x] Test read transactions with responses
- [x] Verify connection handling

### Phase 2: gem5 Integration (NEXT)
1. **Modify ImcflowPIO** ([imcflow_pio.cc](file:///root/project/imcflow/pmap/ISA_sim/gem5/src/imcflow/imcflow_pio.cc))
   - Replace pybind11 calls with socket client code
   - Keep existing `read()` and `write()` interface
   - Add socket connection management (init, reconnect, cleanup)
   - Handle socket errors gracefully

2. **Update gem5 Configuration**
   - Add socket configuration parameters (host, port)
   - Remove Python bridge dependencies
   - Start VCS simulation before gem5 or use external launcher

### Phase 3: RTL Integration
1. **Replace Memory Model with Real RTL**
   - Import actual imcflow RTL modules
   - Connect DPI interface to RTL top-level ports
   - Map address space to RTL interface

2. **Add Timing Model** (if needed)
   - SystemVerilog can model realistic delays
   - Report back actual cycle counts if desired

### Phase 4: Enhancements
- Pipeline multiple outstanding transactions
- Add transaction buffering/queuing
- Implement error handling and recovery
- Add performance monitoring
- Support multiple concurrent clients (if needed)

## Key Design Decisions

### Why Socket Communication?
| Approach | Pros | Cons |
|----------|------|------|
| **Socket (TCP)** | ✅ Separate processes<br>✅ Language agnostic<br>✅ Debuggable<br>✅ Can run on different machines | ⚠️ Slightly higher latency<br>⚠️ Need protocol |
| Shared Memory | Faster | Complex synchronization, platform-specific |
| Named Pipes | Simple | Linux-only, harder debugging |
| Direct Link | Fastest | Requires same process space |

**Decision**: Socket communication chosen for:
- **Flexibility**: gem5 and VCS can run independently
- **Debugging**: Can inspect traffic with tcpdump/wireshark
- **Development**: Can test each side separately
- **Portability**: Works across systems

### DPI-C vs. Other SystemVerilog Interfaces
- **DPI-C**: Chosen for direct C/C++ integration, industry standard
- Alternative (VPI): More complex, less efficient for this use case
- Alternative (PLI): Legacy, avoid

### Blocking vs. Non-Blocking
- **Current Implementation**:
  - `socket_server_accept()`: Blocking (wait for client once at start)
  - `socket_has_transaction()`: Non-blocking (poll for data)
  - `socket_recv_transaction()`: Blocking (wait for full transaction)
  - `socket_send_response()`: Blocking (send full response)

- **gem5 Side**: Will use blocking socket operations since gem5 naturally blocks on MMIO anyway

## Performance Considerations

### Latency Analysis
```
Current (pybind11 in-process):
  gem5 MMIO → Python call: ~100-500 ns

Proposed (socket):
  gem5 MMIO → TCP localhost → VCS: ~1-10 μs
```

**Impact**: For functional simulation, 10x latency increase is acceptable. The gem5 CPU simulation itself is much slower than this overhead.

### Optimization Opportunities
1. **TCP_NODELAY**: Disable Nagle's algorithm for lower latency
2. **Buffering**: Send multiple transactions in one packet
3. **Unix Domain Sockets**: ~2x faster than TCP for local communication
4. **Zero-Copy**: Use sendfile() or splice() where applicable

## Testing Strategy

### Unit Tests
- ✅ Socket server init/cleanup
- ✅ Connection accept/reject
- ✅ Transaction send/receive
- ✅ Error handling (disconnect, timeout)

### Integration Tests
- [ ] gem5 ImcflowPIO → Socket → SystemVerilog memory
- [ ] Full gem5 simulation with socket backend
- [ ] gem5 → Socket → RTL (simple module)
- [ ] gem5 → Socket → Full imcflow RTL

### Regression Tests
- [ ] Compare gem5+Python vs. gem5+Socket+SystemVerilog results
- [ ] Verify identical behavior for same workloads
- [ ] Performance benchmarks

## Files Created

### Proof-of-Concept
```
/root/dpi_example/socket_test/
├── dpi_socket_server.cpp      # DPI-C socket server implementation
├── testbench_socket.sv         # SystemVerilog testbench
├── socket_client.cpp           # Test client (simulates gem5)
├── Makefile                    # Build automation
├── run_test.sh                 # Test runner script
└── README.md                   # Documentation
```

## Next Steps

1. **Immediate**: Modify gem5's ImcflowPIO to use socket client
2. **Test**: Verify gem5 can connect to VCS and perform basic transactions
3. **Integrate**: Replace memory model with actual imcflow RTL interface
4. **Validate**: Run full imcflow workloads and compare against Python simulator

## Conclusion

✅ **Socket-based gem5 ↔ VCS co-simulation is proven feasible**
✅ **DPI-C provides clean interface for SystemVerilog ↔ C++ integration**
✅ **Proof-of-concept successfully demonstrates bidirectional communication**
✅ **Ready to proceed with gem5 integration**

The architecture is sound, the technology works, and the path forward is clear!

module testbench_socket;

    // Import DPI-C functions for socket server
    import "DPI-C" function int socket_server_init(input int port);
    import "DPI-C" function int socket_server_accept();
    import "DPI-C" function int socket_has_transaction();
    import "DPI-C" function int socket_recv_transaction(
        output int is_write,
        output int unsigned addr,
        output int unsigned data
    );
    import "DPI-C" function int socket_send_response(input int unsigned data);
    import "DPI-C" function void socket_server_close();

    // Simple memory model
    logic [31:0] memory [1024]; // 4KB memory

    // Transaction variables
    int is_write;
    int unsigned addr;
    int unsigned data;
    int result;
    int no_transaction_count;
    int transaction_received_count = 0;  // Track if we got any transactions

    initial begin
        $display("=== Starting Socket DPI Test ===\n");

        // Initialize memory with some test data
        for (int i = 0; i < 1024; i++) begin
            memory[i] = 32'h0;
        end
        memory[512] = 32'h12345678; // Pre-populate address 0x2000 (byte addr)

        // Initialize socket server
        $display("[SV] Initializing socket server on port 9999");
        result = socket_server_init(9999);
        if (result != 0) begin
            $display("[SV] ERROR: Failed to initialize socket server");
            $finish;
        end

        // Wait for client connection
        $display("[SV] Waiting for client connection...");
        result = socket_server_accept();
        if (result != 0) begin
            $display("[SV] ERROR: Failed to accept client");
            $finish;
        end

        $display("[SV] Client connected! Starting transaction processing...\n");

        // Main loop: process transactions
        no_transaction_count = 0;
        forever begin
            // Check if transaction is available
            result = socket_has_transaction();

            if (result > 0) begin
                no_transaction_count = 0; // Reset counter
                transaction_received_count++; // Count transactions
                // Transaction available - receive it
                result = socket_recv_transaction(is_write, addr, data);
                if (result != 0) begin
                    $display("[SV] ERROR: Failed to receive transaction");
                    break;
                end

                // Process the transaction
                if (is_write) begin
                    // Write operation - extract word address from byte address
                    // Use bit slicing to avoid SystemVerilog operator issues with DPI variables
                    automatic logic [31:0] addr_local = addr;
                    automatic logic [11:0] byte_offset = addr_local[11:0]; // Lower 12 bits (4KB range)
                    automatic int unsigned word_addr = {20'b0, byte_offset[11:2]}; // Bits [11:2] for word index

                    $display("[SV] Processing WRITE: addr=0x%08x, word=%0d, data=0x%08x",
                             addr, word_addr, data);
                    if (word_addr < 1024) begin
                        memory[word_addr] = data;
                    end else begin
                        $display("[SV] WARNING: Address out of bounds");
                    end
                end else begin
                    // Read operation - extract word address from byte address
                    automatic logic [31:0] addr_local = addr;
                    automatic logic [11:0] byte_offset = addr_local[11:0]; // Lower 12 bits (4KB range)
                    automatic int unsigned word_addr = {20'b0, byte_offset[11:2]}; // Bits [11:2] for word index
                    automatic logic [31:0] read_data;

                    $display("[SV] Processing READ: addr=0x%08x, word=%0d", addr, word_addr);
                    if (word_addr < 1024) begin
                        read_data = memory[word_addr];
                    end else begin
                        read_data = 32'hDEADDEAD; // Error value
                    end
                    $display("[SV] Read data: 0x%08x", read_data);

                    // Send response
                    result = socket_send_response(read_data);
                    if (result != 0) begin
                        $display("[SV] ERROR: Failed to send response");
                        break;
                    end
                end

                $display("");

            end else if (result < 0) begin
                // Error occurred or client disconnected
                $display("[SV] Client disconnected or error occurred");
                break;
            end else begin
                // No transaction available, wait a bit
                no_transaction_count++;

                // If we haven't received ANY transactions yet, wait longer (gem5 initialization)
                // Once we get transactions, use shorter timeout
                if (transaction_received_count == 0) begin
                    // Still waiting for first transaction - be very patient (200 seconds)
                    if (no_transaction_count > 2000000) begin
                        $display("[SV] No transactions after 200s, giving up");
                        break;
                    end
                end else begin
                    // Got transactions, now wait for more with shorter timeout (100 seconds)
                    if (no_transaction_count > 1000000) begin
                        $display("[SV] No more transactions for 10s after receiving %0d transactions",
                                 transaction_received_count);
                        $display("[SV] Assuming test complete");
                        break;
                    end
                end
                #100000; // 100000 time units (wait longer between polls)
            end
        end

        $display("\n[SV] Closing socket server");
        socket_server_close();

        $display("\n=== Socket DPI Test Completed ===");
        $finish;
    end

    // Timeout watchdog (300 seconds of simulation time to allow gem5 initialization)
    initial begin
        #300_000_000_000; // 300 billion time units timeout (5 minutes)
        $display("\n[SV] GLOBAL TIMEOUT (300s) - forcing finish");
        socket_server_close();
        $finish;
    end

endmodule

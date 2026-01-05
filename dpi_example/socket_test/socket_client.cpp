// Simple socket client to test the DPI server
// This simulates what gem5 would do

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

struct Transaction {
    uint8_t is_write;
    uint32_t addr;
    uint32_t data;
};

int main(int argc, char* argv[]) {
    const char* host = "127.0.0.1";
    int port = 9999;

    if (argc > 1) port = atoi(argv[1]);

    printf("[Client] Connecting to %s:%d\n", host, port);

    // Create socket
    int sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock < 0) {
        perror("socket");
        return 1;
    }

    // Connect to server
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    if (inet_pton(AF_INET, host, &addr.sin_addr) <= 0) {
        perror("inet_pton");
        return 1;
    }

    if (connect(sock, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        perror("connect");
        return 1;
    }

    printf("[Client] Connected!\n\n");

    // Test 1: Write transaction
    printf("[Client] Test 1: Writing 0xDEADBEEF to address 0x1000\n");
    Transaction txn_write;
    txn_write.is_write = 1;
    txn_write.addr = 0x1000;
    txn_write.data = 0xDEADBEEF;

    if (send(sock, &txn_write, sizeof(txn_write), 0) != sizeof(txn_write)) {
        perror("send write");
        return 1;
    }

    // Test 2: Read transaction
    printf("[Client] Test 2: Reading from address 0x2000\n");
    Transaction txn_read;
    txn_read.is_write = 0;
    txn_read.addr = 0x2000;
    txn_read.data = 0;

    if (send(sock, &txn_read, sizeof(txn_read), 0) != sizeof(txn_read)) {
        perror("send read");
        return 1;
    }

    // Receive response
    Transaction response;
    if (recv(sock, &response, sizeof(response), MSG_WAITALL) != sizeof(response)) {
        perror("recv response");
        return 1;
    }

    printf("[Client] Read response: 0x%08x\n\n", response.data);

    // Test 3: Multiple writes
    printf("[Client] Test 3: Multiple writes\n");
    for (int i = 0; i < 5; i++) {
        Transaction txn;
        txn.is_write = 1;
        txn.addr = 0x3000 + (i * 4);
        txn.data = 0x100 + i;

        printf("[Client] Writing 0x%08x to address 0x%08x\n", txn.data, txn.addr);
        if (send(sock, &txn, sizeof(txn), 0) != sizeof(txn)) {
            perror("send");
            return 1;
        }
        usleep(100000); // 100ms delay
    }

    printf("\n[Client] All tests completed. Closing connection.\n");
    close(sock);
    return 0;
}

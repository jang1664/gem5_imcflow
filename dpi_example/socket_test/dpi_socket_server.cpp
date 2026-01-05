#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <errno.h>
#include "svdpi.h"

extern "C" {

// Global state for socket server
static int server_fd = -1;
static int client_fd = -1;
static int server_port = 9999;

// Transaction structure matching MMIO protocol
struct Transaction {
    uint8_t is_write;    // 1 = write, 0 = read
    uint32_t addr;       // Address
    uint32_t data;       // Data (for write) or response (for read)
};

// Initialize socket server
// Returns: 0 on success, -1 on error
int socket_server_init(int port) {
    printf("[DPI-C] Initializing socket server on port %d\n", port);

    if (server_fd >= 0) {
        printf("[DPI-C] Server already initialized\n");
        return 0;
    }

    // Create socket
    server_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (server_fd < 0) {
        printf("[DPI-C] ERROR: socket() failed: %s\n", strerror(errno));
        return -1;
    }

    // Allow address reuse
    int opt = 1;
    if (setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt)) < 0) {
        printf("[DPI-C] WARNING: setsockopt() failed: %s\n", strerror(errno));
    }

    // Bind to port
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port = htons(port);

    if (bind(server_fd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        printf("[DPI-C] ERROR: bind() failed: %s\n", strerror(errno));
        close(server_fd);
        server_fd = -1;
        return -1;
    }

    // Listen for connections
    if (listen(server_fd, 1) < 0) {
        printf("[DPI-C] ERROR: listen() failed: %s\n", strerror(errno));
        close(server_fd);
        server_fd = -1;
        return -1;
    }

    printf("[DPI-C] Socket server listening on port %d\n", port);
    server_port = port;
    return 0;
}

// Wait for client connection (blocking)
// Returns: 0 on success, -1 on error
int socket_server_accept() {
    if (server_fd < 0) {
        printf("[DPI-C] ERROR: Server not initialized\n");
        return -1;
    }

    if (client_fd >= 0) {
        printf("[DPI-C] Client already connected\n");
        return 0;
    }

    printf("[DPI-C] Waiting for client connection...\n");

    struct sockaddr_in client_addr;
    socklen_t client_len = sizeof(client_addr);
    client_fd = accept(server_fd, (struct sockaddr*)&client_addr, &client_len);

    if (client_fd < 0) {
        printf("[DPI-C] ERROR: accept() failed: %s\n", strerror(errno));
        return -1;
    }

    printf("[DPI-C] Client connected from %s:%d\n",
           inet_ntoa(client_addr.sin_addr), ntohs(client_addr.sin_port));

    return 0;
}

// Check if a transaction is available (non-blocking)
// Returns: 1 if transaction available, 0 if not, -1 on error
int socket_has_transaction() {
    if (client_fd < 0) {
        return 0; // No client connected
    }

    // Check if data is available (non-blocking peek)
    char buf[1];
    ssize_t n = recv(client_fd, buf, 1, MSG_PEEK | MSG_DONTWAIT);

    if (n > 0) {
        return 1; // Data available
    } else if (n == 0) {
        printf("[DPI-C] Client disconnected\n");
        close(client_fd);
        client_fd = -1;
        return 0;
    } else if (errno == EAGAIN || errno == EWOULDBLOCK) {
        return 0; // No data available
    } else {
        printf("[DPI-C] ERROR: recv() failed: %s\n", strerror(errno));
        close(client_fd);
        client_fd = -1;
        return -1;
    }
}

// Receive a transaction (blocking)
// Returns: 0 on success, -1 on error
// Outputs: is_write, addr, data via pointers
int socket_recv_transaction(int* is_write, unsigned int* addr, unsigned int* data) {
    if (client_fd < 0) {
        printf("[DPI-C] ERROR: No client connected\n");
        return -1;
    }

    Transaction txn;
    ssize_t n = recv(client_fd, &txn, sizeof(txn), MSG_WAITALL);

    if (n != sizeof(txn)) {
        if (n == 0) {
            printf("[DPI-C] Client disconnected during recv\n");
        } else {
            printf("[DPI-C] ERROR: recv() incomplete: %zd/%zu bytes\n", n, sizeof(txn));
        }
        close(client_fd);
        client_fd = -1;
        return -1;
    }

    *is_write = txn.is_write;
    *addr = txn.addr;
    *data = txn.data;

    printf("[DPI-C] Received %s: addr=0x%08x, data=0x%08x\n",
           txn.is_write ? "WRITE" : "READ", txn.addr, txn.data);

    return 0;
}

// Send a read response
// Returns: 0 on success, -1 on error
int socket_send_response(unsigned int data) {
    if (client_fd < 0) {
        printf("[DPI-C] ERROR: No client connected\n");
        return -1;
    }

    Transaction txn;
    txn.is_write = 0;
    txn.addr = 0;
    txn.data = data;

    ssize_t n = send(client_fd, &txn, sizeof(txn), 0);

    if (n != sizeof(txn)) {
        printf("[DPI-C] ERROR: send() failed: %s\n", strerror(errno));
        close(client_fd);
        client_fd = -1;
        return -1;
    }

    printf("[DPI-C] Sent response: data=0x%08x\n", data);
    return 0;
}

// Cleanup
void socket_server_close() {
    printf("[DPI-C] Closing socket server\n");
    if (client_fd >= 0) {
        close(client_fd);
        client_fd = -1;
    }
    if (server_fd >= 0) {
        close(server_fd);
        server_fd = -1;
    }
}

} // extern "C"

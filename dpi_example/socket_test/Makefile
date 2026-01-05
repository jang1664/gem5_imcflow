# Makefile for Socket DPI Test

VCS = vcs
VCS_FLAGS = -full64 -sverilog -debug_access+all -LDFLAGS -Wl,--no-as-needed

# Source files
SV_FILES = testbench_socket.sv
CPP_FILES = dpi_socket_server.cpp

# Targets
.PHONY: all compile run client clean

all: compile

compile:
	@echo "Compiling with VCS..."
	$(VCS) $(VCS_FLAGS) $(SV_FILES) $(CPP_FILES) -o simv_socket

run: compile
	@echo "Running simulation..."
	./simv_socket

client: socket_client.cpp
	@echo "Compiling client..."
	g++ -o socket_client socket_client.cpp
	@echo "Client compiled. Run with: ./socket_client [port]"

test: compile client
	@echo "Starting simulation in background..."
	./simv_socket &
	@sleep 2
	@echo "Running client..."
	./socket_client 9999
	@echo "Waiting for simulation to finish..."
	@wait
	@echo "Test completed!"

clean:
	rm -rf simv_socket simv_socket.daidir csrc ucli.key socket_client *.log

help:
	@echo "Makefile for Socket DPI Test"
	@echo ""
	@echo "Targets:"
	@echo "  make compile  - Compile the simulation"
	@echo "  make run      - Run the simulation (waits for client)"
	@echo "  make client   - Compile the test client"
	@echo "  make test     - Run full test (sim + client)"
	@echo "  make clean    - Clean build artifacts"

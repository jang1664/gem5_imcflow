##########################################################################################
# Makefile for ImcFlow RTL Co-Simulation with gem5
# Integrates DPI-C socket server with ImcFlow RTL
##########################################################################################

.PHONY: help
.DEFAULT_GOAL := help

# Directory structure
BUILD_DIR = build
LOGS_DIR = logs

# Simulation settings
SIMUL_EXEC = vcs
SIMUL_OPTS = ""
DEFINE = SUPPORT_K2+SUPPORT_K3+SUPPORT_K5+SUPPORT_K7+FSIM+DEBUG# + separated (removed MEM_MODEL for direct SRAM access)
DEFINE := $(DEFINE)+MEM_MODEL
DEFINE := $(DEFINE)+BUGFIX_READ_FROM_GPR# only use when you want to simulate rtl without this bug: already tapeouted
DEFINE := $(DEFINE)+BUGFIX_LOAD_USE_HAZARD# enable fix for load-use hazard in inode pipeline (this is not yet implemented in RTL)
DEFINE := $(DEFINE)+ROUTER_BUG_FIX# router arbiter logic fix
DEFINE := $(DEFINE)+BUG_FIX_OVERFLOW
DEFINE := $(DEFINE)+BUGFIX_STEP
PARAM_FILE = "${BUILD_DIR}/parameters.txt"
INCLUDE_DIR = "${IMCFLOW_DIR}/pmap/modules/top/include+${IMCFLOW_DIR}/pmap/classes+${IMCFLOW_DIR}/pmap/include"
SOCKET_PORT ?= 9999

# Output files
SIMV_BINARY = ${BUILD_DIR}/simv_imcflow_gem5
COMPILE_STAMP = ${BUILD_DIR}/.compile_done

# DPI-C compilation flags
DPI_FLAGS = -LDFLAGS -Wl,--no-as-needed

setup:
	@mkdir -p ${BUILD_DIR}
	@mkdir -p ${LOGS_DIR}
	@touch ${PARAM_FILE}

clean: ## Clean logs and temporary files
	rm -f ${LOGS_DIR}/*.log
	rm -f *.key *.history *.swp core.* transcript vsim.wlf vsim_stacktrace.vstf
	rm -rf verdiLog novas*
	rm -rf vcs_compile.log

clean_all: clean ## Clean all build artifacts and logs
	rm -rf ${BUILD_DIR}
	rm -rf ${LOGS_DIR}
	rm -rf m5out
	rm -rf test_outputs

compile: clean_all setup ## Compile the RTL co-simulation (usage: make compile DEFINE="<defparam>" SIMUL_OPTS="-opt1 -opt2")
	cd ${BUILD_DIR} && ${SIMUL_EXEC} \
	-V -sverilog -full64 -debug_access+all -kdb \
	${DPI_FLAGS} \
	${SIMUL_OPTS} \
	+incdir+${INCLUDE_DIR} \
	+define+${DEFINE} \
	-parameters parameters.txt \
	-timescale=1ns/1ps \
	-assert svaext \
	+warn=noUII-L \
	+warn=noIDTS \
	+suppress=TFIPC-L \
	+lint=PCWM \
	+delay_mode_zero \
	-debug_region=cell \
	-xprop=tmerge \
	-f ../tech.f \
	-f ../rtl.f \
	-f ../tb.f \
	-l compile.log \
	-o simv_imcflow_gem5
	@touch ${COMPILE_STAMP}
	@echo ""
	@echo "Build artifacts in: ${BUILD_DIR}/"

run: compile ## Run the RTL simulation (waits for gem5 connection on port 9999)
	@echo "=== Starting ImcFlow RTL Co-Simulation ==="
	@echo "Waiting for gem5 to connect on port $(SOCKET_PORT)..."
	@echo "Log will be saved to: ${LOGS_DIR}/vcs_sim.log"
	${SIMV_BINARY} +SOCKET_PORT=$(SOCKET_PORT)

sim: run ## Alias for run

verdi: ## Open Verdi waveform viewer
	verdi -ssf imcflow_gem5.fsdb -dbdir ${BUILD_DIR}/simv_imcflow_gem5.daidir

help:
	@echo "ImcFlow RTL Co-Simulation Makefile"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Usage examples:"
	@echo "  make compile              - Compile the simulation"
	@echo "  make run                  - Run simulation (waits for gem5)"
	@echo "  make clean_all            - Clean all build artifacts"
	@echo ""

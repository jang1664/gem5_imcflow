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

# Keep the RTL build mode aligned with TVM's master BUGFIX knob.  Both the TVM
# runner and direct Make invocations default to the unfixed RTL configuration.
IMCFLOW_BUGFIX ?= off
IMCFLOW_BUGFIX_MODE := $(shell printf '%s' '$(IMCFLOW_BUGFIX)' | tr '[:upper:]' '[:lower:]')

ifneq ($(words $(filter $(IMCFLOW_BUGFIX_MODE),on off)),1)
$(error IMCFLOW_BUGFIX must be 'on' or 'off' (got '$(IMCFLOW_BUGFIX)'))
endif

BASE_DEFINE = SUPPORT_K2+SUPPORT_K3+SUPPORT_K5+SUPPORT_K7+FSIM+MEM_MODEL+DEBUG
BUGFIX_DEFINE = BUGFIX_READ_FROM_GPR+BUGFIX_LOAD_USE_HAZARD+ROUTER_BUG_FIX+BUG_FIX_OVERFLOW+BUGFIX_STEP+BUGFIX_DWCONV

ifeq ($(IMCFLOW_BUGFIX_MODE),off)
DEFAULT_DEFINE = $(BASE_DEFINE)
else
DEFAULT_DEFINE = $(BASE_DEFINE)+$(BUGFIX_DEFINE)
endif

# Preserve the existing `make compile DEFINE=...` escape hatch.
DEFINE ?= $(DEFAULT_DEFINE)
PARAM_FILE = "${BUILD_DIR}/parameters.txt"
INCLUDE_DIR = ${IMCFLOW_DIR}/pmap/modules/top/include+${IMCFLOW_DIR}/pmap/classes+${IMCFLOW_DIR}/pmap/include
SOCKET_PORT ?= 9999

# Output files
SIMV_BINARY = ${BUILD_DIR}/simv_imcflow_gem5
MANIFEST_TOOL = ./build_manifest.py
MANIFEST_PATH = ${BUILD_DIR}/build_manifest.json
MANIFEST_PENDING = .rtl_build_manifest.pending.json
COMPILE_LOCK = .rtl_compile.lock

# DPI-C compilation flags
DPI_FLAGS = -LDFLAGS -Wl,--no-as-needed
VCS_FLAGS = -V -sverilog -full64 -debug_access+all -kdb \
	-parameters parameters.txt -timescale=1ns/1ps -assert svaext \
	+warn=noUII-L +warn=noIDTS +suppress=TFIPC-L +lint=PCWM \
	+delay_mode_zero -debug_region=cell -xprop=tmerge
FILELISTS = ../tech.f ../rtl.f ../tb.f

# build_manifest.py reads the final, override-aware values through the
# environment.  These are compile inputs; runtime-only values are excluded.
export RTL_BUILD_BUGFIX_MODE := $(IMCFLOW_BUGFIX_MODE)
export RTL_BUILD_DEFINES := $(DEFINE)
export RTL_BUILD_SIMUL_EXEC := $(SIMUL_EXEC)
export RTL_BUILD_SIMUL_OPTS := $(SIMUL_OPTS)
export RTL_BUILD_DPI_FLAGS := $(DPI_FLAGS)
export RTL_BUILD_INCLUDE_DIRS := $(INCLUDE_DIR)
export RTL_BUILD_VCS_FLAGS := $(strip $(VCS_FLAGS))
export RTL_BUILD_FILELISTS := $(FILELISTS)

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

compile: ## Force-compile the RTL co-simulation under the shared build lock
	@flock ${COMPILE_LOCK} $(MAKE) --no-print-directory _compile

ensure-compiled: ## Compile only when the build manifest or simulator binary is stale
	@flock ${COMPILE_LOCK} $(MAKE) --no-print-directory _ensure-compiled

.PHONY: setup clean clean_all compile ensure-compiled _compile _ensure-compiled manifest-current

_ensure-compiled:
	@status=0; \
		python3 ${MANIFEST_TOOL} check --manifest ${MANIFEST_PATH} --binary ${SIMV_BINARY} || status=$$?; \
		if [ $$status -eq 0 ]; then \
			echo "Reusing manifest-matched RTL simulator: ${SIMV_BINARY}"; \
		elif [ $$status -eq 10 ]; then \
			$(MAKE) --no-print-directory _compile; \
		else \
			exit $$status; \
		fi

# Snapshot/validate every input before clean_all replaces an existing build.
_compile:
	@echo "IMCFLOW_BUGFIX=$(IMCFLOW_BUGFIX_MODE)"
	@echo "VCS defines: $(DEFINE)"
	@python3 ${MANIFEST_TOOL} prepare --output ${MANIFEST_PENDING}
	@$(MAKE) --no-print-directory clean_all setup
	cd ${BUILD_DIR} && ${SIMUL_EXEC} \
	${VCS_FLAGS} \
	${DPI_FLAGS} \
	${SIMUL_OPTS} \
	+incdir+${INCLUDE_DIR} \
	+define+${DEFINE} \
	$(foreach filelist,$(FILELISTS),-f $(filelist)) \
	-l compile.log \
	-o simv_imcflow_gem5
	@test -f ${SIMV_BINARY}
	@python3 ${MANIFEST_TOOL} finalize --pending ${MANIFEST_PENDING} --output ${MANIFEST_PATH}
	@echo ""
	@echo "Build artifacts in: ${BUILD_DIR}/"

manifest-current: ## Print the desired RTL build manifest without compiling
	@python3 ${MANIFEST_TOOL} current

run: ensure-compiled ## Run the RTL simulation (waits for gem5 connection on port 9999)
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
	@echo "  make ensure-compiled      - Compile only when the manifest is stale"
	@echo "  make run                  - Run simulation (waits for gem5)"
	@echo "  make clean_all            - Clean all build artifacts"
	@echo ""

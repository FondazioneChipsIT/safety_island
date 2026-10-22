# Copyright 2023 ETH Zurich and University of Bologna
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51

SAFED_ROOT ?= .

# Run the register generator with the project Python environment created by
# `source bootstrap.sh`, even if it is not activated in this shell.
ifneq (,$(wildcard $(SAFED_ROOT)/.venv/bin/python))
PYTHON3 ?= $(abspath $(SAFED_ROOT)/.venv/bin/python)
else ifneq ($(filter safed-hw-gen,$(MAKECMDGOALS)),)
$(warning The project Python environment (.venv) does not exist: regtool.py will run with the first python3 in PATH. Run 'source bootstrap.sh' first so that the flow uses the pinned packages)
endif

include safed.mk

.PHONY: checkout
## Checkout/update dependencies using Bender
checkout: $(SAFED_ROOT)/.deps

.PHONY: scripts
## Generate scripts for all tools
scripts: $(SAFED_SIM_DIR)/compile.tcl

.PHONY: build
## Build the RTL model for vsim
build: scripts safed_sim_all

.PHONY: clean
## Remove the RTL model files
clean: safed_sim_clean

##############
## SOFTWARE ##
##############
.PHONY: pulp-runtime
## Clone pulp-runtime for bare-metal verification
pulp-runtime: sw/pulp-runtime

.PHONY: pulp-freertos
## Clone freertos for real-time OS verification
pulp-freertos: sw/pulp-freertos

.PHONY: help
help: Makefile
	@printf "Safety Island\n"
	@printf "Available targets\n\n"
	@awk '/^[a-zA-Z\-\_0-9]+:/ { \
		helpMessage = match(lastLine, /^## (.*)/); \
		if (helpMessage) { \
			helpCommand = substr($$1, 0, index($$1, ":")-1); \
			helpMessage = substr(lastLine, RSTART + 3, RLENGTH); \
			printf "%-20s %s\n", helpCommand, helpMessage; \
		} \
	} \
	{ lastLine = $$0 }' $(MAKEFILE_LIST)



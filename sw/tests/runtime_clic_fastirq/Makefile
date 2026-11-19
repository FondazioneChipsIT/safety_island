PULP_APP = runtime_clic_fastirq
PULP_APP_FC_SRCS = clic-fastirq.c
PULP_APP_HOST_SRCS = clic-fastirq.c
PULP_APP_ASM_SRCS = handler.S regs.S
PULP_CFLAGS = -Os -g3 -Wall -Wextra -I../runtime_shared/include \
	-Wno-unused-parameter -Wno-unused-function -Wno-unused-variable \
	-Wnull-dereference -Wformat=2

VERBOSE=1
include $(PULP_SDK_HOME)/install/rules/pulp_rt.mk


bsg_tiles_X = 4
bsg_tiles_Y = 4


RISCV_GCC_EXTRA_OPTS ?= -O2 -funroll-loops
OBJECT_FILES=main.o bypass_core_test.o

include ../Makefile.include

all: main.run
#all: main.syn

main.riscv:  $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) $(BSG_MANYCORE_LIB) ../common/crt.o
	$(RISCV_LINK) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) -L. "-l:$(BSG_MANYCORE_LIB)" -o $@ $(RISCV_LINK_OPTS)


main.o: Makefile

include ../../mk/Makefile.tail_rules

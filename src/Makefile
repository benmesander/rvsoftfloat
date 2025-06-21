# RV64I
#TARGET	?=riscv64
#ARCH	?=rv64gc
#ABI	?=lp64

# RV32I
TARGET	?=riscv32
ARCH	?=rv32gc
ABI	?=ilp32d

RVINT	:= ../../rvint
CC	:= clang
LD	:= ld.lld
CFLAGS	:= --target=$(TARGET) -march=$(ARCH) -mabi=$(ABI) -I$(RVINT)/src
LDFLAGS	:=

SRCS	:= atof.s testf.s
OBJS	:= $(SRCS:.s=.o)
EXES	:= testf.x

.PHONY: all clean

all: $(EXES)

%.o: %.s
	$(CC) $(CFLAGS) -c $< -o $@

atof.o: atof.s float.s

testf.x: $(OBJS)
	$(LD) $(LDFLAGS) $^ -o $@

clean:
	rm -f $(OBJS) $(EXES)

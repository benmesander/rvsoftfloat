# RV64I
#TARGET	?=riscv64
#ARCH	?=rv64gc
#ABI	?=lp64

# RV32I
TARGET	?=riscv32
ARCH	?=rv32gc
ABI	?=ilp32d

CC	:= clang
LD	:= ld.lld
CFLAGS	:= --target=$(TARGET) -march=$(ARCH) -mabi=$(ABI)
LDFLAGS	:=

SRCS	:= atof.s
OBJS	:= $(SRCS:.s=.o)
EXES	:= tests.x

.PHONY: all clean

%.o: %.s
	$(CC) $(CFLAGS) -c $< -o $@

atof.o: atof.s float.s

tests.x: $(OBJS)
	$(LD) $(LDFLAGS) $^ -o $@

clean:
	rm -f $(OBJS) $(EXES)

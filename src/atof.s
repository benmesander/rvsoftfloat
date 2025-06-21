.include "../../rvint/src/config.s" # XXX
.include "float.s"

.equ STATUS_SUCCESS, 0
.equ STATUS_TOO_SHORT, 1
.equ STATUS_TOO_LONG, 2
.equ STATUS_MALFORMED, 3	

.rodata

lit_zero:
.byte '0'
lit_zero2:
.ascii "0.0"
lit_minus_zero:
.ascii "-0"
lit_nan:
.ascii "NaN"
lit_qnan:
.ascii "qNaN"
lit_snan:
.ascii "sNaN"
lit_inf:
.ascii "Inf"
list_minus_inf:
.ascii "-Inf"

.macro ADDR address
.if CPU_BITS == 64
.long \address
.else	
.word \address
.endif
.endm

.macro LWU register, offset, base
.if CPU_BITS == 64
	lwu	\register, \offset(\base)
.else
	lw	\register, \offset(\base)
.endif
.endm	

float_lookup_table:
.equ LEN_OFFSET, .-float_lookup_table
.word 1
.equ STRPTR_OFFSET, .-float_lookup_table
ADDR lit_zero
.equ VAL_OFFSET, .-float_lookup_table
.word SP_ZERO
################################
.equ SIZEOF_FLOAT_LOOKUP, .-float_lookup_table
.word 2
ADDR lit_minus_zero
.word SP_MINUS_ZERO
################################
.word 0 # terminator
	



.globl	atof
.text

# a0 ptr to str1
# a1 strlen(a0)
# a2 ptr to str2
# a3 strlen(a2)
# a0 = 0 eq else neq

strncmp:
	bne	a1, a3, strncmp_ne
strncmp_loop:	
	lbu	a4, 0(a0)
	lbu	a5, 0(a2)
	bne	a4, a5, strncmp_ne
	addi	a0, a0, 1
	addi	a2, a2, 1
	addi	a1, a1, -1
	bnez	a1, strncmp_loop
	li	a0, 0
	ret

strncmp_ne:
	li	a0, 1
	ret




# a0 ptr to buf
# a1 strlen(a0)	
# a0 - notfound = 0, found = nonzero
# a1 - float value	
find:
	FRAME	4
	PUSH	ra, 0
	PUSH	s0, 1
	PUSH	s1, 2
	PUSH	s2, 3

	mv	s0, a0
	mv	s1, a1
	la	s2, float_lookup_table

find_loop:
	LWU	a3, LEN_OFFSET, s2
	beqz	a3, find_return
	la	a2, STRPTR_OFFSET(s2)
	mv	a0, s0
	mv	a1, s1
	jal	strncmp
	beqz	a0, find_next
	LWU	a1, VAL_OFFSET, s2
	li	a0, 1
	ret
find_next:
	addi	s2, s2, SIZEOF_FLOAT_LOOKUP
	j	find_loop

find_return:
	li	a0, 0
	ret

	EFRAME	4
	POP	ra, 0
	POP	s0, 1
	POP	s1, 2
	POP	s2, 3
	ret

# in:
# a0 = ptr to buffer
# a1 = strlen(a0)
# out:
# a0 = float
# a1 = status

atof:
	bnez	a1, .atof_1
	li	a0, 0
	li	a1, STATUS_TOO_SHORT
	ret

# handle 0
.atof_1:
	li	a2, 1
	bne	a1, a2, .atof_2
	lbu	a2, 0(a0)
	addi	a2, a2, -'0'
	bnez	a2, .atof_2
	mv	a0, a2		# float 0 is integer 0x0
	li	a1, STATUS_SUCCESS
	ret

# handle NaN, +/-Inf
.atof_2:
	if a1 != 3, then .atof_3
	




	lw	a3, 0(a0)
	slli	a3, a3, 16









	li	a1, STATUS_SUCCESS
	ret

.include "config.s"
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
lit_minus_inf:
.ascii "-Inf"

# macro to define a pointer address (4 or 8 bytes)
.macro ADDR address
.if CPU_BITS == 64
.long \address
.else	
.word \address
.endif
.endm

# lookup table struct layout for 32 and 64 bit machines
.equ float_lookup.len,		0	
.equ float_lookup.strptr, 	4
.if CPU_BITS == 64
.equ float_lookup.val, 		12
.equ sizeof_float_lookup,	16
.else
.equ float_lookup.val,		8
.equ sizeof_float_lookup,	12
.endif	

# special float values lookup table
float_lookup_table:
################################
# "0"	
.word 1
ADDR lit_zero
.word SP_ZERO
################################
# "0.0"
.word 3
ADDR lit_zero2	
.word SP_ZERO
################################
# "-0"
.word 2
ADDR lit_minus_zero
.word SP_MINUS_ZERO
################################
# "NaN"
.word 3
ADDR lit_nan
.word SP_QNAN	
################################
# "qNaN"
.word 4
ADDR lit_qnan	
.word SP_QNAN
################################
# "sNaN"
.word 4
ADDR lit_snan
.word SP_SNAN
################################
# "Inf"
.word 3	
ADDR lit_inf
.word SP_INF
################################
# "-Inf"
.word 4
ADDR lit_minus_inf
.word SP_MINUS_INF
################################
.word 0 # terminator
	
.text
.globl	atof

# compare two strings
# in:
# a0 = ptr to str1
# a1 = strlen(a0)
# a2 = ptr to str2
# a3 = strlen(a2)
# out:
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

# find an entry in the special value lookup table
# in:
# a0 = ptr to string
# a1 = strlen(a0)	
# out:
# a0 = notfound = 0, found = nonzero
# a1 = float value	
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
	lw	a3, float_lookup.len(s2)
	beqz	a3, find_return_notfound
.if CPU_BITS == 32
	lw	a2, float_lookup.strptr(s2)
.else
	ld	a2, float_lookup.strptr(s2)
.endif
	mv	a0, s0
	mv	a1, s1
	jal	strncmp
	beqz	a0, find_next
	lw	a1, float_lookup.val(s2)
	li	a0, 1
	j	find_return
find_next:
	addi	s2, s2, sizeof_float_lookup
	j	find_loop

find_return_notfound:
	li	a0, 0
find_return:	
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
	FRAME	3
	PUSH	ra, 0
	PUSH	s0, 1
	PUSH	s1, 2

	bnez	a1, atof_search_table
	li	a0, 0
	li	a1, STATUS_TOO_SHORT
	j	atof_return

atof_search_table:
	mv	s0, a0
	mv	s1, a1
	jal	find
	bnez	a0, atof_table_notfound
	mv	a0, a1
	li	a1, STATUS_SUCCESS
	j	atof_return
atof_table_notfound:	

	# XXX: impl
atof_return:
	EFRAME	3
	POP	ra, 0
	POP	s0, 1
	POP	s1, 2
	ret


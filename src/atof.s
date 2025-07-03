.include "config.s"
.include "float.s"

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

# lookup table struct layout for 32 and 64 bit machines
.equ float_lookup.len,		0	
.equ float_lookup.strptr, 	4
.equ float_lookup.val,		8
.equ sizeof_float_lookup,	12

# special float values lookup table
# the entries are arranged shortest to longest
float_lookup_table:
################################
# "0"	
.word 1
.word lit_zero
.word SP_ZERO
################################
# "-0"
.word 2
.word lit_minus_zero
.word SP_MINUS_ZERO
################################
# "0.0"
.word 3
.word lit_zero2	
.word SP_ZERO
################################
# "NaN"
.word 3
.word lit_nan
.word SP_QNAN	
################################
# "Inf"
.word 3	
.word lit_inf
.word SP_INF
################################
# "qNaN"
.word 4
.word lit_qnan	
.word SP_QNAN
################################
# "sNaN"
.word 4
.word lit_snan
.word SP_SNAN
################################
# "-Inf"
.word 4
.word lit_minus_inf
.word SP_MINUS_INF
################################
.word 0 # terminator
# the length of the longest string in the table above
.equ MAX_TABLE_LEN_STR, 4
	
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
	add	a1, a1, -1
	slli	a0, a1, 1			# mul by 12
	add	a0, a0, a1
	slli	a1, a0, 2
	add	s2, s2, a1			# shorten linear search by a1 struct elements.

find_loop:
	lw	a3, float_lookup.len(s2)
	beqz	a3, find_return_notfound	# end of table
	bgt	a3, s1, find_return_notfound	# not in table
	lw	a2, float_lookup.strptr(s2)
	mv	a0, s0
	mv	a1, s1
	jal	strncmp
	bnez	a0, find_next
	lwu	a1, float_lookup.val(s2)
	li	a0, 1
	j	find_return
find_next:
	addi	s2, s2, sizeof_float_lookup
	j	find_loop

find_return_notfound:
	li	a0, 0
find_return:	
	POP	ra, 0
	POP	s0, 1
	POP	s1, 2
	POP	s2, 3
	EFRAME	4
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
	li	a3, MAX_TABLE_LEN_STR
	bgt	a1, a3, atof_table_notfound
	mv	s0, a0
	mv	s1, a1
	jal	find
	beqz	a0, atof_table_notfound
	mv	a0, a1
	li	a1, STATUS_SUCCESS
	j	atof_return
atof_table_notfound:	

	# XXX: impl
atof_return:
	POP	ra, 0
	POP	s0, 1
	POP	s1, 2
	EFRAME	3
	ret


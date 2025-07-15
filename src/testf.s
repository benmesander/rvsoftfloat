.include "config.s"
.include "float.s"

.text
.globl _start
_start:
	li	a0, 0
	la	a1, zerostr
	li	a2, 1
	li	a3, SP_ZERO
	jal	atof_test
	
	li	a0, 1
	la	a1, zero2
	li	a2, 3
	li	a3, SP_ZERO
	jal	atof_test

	li	a0, 2
	la	a1, mzero
	li	a2, 2
	li	a3, SP_MINUS_ZERO
	jal	atof_test

	li	a0, 3
	la	a1, nanstr
	li	a2, 3
	li	a3, SP_QNAN
	jal	atof_test

	li	a0, 4
	la	a1, qnanstr
	li	a2, 4
	li	a3, SP_QNAN
	jal	atof_test

	li	a0, 5
	la	a1, snanstr
	li	a2, 4
	li	a3, SP_SNAN
	jal	atof_test

	li	a0, 6
	la	a1, infstr
	li	a2, 3
	li	a3, SP_INF
	jal	atof_test

	li	a0, 7
	la	a1, minfstr
	li	a2, 4
	lui	a3, %hi(SP_MINUS_INF)
	addi	a3, a3, %lo(SP_MINUS_INF)
	jal	atof_test

	li	a0, 8
	la	a1, notfoundstr
	li	a2, 4
	li	a3, 0xDEADBEEF	# Expected to fail - not in table
	jal	atof_test

	j	_end

# a0 = test #
# a1 = ptr to string to convert
# a2 = len of string to convert
# a3 = expected value
atof_test:
	FRAME	5
	PUSH	ra, 0
	PUSH	s0, 1
	PUSH	s1, 2
	PUSH	s2, 3
	PUSH	s3, 4
	mv	s0, a0
	mv	s1, a1
	mv	s2, a2
	mv	s3, a3

	la	a1, test	# "test "
	li	a2, 5
	jal	print

	mv	a0, s0
	jal	to_decu		# number in a0
	mv	a2, a1
	mv	a1, a0
	jal	print

	la	a1, space	# " "
	li	a2, 1
	jal	print

	mv	a1, s1		# string value a1 ptr, a2 len
	mv	a2, s2
	jal	print

	la	a1, equal	# "="
	li	a2, 1
	jal	print
	
	mv	a0, s1
	mv	a1, s2
	jal	atof

	mv	t0, a0
	li	t1, STATUS_SUCCESS
	sub	a0, t0, s3
	bne	a1, t1, atof_test_fail
	bnez	a0, atof_test_fail


	mv	a0, t0
	li	a1, 4
	li	a2, 1
	jal	to_hex

	mv	a2, a1		# result
	mv	a1, a0
	jal	print

	la	a1, space	# " "
	li	a2, 1
	jal	print

	la	a1, pass
	li	a2, 5
	jal	print

atof_test_return:
	POP	ra, 0
	POP	s0, 1
	POP	s1, 2
	POP	s2, 3
	POP	s3, 4
	EFRAME	5
	ret

# s3 is expected value
# t0 is calculated value
atof_test_fail:
	# Print "fail: expected X got Y"
	la	a1, fail_prefix
	li	a2, 5
	jal	print
	mv	a0, s3		# Print expected value
	li	a1, 4
	li	a2, 1
	jal	to_hex
	mv	a2, a1
	mv	a1, a0
	jal	print

#	li	a0, 

	# After printing the error details
	la	a1, newline
	li	a2, 1
	jal	print
	j	atof_test_return

# a1 - ptr to string to print
# a2 - # bytes to print
print:
	li	a0, 1	# stdout
	li	a7, 64	# write syscall
	ecall
	ret

_end:
        li	a0, 0	# exit code
        li	a7, 93	# exit syscall
        ecall

.rodata
test:	.ascii	"test "		# 5
pass:	.ascii	"pass\n"	# 5
fail:	.ascii	"fail\n"	# 5
space:	.ascii	" "		# 1
equal:	.ascii	"="		# 1
zerostr:.ascii	"0"		# 1
zero2:	.ascii	"0.0"		# 3
mzero:	.ascii "-0"		# 2
nanstr:	.ascii	"NaN"		# 3
qnanstr:.ascii	"qNaN"		# 4
snanstr:.ascii	"sNaN"		# 4
infstr:	.ascii	"Inf"		# 3
minfstr:.ascii	"-Inf"		# 4
notfoundstr: .ascii "test"	# 4
fail_prefix: .ascii "fail: expected " # 11
newline: .ascii "\n"		# 1

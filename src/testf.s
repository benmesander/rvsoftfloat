.include "config.s"
.include "float.s"

.text
.globl _start
_start:
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

	jal	to_decu		# number in a0
	mv	a2, a1
	mv	a1, a0
	jal	print

	la	a1, space	# " "
	li	a2, 1
	jal	print

	mv	a1, s1		# string value a1 ptr
	mv	a2, s2
	jal	print

	la	a1, space	# " "
	li	a2, 1
	jal	print
	
	mv	a0, s1
	mv	a1, s2
	jal	atof
	bnez	a0, atof_test_fail

	sub	a0, a1, s3
	bnez	a0, atof_test_fail

	mv	a0, a1
	li	a1, 4
	li	a2, 1
	jal	to_hex

	mv	a2, a1		# result
	mv	a1, a0
	call	print

	la	a1, space	# " "
	li	a2, 1
	jal	print

	la	a1, pass
	li	a2, 5
	jal	print

atof_test_return:
	EFRAME	5
	POP	ra, 0
	POP	s0, 1
	POP	s1, 2
	POP	s2, 3
	POP	s3, 4
	ret

atof_test_fail:
	# XXX: print return code and return value
	la	a1, fail
	li	a2, 5
	jal	print
	j 	atof_test_return

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
test:	.asciz	"test "		# 5
pass:	.asciz	"pass\n"	# 5
fail:	.asciz	"fail\n"	# 5
space:	.asciz	" "		# 1

.equ FLOAT_MANTISSA_BITS, 23
.equ FLOAT_EXPONENT_BITS, 8
.equ FLOAT_EXPONENT_BIAS, 127

.equ STATUS_SUCCESS, 0
.equ STATUS_TOO_SHORT, 1
.equ STATUS_TOO_LONG, 2
.equ STATUS_MALFORMED, 3	


.globl	atof
.text

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

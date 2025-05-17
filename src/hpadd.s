# IEEE754 Half-Precision Floating Point Addition in RISC-V Assembly
# This implements addition of two half-precision (16-bit) floating point numbers
# following the IEEE754 standard with proper GRS bit handling.
#
# Arguments:
#   a0 - First half-precision float (16 bits)
#   a1 - Second half-precision float (16 bits)
# Returns:
#   a0 - Result of adding the two half-precision floats (properly rounded)

.equ    SIGN_MASK,      0x8000      # Bit mask for sign bit (bit 15)
.equ    EXPONENT_MASK,  0x7C00      # Bit mask for exponent field (bits 10-14)
.equ    MANTISSA_MASK,  0x03FF      # Bit mask for mantissa field (bits 0-9)
.equ    EXP_MAX,        0x1F        # Maximum exponent value (5 bits all 1)
.equ    EXPONENT_BIAS,  15          # Exponent bias for half-precision
.equ    IMPLICIT_ONE,   0x0400      # Implicit 1 bit (bit 10) for normalized numbers

# For internal expanded precision representation:
.equ    MANT_EXTRA_BITS, 3          # GRS (Guard, Round, Sticky) bits
.equ    INT_MANT_BITS,  13          # 10-bit mantissa + implicit bit + GRS
.equ    INT_MANT_MASK,  0x1FFF      # Mask for expanded internal mantissa

.globl  add_f16                     # Make function available externally

add_f16:
    # Save registers that will be modified
    addi    sp, sp, -(12 * (CPU_BITS/8))  # Create stack space based on register width
    
    # Store registers we'll use
    .if CPU_BITS == 32
        sw      ra, 0(sp)
        sw      s0, 4(sp)
        sw      s1, 8(sp)
        sw      s2, 12(sp)
        sw      s3, 16(sp)
        sw      s4, 20(sp)
        sw      s5, 24(sp)
        sw      s6, 28(sp)
        sw      s7, 32(sp)
        sw      s8, 36(sp)
        sw      s9, 40(sp)
        sw      s10, 44(sp)
    .else
        sd      ra, 0(sp)
        sd      s0, 8(sp)
        sd      s1, 16(sp)
        sd      s2, 24(sp)
        sd      s3, 32(sp)
        sd      s4, 40(sp)
        sd      s5, 48(sp)
        sd      s6, 56(sp)
        sd      s7, 64(sp)
        sd      s8, 72(sp)
        sd      s9, 80(sp)
        sd      s10, 88(sp)
    .endif

    # Extract components of first float (a0)
    li      t0, SIGN_MASK
    and     s0, a0, t0          # s0 = sign of first float
    
    li      t0, EXPONENT_MASK
    and     t0, a0, t0          # t0 = exponent field (not shifted yet)
    srli    s1, t0, 10          # s1 = actual exponent value (shifted)
    
    li      t0, MANTISSA_MASK
    and     s2, a0, t0          # s2 = mantissa of first float
    
    # Save original exponent values to detect denormals
    mv      s9, s1              # s9 = original exponent of first float (to track denormals)
    
    # Extract components of second float (a1)
    li      t0, SIGN_MASK
    and     s3, a1, t0          # s3 = sign of second float
    
    li      t0, EXPONENT_MASK
    and     t0, a1, t0          # t0 = exponent field (not shifted yet)
    srli    s4, t0, 10          # s4 = actual exponent value (shifted)
    
    li      t0, MANTISSA_MASK
    and     s5, a1, t0          # s5 = mantissa of second float
    
    # Save original exponent values to detect denormals
    mv      s10, s4             # s10 = original exponent of second float (to track denormals)

    # Check for special cases: NaN, Infinity
    li      t0, EXP_MAX
    beq     s1, t0, check_special_a     # If exponent is max (0x1F), might be NaN or Infinity
    beq     s4, t0, check_special_b     # If exponent is max (0x1F), might be NaN or Infinity
    j       check_zero

check_special_a:
    bne     s2, zero, return_nan        # If mantissa is non-zero, it's a NaN
    # a0 is infinity
    beq     s4, t0, check_inf_inf       # Check if both a0 and a1 are infinity
    mv      a0, a0                      # Return infinity with the correct sign
    j       cleanup

check_inf_inf:
    bne     s3, s0, return_nan          # If signs are different and both infinity, return NaN
    mv      a0, a0                      # Otherwise return infinity with the correct sign
    j       cleanup

check_special_b:
    bne     s5, zero, return_nan        # If mantissa is non-zero, it's a NaN
    # a1 is infinity, a0 is not infinity (based on flow)
    mv      a0, a1                      # Return infinity from a1
    j       cleanup

return_nan:
    li      a0, 0x7E00                  # Return a canonical QNaN
    j       cleanup

check_zero:
    # Check for zero/denormal handling
    beq     s1, zero, handle_a_special  # Check if first float has zero exponent
    beq     s4, zero, handle_b_special  # Check if second float has zero exponent
    j       prepare_normal_case

handle_a_special:
    beq     s2, zero, a_is_zero         # If exponent and mantissa are zero, a0 is zero
    # Handle denormalized number in a0 - set original exponent flag and update exponent
    li      s1, 1                       # Set exponent to 1 for denormalized
    j       prepare_normal_case

a_is_zero:
    mv      a0, a1                      # If a0 is zero, result is a1
    j       cleanup

handle_b_special:
    beq     s5, zero, b_is_zero         # If exponent and mantissa are zero, a1 is zero
    # Handle denormalized number in a1 - set original exponent flag and update exponent
    li      s4, 1                       # Set exponent to 1 for denormalized
    j       prepare_normal_case

b_is_zero:
    # a0 is already the result
    j       cleanup

prepare_normal_case:
    # Convert to internal expanded precision format with space for GRS bits
    # Shift mantissa left to make room for GRS bits
    slli    s2, s2, MANT_EXTRA_BITS    # s2 = expanded mantissa for a0 with room for GRS
    slli    s5, s5, MANT_EXTRA_BITS    # s5 = expanded mantissa for a1 with room for GRS
    
    # Add implicit bit based on ORIGINAL exponent values
    beq     s9, zero, a0_skip_implicit  # If original exponent was 0, it's denormal
    li      t0, IMPLICIT_ONE << MANT_EXTRA_BITS
    or      s2, s2, t0                  # Add implicit 1 bit for normalized numbers
a0_skip_implicit:

    beq     s10, zero, a1_skip_implicit # If original exponent was 0, it's denormal
    li      t0, IMPLICIT_ONE << MANT_EXTRA_BITS
    or      s5, s5, t0                  # Add implicit 1 bit for normalized numbers
a1_skip_implicit:

    # Align exponents
    sub     t0, s1, s4                  # t0 = exp_diff = exp1 - exp2
    beq     t0, zero, same_exponent     # If exponents are the same, skip alignment
    
    blt     t0, zero, a0_smaller_exp    # If exp1 < exp2, shift a0's mantissa
    
    # a0 has larger exponent, shift a1's mantissa right with GRS tracking
    mv      s8, s1                      # Final exponent = larger exponent (a0)
    neg     t0, t0                      # Make exp_diff positive
    li      t1, INT_MANT_BITS
    bge     t0, t1, a1_too_small        # If shift amount >= total bits, result is just a0
    
    # Perform right shift with sticky bit collection
    li      t4, 0                       # Initialize sticky bit
    mv      t2, s5                      # Work with copy of mantissa
    
    # First collect bits that will be completely shifted out into sticky bit
    li      t1, 1
    blt     t0, t1, a1_shift_mantissa   # Skip if shift amount is 0
    addi    t3, t0, -1
    srl     t1, t2, t3                  # Get the last bit being shifted out
    and     t1, t1, 1                   # Isolate just that bit
    or      t4, t4, t1                  # Add to sticky bit
    
a1_shift_mantissa:
    # Perform the main shift
    srl     s5, s5, t0                  # Right shift a1's mantissa by exp_diff
    
    # Preserve sticky bit
    li      t1, 1
    slli    t4, t4, 0                   # Place sticky bit in bit 0 of final mantissa
    or      s5, s5, t4                  # Combine with shifted mantissa
    j       same_exponent

a0_smaller_exp:
    mv      s8, s4                      # Final exponent = larger exponent (a1)
    
    li      t1, INT_MANT_BITS
    bge     t0, t1, a0_too_small        # If shift amount >= total bits, result is just a1
    
    # Perform right shift with sticky bit collection
    li      t4, 0                       # Initialize sticky bit
    mv      t2, s2                      # Work with copy of mantissa
    
    # First collect bits that will be completely shifted out into sticky bit
    li      t1, 1
    blt     t0, t1, a0_shift_mantissa   # Skip if shift amount is 0
    addi    t3, t0, -1
    srl     t1, t2, t3                  # Get the last bit being shifted out
    and     t1, t1, 1                   # Isolate just that bit
    or      t4, t4, t1                  # Add to sticky bit
    
a0_shift_mantissa:
    # Perform the main shift
    srl     s2, s2, t0                  # Right shift a0's mantissa by exp_diff
    
    # Preserve sticky bit
    li      t1, 1
    slli    t4, t4, 0                   # Place sticky bit in bit 0 of final mantissa
    or      s2, s2, t4                  # Combine with shifted mantissa
    j       same_exponent

a0_too_small:
    # a0 is so small compared to a1 that it doesn't affect the result
    mv      a0, a1
    j       cleanup

a1_too_small:
    # a1 is so small compared to a0 that it doesn't affect the result
    j       cleanup

same_exponent:
    # Add or subtract mantissas based on signs
    xor     t0, s0, s3                  # Compare signs
    beq     t0, zero, same_sign         # If signs are the same, add mantissas
    
    # Different signs, subtract smaller from larger
    blt     s2, s5, s2_smaller
    sub     s7, s2, s5                  # s7 = result mantissa = s2 - s5
    mv      s6, s0                      # Result takes sign of larger magnitude number
    j       normalize_result
    
s2_smaller:
    sub     s7, s5, s2                  # s7 = result mantissa = s5 - s2
    mv      s6, s3                      # Result takes sign of larger magnitude number
    j       normalize_result
    
same_sign:
    add     s7, s2, s5                  # s7 = result mantissa = s2 + s5
    mv      s6, s0                      # Result takes the common sign
    
    # Check for overflow in mantissa (need to shift right and increment exponent)
    li      t0, (IMPLICIT_ONE << MANT_EXTRA_BITS) << 1
    bgeu    s7, t0, mantissa_overflow
    j       normalize_result
    
mantissa_overflow:
    # Need to shift right by 1, keep track of sticky bit
    andi    t1, s7, 1                   # Get sticky bit (the bit that will be shifted out)
    srli    s7, s7, 1                   # Shift mantissa right by 1
    or      s7, s7, t1                  # Preserve sticky bit (put into LSB)
    addi    s8, s8, 1                   # Increment exponent
    
normalize_result:
    # Check if result is zero
    beq     s7, zero, return_zero

    # Normalize the result (find leading 1 and adjust exponent)
    li      t0, (IMPLICIT_ONE << MANT_EXTRA_BITS)  # Position of implicit 1 in our expanded format
    li      t2, 0                        # Counter for left shifts
    
find_leading_one:
    bgeu    s7, t0, check_exp_range      # If MSB is set, we're normalized
    slli    s7, s7, 1                    # Shift mantissa left
    addi    t2, t2, 1                    # Increment shift counter
    addi    s8, s8, -1                   # Decrement exponent
    li      t1, 30                       # Maximum reasonable shifts
    bge     t2, t1, return_zero          # If we've shifted too much, it's effectively zero
    j       find_leading_one

check_exp_range:
    # Check if exponent is too large (overflow to infinity)
    li      t1, EXP_MAX
    bge     s8, t1, overflow_to_inf      # If exponent >= max exponent value, return infinity
    
    # Check if result is denormalized (exponent <= 0)
    li      t1, 0
    bgt     s8, t1, prepare_result       # If exponent > 0, it's normalized
    
    # Handle denormalized result
    li      t1, 1                        # Minimum normalized exponent
    sub     t1, t1, s8                   # Right shift amount = 1 - exponent (negative exponent becomes positive shift)
    
    # For denormal numbers, we need to shift right and maintain sticky bit
    li      t2, INT_MANT_BITS           # Maximum shift before definitely zero
    bge     t1, t2, return_zero          # If shift too large, result underflows to zero
    
    # Set up for shifting
    li      t4, 0                        # Initialize sticky bit accumulator
    mv      t2, s7                       # Work with copy of mantissa
    
    # Collect bits that will be shifted out into sticky
    addi    t3, t1, -1                   # Get position of last bit to be shifted out
    li      t5, 0                        # Initialize mask
    li      t6, 1
    blt     t3, t6, skip_sticky          # Skip if we're only shifting by 1
    srl     t5, t2, t3                   # Get bits that will be shifted out
    and     t5, t5, 1                    # Get just the last bit
    or      t4, t4, t5                   # Add to sticky accumulator
    
skip_sticky:
    # Perform the main shift
    srl     s7, s7, t1                   # Shift right by t1 bits
    
    # Preserve sticky bit
    or      s7, s7, t4                   # Combine with sticky bit
    li      s8, 0                        # Set exponent to 0 for denormalized result

prepare_result:
    # Prepare for rounding (IEEE round-to-nearest, ties to even)
    andi    t0, s7, 0x7                  # Get GRS bits (assume 3 extra bits)
    srli    s7, s7, MANT_EXTRA_BITS      # Shift out GRS bits, leaving just the mantissa bits
    
    # Apply rounding based on GRS bits
    li      t1, 0x4                      # Check if G bit is set (0b100)
    and     t2, t0, t1
    beq     t2, zero, round_done         # If G bit not set, no rounding up
    
    # G bit is set, check tie case (G=1, R=0, S=0)
    li      t1, 0x4                      # 0b100 = Exactly G set, R and S clear
    beq     t0, t1, check_tie_to_even    # If exactly G, we have a tie
    
    # Not a tie but G is set, check if R or S is set for rounding up
    li      t1, 0x3                      # Check R and S bits (0b011)
    and     t2, t0, t1
    beq     t2, zero, round_done         # If neither R nor S set, don't round up
    j       round_up                     # G=1 and (R=1 or S=1 or both), round up
    
check_tie_to_even:
    # For ties, round to make LSB even
    andi    t1, s7, 1                    # Get LSB of mantissa
    beq     t1, zero, round_done         # If LSB is even, don't round up
    
round_up:
    addi    s7, s7, 1                    # Round up
    li      t0, MANTISSA_MASK + 1        # Check if rounding caused overflow
    bne     s7, t0, round_done           # If no overflow, continue
    
    # Rounding caused mantissa overflow, adjust
    srli    s7, s7, 1                    # Shift mantissa right
    addi    s8, s8, 1                    # Increment exponent
    li      t0, EXP_MAX                  # Check if exponent now overflows
    bge     s8, t0, overflow_to_inf      # If exponent overflows, return infinity
    
round_done:
    # Assemble the final float
    # Make sure we only keep fractional bits (remove any implicit 1 bit)
    li      t0, MANTISSA_MASK
    and     s7, s7, t0                   # Ensure mantissa fits in 10 bits
    
    # Combine exponent and mantissa
    slli    t0, s8, 10                   # Shift exponent to correct position
    or      t0, t0, s7                   # Combine exponent and mantissa
    or      a0, t0, s6                   # Add sign bit
    j       cleanup
    
overflow_to_inf:
    li      a0, EXPONENT_MASK           # Set exponent bits to all 1s, mantissa to 0
    or      a0, a0, s6                   # Add the correct sign bit
    j       cleanup
    
return_zero:
    # Return signed zero based on the signs of the inputs
    beq     s0, s3, use_common_sign     # If signs are the same, use that sign
    li      a0, 0                       # Otherwise return +0 (this is IEEE754 behavior)
    j       cleanup
    
use_common_sign:
    mv      a0, s0                      # Return zero with the common sign

cleanup:
    # Restore registers
    .if CPU_BITS == 32
        lw      ra, 0(sp)
        lw      s0, 4(sp)
        lw      s1, 8(sp)
        lw      s2, 12(sp)
        lw      s3, 16(sp)
        lw      s4, 20(sp)
        lw      s5, 24(sp)
        lw      s6, 28(sp)
        lw      s7, 32(sp)
        lw      s8, 36(sp)
        lw      s9, 40(sp)
        lw      s10, 44(sp)
    .else
        ld      ra, 0(sp)
        ld      s0, 8(sp)
        ld      s1, 16(sp)
        ld      s2, 24(sp)
        ld      s3, 32(sp)
        ld      s4, 40(sp)
        ld      s5, 48(sp)
        ld      s6, 56(sp)
        ld      s7, 64(sp)
        ld      s8, 72(sp)
        ld      s9, 80(sp)
        ld      s10, 88(sp)
    .endif
    
    addi    sp, sp, (12 * (CPU_BITS/8))  # Restore stack pointer
    
    ret                                  # Return with result in a0

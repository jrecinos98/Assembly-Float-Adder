.data

A:
	.float -1290.55
B:
	 #7 decimal digits is the max precision 
	.float -10.25
C:
	.float 0.0
	
MMask:
	.word 0x007FFFFF
MSize:
	.word 23
MaxExp:
	.word 255
Implicit:
	.word 0x00800000
EMask:
	.word 0x7F800000
SMask:
	.word 0x80000000

#MAIN PROMPTS
welcome_message: .asciiz "\nWelcome to My Assembly Float Adder!"
float_prompt1:   .asciiz "\n\n1st Number: "
float_prompt2:   .asciiz "2nd Number: "
float_result:    .asciiz "Sum Result: "
float_buffer:    .float 0.0

.text

main:
		la $a0, welcome_message
	li $v0, 4
	syscall

user_prompt_loop:
		# user prompt for 1st number
		la $a0, float_prompt1
		li $v0, 4
		syscall
		li  $v0, 6
		syscall
		mfc1 $t0, $f0

		# user prompt for 2nd number
		la $a0, float_prompt2
		li $v0, 4
		syscall
		li  $v0, 6
		syscall
		mfc1 $t1, $f0

		# exit if both numbers are zero
		addu $t2, $t0, $t1
		beq  $t2, $zero, exit

		# load floating numbers
		add $a0, $t0, $zero
		add $a1, $t1, $zero

		# add floating numbers
		jal MYADD
	
		la $t0, float_buffer
		sw $v0, 0($t0)
		l.s $f1, ($t0)

		# print sum
		la $a0, float_result
		li $v0, 4
		syscall
		mov.s $f12, $f1
		li  $v0, 2
		syscall


		j user_prompt_loop

exit:
	li $v0, 10
	syscall


MYADD:
	#store registers
	addiu $sp, $sp, -36
	sw $ra, 0($sp)
	sw $s0, 4($sp)
	sw $s1, 8($sp)
	sw $s2, 12($sp)
	sw $s3, 16($sp)
	sw $s4, 20($sp)
	sw $s5, 24($sp)
	sw $s6, 28($sp)
	sw $s7, 32($sp)



	move $s0, $a0
	move $s1, $a1

	#Exponent for first float
	move $a0, $s0
	jal getExponent
	move $s2, $v0

	#Exponent for second float
	move $a0, $s1
	jal getExponent
	move $s3, $v0

sort:
	
	#Find the smallest exponent and put the smallest in $s0.
	blt $s2, $s3, mantissa

	#if $s2 > $s3:

	#temp copy of greatest exponent
	move $t0, $s0
	move $t1, $s2
	
	move $s0, $s1
	move $s2, $s3

	#restore the greater exponent
	move $s1, $t0
	move $s3, $t1

mantissa:	

	#Mantissa for first float (One with smallest exponent)
	move $a0, $s0
	jal getMantissa
	move $s4, $v0


	#Mantissa for the second float (One with greatest exponent)
	move $a0, $s1
	jal getMantissa
	move $s5, $v0

	

#THIS SHOULD WORK REGARDLESS OF EXPONENT SIGN SINCE EXPONENT HAS BIAS.
shift:	
	#R bit
	li $s6,0
	#S bit
	li $s7,0

	#subtract $s2 from $s3 to get the diff in exponents and shift amount
	sub $t2, $s3, $s2
	#Add to the exponent of the smallest one
	add $s2, $s2, $t2

	

rounding:
	beq $t2, $0, sign
	#Once S is set it never changes. First iteration it is impossible to set S
	or $s7, $s7, $s6
	#Get the last bit before shift
	andi $s6, $s4, 0x0001
	#Shift to the right
	sra $s4, $s4, 1
	addi $t2, $t2, -1
	j rounding

	#At the end of the loop R and S bit are set to their correct location



sign:
	
	#Get sign of float in $s0
	move $a0, $s0
	jal getSign
	#Original float not needed anymore
	move $s0, $v0

	#Get sign of float in $s1
	move $a0, $s1
	jal getSign
	#original float not needed anymore
	move $s1, $v0

	#If not the same then we need to subtract the smallest mantissa to the smallest
	bne $s0, $s1, subtract

addFloat:    
	#The signs are the same if I get here. Only need one exponent so replace $s3
	add $s3, $s5, $s4

	#Now there may be more than 23 bits in Mantissa so it must be normalized
	j normal

subtract:

	#Need to find the smallest value Mantissa. If $s4 < $s5 no swap needed
	blt $s4, $s5, subtractFloat
	
	#put one with smallest mantissa in lower register if not already there
	move $t2, $s0
	move $t3, $s2
	move $t4, $s4
	
	move $s0, $s1
	move $s2, $s3
	move $s4, $s5

	#restore
	move $s1, $t2
	move $s3, $t3
	move $s5, $t4	

subtractFloat:

	#Subtract smallest Mantissa ($s4) from largest Mantissa($s5)
	subu $s3, $s5, $s4

	#edge case when the value equals to 0 after subtraction
	beq $s3, $0, retZero
	j normal
retZero:
	li $v0, 0
	j returnFloat

normal: #Pre-Condition: $s1 contains the sign bit, $s2 contains the exponent, $s3 contains the mantissa
	

	#combine S & R bit
	or $s0, $s6, $s7

	#Move arguments
	#Biggest mantissa sign stored in $s1
	move $a0, $s1
	#Esponent is the same for both so pick whichever
	move $a1, $s2
	#Move Mantissa
	move $a2, $s3
	#Move S&R bit 
	move $a3, $s0


	jal normalizeFloat

returnFloat:
	#Move normalized float
	move $s0, $v0


	#restore registers and stack
	lw $ra, 0($sp)
	lw $s0, 4($sp)
	lw $s1, 8($sp)
	lw $s2, 12($sp)
	lw $s3, 16($sp)
	lw $s4, 20($sp)
	lw $s5, 24($sp)
	lw $s6, 28($sp)
	lw $s7, 32($sp)
	
	addiu $sp, $sp, 36

	jr $ra




normalizeFloat: #Checks Mantissa after the operation. Normalizes the number, rounds it and stitches it all together
	
	#Store registers
	addiu $sp, $sp, -24
	sw $ra, 0($sp)
	sw $s0, 4($sp)
	sw $s1, 8($sp)
	sw $s2, 12($sp)
	sw $s3, 16($sp)
	sw $s4, 20($sp)

	#sign 
	move $s0, $a0

	#Exponent
	move $s1, $a1

	#The Mantissa STILL has the implicit "1" in front 
	move $s2, $a2


	

    #Get R & S
	andi $s3, $a3 , 0x0002
	andi $s4, $a3, 0x0001


	#sra $s2, $s2, 2

	# Has  the last 24 bits on
 	li $t2, 0x00FFFFFF

 	#Only time this will be true is if any bit after 24 is 1, in which case we need to shift right
 	bgt $s2, $t2, shiftRight

 	#Has the 24th bit on and everything else 0
 	li $t2, 0x00800000

 	#Only will be true if every bit after the 23th bit is 0
 	blt $s2, $t2, shiftLeft

 	#If it gets here it means that no shift is necessary and it can be joined
 	j checkOverflow

shiftRight: #There can be muliple right shifts
 	move $t1, $s2
 	li $t2,0
 	li $t3, 0x00FFFFFF


rightLoop:

 	
 	#Check if copy is still greater than the mask 
 	slt $t4, $t1, $t3
 	
 	#If it equals zero it means it is equal to or less than mask.
 	bne $t4, $0, endLoopRight
	
	#Modify S bit
	or $s4, $s4, $s3
	#extract R bit
 	andi $s3, $s2, 0x0001

 	sra $t1, $t1, 1
 	addi $t2, $t2, 1
 	j rightLoop

endLoopRight:
 	#Adjust exponent
 	add $s1, $s1, $t2
 	#shift
 	sra $s2, $s2, $t2

 	j checkOverflow


 shiftLeft: #There can be multiple left shifts so have to figure out 
	
 	move $t1, $s2
 	li $t2, 0
 	li $t3, 0x00800000
 
 	
 loopLeft:
 	#Check if copy is still less than the mask 
 	slt $t4, $t1, $t3
 	
 	#If it equals zero it means it is equal to or greater than mask.
 	beq $t4, $0, endLoopLeft

 	#Shift copy left
 	sll $t1, $t1, 1

 	#Add one to counter
 	addi $t2, $t2, 1
 	j loopLeft
 endLoopLeft:
 	#subtract exponent
 	subu $s1, $s1, $t2
 	#shift left by the amount in counter
 	sll $s2, $s2, $t2
	
	#subtract one from exponent. R would be shifted one less than mantissa
	addi $t2, $t2, -1

	#shift R if present
	sll $s3, $s3, $t2

	#Now OR with the mantissa to the location it should be
	or $s2, $s2, $s3

	#Reset R
	li $s3, 0


checkOverflow: 

	#Contains the value of exponent with overflow
	lw $t2, MaxExp
	
	beq $s1, $0, underflow
	beq $s1, $t2, overflow

	j checkRound

overflow:
	li $s2, 0
	j combine

underflow:
	
	li $v0, 0
	j return

checkRound:
	 #Add R & S bit
	add $t2, $s3, $s4
	li $t3, 2
	#if the sum equals 2 then both R & S are one and we round
	beq $t2, $t3, round
	j combine
round:
	#Round by adding to mantissa
	add $s2, $s2, 1

	#Set up function arguments
	move $a0, $s0
	move $a1, $s1
	move $a2, $s2
	#Only move the S bit. R gets reset but S should be 1 once it becomes 1.
	move $a3, $s4

	#recursively call function on Mantissa in case it need to be re-normalized
	jal normalizeFloat

	#The float will be already stored in $v0 so just restore stack and return
	j return

combine:

	lw $t0, MMask
	lw $t1, MSize

	#Fix exponent
	sll $s1, $s1, $t1
	#cleanse mantissa
	and $s2, $s2, $t0	

	#stitch all the pieces together
	or $s1,$s1, $s2
	or $s0, $s0, $s1
	
	#At the end of the recurssion (if any) we want to move result to $v0. 
	#After unwinding, the original function call will assume the result is in $v0 and simply restore the stack and return to main
	j result

result:
	
	move $v0, $s0 

return:
	#restore stack
	lw $ra, 0($sp)
	lw $s0, 4($sp)
	lw $s1, 8($sp)
	lw $s2, 12($sp)
	lw $s3, 16($sp)
	lw $s4, 20($sp)
	addiu $sp, $sp, 24

	
	jr $ra
	
getMantissa:#$a0 must contain the register with the float. RETURNS WITH IMPLICIT 1 ADDED
	
	lw $t0, MMask
	lw $t1, Implicit

	#Extract mantissa
	and $t0, $a0, $t0

	#Add implicit 1
	or $v0, $t0, $t1
	
	jr $ra

getExponent: #$a0 contains the float. Returns exponent with bias (not real exponent). Exponent is unsigned
	
	lw $t0, EMask
	lw $t1, MSize

	#extract exponent portion
	and $t0, $a0, $t0
	
	#Shift to the right to get the exponent
	sra $v0, $t0, $t1

	jr $ra

getSign:
	lw $t0, SMask
	and $v0, $a0, $t0
	jr $ra
	

.globl write_handler
#.align 4
write_handler:
    addi	a2, x0, 0		# set 0 up for i
    addi 	x5, x0, 1		# set up 1
    addi 	x6, x0, 2		# set up 2
    addi 	x7, a2, 0		# save count
    
write_handler_loop:
    csrw 	0x7C4, x5		# set dev_select csr to 1
    csrw 	0x7C5, x6		# set dev_select csr to 2
    sb  	x0, 0(a0)		# perform uart write
    csrw 	0x7C4, x0		# set dev_select csr to 0
    csrw 	0x7C5, x0		# set dev_select csr to 0
    addi	a0, a0, 1		# increment buffer
    addi	a2, a2, 1		# increment i
    addi	a1, a1, -1		# decrement count
    bne		a1, x0, write_handler_loop	# loop back if count doesn't match
    addi	a0, a2, 0		# set return value to i
    addi	a0, a2, 0		# return i
    jalr	x0, 0(ra)		# ret	

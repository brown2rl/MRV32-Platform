.globl read_handler
#.align 4
read_handler: 
    addi	a3, x0, 13		# set \r
    addi	a4, x0, 0		# set 0 up for i
    addi 	x5, x0, 1		# set up 1
    addi 	x6, x0, 2		# set up 2
    addi 	x7, a1, 0		# save count
    wfi
    csrw 	0x7C4, x6		# set dev_select csr to 2
    csrw 	0x7C5, x5		# set dev_select csr to 1
    sb		x0, 0(a0)
    csrw 	0x7C4, x0		# set dev_select csr to 0
    csrw 	0x7C5, x0		# set dev_select csr to 0
    lbu		a5, 0(a0)		# load ascii character into a5
    beq 	a2, x0, canonical	# branch to canonical mode if flag == 0
    addi	a4, a4, 1		# increment i
    csrw 	0x7C4, x0		# set dev_select csr to 0
    csrw 	0x7C5, x0		# set dev_select csr to 0
    addi 	a0, a4, 0		# return i
    jalr 	x0, 0(ra)		# ret
    
canonical:
    beq		a3, a5, return_i	# branch to return i
    csrw 	0x7C4, x5		# set dev_select csr to 1
    csrw 	0x7C5, x6		# set dev_select csr to 2
    sb  	x0, 0(a0)		# perform uart write
    addi	a0, a0, 1		# increment buf
    addi	a4, a4, 1		# increment i
    beq		a4, a1, return_i	# branch to return i
    wfi
    
return_i:
    csrw 	0x7C4, x0		# set dev_select csr to 0
    csrw 	0x7C5, x0		# set dev_select csr to 0
    addi	a0, a4, 0		# return i
    jalr	x0, 0(ra)		# ret	

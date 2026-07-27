.globl sys_sd_read
#.align 4
sys_sd_read:
    addi 	x5, x0, 1		# set up 1
    addi 	x6, x0, 3		# set up 3
    csrw 	0x7C4, x6		# set dev_select csr to 3
    csrw 	0x7C5, x5		# set dev_select csr to 1
    sb  	a1, 0(a0)		# perform sd card read
    csrw 	0x7C4, x0		# set dev_select csr to 0
    csrw 	0x7C5, x0		# set dev_select csr to 0
    addi	a0, x0, 1		# return i
    jalr	x0, 0(ra)		# ret	

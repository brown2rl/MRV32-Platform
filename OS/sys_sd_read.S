.globl sys_sd_read
#.align 4
sys_sd_read:
    addi 	x5, x0, 1		# set up 1
    csrw 	0x7CF, x5		# set dev_select csr to 1
    lbu  	a1, 0(a0)		# perform sd card read
    csrw 	0x7CF, x0		# put dev_select back at 0
    addi	a0, x0, 512		# return i
    jalr	x0, 0(ra)		# ret	

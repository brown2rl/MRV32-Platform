(* dont_touch = "true" *)
module System(clk_in1, tx, rx, miso, mosi, cs, sclk);

input clk_in1, rx, miso;
output tx, mosi, cs, sclk;
wire rxinterrupt, rxack, txready, txbusy, tuwfi, tx_irq_en, dev_start_signal, dev_stop_signal, address_progression, sdevram, srs, tu, restu, ecall, tucall, tuint, sret, mret, rdwe, cur, sdrd, sdrs, next_read_address, read_write_address, in0o, rstco, tupccs, tucspc, ipc, rpi, ramwe, stupc, stucsr, scmcsi, scmcst, scsr0, rlpccs, pc, scmpc, jalr, pcpi, spm, smr, srm, crm, smi, sri, spcr, spcrt, srpc, spca, sraa, srab, sar, scmr, srcm, srram, srr8, srr16, srr32, sramrs8, sramrs16, sramrs32, sramru8, sramru16, sramru32, scsr, srcs, spcs, scsp, scmcs, csbmr, csbmi, csor, csori, csan, csrl, csani, smrar, add, mul, lt, gt, gtu, br, eq, neq, ltu, XOR, OR, AND, sll, srl, sra, sub, sllr, scma, scmau, scm;
wire[4:0] REG_A, REG_B, REG_D, ALU_OP;
wire[5:0] div_cnt;
wire[31:0] testwire, PC_MAR, MAR_RAM, SAR_SDC, MAR_UART, RAM_IR, IR_CM, PC_REGS, REGS_PC, REGS_SAR, REGS_ALU_A, REGS_ALU_B, ALU_REGS, CM_REGS, REGS_CM, ALU_CM, REGS_RAM, RAM_REGS, CSR_REGS, REGS_CSR, REGS_MAR, CM_CSRI, CM_CSRT, PC_CSR, CSR_PC_MTVEC, CSR_PC_MEPC, CSR_PC_TXVEC, CSR_PC_RXVEC, TU_CSR, TU_PC, UART_MAR, CSR_PC_SDCWVEC, CSR_PC_SDCRVEC, CSR_DEV_BUS_IN, CSR_DEV_BUS_OUT, PC_CACHE, REGS_CACHE, CACHE_IR, CACHE_RAM, CACHE_MAR;
wire[11:0] CM_CSR;
reg[31:0] DEV_REGS, DEV_UART, DEV_RAM, DEV_SDC, DEV;
reg[7:0] incont, outcont, ramcontout, sdccontout, uartcontout;
wire[19:0] CM_PC;
wire[31:0] CM_MAR;
wire[31:0] CM_ALU, PC_ALU;
wire[7:0] tx_byte, rx_byte, RAM_DEV, UART_DEV, SDC_DEV, MAR_DEV, ramcontin, sdccontin, uartcontin;
wire[15:0] clk_cnt;
reg indicators = 1, srmp, srsp;

clk_wiz_0 CW1(clk_out1, clk_in1);

(* dont_touch = "true" *)
Cache CACHE(clk_out1, pc, );

(* dont_touch = "true" *)
Program_Counter PC1(clk_out1, indicators, pc, tupc, stucsrpc, pcpi, ipc, jalr, srpc, scspcecall, scspcmret, scspctxint, scspcrxint, bacm, PC_MAR, PC_ALU, CM_PC, REGS_PC, PC_REGS, CSR_PC_MTVEC, CSR_PC_MEPC, CSR_PC_TXVEC, CSR_PC_RXVEC, PC_CSR, TU_PC);

(* dont_touch = "true" *)
MAR MAR1(clk_out1, mpi, rpi, spm, srm, srmp, crm, smi, scm, address_progression, PC_MAR, MAR_RAM, REGS_MAR, CM_MAR, MAR_UART);

(* dont_touch = "true" *)
SAR SAR1(clk_out1, srs, srsp, REGS_SAR, SAR_SDC);

(* dont_touch = "true" *)
IR IR1(clk_out1, sri, srm, smi, mpi, rpi, srr8, srr16, srr32, crm, pc, IR_CM, RAM_IR);

(* dont_touch = "true" *)
RAM RAM1(clk_out1, indicators, dev_start_signal, dev_stop_signal, address_progression, sdevram, rst, srr8, srr16, srr32, sramrs8, sramrs16, sramrs32, sramru8, sramru16, tx_irq_en, next_read_address, DEV_RAM, RAM_DEV, MAR_RAM, RAM_REGS, REGS_MAR, REGS_RAM, RAM_IR, ramcontin, ramcontout, CSR_DEV_BUS_IN, CSR_DEV_BUS_OUT);

(* dont_touch = "true" *)
CM CM1(clk_out1, rst, tu, restu, ecall, sret, mret, tuwfi, rxinterrupt, tx_int_ack, dev_start_signal, dev_stop_signal, sdevram, sdrs, sdrd, sdws, sdwd, spp, ssp, srs, pc, bacm, stucsrpc, pcpi, ipc, mpi, rpi, scmcsi, scmcst, scmpc, jalr, cur, smi, spm, srm, crm, sri, spcr, spcrt, srpc, spca, sraa, srab, sar, scmr, srcm, srram, srr8, srr16, srr32, sramrs8, sramrs16, sramrs32, sramru8, sramru16, scsr, srcs, spcs, scsp, scmcs, csbmr, csbmi, csor, csori, csan, csrl, csani, smrar, scma, scmau, stupc, ALU_OP, CM_PC, IR_CM, REGS_CM, CM_REGS, REG_A, REG_B, REG_D, CM_ALU, ALU_CM, CM_CSR, CM_CSRI, CM_CSRT, CM_MAR, CSR_DEV_BUS_IN, CSR_DEV_BUS_OUT);
      
(* dont_touch = "true" *)
REGS REGS1(clk_out1, indicators, out, spcr, spcrt, sraa, srab, sar, scmr, sramr, scsr, sramrs8, sramrs16, sramrs32, sramru8, sramru16, REGS_SAR, PC_REGS, REGS_PC, CM_REGS, REGS_CM, RAM_REGS, REGS_RAM, CSR_REGS, REGS_CSR, REGS_MAR, REGS_ALU_A, REG_A, REG_B, REG_D, REGS_ALU_B, ALU_REGS);
    
(* dont_touch = "true" *)
ALU ALU1(clk_out1, spca, sraa, srab, scma, scmau, bacm, div_cnt, ALU_OP, REGS_ALU_A, REGS_ALU_B, ALU_REGS, CM_ALU, PC_ALU, ALU_CM);

(* dont_touch = "true" *)
CSR CSR1(clk_out1, ecall, mret, tucall, tuint, tupccs, stucsr, scmcsi, scmcst, scsr0, srcs, spcs, scmcs, csbmr, csbmi, csor, csori, csan, csrl, csani, CSR_REGS, REGS_CSR, CSR_PC_MTVEC, CSR_PC_MEPC, CSR_PC_TXVEC, CSR_PC_RXVEC, PC_CSR, CM_CSR, CM_CSRI, CM_CSRT, TU_CSR, CSR_PC_SDCWVEC, CSR_PC_SDCRVEC, CSR_DEV_BUS_IN, CSR_DEV_BUS_OUT);

(* dont_touch = "true" *)
Trap_Unit TU1(clk_out1, restu, tuwfi, tucall, tuint, tupc, rxinterrupt, rxack, tx_irq_en, rxpending, rxack, txready, tx_int_ack, txbusy, ecall, sret, mret, tupccs, tucspc, stupc, stucsr, stucsrpc, scspcecall, scspcmret, scspctxint, scspcrxint, scsr0, TU_PC, TU_CSR);

(* dont_touch = "true" *)
UART UART1(clk_out1, indicatorsin, cur, tx, rx, rxack, srm, mpi, srr8, srr32, rxinterrupt, txready, txbusy, UART_DEV, DEV_UART, REGS_MAR, UART_MAR, MAR_UART, uartcontin, uartcontout, CSR_DEV_BUS_IN, CSR_DEV_BUS_OUT);

(* dont_touch = "true" *)
SD_Controller SDC1(clk_out1, reset, ss, start, tx_byte, sdc_wirq_en, sdc_rirq_en, srr8, srr32, next_read_address, next_write_address, cs_en, clk_on, clk_cnt, rx_byte, busy, done, card_busy, sd_read_interrupt, sd_write_interrupt, SDC_DEV, DEV_SDC, MAR_DEV, SAR_SDC, sdccontin, sdccontout, CSR_DEV_BUS_IN, CSR_DEV_BUS_OUT);

(* dont_touch = "true" *)
SPI_Engine SPI1(clk_out1, start, tx_byte, cs_en, clk_on, clk_cnt, miso, rx_byte, busy, done, cs, sclk, mosi);


always @*
begin
	begin
	begin
	case (CSR_DEV_BUS_IN)
		1: 	
		begin	
			DEV = RAM_DEV;
			srmp = spp;
		end
		2: 	
		begin
			DEV = UART_DEV;
		end
		3: 	
		begin	
			DEV = SDC_DEV;
		   	srsp = spp;
		end
	endcase
	end
	
	begin
	case (CSR_DEV_BUS_OUT)
		1: 	
		begin	
			DEV_RAM = DEV;
			srmp = ssp;
		end
		2: 
		begin
			DEV_UART = DEV;
		end
		3: 	
		begin	
			DEV_SDC = DEV;
			srsp = ssp;
		end
	endcase
	end
	
	// in/out controls
	begin
	case (CSR_DEV_BUS_IN)
		1: 	
		begin	
			outcont = ramcontin;
		end
		2: 	
		begin
			outcont = uartcontin;
		end
		3: 	
		begin	
			outcont = sdccontin;
		end
	endcase
	end
	
	begin
	case (CSR_DEV_BUS_OUT)
		1: 	
		begin	
			ramcontout = outcont;
		end
		2: 	
		begin
			uartcontout = outcont;
		end
		3: 	
		begin	
			sdccontout = outcont;
		end
	endcase
	end
	
	begin
	case (CSR_DEV_BUS_IN)
		1: 	
		begin	
			ramcontout = incont;
		end
		2: 	
		begin
			uartcontout = incont;
		end
		3: 	
		begin	
			sdccontout = incont;
		end
	endcase
	end
	
	// out/out controls
	begin
	case (CSR_DEV_BUS_OUT)
		1: 	
		begin	
			incont = ramcontin;
		end
		2: 	
		begin
			incont = uartcontin;
		end
		3: 	
		begin	
			incont = sdccontin;
		end
	endcase
	end
	end
end


endmodule
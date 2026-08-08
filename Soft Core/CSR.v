module CSR(clk, ecall, mret, tucall, tuint, tupccs, stucsr, scmcsi, scmcst, scsr0, srcs, spcs, scmcs, csbmr, csbmi, csor, csori, csan, csrl, csani, CSR_REGS, REGS_CSR, CSR_PC_MTVEC, CSR_PC_MEPC, CSR_PC_TXVEC, CSR_PC_RXVEC, PC_CSR, CM_CSR, CM_CSRI, CM_CSRT, TU_CSR, CSR_PC_SDCWVEC, CSR_PC_SDCRVEC, CSR_DEV_BUS_IN, CSR_DEV_BUS_OUT);

input clk, ecall, mret, tucall, tuint, tupccs, stucsr, scsr0, srcs, spcs, scmcs, scmcsi, scmcst, csbmr, csbmi, csor, csori, csan, csrl, csani;
input[31:0] REGS_CSR, PC_CSR, CM_CSRI, CM_CSRT, TU_CSR;
input[11:0] CM_CSR;
output[31:0] CSR_REGS, CSR_PC_MTVEC, CSR_PC_MEPC, CSR_PC_TXVEC, CSR_PC_RXVEC, CSR_PC_SDCWVEC, CSR_PC_SDCRVEC, CSR_DEV_BUS_IN, CSR_DEV_BUS_OUT;
reg[31:0] CSR, bitmask, misa, mstatus, mtvec, mepc, mcause, mscratch, mtval, mie, mip, cycle, instret, mhartid, txvec, rxvec, sdcwvec, sdcrvec, devsel, busin, busout;
reg[4:0] immediate;

initial
begin
	misa 	= 32'h40001104;
	mstatus = 32'h0;
	mtvec	= 32'h0;
	mepc 	= 32'h0;
	mcause 	= 32'h0;
	mtval	= 32'h0;
	mie	= 32'h0;
	mip	= 32'h0;
	cycle	= 32'h0;
	instret	= 32'h0;
	mhartid	= 32'h0;
	busin	= 32'h0;
	busout	= 32'h0;
	txvec = 32'h0;
	rxvec = 32'h0;
	sdcwvec = 32'h0;
	sdcrvec = 32'h0;
	devsel = 32'h0;
end
				
always @(posedge clk)
if (scmcs)
	immediate <= CM_CSRI[4:0];

always @(posedge clk)
if (CM_CSR != 12'h301 && CM_CSR != 12'hF14)
begin
if (srcs)
begin
	CSR <= REGS_CSR;
end
else if (csor)
begin
	CSR <= CSR | REGS_CSR;
end
else if (csan)
begin
	CSR <= CSR & ~REGS_CSR;
end
else if (scmcsi)
begin
	CSR <= { 27'b0 , immediate };
end
else if (csori)
begin
	CSR <= CSR | { 27'b0 , immediate };
end
else if (csani)
begin
	CSR <= CSR & ~{ 27'b0 , immediate };
end
else if (scmcs)
begin
case (CM_CSR)
	12'h301 : CSR <= misa;
	12'h300 : CSR <= mstatus;
	12'h305 : CSR <= mtvec;
	12'h340 : CSR <= mscratch;			 
	12'h341 : CSR <= mepc;
	12'h342 : CSR <= mcause;
	12'h343 : CSR <= mtval;
	12'h304 : CSR <= mie;
	12'h344 : CSR <= mip;
	12'h7C0 : CSR <= txvec;
	12'h7C1 : CSR <= rxvec;
	12'h7C2 : CSR <= sdcwvec;
	12'h7C3 : CSR <= sdcrvec;
	12'h7C4 : CSR <= busin;
	12'h7C5 : CSR <= busout;
	12'hC00 : CSR <= cycle;
	12'hC02 : CSR <= instret;
	12'hF14 : CSR <= mhartid;
	default : CSR <= 0;
endcase
end
else if (stucsr)
	CSR <= mtvec;
end

always @(posedge clk)
begin
if (csrl)
begin
case (CM_CSR)
	12'h301 : misa <= CSR;
	12'h300 : mstatus <= CSR;
	12'h305 : mtvec <= CSR;
	12'h340 : mscratch <= CSR;
	12'h341 : mepc <= CSR;
	12'h342 : mcause <= CSR;
	12'h343 : mtval <= CSR;
	12'h304 : mie <= CSR;
	12'h344 : mip <= CSR;
	12'h7C0 : txvec <= CSR;
	12'h7C1 : rxvec <= CSR;
	12'h7C2 : sdcwvec <= CSR;
	12'h7C3 : sdcrvec <= CSR;
	12'h7C4 : busin <= CSR;
	12'h7C5 : busout <= CSR;
	12'hC00 : cycle <= CSR;
	12'hC02 : instret <= CSR;
	12'hF14 : mhartid <= CSR;
endcase
end
if (tupccs)
begin
	mepc <= PC_CSR + 4;
end
end

//always @*
//begin
//	$display("busin = ", busin);
//	$display("busout = ", busout);
//end

assign	CSR_REGS = CSR;
assign	CSR_PC_MTVEC = mtvec;
assign	CSR_PC_MEPC = mepc;
assign	CSR_PC_TXVEC = txvec;
assign	CSR_PC_RXVEC = rxvec;
assign	CSR_PC_SDCWVEC = sdcwvec;
assign	CSR_PC_SDCRVEC = sdcrvec;
assign  CSR_DEV_BUS_IN = busin;
assign  CSR_DEV_BUS_OUT = busout;

endmodule
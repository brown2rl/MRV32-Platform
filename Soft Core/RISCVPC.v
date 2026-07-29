module Program_Counter(clk, indicators, pc, tupc, stucsrpc, pcpi, ipc, jalr, srpc, scspcecall, scspcmret, scspctxint, scspcrxint, bacm, PC_MAR, PC_ALU, CM_PC, REGS_PC, PC_REGS, CSR_PC_MTVEC, CSR_PC_MEPC, CSR_PC_TXVEC, CSR_PC_RXVEC, PC_CSR, TU_PC);

input clk, indicators, pc, ipc, tupc, stucsrpc, pcpi, jalr, srpc, scspcecall, scspcmret, scspctxint, scspcrxint, bacm;
input[31:0] REGS_PC, CSR_PC_MTVEC, CSR_PC_MEPC, CSR_PC_TXVEC, CSR_PC_RXVEC, TU_PC;
input[19:0] CM_PC;
output[31:0] PC_REGS, PC_CSR, PC_ALU;
output reg[31:0] PC_MAR;
reg[33:0] program_counter;

initial
begin
	program_counter = 34'b0;
end

always @*
if (indicators)
	$display("PC/4 = %d", program_counter/4);

always @(posedge clk)
begin
/*if (stucsrpc)
begin
	program_counter <= CSR_PC;
end
else*/ if (srpc)
begin
	program_counter <= REGS_PC;
end
else if (pcpi)
begin
	if (jalr)
	begin
		program_counter <= program_counter + ({ {14{CM_PC[19]}}, CM_PC[19:0]} & ~1);
	end
	else
	begin
		program_counter <= program_counter + ({ {14{CM_PC[19]}}, CM_PC[19:0]} << 1);
	end
end
else if (bacm)
begin
	program_counter <= program_counter + ({ {22{CM_PC[11]}}, CM_PC[11:0]} << 1);
end
else if (pc)
begin
	program_counter <= program_counter + 4;
end 
else if (tupc)
	program_counter <= program_counter + 4;
else if (scspcecall)
begin
	program_counter <= CSR_PC_MTVEC;
end
else if (scspcmret)
begin
	program_counter <= CSR_PC_MEPC;
end
else if (scspctxint)
begin
	program_counter <= CSR_PC_TXVEC;
end
else if (scspcrxint)
begin
	program_counter <= CSR_PC_RXVEC;
end
end

always @*
if (!ipc)
	PC_MAR = program_counter;
else
	PC_MAR = 34'b0;

assign PC_ALU = program_counter;
assign PC_REGS = program_counter;
assign PC_CSR = program_counter;

endmodule
module MAR(clk, mpi, rpi, spm, srm, srmp, crm, smi, address_progression, PC_MAR, MAR_RAM, REGS_MAR, CM_MAR, MAR_UART);

input clk, mpi, rpi, spm, srm, srmp, crm, smi, address_progression;
input[31:0] PC_MAR, REGS_MAR;
input[31:0] CM_MAR;
output[31:0] MAR_RAM, MAR_UART;
reg[31:0] MAR;
reg increment_mar; 

initial
begin
	MAR = 0;
end

wire immediate = smi ? $signed(CM_MAR) : 34'd0;

always @(posedge clk)
if (srm || srmp)
begin
	//$display("REGS_MAR = %h", REGS_MAR);
	MAR <= (REGS_MAR);
end
else if (crm)
begin
   	MAR <= 34'b0;
end
else if (mpi)
begin
	MAR <= MAR + immediate;
end
else if (spm)
begin
	MAR <= PC_MAR;
end
else if (rpi)
begin
	MAR <= $signed(CM_MAR) + REGS_MAR;
end
else if (address_progression)
begin
    increment_mar <= 1;
end
else if (increment_mar)
begin
    MAR <= MAR + 1;
    increment_mar <= 0;
end


assign MAR_RAM = MAR;
assign MAR_UART = MAR;

endmodule
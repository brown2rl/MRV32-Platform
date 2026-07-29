module IR(clk, sri, srm, smi, mpi, rpi, srr8, srr16, srr32, crm, pc, IR_CM, RAM_IR);

input clk, sri, srm, smi, mpi, rpi, srr8, srr16, srr32, crm, pc;
input[31:0] RAM_IR;
output[31:0] IR_CM;
reg[31:0] instruction;

always @(posedge clk)
if (sri && !srm && !smi && !mpi && !rpi && !srr8 && !srr16 && !srr32 && !crm && !pc)
begin
	instruction <= RAM_IR;
end

assign	IR_CM = instruction;

endmodule
// first iteration, 6 rightmost bits are 0, next iteration
// cache word = 32 bytes
// inputs: ram, pc, regs
// outputs: ir, ram, mar
// a few hard coded instructions
// states: done, idle, ram, pc, regs
// cache control bit input
// perifrials and regs are cache_data
// data cache address register module (DCAR)
// instruction cache address register module (ICAR)
 
module CACHE(clk, scm, pc);

input clk, scm, pc; //indicators, rst, srr8, srr16, srr32, sramrs8, sramrs16, sramrs32, sramru8, sramru16, byte_ready, dev_start_signal, sdevram;
input[31:0] PC_CACHE, REGS_CACHE, RAM_CACHE, CSR_DEV_BUS_IN, CSR_DEV_BUS_OUT;

output[31:0] CACHE_IR, CACHE_RAM, CACHE_MAR, CACHE_REGS, CACHE_DCAR, CACHE_ICAR;
output cache_done;

reg[16:0] mar_address;
reg[31:0] instruction;
reg[31:0] cache_data[0:31], cache_instruction[0:31];

wire cd, ci;

always @(posedge clk)
	if(scm)
	begin
   	//	mar_address <= 
	end

assign CACHE_MAR = mar_address;
assign CACHE_IR = instruction;

/*
always @*
if(cd)
	begin
		assign CACHE_RAM = cache_data[1]; //hardcoded for now
	end
if(ci)
	begin
		assign CACHE_RAM = cache_instruction[1]; //hardcoded for now
	end
*/
endmodule

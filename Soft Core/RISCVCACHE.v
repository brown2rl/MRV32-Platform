// first iteration, 6 rightmost bits are 0, next iteration
// cache word = 32 bytes
// inputs: ram, pc, regs
// outputs: ir, ram, mar
// a few hard coded instructions
// states: done, idle, ram, ram_full, pc, pc_full, regs, regs_full, ir, ir_full, mar, mar_full 
// cache control bit input
// perifrials and regs are cache_data
// data cache address register module (DCAR)
// instruction cache address register module (ICAR)
 
module CACHE(clk, scm, pc);

input clk, scm, pc; //indicators, rst, srr8, srr16, srr32, sramrs8, sramrs16, sramrs32, sramru8, sramru16, byte_ready, dev_start_signal, sdevram;
input[31:0] PC_CACHE, REGS_CACHE, RAM_CACHE, CSR_DEV_BUS_IN, CSR_DEV_BUS_OUT;

output[31:0] CACHE_IR, CACHE_RAM, CACHE_MAR, CACHE_REGS, CACHE_DCAR, CACHE_ICAR;
output cache_done;

reg[31:0] mar_address; // may need to change to 17
reg[31:0] instruction;
reg[31:0] cache_data[0:31], cache_instruction[0:31];
reg[7:0] mar_index, ram_index, regs_index, ir_index, pc_index;
reg[3:0] done, idle, ram_state, ram_full_state, pc_state, pc_full_state, regs_state, regs_full_state, ir_state, ir_full_state, mar_state, mar_full_state, bus_state, bus_full_state, current_state, next_state;

reg cd, ci, done, idle, ram, pc, regs;

initial
	begin
		cd, ci, cache_done, done, idle, ram, pc, regs = 0;
		done = 4'b0000;
		idle = 4'b0001;
		ram_state = 4'b0010;
		ram_full_state = 4'b0011;
		pc_state = 4'b0100;
		pc_full_state = 4'b0101;
		regs_state = 4'b0110;
		regs_full_state = 4'b0111;
		ir_state = 4'b1000;
		ir_full_state = 4'b1001;
		mar_state = 4'b1010;
		mar_full_state = 4'b1011;
		bus_state = 4'b1100;
		bus_full_state = 4'b1101;
		current_state = idle;
		next_state = done;		
	end



always @(posedge clk)
	current_state <= next_state;
	
	if(scm && current_state == mar_state)
		begin
   	//		mar_address <= cache_data[mar_index];
	//
		end
	if(current_state == ir_state)
		begin
	//		instruction <= cache_instruction[ir_index];
		end

assign CACHE_MAR = mar_address;
assign CACHE_IR = instruction;

/*
always @*
if(current_state == mar_full_state)
	begin
		scm = 0;
	end

else if(current_state == ram_state && cd ^ ci)
	begin
		if(cd)
			begin
				assign CACHE_RAM = cache_data[ram_index];
			end
		if(ci)
			begin
				assign CACHE_RAM = cache_instruction[ram_index];
			end
	end


*/
endmodule

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
 
module CACHE(clk, scm, spm);

input clk, scm, spm; //indicators, rst, srr8, srr16, srr32, sramrs8, sramrs16, sramrs32, sramru8, sramru16, byte_ready, dev_start_signal, sdevram;
input[31:0] PC_CACHE, REGS_CACHE, RAM_CACHE, CSR_DEV_BUS_IN, CSR_DEV_BUS_OUT;
input[279] DCAR_CACHE, ICAR_CACHE;

output[31:0] CACHE_IR, CACHE_RAM, CACHE_MAR, CACHE_REGS;
output[278:0] CACHE_DCAR, CACHE_ICAR;
output cache_done;

reg[31:0] mar_address; //  tag + 5 bit index + 5 bit offset

reg[31:0] cache_word;
reg[279:0] cache_data[0:31], cache_instruction[0:31]; // data reg -> 0-10: mar, 11-19: regs, 20-30: pc; instruction reg -> 0-16: pc, 17-31: ram
reg[278:0] cache_data_temp;
reg[7:0] mar_index, ram_index, regs_index, ir_index, pc_index;
// index_instruction;
reg[3:0] done, idle, ram_state, ram_full_state, pc_state, pc_full_state, regs_state, regs_full_state, ir_state, ir_full_state, mar_state, mar_full_state, bus_state, bus_full_state, current_state, next_state;
reg cd, ci;

reg[ index = PC_CACHE[9:5];
reg[4:0] offset = PC_CACHE[4:0];
reg[7:0] offset_bit;

initial
	begin
		cd, ci, cache_done = 0;
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
		DCAR_CACHE[279] = 1'b0;		
	end



always @(posedge clk)
	begin
		current_state <= next_state;

		if(scm)
			begin
				index_data <= DCAR_CACHE[9:5];
				offset_data <= DCAR_CACHE[4:0];
				cache_data[index_data] <= DCAR_CACHE[278:0];
				DCAR_CACHE[279] <= 1;
   				mar_address <= cache_data[offset_data];
				cache_data_temp <= cache_data[index_data];
			end
	end

always @(posedge clk)
	begin
		if (cache_data_temp[278] != 1)
			begin 
				current_state <= mar_state; 
			end
		else
			begin
				/* send byte-selected data to ir */
				next_state <= ir_state;
			end
	end

always @*
	begin
		// bit shift
		offset_bit[7:0] = offset[4:0] << 3;

		if (cache_data_temp[277:256] == PC_CACHE[31:10])
			begin
				cache_word = cache_data_temp[offsetbit +: 32];
			end

		if(current_state == mar_full_state)
			begin
				scm = 0;
			end
		else if(current_state == mar_state)
			begin
				scm = 1;
			end
/*
		else if(current_state == ram_state && cd ^ ci)
			begin
				if(cd)
					begin
						CACHE_RAM = cache_data[ram_index];
					end
				if(ci)
					begin
						CACHE_RAM = cache_instruction[ram_index];
					end
*/
	end
endmodule

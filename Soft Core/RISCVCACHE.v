// first iteration, 6 rightmost bits are 0, next iteration
// cache word = 32 bytes
// inputs: ram, pc, regs
// outputs: ir, ram, mar
// a few hard coded instructions
// states: ACCESS, INDEX, IDLE, READ, WRITE, DONE
// cache control bit input 
// perifrials and regs are cache_data
// data cache address register module (DCAR)
// instruction cache address register module (ICAR)
 
module CACHE(clk, scm, spm); 

	input clk, scm; //, spm; //indicators, rst, srr8, srr16, srr32, sramrs8, sramrs16, sramrs32, sramru8, sramru16, byte_ready, dev_start_signal, sdevram; 

	input[31:0] PC_CACHE, REGS_CACHE, RAM_CACHE, CSR_DEV_BUS_IN, CSR_DEV_BUS_OUT; 
	input[279] DCAR_CACHE, ICAR_CACHE; 

	output[31:0] CACHE_IR, CACHE_RAM, CACHE_MAR, CACHE_REGS; 
	output[278:0] CACHE_DCAR, CACHE_ICAR; 

	output cache_done, read_start; 

	reg[31:0] mar_address, cache_word, cache_address; 
	reg[279:0] cache_data[0:31], cache_instruction[0:31]; // data reg -> 0-10: mar, 11-19: regs, 20-30: pc; instruction reg -> 0-16: pc, 17-31: ram 
	reg[278:0] cache_line_data, cache_line_instruction; //32 bytes, tag + 5 bit index + 5 bit offset, consider 64 bytes (256+278) wide 
	reg[3:0] ACCESS, INDEX, IDLE, READ, WRITE, DONE, data_cache_state, instruction_cache_state;
	reg[4:0] address_to_index[0:31]; // stores array indicies, use index to seach for the array index 
	reg[4:0] offset, cache_index; 
	reg[7:0] offset_bit, address_index;
	reg accessed_data, found_index, enqueued_data; 

	localparam b = 0, h = 1, w = 2; 

        wire width = (8 << ((lb || lbu) ? b : (lh || lhu) ? h : w) - 1);

	initial 
		begin 
			ACCESS = 4'b0;
			INDEX = 4'b0001;
			IDLE = 4'B0010;
			READ = 4'b0011;
			WRITE = 4'b0100;
			DONE = 4'b0101;
			ENQUEUED = 4'b0111;
			data_cache_state = IDLE;
			instruction_cache_state = IDLE;
			accessed_data, got_index, read_start = 0;
		end 

	//data_cache access 
	always @(posedge clk) 
		begin 
			if (data_cache_state == ACCESS) 
				begin 
					cache_data_line <= cache_data[cache_index]; 
					accessed_data <= 1; 
				end 
			else 
				begin 
					accessed_data <= 0; 
				end 
		end 

	//address index to cache index 
	always @(posedge clk) 
		begin 
			if (data_cache_state == INDEX)
				begin 
					cache_index <= address_to_index[address_index]; 
					found_index <= 1; 
				end 
			else 
				begin 
					found_index <= 0; 
				end 
		end 

	
	always @* 
		begin 
			address_index = PC_CACHE[9:5];
			
			// bit select
			offset = PC_CACHE[4:0];
 
			// bit shift 
			offset_bit[7:0] = offset[4:0] << 3; 
			word[31:0] = cache_data_line[offset_bit +: 32]; 
			data_out = word[width : 0 ];

			if (cache_line[277:256] == PC_CACHE[31:10]) 
				begin 
					cache_word = cache_data_line[offsetbit +: 32]; 
				end


			read_start = (data_cache_state == READ);
		end 
		
	

	//data cache decision fsm 
	always @(posedge clk) 
		begin 
			if (data_cache_state == IDLE && scm)
				begin 
					data_cache_state <= INDEX; 
				end
 
			if (data_cache_state == INDEX && got_index) 
				begin
					data_cache_state <= ACCESS;
				end

			if (data_cache_state == ACCESS && accessed_data)
				begin
					if (cache_data_line[277:256] == PC_CACHE[31:10] && cache_data_line[278])
						begin
							data_cache_state <= FINISH;
						end
				end
			else
				begin
					data_cache_state <= READ;
				end

			if (data_cache_state == READ)
				begin
					data_cache_state <= WRITE;
				end

			if (data_cache_state == WRITE)
				begin
					data_cache_state <= DONE;
				end

			if (data_cache_state == DONE)
				begin
					data_cache_state <= IDLE;
				end
	end

	assign CACHE_MAR = mar_address;
	assign CACHE_IR = (cache_data_line[277:256] == PC_CACHE[31:10] && cache_data_line[278]) ? cache_data_out : /*RAM RESULTS??*/

endmodule
